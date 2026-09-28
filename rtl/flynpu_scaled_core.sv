module flynpu_scaled_core (
    input  logic clk,
    input  logic rst_n,
    
    // 글로벌 입력 (하나의 픽셀이 전체 연산기에 브로드캐스트 됨)
    input  logic signed [7:0] pixel_in,
    input  logic pixel_valid,
    
    // 거대 배열 출력 (예: 128개의 MAC 결과)
    output logic signed [127:0][31:0] accum_outs,
    output logic out_valid
);

    /* 
     * [Massive Scale-Up 아키텍처 인스턴스화]
     * 이미 설계된 병렬 코어의 파라미터(NUM_MACS)를 변경하는 것만으로
     * 하드웨어 칩 내부에서 연산기와 메모리가 자동으로 복제(Generate)됩니다.
     * 여기서는 검증을 위해 기존 4개에서 128개로 스케일업을 진행합니다. 
     * (실제 팹(Fab)에 맡길 때는 이 숫자를 4096으로 변경하면 됩니다.)
     */
    flynpu_parallel_core #(
        .NUM_MACS(128),     // 연산기(MAC)와 SRAM 뱅크를 128개로 확장
        .DATA_WIDTH(8),
        .ACCUM_WIDTH(32),
        .ADDR_WIDTH(10)
    ) massive_array (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .accum_outs(accum_outs),
        .out_valid(out_valid)
    );

endmodule
