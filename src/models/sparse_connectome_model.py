import os
import torch
import torch.nn as nn
import networkx as nx
import numpy as np

class SparseConnectomeLayer(nn.Module):
    def __init__(self, num_nodes, sparse_adj):
        super().__init__()
        self.num_nodes = num_nodes
        # 신경망 가중치로 사용될 희소 행렬 (학습 가능하도록 Parameter로 등록 가능, 여기서는 고정값(학습 전)으로 테스트)
        self.sparse_weight = nn.Parameter(sparse_adj)
        
        # 활성화 함수 (초파리 신경망의 Non-linear 특성을 모방하기 위해 ReLU 사용)
        self.activation = nn.ReLU()

    def forward(self, x):
        # x: [배치 크기, 노드 수] (각 뉴런의 입력 신호 강도)
        # Sparse Matrix Multiplication (희소 행렬 곱셈)
        # NPU의 핵심 기능이 될 연산: (입력 신호) x (시냅스 가중치)
        # torch.sparse.mm 은 [희소행렬, 밀집행렬] 곱을 지원하므로 차원을 맞춰줍니다.
        
        # x.t() -> [노드 수, 배치 크기]
        out = torch.sparse.mm(self.sparse_weight, x.t())
        
        # 다시 원래 차원으로 복구 후 활성화 함수 통과 -> [배치 크기, 노드 수]
        out = self.activation(out.t())
        return out

def create_sparse_tensor_from_graph(G):
    """NetworkX 그래프를 PyTorch 희소 텐서(Sparse Tensor)로 변환"""
    num_nodes = G.number_of_nodes()
    
    # 노드 ID를 0부터 시작하는 인덱스로 매핑
    node_list = list(G.nodes())
    node_to_idx = {node: i for i, node in enumerate(node_list)}
    
    indices = []
    values = []
    
    for u, v, data in G.edges(data=True):
        idx_u = node_to_idx[u]
        idx_v = node_to_idx[v]
        weight = float(data.get('weight', 1.0))
        
        # 방향성 그래프의 경우 adjacency matrix 구성 (post <- pre)
        indices.append([idx_v, idx_u])
        values.append(weight)
        
    indices = torch.tensor(indices, dtype=torch.long).t()
    values = torch.tensor(values, dtype=torch.float32)
    
    # 희소 텐서 생성
    sparse_adj = torch.sparse_coo_tensor(indices, values, size=(num_nodes, num_nodes))
    return sparse_adj

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    graph_path = os.path.join(base_dir, '../../data/optic_lobe_sample.graphml')
    
    print("1. 추출된 뇌 구조 그래프(.graphml)를 로드합니다...")
    if not os.path.exists(graph_path):
        print("그래프 파일이 없습니다. 데이터 추출 스크립트를 먼저 실행하세요.")
        return
        
    G = nx.read_graphml(graph_path)
    num_nodes = G.number_of_nodes()
    num_edges = G.number_of_edges()
    
    print("2. 파이토치 희소 텐서(Sparse Tensor)로 변환합니다...")
    sparse_adj = create_sparse_tensor_from_graph(G)
    
    # Sparsity(희소성) 계산: 0이 아닌 값의 비율
    sparsity = 1.0 - (num_edges / (num_nodes * num_nodes))
    print(f"   - 노드 개수(뉴런): {num_nodes}")
    print(f"   - 간선 개수(시냅스): {num_edges}")
    print(f"   - 매트릭스 희소성(Sparsity): {sparsity:.4%} (대부분의 값이 0임)")
    
    print("\n3. SparseConnectomeLayer(NPU 모사 계층)를 초기화합니다...")
    model = SparseConnectomeLayer(num_nodes, sparse_adj)
    
    print("4. 가상의 망막 입력(Retinal Input) 신호를 생성하여 추론(Forward)을 테스트합니다...")
    batch_size = 4
    # 가상의 입력 신호 (랜덤하게 자극 부여)
    dummy_input = torch.rand((batch_size, num_nodes))
    
    output = model(dummy_input)
    
    print("\n✅ 모델 연산 성공!")
    print(f"   - 입력 신호 크기: {dummy_input.shape} (배치 {batch_size}, 뉴런 {num_nodes})")
    print(f"   - 출력 신호 크기: {output.shape} (배치 {batch_size}, 뉴런 {num_nodes})")
    print(f"   - 첫 번째 배치의 상위 5개 뉴런 출력값: \n{output[0, :5].detach().numpy()}")
    print("\n이 결과를 바탕으로 하드웨어 설계 시 MAC(곱셈-누산기) 유닛의 동작을 검증하게 됩니다.")

if __name__ == "__main__":
    main()
