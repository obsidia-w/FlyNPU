import os
import networkx as nx
import matplotlib.pyplot as plt

def visualize_and_save():
    # 데이터 경로 설정
    base_dir = os.path.dirname(os.path.abspath(__file__))
    graph_path = os.path.join(base_dir, '../../data/optic_lobe_sample.graphml')
    output_image_path = os.path.join(base_dir, '../../data/optic_lobe_sample.png')
    
    print(f"[{graph_path}]에서 그래프 데이터를 불러오는 중...")
    
    try:
        # 그래프 불러오기
        G = nx.read_graphml(graph_path)
    except FileNotFoundError:
        print("그래프 파일이 존재하지 않습니다. 먼저 데이터 추출 스크립트를 실행해 주세요.")
        return
        
    print(f"불러오기 완료! (노드: {G.number_of_nodes()}개, 간선: {G.number_of_edges()}개)")
    
    # 시각화 설정
    plt.figure(figsize=(12, 12), facecolor='white')
    plt.title("FlyNPU: Optic Lobe Connectome Sample (100 Neurons)", fontsize=16)
    
    # 노드 배치 알고리즘 (spring_layout이 연결성 기반으로 보기 좋게 배치함)
    print("그래프 레이아웃 계산 중 (시간이 조금 걸릴 수 있습니다)...")
    pos = nx.spring_layout(G, k=0.15, iterations=50, seed=42)
    
    # 간선(시냅스) 가중치에 따라 선 굵기 조절
    try:
        weights = [float(G[u][v].get('weight', 1.0)) for u, v in G.edges()]
        # 선 굵기를 적당히 스케일링
        max_weight = max(weights) if weights else 1
        edge_widths = [(w / max_weight) * 3.0 + 0.1 for w in weights]
    except Exception:
        edge_widths = 0.5
        
    # 그리기
    nx.draw_networkx_nodes(G, pos, node_size=30, node_color='skyblue', edgecolors='black', linewidths=0.5)
    nx.draw_networkx_edges(G, pos, width=edge_widths, alpha=0.6, edge_color='gray', arrows=True, arrowsize=8)
    
    plt.axis('off') # 축 숨기기
    plt.tight_layout()
    
    # 이미지로 저장
    plt.savefig(output_image_path, dpi=300, bbox_inches='tight')
    print(f"\n✅ 시각화 완료! 이미지가 저장되었습니다: {output_image_path}")

if __name__ == "__main__":
    visualize_and_save()
