# 🗺️ OTIS 진동 측정 앱: 전체 스크립트 흐름도 (Overall Flow)

이 문서는 OTIS 엘리베이터 진동 측정 앱의 주요 비즈니스 기능이 **실제 어느 스크립트에서 어떻게 구현되어 있는지** 파악하기 위한 전체 흐름 요약입니다. 앱은 크게 [준비] - [측정] - [분석 및 결과] 로 나뉘며 각 역할에 맞는 dart 파일들이 존재합니다.

---

## 🚀 단계별 주요 스크립트 매핑

### Step 1. 앱 실행 및 기본 환경 세팅 (준비 단계)
*   **`[01_auth_repository]` ([auth_repository.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/auth_repository.dart))**: 사번 확인 및 보안을 담당합니다.
*   **`[02_prefs_store]` ([prefs_store.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/prefs_store.dart))**: 최근 입력한 현장 정보를 기억해주는 캐시 스토어입니다.
*   **`[03_metrics_config]` ([metrics_config.dart](file:///c:/Users/User/Desktop/OTIS/lib/model/metrics_config.dart))**: 진동 허용치 등 OTIS 공식 평가 기준을 담고 있는 모델입니다.
*   **`[04_capture_config]` ([capture_config.dart](file:///c:/Users/User/Desktop/OTIS/lib/domain/capture/capture_config.dart))**: 기기의 센서 샘플링 설정 등을 정의합니다.

### Step 2. 측정 시작 및 현장 데이터 수집 (측정 단계)
*   **`[05_sensor_channel]` ([sensor_channel.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/sensor_channel.dart))**: 안드로이드 기기의 실제 가속도/중력 **센서 값을 가지고 오는 곳**입니다. 네이티브와의 통신을 담당합니다.
*   **`[09_measuring_screen]` ([measuring_screen.dart](file:///c:/Users/User/Desktop/OTIS/lib/ui/features/measure/measuring_screen.dart))**: 센서를 켜고 화면을 그리며 **실제 측정이 일어나는 곳**입니다. 데이터를 가공(`grid_resampler.dart`)하고 안전하게 파일로 저장합니다.

### Step 3. 최종 결과 산출 및 리포팅 (결과 단계)
*   **`[07_measurement_repository]` ([measurement_repository.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/measurement_repository.dart))**: 산출된 진동 결과를 DB나 로컬 저장소에 보관 및 관리합니다.
*   **`[06_report_generator]` ([report_generator.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/report_generator.dart))**: 진동 데이터를 읽기 편한 보고서(PDF, CSV)로 변환해주는 역할을 합니다.
*   **`[08_parse_raw]` ([parse_raw.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/parse_raw.dart))**: 구형 EVIMP1 장비의 텍스트 결과물을 해석해 최신 시스템으로 불러오는 통역기입니다.
