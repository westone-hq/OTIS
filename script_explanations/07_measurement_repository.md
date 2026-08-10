# 🗄️ 측정 데이터 저장소 (Measurement Repository)

측정 완료 후 가공된 진동 데이터 및 메타데이터를 영구적으로 저장하고 검색할 수 있도록 관리하는 스크립트입니다.

## 📄 관련 스크립트
*   **[measurement_repository.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/measurement_repository.dart)**
*   **[measurement_result.dart](file:///c:/Users/User/Desktop/OTIS/lib/model/measurement_result.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 측정 결과 영구 저장
- `measuring_screen.dart`에서 측정이 끝나 생성된 결과 객체나 파일 경로를 디바이스의 로컬 DB 또는 안전한 디렉토리에 분류하여 저장합니다.

### 2. 과거 기록 열람
- `history_screen.dart` 등에서 과거에 측정한 기록 리스트를 불러오거나 특정 현장의 상세 데이터를 가져올 때 사용하는 데이터 접근 계층(DAO) 역할을 합니다.
