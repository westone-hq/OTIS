# 🎛️ 하드웨어 측정 설정 (Capture Config)

스마트폰의 내장 센서들을 통해 진동을 캡처할 때, 어떤 주기로 얼마만큼의 데이터를 수집할지 하드웨어의 동작 지침을 결정하는 스크립트입니다.

## 📄 관련 스크립트
*   **[capture_config.dart](file:///c:/Users/User/Desktop/OTIS/lib/domain/capture/capture_config.dart)**
*   **[sample_interval.dart](file:///c:/Users/User/Desktop/OTIS/lib/domain/capture/sample_interval.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 샘플링 레이트(Sampling Rate) 설정
- 1초에 몇 번 센서 데이터를 가져올지(예: 100Hz, 200Hz 등) 결정하는 환경 변수 역할을 합니다.

### 2. 센서 노이즈 필터링 정책
- 미세한 손떨림이나 비정상적인 튀는 값을 배제하기 위한 하드웨어 수집 단계에서의 민감도를 세팅합니다.
