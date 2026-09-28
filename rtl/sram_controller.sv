module sram_controller #(
    parameter ADDR_WIDTH = 10, // 주소 비트 수 (1024개의 엔트리)
    parameter DATA_WIDTH = 8   // 데이터 비트 수 (8-bit 양자화 가중치)
)(
    input  logic clk,
    input  logic rst_n,
    
    // 읽기 인터페이스 (MAC 유닛 및 FSM에서 데이터 요청)
    input  logic read_req,
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic signed [DATA_WIDTH-1:0] read_data,
    output logic read_valid,
    
    // 쓰기 인터페이스 (부팅 시 외부에 있는 파이토치 학습 결과를 로드)
    input  logic write_en,
    input  logic [ADDR_WIDTH-1:0] write_addr,
    input  logic signed [DATA_WIDTH-1:0] write_data
);

    // 내부 SRAM 메모리 배열 선언
    // ASIC 합성을 진행할 때는 팹(TSMC, 삼성 등)에서 제공하는 SRAM 매크로로 치환됩니다.
    logic signed [DATA_WIDTH-1:0] memory_array [0:(1<<ADDR_WIDTH)-1];

    // SRAM 쓰기 동작 (동기식)
    always_ff @(posedge clk) begin
        if (write_en) begin
            memory_array[write_addr] <= write_data;
        end
    end
    
    // SRAM 읽기 동작 (1 Cycle 레이턴시)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= '0;
            read_valid <= 1'b0;
        end else begin
            if (read_req) begin
                read_data <= memory_array[read_addr];
                read_valid <= 1'b1;
            end else begin
                read_valid <= 1'b0;
            end
        end
    end

endmodule
