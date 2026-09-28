module flynpu_axi_wrapper #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 12 // 4KB 주소 공간
)(
    // AXI4-Lite 전역 클럭 및 리셋
    input  wire S_AXI_ACLK,
    input  wire S_AXI_ARESETN,

    // AXI4-Lite 쓰기 주소 (Write Address) 채널
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,

    // AXI4-Lite 쓰기 데이터 (Write Data) 채널
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire S_AXI_WVALID,
    output wire S_AXI_WREADY,

    // AXI4-Lite 쓰기 응답 (Write Response) 채널
    output wire [1:0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input  wire S_AXI_BREADY,

    // AXI4-Lite 읽기 주소 (Read Address) 채널
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,

    // AXI4-Lite 읽기 데이터 (Read Data) 채널
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input  wire S_AXI_RREADY
);

    // -----------------------------------------------------
    // 1. 메모리 맵(Memory Map) 레지스터 주소 정의
    // -----------------------------------------------------
    localparam ADDR_CTRL   = 12'h000; // 제어 레지스터 (Bit 0: Start, Bit 1: Reset)
    localparam ADDR_STATUS = 12'h004; // 상태 레지스터 (Bit 0: Done)
    localparam ADDR_PIXEL  = 12'h008; // 픽셀 입력 레지스터 (8-bit 입력용)
    localparam ADDR_RESULT_BASE = 12'h100; // 결과값 읽기 시작 주소 (128코어 결과, 각 4바이트)

    // -----------------------------------------------------
    // 2. 내부 제어 레지스터 및 상태 변수
    // -----------------------------------------------------
    logic [31:0] slv_reg_ctrl;
    logic [31:0] slv_reg_pixel;
    logic [127:0][31:0] npu_accum_outs; // NPU의 128개 연산 결과
    logic npu_out_valid;

    // NPU 구동을 위한 연결 신호
    logic npu_rst_n;
    logic [7:0] npu_pixel_in;
    logic npu_pixel_valid;

    assign npu_rst_n = S_AXI_ARESETN & ~slv_reg_ctrl[1]; // 소프트웨어 리셋 기능
    assign npu_pixel_in = slv_reg_pixel[7:0];
    assign npu_pixel_valid = slv_reg_ctrl[0]; // Start 비트가 1이 되면 픽셀 주입

    // -----------------------------------------------------
    // 3. AXI 쓰기(Write) 로직 (CPU -> NPU 레지스터 쓰기)
    // -----------------------------------------------------
    logic aw_en;
    logic axi_awready, axi_wready, axi_bvalid;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = 2'b00; // OKAY
    assign S_AXI_BVALID  = axi_bvalid;

    always_ff @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            slv_reg_ctrl <= 0;
            slv_reg_pixel <= 0;
            aw_en <= 1'b1;
        end else begin
            // 쓰기 주소 및 데이터 핸드셰이크
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end

            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end

            // 실제 레지스터에 데이터 쓰기
            if (axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID) begin
                case (S_AXI_AWADDR)
                    ADDR_CTRL:  slv_reg_ctrl <= S_AXI_WDATA;
                    ADDR_PIXEL: slv_reg_pixel <= S_AXI_WDATA;
                    default: ; // 결과 레지스터는 읽기 전용이므로 쓰기 무시
                endcase
            end

            // 쓰기 응답(BVALID)
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
                aw_en <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------
    // 4. AXI 읽기(Read) 로직 (NPU 레지스터 -> CPU 읽기)
    // -----------------------------------------------------
    logic axi_arready, axi_rvalid;
    logic [31:0] axi_rdata;

    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RVALID  = axi_rvalid;
    assign S_AXI_RRESP   = 2'b00; // OKAY
    assign S_AXI_RDATA   = axi_rdata;

    always_ff @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                // 주소 디코딩을 통한 데이터 읽기
                if (S_AXI_ARADDR == ADDR_CTRL) begin
                    axi_rdata <= slv_reg_ctrl;
                end else if (S_AXI_ARADDR == ADDR_STATUS) begin
                    axi_rdata <= {31'b0, npu_out_valid}; // 최하위 비트에 Done 상태 반환
                end else if (S_AXI_ARADDR == ADDR_PIXEL) begin
                    axi_rdata <= slv_reg_pixel;
                end else if (S_AXI_ARADDR >= ADDR_RESULT_BASE && S_AXI_ARADDR < (ADDR_RESULT_BASE + 128*4)) begin
                    // 결과 배열 읽기 (예: 주소가 0x100이면 코어 0, 0x104면 코어 1)
                    int core_idx;
                    core_idx = (S_AXI_ARADDR - ADDR_RESULT_BASE) / 4;
                    axi_rdata <= npu_accum_outs[core_idx];
                end else begin
                    axi_rdata <= 32'hDEADBEEF; // 에러/잘못된 주소
                end
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------
    // 5. 대망의 128-Core FlyNPU 실체화 인스턴스
    // -----------------------------------------------------
    flynpu_scaled_core u_flynpu_core (
        .clk(S_AXI_ACLK),
        .rst_n(npu_rst_n),
        .pixel_in(npu_pixel_in),
        .pixel_valid(npu_pixel_valid),
        .accum_outs(npu_accum_outs),
        .out_valid(npu_out_valid)
    );

endmodule
