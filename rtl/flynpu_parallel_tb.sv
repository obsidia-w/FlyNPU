module flynpu_parallel_tb;

    logic clk;
    logic rst_n;
    
    // 입력 (브로드캐스트)
    logic signed [7:0] pixel_in;
    logic pixel_valid;
    
    // 출력 (병렬 MAC 누산 결과들)
    logic signed [3:0][31:0] accum_outs;
    logic out_valid;

    // 4개의 병렬 MAC을 가진 코어 인스턴스화
    flynpu_parallel_core #(.NUM_MACS(4)) dut (.*);

    // 100MHz 클록 생성
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 자극 인가 시퀀스
    initial begin
        rst_n = 0; 
        pixel_valid = 0; 
        pixel_in = '0;
        #25 rst_n = 1;
        
        $display("========================================");
        $display(" FlyNPU Parallel Core Simulation Start  ");
        $display("========================================");
        
        // 이미지 픽셀 브로드캐스트 테스트
        @(posedge clk); 
        pixel_valid = 1; 
        pixel_in = 8'h1A; // 모든 4개 MAC에 동시 전달됨
        
        @(posedge clk); 
        pixel_in = 8'h05;
        
        @(posedge clk); 
        pixel_valid = 0;
        
        #150;
        $display("Simulation Finished.");
        $finish;
    end

    // Waveform 덤프
    initial begin
        $dumpfile("flynpu_parallel.vcd");
        $dumpvars(0, flynpu_parallel_tb);
    end

endmodule
