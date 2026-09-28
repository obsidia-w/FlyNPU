module flynpu_parallel_core #(
    parameter NUM_MACS = 4, // 4개의 병렬 연산기 배치 (Spatial Architecture)
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input  logic clk,
    input  logic rst_n,
    
    // 입력 포트: 데이터 재사용(Data Reuse)을 위해 하나의 입력(예: 픽셀)이 모든 MAC으로 브로드캐스트됨.
    input  logic signed [DATA_WIDTH-1:0] pixel_in,
    input  logic pixel_valid,
    
    // 출력 포트: 각 MAC에서 누적된 출력 배열
    output logic signed [NUM_MACS-1:0][ACCUM_WIDTH-1:0] accum_outs,
    output logic out_valid
);

    // 내부 신호 선언
    logic mac_enable [NUM_MACS-1:0];
    logic mac_clear [NUM_MACS-1:0];
    logic signed [DATA_WIDTH-1:0] sram_read_data [NUM_MACS-1:0];
    logic sram_read_valid [NUM_MACS-1:0];
    
    logic sram_read_req;
    logic [ADDR_WIDTH-1:0] sram_read_addr;

    // [SystemVerilog Generate Block] 여러 개의 병렬 SRAM 뱅크와 MAC 유닛 인스턴스화
    genvar i;
    generate
        for (i = 0; i < NUM_MACS; i++) begin : pe_array
            
            // 1. 개별 SRAM 뱅크 (각 MAC별로 전용 가중치 저장소 할당 = 메모리 대역폭 문제 해결)
            sram_controller #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) u_sram_bank (
                .clk(clk),
                .rst_n(rst_n),
                .read_req(sram_read_req),
                .read_addr(sram_read_addr),
                .read_data(sram_read_data[i]),
                .read_valid(sram_read_valid[i]),
                .write_en(1'b0), // 임시 하드코딩
                .write_addr('0),
                .write_data('0)
            );
            
            // 2. 개별 Sparse MAC 유닛 (연산기)
            sparse_mac #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACCUM_WIDTH(ACCUM_WIDTH)
            ) u_mac (
                .clk(clk),
                .rst_n(rst_n),
                .activation_in(pixel_in), // ⭐️ 브로드캐스트 (하나의 입력을 다같이 공유)
                .weight_in(sram_read_data[i]),
                .weight_valid(sram_read_valid[i]), // 0이면 스위칭 전력 절감
                .enable(mac_enable[i]),
                .clear(mac_clear[i]),
                .accum_out(accum_outs[i])
            );
            
        end
    endgenerate

    // 3. 통합 스케줄링 컨트롤러 (모든 MAC 및 SRAM을 동시에 제어)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_read_req <= 1'b0;
            sram_read_addr <= '0;
            out_valid <= 1'b0;
            for (int j = 0; j < NUM_MACS; j++) begin
                mac_enable[j] <= 1'b0;
                mac_clear[j] <= 1'b1;
            end
        end else begin
            if (pixel_valid) begin
                sram_read_req <= 1'b1;
                sram_read_addr <= sram_read_addr + 1; // 단순 선형 읽기
                out_valid <= 1'b0;
                
                for (int j = 0; j < NUM_MACS; j++) begin
                    mac_clear[j] <= 1'b0;
                    mac_enable[j] <= 1'b1;
                end
            end else begin
                sram_read_req <= 1'b0;
                if (sram_read_addr > 0) out_valid <= 1'b1;
                
                for (int j = 0; j < NUM_MACS; j++) begin
                    mac_enable[j] <= 1'b0;
                end
            end
        end
    end

endmodule
