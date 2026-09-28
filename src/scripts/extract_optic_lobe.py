import os
import pandas as pd
import networkx as nx
from caveclient import CAVEclient
import time
import warnings
warnings.filterwarnings("ignore") # urllib3 SSL 경고 숨김 처리

DATASTORE_URL = "https://global.daf-apis.com"
DATASET_NAME = "flywire_fafb_public"

def setup_client():
    client = CAVEclient(DATASET_NAME, server_address=DATASTORE_URL)
    return client

def extract_optic_lobe_neurons(client, limit=50):
    print(f"FlyWire 데이터베이스에서 시각계(Optic) 뉴런 상위 {limit}개를 가져옵니다...")
    df = client.materialize.query_table(
        'hierarchical_neuron_annotations',
        filter_equal_dict={'classification_system': 'super_class', 'cell_type': 'optic'},
        limit=limit
    )
    # 루트 ID 추출 (실제 뉴런의 고유 ID)
    root_ids = df['pt_root_id'].unique().tolist()
    print(f"고유한 시각계 뉴런 {len(root_ids)}개를 찾았습니다.")
    return root_ids

def extract_synapses(client, root_ids):
    print("뉴런 간 시냅스 데이터를 추출하여 가중치를 계산합니다...")
    try:
        # synapses_nt_v1 테이블에서 선택된 뉴런들 간의 연결만 추출
        # pre(시냅스 전 뉴런)와 post(시냅스 후 뉴런)가 모두 추출한 시각계 뉴런인 경우
        synapse_df = client.materialize.query_table(
            'synapses_nt_v1',
            filter_in_dict={'pre_pt_root_id': root_ids, 'post_pt_root_id': root_ids}
        )
        print(f"총 {len(synapse_df)}개의 시냅스(접점)를 찾았습니다.")
        
        # 두 뉴런 사이에 여러 개의 시냅스가 있을 수 있으므로 그룹화하여 weight로 변환
        edges = synapse_df.groupby(['pre_pt_root_id', 'post_pt_root_id']).size().reset_index(name='weight')
        print(f"중복 연결을 병합하여 총 {len(edges)}개의 유효 간선(Edge)을 생성했습니다.")
        return edges
    except Exception as e:
        print(f"시냅스 추출 중 오류 발생: {e}")
        return pd.DataFrame(columns=['pre_pt_root_id', 'post_pt_root_id', 'weight'])

def save_to_graph(nodes, edges_df, output_path):
    G = nx.DiGraph()
    G.add_nodes_from(nodes)
    
    # 간선 추가 (weight 속성 포함)
    for _, row in edges_df.iterrows():
        G.add_edge(row['pre_pt_root_id'], row['post_pt_root_id'], weight=row['weight'])
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    nx.write_graphml(G, output_path)
    print(f"그래프 데이터가 {output_path}에 성공적으로 저장되었습니다.")
    print(f"[최종 요약] 노드 수: {G.number_of_nodes()}, 간선 수: {G.number_of_edges()}")

if __name__ == "__main__":
    print("--- FlyNPU: Optic Lobe Connectome Data Extraction ---")
    client = setup_client()
    
    # 테스트를 위해 100개의 뉴런만 추출 (전체 데이터는 수백만 개이므로 메모리/시간 소요)
    optic_neurons = extract_optic_lobe_neurons(client, limit=100)
    
    if len(optic_neurons) > 0:
        edges_df = extract_synapses(client, optic_neurons)
        
        output_file = os.path.join(os.path.dirname(__file__), '../../data/optic_lobe_sample.graphml')
        save_to_graph(optic_neurons, edges_df, output_file)
        
        print("\n✅ 데이터 추출 및 그래프 저장이 완료되었습니다!")
        print("이제 이 데이터를 PyTorch 모델에 올려서 학습을 진행할 수 있습니다.")
    else:
        print("뉴런을 추출하지 못했습니다.")
