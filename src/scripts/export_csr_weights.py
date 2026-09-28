import os
import torch
import numpy as np
from scipy.sparse import csr_matrix
import sys

# 이전에 만든 모델의 경로를 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.train_optic_model import FlyVisionModel

def export_weights_to_csr_verilog(model_weights, mask, output_dir):
    """
    PyTorch 가중치와 마스크를 적용한 희소 행렬을 CSR(Compressed Sparse Row) 포맷으로 변환 후
    Verilog $readmemh 함수로 읽을 수 있는 .mem 텍스트 파일로 추출합니다.
    """
    # 1. 마스크를 씌운 실제 유효 가중치 계산
    effective_weights = (model_weights * mask).detach().cpu().numpy()
    
    # 양자화 (하드웨어 테스트를 위해 Float -> 8비트 정수로 스케일링)
    # 실제로는 세밀한 QAT/PTQ 기법을 쓰지만, 여기서는 단순화하여 -128~127 범위로 매핑합니다.
    max_val = np.abs(effective_weights).max()
    if max_val > 0:
        quantized_weights = np.round((effective_weights / max_val) * 127).astype(np.int8)
    else:
        quantized_weights = effective_weights.astype(np.int8)
        
    # 2. SciPy를 이용해 CSR 형식으로 변환
    sparse_csr = csr_matrix(quantized_weights)
    
    # CSR 포맷의 3가지 핵심 배열 추출
    values = sparse_csr.data           # 0이 아닌 실제 데이터 값들 (가중치)
    col_indices = sparse_csr.indices   # 각 데이터가 위치한 열(Column) 인덱스
    row_ptrs = sparse_csr.indptr       # 각 행(Row)이 시작되는 values 배열 내의 포인터
    
    print("--- CSR 변환 통계 ---")
    print(f"전체 파라미터 수: {effective_weights.size}")
    print(f"0이 아닌 유효 파라미터 수: {len(values)}")
    print(f"최종 Sparsity: {1.0 - len(values)/effective_weights.size:.4%}")
    
    # 3. Verilog 메모리 초기화 파일(.mem)로 저장 (Hex 포맷)
    os.makedirs(output_dir, exist_ok=True)
    
    # 값을 2의 보수 Hex 문자열로 변환하여 저장하는 헬퍼
    def save_hex(filename, data_array, bits=8):
        with open(os.path.join(output_dir, filename), 'w') as f:
            for val in data_array:
                # 음수 처리를 위한 비트마스킹 (2의 보수)
                val_masked = int(val) & ((1 << bits) - 1)
                format_str = f"{{:0{bits//4}x}}\n"
                f.write(format_str.format(val_masked))
                
    save_hex('csr_values.mem', values, bits=8)
    save_hex('csr_col_indices.mem', col_indices, bits=16) # 인덱스는 16비트로 저장
    save_hex('csr_row_ptrs.mem', row_ptrs, bits=16)       # 포인터도 16비트로 저장
    
    print(f"\n✅ CSR 포맷 메모리 파일 추출이 완료되었습니다. 저장 위치: {output_dir}")

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    graph_path = os.path.join(base_dir, '../../data/optic_lobe_sample.graphml')
    output_dir = os.path.join(base_dir, '../../data/verilog_mem/')
    
    # 모델 껍데기 인스턴스화 (원래는 .pth 파일에서 훈련된 가중치를 로드해야 함)
    input_dim = 28 * 28
    connectome_nodes = 100
    num_classes = 10
    
    # 테스트용으로 모델 생성 후 임의의(초기화된) 가중치로 추출 진행
    print("모델 구조를 불러옵니다...")
    model = FlyVisionModel(input_dim, connectome_nodes, num_classes, graph_path)
    
    # Optic Lobe 층의 가중치와 마스크 추출
    optic_weights = model.optic_lobe.weight
    optic_mask = model.optic_lobe.fixed_mask
    
    export_weights_to_csr_verilog(optic_weights, optic_mask, output_dir)

if __name__ == "__main__":
    main()
