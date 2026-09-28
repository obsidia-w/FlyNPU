module flynpu_top #(
    parameter NUM_NEURONS = 100,
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    
    // 외부 데이터 인터페이스 (가상의 이미지 픽셀 입력)
    input  logic signed [DATA_WIDTH-1:0] pixel_in,
    input  logic pixel_valid,
    
    // 출력 인터페이스 (분류 결과)
    output logic [3:0] class_out, // 0~9 클래스
    output logic out_valid
);

    // 내부 신호 선언
    logic signed [DATA_WIDTH-1:0] neuron_activation [NUM_NEURONS-1:0];
    logic signed [DATA_WIDTH-1:0] synapse_weight;
    logic weight_valid_sig;
    logic mac_enable;
    logic mac_clear;
    
    logic signed [ACCUM_WIDTH-1:0] mac_out;

    // 1. Sparse MAC 유닛 인스턴스화 (핵심 연산기)
    sparse_mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) u_sparse_mac (
        .clk(clk),
        .rst_n(rst_n),
        .activation_in(neuron_activation[0]), // 단순화를 위해 첫 번째 뉴런만 연결 (실제는 NoC 라우터 필요)
        .weight_in(synapse_weight),
        .weight_valid(weight_valid_sig),
        .enable(mac_enable),
        .clear(mac_clear),
        .accum_out(mac_out)
    );

    // 2. FSM (유한 상태 머신) 컨트롤러 구현
    typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
    state_t state, next_state;

    // 상태 전이 (State Transition)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // 다음 상태 및 제어 신호 결정 (Next State & Output Logic)
    always_comb begin
        next_state = state;
        mac_enable = 1'b0;
        mac_clear = 1'b0;
        out_valid = 1'b0;
        weight_valid_sig = 1'b0;
        synapse_weight = '0;
        class_out = '0;

        case (state)
            IDLE: begin
                mac_clear = 1'b1;
                if (pixel_valid) next_state = COMPUTE;
            end
            COMPUTE: begin
                mac_enable = 1'b1;
                // 현재는 하드코딩된 테스트. 추후 SRAM 컨트롤러와 연동하여 CSR 데이터를 꺼내옵니다.
                weight_valid_sig = 1'b1; 
                synapse_weight = 8'h02;  
                next_state = DONE;
            end
            DONE: begin
                out_valid = 1'b1;
                class_out = mac_out[3:0]; // 임시 연결
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
