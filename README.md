# OTIS 승강기 진동·소음 측정 앱 (Vibration Checker)

OTIS 승강기 설치 및 유지보수 현장에서 승강기 운행 중 발생하는 진동(X, Y, Z축)과 소음(dBA)을 실시간으로 측정하고, OTIS TUNE 규격에 따라 임계를 자동 판정하여 리포트를 생성·공유하는 Flutter 모바일 애플리케이션입니다.

---

## 📱 주요 특징 및 사용자 경험 (Elder UX)

이 애플리케이션은 현장에서 장갑을 끼고 작업하거나 **나이가 있는 현장 작업자(어르신 작업자)**를 위해 설계되었습니다.
* **초대형 터치 타깃 및 시인성**: 최소 터치 영역 56dp(`AppDims.touchMin`), 주 행동 버튼 높이 64dp 풀위드 적용, 본문 폰트 18sp 이상 엄수.
* **원거리 시인성 라이브 뷰**: 측정 중 라이브 화면에서 72sp 크기의 초대형 폰트로 실시간 속도를 표시하여 기기를 바닥에 내려놓고도 서서 확인 가능.
* **3중 상태 표시 (Color + Icon + Text)**: 색약자 및 현장 조도 환경을 고려하여, 임계 초과 상태를 절대 색상만으로 표시하지 않고 **[색상(빨강) + 경고 아이콘(⚠️) + 텍스트("기준 초과")]** 3중으로 동시 표출.
* **한 화면 한 행동 (One Primary Action per Screen)**: 사용자 혼선을 막기 위해 각 화면당 가장 중요한 주 버튼을 1개로 제한.

---

## 🗺️ 화면 구성 및 라우팅 (`lib/features/`)

`go_router` 기반으로 명확하고 안전한 화면 전환을 제공합니다.

| 화면명 | 라우트 경로 | 핵심 기능 및 구성 |
| :--- | :--- | :--- |
| **로그인 Screen** | `/login` | 사번(`OTIS-XXXX` 등) 및 비밀번호 입력, 유효성 검증 |
| **홈 (메인) Screen** | `/` | 제번(`2024F 1447R01`), 현장명(`럭키종합건설/송정동근생`) 등 실데이터 요약 및 [측정 시작] 대형 버튼 |
| **측정 설정 Screen** | `/measure/start` | 5/10/30/60초 측정 타이머 선택 및 스마트폰 바닥 거치 안내 바텀 시트 제공 |
| **측정 라이브 Screen** | `/measure/live` | 실시간 속도(m/s) 72sp 표출, 경과 시간 카운트트, 안전한 측정 중단 다이얼로그 |
| **결과 통합 Screen** | `/result` | 6대 지표(P2P X/Y/Z, 소음, 거리, 속도) 요약 카드 & 8종 시계열 차트 스크롤 뷰 (`fl_chart` 연동) |
| **저장 목록 Screen** | `/history` | 과거 저장된 측정 결과 목록(날짜, 층수, 결과 상태) 조회 및 행 탭 시 상세 결과 이동 |
| **이메일 발송 Sheet** | (Bottom Sheet) | PDF 보고서, RAW 데이터, 차트 이미지, 메일 본문 요약 체크박스 선택 및 발송 |
| **설정 Screen** | `/settings` | 사용자 프로필, 기본 수신 이메일 검증 및 변경, 앱 버전 정보, 로그아웃 확인 다이얼로그 |

---

## 🏗️ 도메인 로직 및 아키텍처 (`lib/domain/`)

UI와 수치 연산 로직을 철저히 분리하여 **계약 주도 설계(Contract-First Design)**로 구축되었습니다.

### 1. 수치 해석 및 임계 판정 모듈 (`metrics.dart`)
* **P2P (Peak-to-Peak) 산출**: 진동 파형의 최대값과 최소값 차이를 도출.
* **A95 산출**: ISO 18738 기준에 따른 상위 5%(95백분위수) 최대 절대 피크치 도출.
* **임계 자동 판정 (`ThresholdEvaluation`)**: OTIS TUNE 규격 기준(X·Y축 > 10mg, Z축 > 15mg, 소음 > 50dBA) 초과 시 즉각 경고 판정.
* **수치 적분/미분 연산**: 가속도(mg) $\rightarrow$ 속도(m/s) $\rightarrow$ 이동 거리(m) 수치 적분 및 저크(da/dt) 산출.

### 2. EVIMP1 RAW 파서 (`parse_raw.dart`)
* 실제 계측기 데이터 형식(`assets/sample/2024F1447R01.txt`, 256Hz 4컬럼 6,988개 샘플) 파싱 및 시계열 배열 변환.
* **[실데이터 전환 스위치]**: `ResultScreen` 상단 바의 데이터 토글 버튼(🔀)을 통해 기본 예시(Mock) 데이터와 실제 6,988개 파싱 실데이터를 원클릭으로 상호 전환 가능.

