module flynpu_tb;

    // 클록 및 리셋 신호
    logic clk;
    logic rst_n;
    
    // 입력 자극(Stimulus)
    logic signed [7:0] pixel_in;
    logic pixel_valid;
    
    // 출력 확인(Monitor)
    logic [3:0] class_out;
    logic out_valid;
    
    // 설계한 최상위 모듈(Device Under Test) 인스턴스화
    flynpu_top #(
        .NUM_NEURONS(100),
        .DATA_WIDTH(8),
        .ACCUM_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .class_out(class_out),
        .out_valid(out_valid)
    );
    
    // 클록 제너레이터 (100MHz 가정)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // 시뮬레이션 시퀀스 시작
    initial begin
        // 1. 초기화 및 리셋 인가
        rst_n = 0;
        pixel_in = '0;
        pixel_valid = 0;
        #25 rst_n = 1;
        
        $display("========================================");
        $display("   FlyNPU Testbench Simulation Start    ");
        $display("========================================");
        
        // 2. 가상의 픽셀 입력 주입 (망막 자극 시뮬레이션)
        @(posedge clk);
        pixel_valid = 1;
        pixel_in = 8'h1A; // 임의의 활성화 값 1
        @(posedge clk);
        pixel_in = 8'h2B; // 임의의 활성화 값 2
        @(posedge clk);
        pixel_valid = 0;
        
        // 3. 연산 완료 대기 
        #200;
        
        $display("Simulation Finished.");
        $finish;
    end
    
    // 파이썬에서 압축 추출한 CSR 가중치 파일(.mem) 로드 테스트
    logic [7:0] csr_values [0:170];
    initial begin
        // PyTorch 모델에서 뽑은 171개의 8비트 가중치 파일을 시뮬레이터 메모리에 할당
        // 실제 ASIC 칩에서는 이 데이터들이 부팅 시 Flash에서 SRAM으로 복사됩니다.
        $readmemh("data/verilog_mem/csr_values.mem", csr_values);
        #1;
        $display("Loaded CSR Values. First value: %h", csr_values[0]);
    end

    // 파형(Waveform) 덤프 설정 (GTKWave 등을 위함)
    initial begin
        $dumpfile("flynpu_tb.vcd");
        $dumpvars(0, flynpu_tb);
    end

endmodule
