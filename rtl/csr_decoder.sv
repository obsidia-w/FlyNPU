module csr_decoder #(
    parameter PTR_WIDTH = 16,
    parameter IDX_WIDTH = 16
)(
    input  logic clk,
    input  logic rst_n,
    
    // 상위 제어기 입력 (현재 계산 중인 뉴런 행 번호)
    input  logic [PTR_WIDTH-1:0] current_row,
    input  logic row_start, // 새로운 Row 연산 시작 트리거
    
    // SRAM 인터페이스 (CSR 포인터 읽기용)
    output logic ptr_read_req,
    input  logic [PTR_WIDTH-1:0] row_ptr_val,
    input  logic [PTR_WIDTH-1:0] next_row_ptr_val,
    
    // SRAM 인터페이스 (CSR 인덱스 읽기용)
    output logic idx_read_req,
    input  logic [IDX_WIDTH-1:0] col_idx_val,
    
    // MAC 유닛 제어 출력 (디코딩 결과)
    output logic weight_valid,
    output logic [IDX_WIDTH-1:0] target_neuron_idx
);

    logic [PTR_WIDTH-1:0] current_ptr;
    logic [PTR_WIDTH-1:0] end_ptr;
    
    // 상태 머신 선언
    typedef enum logic [1:0] {IDLE, FETCH_PTR, DECODE_ROW} state_t;
    state_t state, next_state;

    // 1. 상태 전이 및 포인터 카운터 로직
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_ptr <= '0;
            end_ptr <= '0;
        end else begin
            state <= next_state;
            
            if (state == FETCH_PTR) begin
                current_ptr <= row_ptr_val;
                end_ptr <= next_row_ptr_val;
            end else if (state == DECODE_ROW && current_ptr < end_ptr) begin
                current_ptr <= current_ptr + 1; // 0이 아닌 유효 데이터만 순회
            end
        end
    end
    
    // 2. 출력 로직 및 다음 상태 결정
    always_comb begin
        next_state = state;
        ptr_read_req = 1'b0;
        idx_read_req = 1'b0;
        weight_valid = 1'b0;
        target_neuron_idx = '0;
        
        case (state)
            IDLE: begin
                if (row_start) begin
                    ptr_read_req = 1'b1;
                    next_state = FETCH_PTR;
                end
            end
            FETCH_PTR: begin
                // SRAM 읽기 레이턴시 (1 Cycle) 대기
                next_state = DECODE_ROW;
            end
            DECODE_ROW: begin
                if (current_ptr < end_ptr) begin
                    idx_read_req = 1'b1; // 컬럼 인덱스 요청
                    weight_valid = 1'b1; // MAC 활성화 신호 전송 (0이 아닌 가중치 발견)
                    target_neuron_idx = col_idx_val;
                end else begin
                    next_state = IDLE; // 해당 행 처리 완료, 대기 상태로 복귀
                end
            end
        endcase
    end

endmodule
