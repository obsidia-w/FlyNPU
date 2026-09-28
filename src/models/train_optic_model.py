import os
import torch
import torch.nn as nn
import torch.optim as optim
import networkx as nx
import torchvision
import torchvision.transforms as transforms
from torch.utils.data import DataLoader

class MaskedConnectomeLayer(nn.Module):
    """
    초파리 뇌 연결망(Connectome)의 희소성(Sparsity)을 반영한 커스텀 레이어.
    실제 학습을 위해 Dense 행렬과 이진 마스크(Binary Mask)를 사용합니다.
    (NPU에서는 이 마스크를 활용해 불필요한 연산을 0으로 건너뜁니다.)
    """
    def __init__(self, num_nodes, graph_path):
        super().__init__()
        self.num_nodes = num_nodes
        
        # 1. 생물학적 마스크(Sparsity) 로드 및 생성
        self.mask = self._create_mask_from_graph(graph_path)
        
        # 2. 학습 가능한 가중치 (초기에는 마스크와 동일한 구조로 초기화)
        self.weight = nn.Parameter(torch.randn(num_nodes, num_nodes) * 0.1)
        self.bias = nn.Parameter(torch.zeros(num_nodes))
        
        self.activation = nn.ReLU()

    def _create_mask_from_graph(self, graph_path):
        G = nx.read_graphml(graph_path)
        node_list = list(G.nodes())
        node_to_idx = {node: i for i, node in enumerate(node_list)}
        
        # 0으로 채워진 마스크 생성
        mask = torch.zeros((self.num_nodes, self.num_nodes), dtype=torch.float32)
        
        # 시냅스가 있는 곳만 1로 설정
        for u, v in G.edges():
            mask[node_to_idx[u], node_to_idx[v]] = 1.0
            
        # GPU 연산을 대비해 buffer로 등록 (학습되지 않는 고정값)
        self.register_buffer('fixed_mask', mask)
        return mask

    def forward(self, x):
        # 가중치에 마스크를 씌워 강제로 Sparse하게 만듦
        # W_sparse = W_dense * Mask
        sparse_weight = self.weight * self.fixed_mask
        
        # 선형 변환: y = x * W^T + b
        out = torch.matmul(x, sparse_weight.t()) + self.bias
        return self.activation(out)

class FlyVisionModel(nn.Module):
    def __init__(self, input_dim, connectome_nodes, num_classes, graph_path):
        super().__init__()
        # 1. 망막/시신경 계층 (이미지 픽셀 -> Optic Lobe 입력)
        self.retina_layer = nn.Linear(input_dim, connectome_nodes)
        self.retina_act = nn.ReLU()
        
        # 2. 초파리 시각계 커넥톰 모방 계층 (Sparse Layer)
        self.optic_lobe = MaskedConnectomeLayer(connectome_nodes, graph_path)
        
        # 3. 뇌 중심부 분류/판단 계층 (출력)
        self.brain_out = nn.Linear(connectome_nodes, num_classes)

    def forward(self, x):
        x = x.view(x.size(0), -1) # Flatten (배치, 784)
        x = self.retina_act(self.retina_layer(x))
        x = self.optic_lobe(x)
        x = self.brain_out(x)
        return x

def train_model():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    graph_path = os.path.join(base_dir, '../../data/optic_lobe_sample.graphml')
    
    print("--- FlyNPU: Pytorch Training using Sparse Connectome ---")
    
    # 하이퍼파라미터
    input_dim = 28 * 28 # MNIST 이미지 크기
    connectome_nodes = 100 # 우리가 추출한 100개의 뉴런
    num_classes = 10 # 0~9 숫자 분류
    epochs = 5
    
    # 모델 초기화
    print(f"모델 초기화 중... (커넥톰 파일: {graph_path})")
    model = FlyVisionModel(input_dim, connectome_nodes, num_classes, graph_path)
    
    # 손실 함수 및 최적화
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.005) # 학습률 약간 조정
    
    # MNIST 데이터셋 다운로드 및 로드 (빠른 테스트를 위해)
    print("MNIST 데이터셋을 준비합니다...")
    transform = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.5,), (0.5,))])
    data_dir = os.path.join(base_dir, '../../data/')
    train_dataset = torchvision.datasets.MNIST(root=data_dir, train=True, transform=transform, download=True)
    
    # 정확도를 유의미하게 높이기 위해 5000개 샘플 사용
    subset_indices = range(5000)
    train_subset = torch.utils.data.Subset(train_dataset, subset_indices)
    train_loader = DataLoader(train_subset, batch_size=32, shuffle=True)
    
    print(f"\n본격적인 학습 시작! (총 {len(train_subset)}개 이미지 샘플 사용)")
    model.train()
    
    for epoch in range(epochs):
        running_loss = 0.0
        correct = 0
        total = 0
        
        for i, (inputs, labels) in enumerate(train_loader):
            optimizer.zero_grad()
            
            # Forward
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            
            # Backward
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            
            # 정확도 계산
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
        print(f"[Epoch {epoch+1}] Loss: {running_loss/len(train_loader):.4f} | Accuracy: {100 * correct / total:.2f}%")
        
    print("\n✅ 학습 테스트 완료! 초파리 커넥톰 모델이 이미지를 보고 패턴을 학습했습니다.")
    print("훈련된 이 모델의 가중치(Weight)를 나중에 하드웨어 설계 시 메모리(SRAM)에 집어넣어 테스트할 것입니다.")

if __name__ == "__main__":
    train_model()