### 3. 안드로이드 Kotlin 센서 연동 인터페이스 (`sensor_channel.dart`)
* **이중 안전망(Fallback) 구조**: 네이티브 `EventChannel('com.otis.vibration_checker/sensors_stream')`로부터 실시간 센서 데이터를 수신하되, 센서가 없는 에뮬레이터나 위젯 테스트 환경에서는 자동으로 가상(Mock) 가속 애니메이션 스트림으로 전환되어 크래시를 방지.
* 기기별 샘플링 주파수 불균일성을 보완하기 위한 선형 보간(Linear Interpolation) 및 소음 보정 오프셋(`calibrationOffsetDba`) 아키텍처 반영.

### 4. TUNE 리포트 생성기 (`report_generator.dart`)
* PDF 문서 생성 및 이메일 전송용 ASCII 표 양식 요약문(`generateSummaryText`) 생성 공용 인터페이스.
* 한글 폰트(`Pretendard.ttf`) 임베딩 설계를 적용하여 문서 깨짐 방지 준비 완비.

---

## 🎨 디자인 시스템 및 토큰 (`lib/core/theme.dart`)

디자인 일관성과 실무 유지보수성을 위해 **모든 색상, 치수, 타이포그래피는 하드코딩이 엄격히 금지**되며 `AppColors`, `AppDims`, `AppText` 토큰만 사용합니다.
* **색상 토큰 (`AppColors`)**: `navy`(0xFF0A192F, 메인 브랜드), `steel`(0xFF4A5568), `red`(0xFFD9381E, 경고/초과), `green`(0xFF10B981, 정상), `bg`(0xFFF8FAFC)
* **치수 토큰 (`AppDims`)**: 터치 타깃 `touchMin`(56), 주 버튼 높이 `btnHeight`(64), 카드 라운드 `radius`(12), 화면 여백 `screenPad`(20)

---

## 🚀 로컬 실행 및 테스트 방법

### 1. 의존성 패키지 설치
```bash
flutter pub get
```

### 2. 정적 코드 분석 (Lint & Static Analysis)
전체 프로젝트의 코드 무결성과 규칙 위반 여부를 검사합니다.
```bash
dart analyze --fatal-infos --fatal-warnings
```

### 3. 자동화 유닛 및 위젯 테스트 실행
도메인 수치 연산, 파서, 센서 채널 예외 처리, 화면별 UI 렌더링 및 제스처를 검증하는 **전체 19개 자동화 테스트**를 실행합니다.
```bash
flutter test
```
*(기대 결과: `All tests passed!` - 100% 통과)*

### 4. 앱 실행
```bash
flutter run
```

---

## 📁 디렉토리 구조 요약
```text
lib/
├── core/
│   ├── router.dart         # go_router 라우팅 명세 및 페이지 전환 설정
│   └── theme.dart          # 디자인 시스템 토큰 (AppColors, AppDims, AppText)
├── domain/
│   ├── models/             # MeasurementResult, ResultItem 등 도메인 엔티티
│   ├── metrics.dart        # P10 수치 해석, A95, P2P, 임계 판정, 미적분 연산 모듈
│   ├── parse_raw.dart      # P9 EVIMP1 256Hz RAW 텍스트 데이터 파싱 유틸
│   ├── sensor_channel.dart # P11 안드로이드 Kotlin 센서 채널 매니저 및 Fallback 구조
│   └── report_generator.dart # P12 TUNE 리포트 PDF 및 요약 텍스트 문서화 모듈
├── features/
│   ├── auth/               # S1 로그인 화면
│   ├── home/               # S2 홈 (메인) 화면
│   ├── measure/            # S3 측정 시작 설정 & S4 실시간 라이브 화면
│   ├── result/             # S5 결과 통합 화면 (카드 + 차트) & MetricCard
│   ├── history/            # S5 저장된 측정 이력 목록 화면
│   ├── settings/           # S6 설정 및 이메일 검증 화면
│   └── shared/             # P7 이메일 발송 바텀 시트 등 공용 위젯
└── main.dart               # 앱 엔트리포인트 및 테마 설정
test/
├── domain/
│   ├── metrics_test.dart           # 수치 연산 알고리즘 5개 유닛 테스트
│   ├── parse_raw_test.dart         # RAW 파일 파싱 정확도 2개 유닛 테스트
│   └── report_and_sensor_test.dart # 센서 모델, 채널 Fallback, 리포트 4개 유닛 테스트
└── widget_test.dart                # S1~S6/P7/P8 전 화면 UI 및 인터랙션 8개 위젯 테스트
```
