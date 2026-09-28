# 🪰 FlyNPU: Drosophila-Inspired Sparse NPU Architecture

**FlyNPU**는 초파리(Fruit Fly) 시각계(Optic Lobe)의 실제 생물학적 뇌 신경망(Connectome) 데이터를 기반으로 설계된 **초저전력 희소(Sparse) AI 반도체 아키텍처**입니다. 

## 🌟 Key Features (주요 특징)
*   **Bio-Inspired Sparsity (98.29%)**: FlyWire 오픈소스 데이터베이스에서 추출한 실제 초파리 시냅스 연결망 데이터를 활용하여 극단적인 희소 행렬 구조를 달성했습니다.
*   **Ultra-Low Power MAC**: 하드웨어 RTL 수준에서 0인 가중치가 들어올 때 연산을 완전히 스킵(Skip)하는 `sparse_mac.sv`를 도입하여 스위칭 전력(Dynamic Power) 소모를 차단했습니다.
*   **Spatial Parallel Architecture**: 데이터 대역폭 문제를 해결하기 위해 4개의 SRAM 뱅크와 4개의 MAC을 병렬로 묶고, 입력 픽셀을 브로드캐스트(Broadcast)하는 `flynpu_parallel_core`를 채택했습니다.
*   **Full-Stack Validation**: PyTorch를 이용한 소프트웨어 정확도 검증(MNIST 93.1% 달성)부터 SystemVerilog 파형 시뮬레이션 및 Yosys 논리 합성(77,918 Gates)까지 모든 스택을 검증했습니다.

## 📂 Project Structure (프로젝트 구조)
*   `data/`: FlyWire API로 추출된 그래프 데이터(`*.graphml`) 및 하드웨어 시뮬레이션용 CSR 포맷 메모리 파일(`*.mem`).
*   `rtl/`: SystemVerilog 하드웨어 코어 설계도 (`sparse_mac.sv`, `sram_controller.sv`, `csr_decoder.sv`, `flynpu_parallel_core.sv` 등).
*   `src/models/`: 희소 텐서를 활용해 98%가 비어있는 상태에서도 학습이 가능함을 증명한 PyTorch 딥러닝 스크립트.
*   `src/scripts/`: CAVEclient 연동 및 가중치 양자화/압축(CSR) 추출 파이썬 스크립트.

## 🚀 How to Run (실행 방법)
### 1. Software (PyTorch)
```bash
# 가상환경 활성화 및 패키지 설치 후
python src/models/train_optic_model.py
```

### 2. Hardware Simulation (Icarus Verilog)
```bash
# 병렬 코어 시뮬레이션 및 파형 추출
iverilog -g2012 -o parallel_sim.out rtl/*.sv
vvp parallel_sim.out
```

## 📝 License
This project is for educational and research purposes. Data provided by the FlyWire Consortium.
