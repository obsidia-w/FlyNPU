module sparse_mac #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    
    // 입력 인터페이스
    input  logic signed [DATA_WIDTH-1:0] activation_in, // 뉴런 입력 신호 (망막 혹은 이전 층)
    input  logic signed [DATA_WIDTH-1:0] weight_in,     // 시냅스 가중치 (SRAM에서 읽어옴)
    input  logic weight_valid,                          // 1: 시냅스 연결 있음, 0: 끊어짐 (Sparsity 핵심)
    input  logic enable,                                // 연산 활성화 신호
    input  logic clear,                                 // 누산기 초기화 신호
    
    // 출력 인터페이스
    output logic signed [ACCUM_WIDTH-1:0] accum_out     // 누적된 계산 결과
);

    logic signed [ACCUM_WIDTH-1:0] accumulator;
    logic signed [ACCUM_WIDTH-1:0] mult_result;

    // 곱셈기 (승산기)
    assign mult_result = activation_in * weight_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
        end else if (clear) begin
            accumulator <= '0;
        end else if (enable) begin
            // ⭐️ 저전력(Low-Power) Sparse 연산의 핵심 ⭐️
            // weight_valid가 1일 때만 덧셈 연산을 수행하고, 0일 때는 레지스터 값을 유지합니다.
            // Clock Gating 등과 결합하면 불필요한 스위칭 전력을 크게 아낄 수 있습니다.
            if (weight_valid) begin
                accumulator <= accumulator + mult_result;
            end
        end
    end

    assign accum_out = accumulator;

endmodule
