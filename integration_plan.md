# OTIS 진동 측정 앱 — develop × feature-ui 통합 실행 계획 (v1)

작성일: 2026-07-04 · 실행 환경: Antigravity (agentic IDE)
대상 저장소: `feature-ui` 브랜치를 베이스로 한 통합 브랜치 · 참조 소스: `develop` 브랜치

이 문서는 그대로 Antigravity에 투입해 Phase 단위로 실행하는 것을 전제로 작성되었다. 각 Phase는
독립적으로 완료 가능하며, 완료 조건(DoD)과 검증 커맨드를 포함한다. Phase 안의 작업 항목은
파일 단위로 지정한다.

---

## 0. 확정 사항 (Decision Log)

사용자 지시에 따라, 프로젝트 문서에 근거가 있는 항목은 아래와 같이 확정한다.
근거: `Vibration Checking App Development_20260630.pdf`(이하 **개발문서**),
`FOD)FI-2026-697-033 Tune APP 사용 시 주의사항 홍보`(이하 **FI**),
`EXTERNAL TUNE (PAAS) Summary Report - 675414 - 2024F 1447R01`(이하 **EVA메일**, 첨부 raw가
현재 `assets/sample/2024F1447R01.txt`와 동일 — 개발문서 p.5~7 리포트와 같은 측정 건).

| # | 항목 | 확정 내용 | 근거 |
|---|---|---|---|
| D1 | 플랫폼 | Android 우선. iOS는 향후 가능성만 언급 → 지금은 Android만 빌드 대상 | 개발문서 p.1, Req.1 |
| D2 | 지표 표기 | X/Y/Z 진동 "Peak to Peak[mg]" 로 표기하되, 실제 값은 EVA의 **Aptp(A95 peak-to-peak)** 산출치 | 개발문서 p.5(표기), p.6(Aptp=8.2/12.9/22.2) |
| D3 | 임계·색상 | X>10mg, Y>10mg, Z>15mg, 소음>50dBA 초과 시 붉은색 | 개발문서 p.5 |
| D4 | 평가 구간 | 지표는 **정속 구간** 기준으로 산출. 검증: 정속구간 소음 max=71.7dBA로 리포트와 정확 일치(전구간 max는 77.2) | 개발문서 p.6 + 골든 raw 재현 실험 |
| D5 | 거리·속도 | 수직축 가속도 수치 적분으로 산출. 검증: 골든 raw 적분 → 최대속도 1.51m/s·거리 21.0m (리포트 1.5m/s·20m) | 개발문서 p.7 + 재현 실험 |
| D6 | 차트 8종·단위 | X/Y/Z 진동[mg], Noise[dBA], Position[m], Vel[m/s], **Acc[m/s²], Jerk[m/s³]** | 개발문서 p.6~7 |
| D7 | 거치·축 매핑 | 폰을 카 바닥 중앙, **폰 상단(기기 +Y)이 도식의 Y축 방향**. 축 매핑은 항등(기기 X/Y/Z → 리포트 X/Y/Z). 도식은 개발문서 p.4가 최종(“초기 공유 자료와 방향이 다름” 명시), FI 3항과 일치 | FI 3-3), 개발문서 p.4 |
| D8 | 골든 기대값 | X 8.2 / Y 12.9 / Z 22.2 mg · 71.7dBA · 20m · 1.5m/s. **주의: 현 mock과 AGENTS.md는 X↔Y가 스왑되어 있음 → 문서 기준으로 수정** | 개발문서 p.6~7 |
| D9 | 시작 지연 | 카운트다운 옵션 **0 / 5 / 10 / 15초** (현 feature-ui의 5/10/30/60 교체) | 개발문서 p.3 참고앱 스크린샷 |
| D10 | UI 원칙 | “화면은 최대한 직관적이고 간단할수록 좋음” → 요구사항 외 기능(예: 오디오 첨부)은 제거 | 개발문서 p.3 |
| D11 | 로그인 | ID: Otis 사번 6자리 / 협력업체 T+5자리. PW=ID(변경 불가 허용). 관리자의 ID 활성/비활성 관리 필요 | 개발문서 Req.2 |
| D12 | 이메일 | 결과 Report는 ID별 저장된 email로 발송, email은 사용자가 직접 입력. 발송 항목 선택 가능 | 개발문서 Req.3, 6 |
| D13 | 저장 | Test 결과는 **PDF + raw data 두 가지로 자동 저장**. raw 포맷은 골든 샘플과 동일한 **EVIMP1** 채택(EVA 호환, 파서 기구현) | 개발문서 Req.4 + EVA메일 첨부 포맷 |
| D14 | 즉시 확인 | 결과는 Mobile에서 바로 확인 | 개발문서 Req.5 |
| D15 | SDK | 양 브랜치 모두 `flutter upgrade`로 **최신 stable 통일** | 사용자 지시 |
| D16 | 통합 방향 | feature-ui의 구조(라우팅·화면·도메인·테스트)를 베이스로, develop의 실센서 측정 파이프라인을 측정 엔진으로 이식 | 분석 결과 |

**미확정 → Phase 7로 이월 (개발문서 Action item과 동일):**
- OI-1: X/Y축 Aptp의 EVA 필터 스펙(축별 주파수 가중 추정) → 오차범위 Fix는 "Test 진행하면서 최종 결정"
- OI-2: Login ID 관리 방향·ID 목록 ("최종 확정 후 공유" 대기) → 서버 인증/관리자 기능은 어댑터만 준비
- OI-3: 법인폰·설치협력업체 휴대폰 기종 목록 → 기기 매트릭스 테스트 대기
- OI-4: 소음 dBA 기기별 캘리브레이션 오프셋 값

---

## 1. 알고리즘 검증 요약 (계획의 근거)

골든 raw(`2024F1447R01.txt`, EVIMP1/256Hz/6,988샘플/27.3s)에 대해 재현 실험한 결과:

| 지표 | 리포트 값 | 재현 결과 | 상태 |
|---|---|---|---|
| 소음 최대 | 71.7 dBA | 정속구간(v>1.4m/s, 11.6~22.0s) max = **71.7** | ✅ 정의 확정 |
| 최대 속도 | 1.5 m/s | Z 적분 max = **1.509** | ✅ 정의 확정 |
| 운행 거리 | 20 m | Z 이중적분 = **21.0** (오차 5%) | ✅ 방식 확정, 허용오차는 OI-1 |
| Z Aptp | 22.2 mg | 정속구간 + 0.5s 이동평균 제거 후 P2P = **22.0~22.5** | ✅ 근사 재현 |
| X Aptp | 8.2 mg | 후보 최상 8.8(0.05s 윈도우 95pct) / 대부분 18~23 | ⚠️ 필터 미상 → OI-1 |
| Y Aptp | 12.9 mg | 후보 12.8(주행구간 2×absA95) / 대부분 16~33 | ⚠️ 필터 미상 → OI-1 |

시사점: ① 지표는 반드시 **정속 구간**에서 산출한다. ② 진동 신호는 **모션 성분(저주파, 적분용)과
진동 성분(고역, 지표용)으로 분리**해야 한다(분리 없으면 Z P2P가 90.8mg로 4배 부풀어 전 지표
오판). ③ X/Y는 EVA가 축별 주파수 가중을 적용하는 것으로 추정되므로 필터 파라미터를
**설정값(MetricsConfig)** 으로 외부화하고 Phase 7 병행측정에서 피팅한다.

기존 두 브랜치의 산출은 모두 이 정의와 불일치: feature-ui는 전구간 단순 P2P(X 23.3/Y 32.6/Z 90.8
→ 3축 모두 오판), develop은 전주행 윈도우 A95 P2P(17~33mg). 둘 다 Phase 1에서 교체된다.

---

## 2. 목표 아키텍처

```
lib/
├── core/                    # (feature-ui 유지) router, theme
├── domain/
│   ├── models/              # MeasurementResult, SiteInfo(신규), MeasureSettings(신규)
│   ├── measure/             # ★ 신규: 측정 엔진 (develop 이식 + 재구성)
│   │   ├── sensor_sample.dart        # 통일 샘플 모델 (mg, tsUs)
│   │   ├── metrics_config.dart       # 필터/윈도우/임계 파라미터 (OI-1 캘리브레이션 대상)
│   │   ├── signal_filters.dart       # 이동평균, 저역/고역 분리, 리샘플
│   │   ├── ride_detector.dart        # develop _detectRideSegment 이식 + 정속구간 검출
│   │   ├── motion_integrator.dart    # 부호 유지 적분 → v(t), s(t), 저크
│   │   ├── vibration_metrics.dart    # 윈도우 P2P → A95(Aptp), noiseMax
│   │   └── measurement_engine.dart   # 스트림 수집→분석→MeasurementResult
│   ├── sensor_channel.dart  # (유지) 폴백 로직 수정
│   ├── parse_raw.dart       # (유지) + EVIMP1 writer 추가
│   ├── report_generator.dart# PDF 실구현
│   └── repository/          # ★ 신규: MeasurementRepository (파일 저장/목록)
├── features/                # (feature-ui 유지) + 세션 연결
│   └── shared/measurement_session.dart  # ★ 신규: 화면 간 상태 (외부 패키지 없이)
android/.../MainActivity.kt + SensorStreamHandler.kt + NoiseCaptureHandler.kt  # ★ 신규
assets/fonts/Pretendard-Regular.ttf, Pretendard-Bold.ttf                       # ★ 신규
```

데이터 흐름: `Login → Home(SiteInfo 입력) → Start(지연 선택+거치 안내) → 카운트다운 →
Measuring(엔진 수집·라이브) → 완료 → 엔진 분석 → Repository 저장(raw+PDF 자동) →
Result(:id) → Email 발송(선택 항목)`. History/Settings는 Repository/Prefs를 읽는다.

상태 관리: AGENTS.md 규칙 유지(외부 상태관리 패키지 금지). `MeasurementSession`은
앱 수명 동안 유지되는 단순 클래스(정적 인스턴스)로 SiteInfo·설정·마지막 결과 id를 보관.

---

## Phase 0 — 저장소·SDK 기반 정리

목표: 통합 브랜치에서 최신 Flutter로 두 코드베이스가 컴파일·테스트되는 상태.

| # | 작업 | 상세 |
|---|---|---|
| 0-1 | 브랜치 구성 | feature-ui HEAD에서 `integration/v1` 생성. develop의 `lib/` 4개 파일(main 제외)을 `reference/develop/` 아래로 복사해 이식 참조용으로 보존(빌드 제외 경로) |
| 0-2 | Flutter 업그레이드 | `flutter upgrade` → 최신 stable. `pubspec.yaml` `environment.sdk`를 설치된 Dart로 상향. `flutter pub upgrade --major-versions` 후 go_router·fl_chart 메이저 breaking change 대응(라우팅 API, 차트 titles API 변동 확인) |
| 0-3 | 의존성 추가 | `sensors_plus`(에뮬레이터 폴백·예비), `wakelock_plus`, `pdf`, `path_provider`, `shared_preferences`, `flutter_email_sender`(또는 `share_plus`, Phase 5에서 확정), `intl`(일시 포맷) |
| 0-4 | 컴파일 이슈 선제 확인 | `result_screen.dart`의 `scrollCacheExtent: ScrollCacheExtent.pixels(3000)`이 최신 SDK에서 유효한지 확인. 미지원이면 `cacheExtent: 3000.0`으로 교체 |
| 0-5 | 테스트 정리 | develop의 `widget_test.dart`(단일 화면 스모크)는 이식하지 않고 폐기. feature-ui 테스트 19개가 신 SDK에서 통과하도록 수정 |
| 0-6 | 정적 규칙 | `analysis_options.yaml` flutter_lints 최신으로 통일 |
| 0-7 | 앱 식별자 | `com.otis.vibration_checker` 유지(develop의 `com.example.*`는 폐기). `AndroidManifest.xml`의 `RECORD_AUDIO` 유지, `VIBRATE`는 사용처 없으면 제거 |

DoD: `dart analyze --fatal-infos --fatal-warnings` 0건 · `flutter test` 전체 통과 ·
실기기/에뮬레이터에서 로그인→홈 진입 확인.

---

## Phase 1 — 측정 엔진 (domain/measure)

목표: 문서 확정 정의(D2~D6)를 구현한 순수 Dart 엔진. UI 독립·전 로직 유닛테스트.

### 1-A. 모델·설정
- `sensor_sample.dart`: `SensorSample{int tsUs; double x,y,z; double noiseDba;}` **단위는 mg**로
  통일(EVIMP1·네이티브 채널과 동일). develop의 m/s² 모델은 이식 시 변환(1 m/s² = 101.97 mg,
  develop `VibrationResult.metersPerSecondSquaredToMg` 상수 재사용).
- `metrics_config.dart`: `baselineSec=1.0`, `motionLowpassCutoffHz`(기본 0.8),
  `rideSpeedThreshold=0.05 m/s`, `constantSpeedRatio=0.9`(정속 = |v| > 0.9×max|v|),
  `aptpWindowSec`(기본 0.5, 축별 오버라이드 가능), `aptpPercentile=0.95`,
  임계 `xy=10, z=15, noise=50`. **모든 수치는 이 파일에서만 정의**(OI-1 캘리브레이션 단일 지점).

### 1-B. 신호 파이프라인 (`signal_filters.dart`, `ride_detector.dart`, `motion_integrator.dart`)
1. 기준선 보정: 측정 시작 후 `baselineSec` 평균을 3축에서 차감 — develop
   `_applyBaselineCorrection` 이식(카운트다운 종료 직후 정지 상태 전제, Start 화면 안내 문구와 연동).
2. 성분 분리: `motion = lowpass(signal)`(이동평균 창 = sr/cutoff 기반), `vibration = signal − motion`.
   현 develop의 3-sample 이동평균은 폐기(50Hz 가정 스무딩일 뿐 성분 분리가 아님).
3. 실측 샘플레이트: 타임스탬프 중앙값 간격으로 산출. **develop의 `estimatedSamplesPerSecond=50`
   하드코딩 제거.**
4. 적분(수직축 motion 성분): `v[i]=v[i-1]+a·dt` **부호 유지 — 현 feature-ui
   `calculateSpeedSeries`의 `math.max(0.0, ...)` 클램프 제거(하강 측정에서 속도·거리가 0이 되는
   버그).** `maxSpeed=max|v|`, `distance=|s(end)|`, 표시용 속도 시계열은 `|v|`.
   루프 내 `toStringAsFixed` 반올림 전부 제거(표시 단계에서만 포맷).
5. 구간 검출: ride = `|v| > rideSpeedThreshold` 첫~끝(+develop의 패딩 로직 이식),
   constant = `|v| > constantSpeedRatio×max|v|` 연속 구간. 폴백: 정속 미검출 시 ride 전체,
   ride 미검출 시 전 구간 + `usedDetectedRideSegment=false` 플래그(develop 개념 유지).

### 1-C. 지표 산출 (`vibration_metrics.dart` 개편)
- Aptp: **정속구간의 vibration 성분**을 `aptpWindowSec` 텀블링 윈도우로 나눠 윈도우별
  P2P를 구하고 그 95퍼센타일. develop `_axisRideResult`의 구조 재사용, percentile은
  `ceil((n-1)·p)` 방식 유지.
- noiseMax: 정속구간 dBA의 최대값(D4 검증 완료).
- 저크: motion 성분 미분, 단위 m/s³. `accelSeries`는 motion 성분을 **m/s²로 변환**
  (현재 mg 원신호를 m/s² 라벨로 그리는 단위 불일치 수정, D6).
- `ThresholdEvaluation`(feature-ui) 유지 — 입력만 Aptp로 교체.

### 1-D. 엔진 (`measurement_engine.dart`)
`start(Stream<SensorSample>) → 버퍼링 → stop() → analyze() → MeasurementResult`.
`MeasurementResult`에 추가 필드: `sampleRate`, `usedDetectedRideSegment`,
`constantSpeedRange`, `rawSamples`(EVIMP1 저장용). 시계열은 표시용으로 유지.

### 1-E. 테스트 (골든 픽스처 = `assets/sample/2024F1447R01.txt`)
| 테스트 | 기대값 | 허용오차 |
|---|---|---|
| noiseMax | 71.7 dBA | ±0.5 |
| maxSpeed | 1.50 m/s | ±0.05 |
| distance | 20~21 m | 문서 20 vs 적분 21 → ±1.5m로 시작, OI-1에서 확정 |
| Z Aptp | 22.2 mg | ±2 |
| X·Y Aptp | 8.2 / 12.9 mg | 초기엔 `10±4 / 13±7` 수준의 완화 검증 + `// OI-1` 주석, 캘리브레이션 후 조임 |
| 하강 측정 | Z 부호 반전 합성 입력 | distance·maxSpeed 동일값 (클램프 버그 회귀 방지) |
| EVIMP1 roundtrip | writer→parser | 원본 배열 일치 |

DoD: 위 테스트 + 기존 도메인 테스트 통과. 엔진은 Flutter import 없는 순수 Dart.

---

## Phase 2 — 네이티브 센서·소음 채널 (Kotlin) + Dart 연동 수정

목표: feature-ui가 설계만 해둔 `EventChannel('com.otis.vibration_checker/sensors_stream')` 계약을
실제 구현. develop의 sensors_plus 경로는 에뮬레이터 폴백으로 강등.

### 2-A. Kotlin (`android/app/src/main/kotlin/com/otis/vibration_checker/`)
- `SensorStreamHandler.kt`: `TYPE_LINEAR_ACCELERATION`을 `SENSOR_DELAY_FASTEST`로 구독,
  `event.timestamp`(ns) 기반. m/s² → mg 변환 후 **256Hz 선형 보간 리샘플**(sensor_channel.dart
  주석의 설계 그대로 — S22류는 400~500Hz 콜백 가능). 32샘플 단위 배칭으로 채널 오버헤드 절감.
- `NoiseCaptureHandler.kt`: `AudioRecord` 44.1kHz mono → 125ms 프레임 RMS → dBFS →
  `dBA = dBFS + 기준오프셋 + calibrationOffsetDba`(A-weighting은 1차 근사 필터로 시작,
  정밀 보정은 OI-4). 프레임당 1값을 최근 가속도 샘플들에 부여.
- `MainActivity.kt`: MethodChannel `checkAvailable/startCapture/stopCapture` 구현,
  `startCapture` 인자(`sampleRate`, `calibrationOffset`)는 기존 Dart 계약 그대로 수신.

### 2-B. Dart 연동 수정 (`sensor_channel.dart`, `measuring_screen.dart`)
- **폴백 버그 수정**: `_sensorSub?.isPaused != false` 조건은 활성 구독에서 항상 거짓이라
  mock이 영원히 미적용(현재 라이브 속도 0.00 고정). → `checkSensorsAvailable()` 결과 +
  "첫 실샘플 수신 여부" 플래그로 실/모의 스트림을 **명시적으로 하나만** 구독.
  테스트·에뮬레이터는 `SensorChannelManager(useMock: true)` 주입.
- 라이브 속도 = 엔진의 실시간 적분 |v| (현행 `sample.z * 0.0098` 순간가속도 표기 제거).
- UI 갱신 스로틀: 수집은 버퍼에 직접, `setState`는 100~200ms 주기(develop의 50Hz setState 문제 해소).
- `wakelock_plus`: 측정 시작 시 enable, 종료/이탈 시 disable (develop 로직 이식).
- 런타임 권한: 측정 시작 전 `RECORD_AUDIO` 요청. 거부 시 "소음 제외 측정" 안내 후 진행
  허용(진동만) — 결과에 소음 N/A 표기.

DoD: [PENDING: 실기기 연결 후 검증] 실기기 로그로 유효 샘플레이트 250~260Hz 확인 · 마이크 dBA가 조용/시끄러움에 반응 · [완료] 에뮬레이터에서 mock으로 전 플로우 동작 · 권한 거부 시 크래시 없음.

---

## Phase 3 — 세션·화면 데이터 흐름 연결

목표: 화면 8종이 실제 데이터로 이어지는 E2E. 현재 흐름 단절 지점을 모두 해소.

| # | 파일 | 수정 |
|---|---|---|
| 3-1 | `features/shared/measurement_session.dart` (신규) | `SiteInfo{jobNo, siteName, bottomFloor, topFloor, direction, model}`, `delaySec`, `lastResultId` 보관. 정적 싱글턴 |
| 3-2 | `home_screen.dart` | 검증 통과 시 SiteInfo를 세션에 저장 후 `/start` 이동(현재는 입력값이 어디에도 전달되지 않음). 마지막 입력 복원 TODO는 `shared_preferences`로 구현 |
| 3-3 | `start_screen.dart` | 지연 옵션 `[0,5,10,15]`초로 교체(D9). 선택값 세션 저장. "카운트다운 시작" → 카운트다운 진입 |
| 3-4 | 카운트다운 (신규 위젯 or `/measuring` 진입 페이즈) | 참고앱 2번째 화면 스타일: 어두운 배경 + 초대형 남은 초. 종료 시 자동으로 측정 시작. **현재는 카운트다운 자체가 미구현(버튼 즉시 이동)** — develop `_startCountdown` 로직 이식. 0초 선택 시 즉시 시작 |
| 3-5 | `measuring_screen.dart` | 엔진 연결(2-B), "테스트 완료" → `engine.stop()` → 분석 → Repository 저장(Phase 4) → `context.pushReplacement('/result/$realId')` (**현행 `/result/demo` 고정 제거**). 측정 시작 직후 1초 "기준 보정 중" 표시 |
| 3-6 | `result_screen.dart` | `id`로 Repository 로드. mock/raw 토글은 `kDebugMode` 한정으로 격리. 차트 다운샘플: 표시용 ≤800pt(스트라이드 or LTTB) — 6,988pt×8차트 `isCurved` 렌더 부하 해소. X축을 시간(초)으로. **임계 표시 수정**: 카드·차트 초과색은 `result.xExceeded` 등 지표 판정만 사용(현행 `series.any(v>threshold)`는 진폭≠P2P 오판). 진동 차트의 수평 임계선은 제거하고 리포트처럼 Aptp 값 주석으로 대체, 소음 차트의 50dBA 선만 유지(진폭 기준이므로 유효) |
| 3-7 | `history_screen.dart` | `MeasurementResult.mockList` → Repository 목록. 항목 삭제(파일 삭제 포함) 추가 |
| 3-8 | `send_email_sheet.dart` | 수신자 하드코딩(`soonkyu.lee@otis.com`) 제거 → 설정 저장값 로드. "측정 소리(오디오)" 항목 제거(D10, 요구사항 외) |
| 3-9 | 모델 정합 | `measurement_result.dart`의 mock을 문서 값으로 수정: **X 8.2 / Y 12.9**(현행 스왑 상태), 방향 문자열 통일. `b1Floor` 헬퍼 정리 |

DoD: 실기기에서 로그인→입력→지연 10초→측정 30초(실승강기 또는 흔들기)→결과 저장→히스토리
재진입→이메일 시트까지 수동 E2E 1회 통과. 위젯 테스트를 신규 플로우로 갱신.

---

## Phase 4 — 저장 (raw EVIMP1 + PDF 자동 저장) & 리포트

목표: Req.4 "PDF와 raw data 두 가지 자동 저장" + Req.5 즉시 확인의 영속 기반.

### 4-A. Repository (`domain/repository/measurement_repository.dart`)
- 경로: `getApplicationDocumentsDirectory()/measurements/{id}/` 에
  `raw.txt`(EVIMP1) · `meta.json`(SiteInfo+지표+판정) · `report.pdf`.
  id = `{제번압축}_{yyyyMMdd_HHmmss}`.
- `save(result)`, `list()`(meta 스캔, 최신순), `load(id)`, `delete(id)`.
- EVIMP1 writer: 헤더 `EVIMP1\n{sampleRate}\n` + `x y z noise` 4컬럼 —
  `parse_raw.dart`와 왕복 일치 테스트(Phase 1-E와 공유).

### 4-B. PDF (`report_generator.dart` 실구현)
- `pdf` 패키지. 한글 폰트: `assets/fonts/Pretendard-Regular/Bold.ttf` 추가 후
  `pw.ThemeData.withFont` 주입(기존 주석의 설계 그대로 — 미주입 시 한글 전량 깨짐).
- 레이아웃 = 개발문서 p.5 리포트 형태: 상단 현장정보(제번/현장명/최하층/최상층/일시/방향),
  6지표 표(초과 셀 붉은 배경/글자, D3), 이어서 차트 8종(D6 순서: X/Y/Z/Noise/Pos/Vel/Acc/Jerk).
- 차트 이미지: 측정 완료 시 오프스크린 `RepaintBoundary` 캡처 유틸로 fl_chart를 PNG화 후 PDF
  삽입(구현 단순·화면과 100% 일치). 캡처 해상도 2x.
- `generateSummaryText` 유지(이메일 본문용) — 값 소스만 신규 지표로.

### 4-C. 자동 저장 연결
- Measuring 완료 훅에서 `repository.save()` 동기 완료 후 결과 화면 이동. 실패 시 재시도
  다이얼로그(결과 유실 방지). 저장 완료 스낵바에 파일 위치 안내.

DoD: 측정 1회 → 폰에 3파일 생성 · 앱 재시작 후 History에 노출 · PDF를 외부 뷰어로 열어
한글·붉은 표시·차트 8종 확인 · roundtrip 테스트 통과.

---

## Phase 5 — 로그인·설정·이메일 발송

### 5-A. 인증 (`features/auth/` + `domain/auth_repository.dart` 신규)
- `AuthRepository` 인터페이스: `login(id, pw)`, `isEnabled(id)`. 현행 정규식
  `^(\d{6}|[Tt]\d{5})$`·PW=ID 검증(D11)을 `LocalAuthRepository`로 이동.
- 관리자 활성/비활성(Req.2-③)은 서버 확정 대기(OI-2) → 인터페이스에 자리만 두고
  Local 구현은 항상 enabled. 로그인 성공 시 `shared_preferences`에 id 저장(자동 로그인),
  설정의 로그아웃과 연결. 라우터에 로그인 가드(redirect) 추가.

### 5-B. 설정 영속화 (`settings_screen.dart`)
- 이메일 저장/로드를 `shared_preferences`로 (현재 컨트롤러 초기값 하드코딩+휘발).
  키는 ID별(`email_{id}`) — Req.3-① "각 ID별 email".
- 프로필 표시 = 로그인 id. 하드코딩 제거.

### 5-C. 이메일 발송 (`send_email_sheet.dart`)
- 1차 구현: `flutter_email_sender`(기기 메일 앱 compose)로 수신자=설정 email,
  제목=`TUNE Summary Report - {제번} - {일시}`(EVA메일 제목 패턴), 본문=`generateSummaryText`,
  첨부=체크 항목(PDF/raw/차트 PNG). 문서가 발송 '방식'을 지정하지 않으므로 기기 메일 경유가
  최소 구현 — 서버 자동발송 필요 여부는 OI-2와 함께 OTIS 확인 항목으로 기록.
- 체크박스: PDF 리포트 / RAW 데이터 / 차트 이미지 / 지표 요약(본문) — 오디오 제거(3-8).

DoD: 실기기에서 메일 앱으로 첨부 2종 이상 발송 성공 · 로그아웃→재로그인 시 이메일 유지 ·
잘못된 ID 형식 4종(5자리, 7자리, T4자리, 영문) 거부 테스트.

---

## Phase 6 — 품질·성능·회귀 마감

- 성능: 60s@256Hz×4ch 측정의 메모리(≈수 MB, 문제 없음 확인) · 결과 화면 프레임 드랍 프로파일
  (다운샘플 후 60fps) · 측정 중 setState 빈도 로그로 스로틀 검증.
- AGENTS.md 디자인 감사: 하드코딩 색/치수 grep(`Color(0x`, 숫자 리터럴), 3중 상태 표시 유지,
  터치 56dp/버튼 64dp, 화면당 주 버튼 1개 유지 여부 전 화면 점검.
- 테스트 최종: 도메인(골든/roundtrip/필터/적분/판정) + 위젯(신 플로우) 전체 green,
  커버리지 리포트 생성.
- 문서: README·AGENTS.md를 통합 구조로 갱신(**AGENTS.md 6항의 X/Y 스왑 값 수정 포함**),
  MetricsConfig 파라미터 표와 OI 목록 명시.

DoD: `flutter analyze` 0건 · `flutter test` 전체 통과 · 릴리즈 빌드(`flutter build apk --release`) 성공.

---

## Phase 7 — 현장 캘리브레이션 & 외부 확정 (OTIS 협업, 코드 외 활동 포함)

개발문서 Action item을 실행 계획으로 전환한 단계. 앱 출시 판정의 전제 조건.

1. **오차범위 Fix (OI-1)**: EVA(또는 법인폰 TUNE)와 동일 카 동시 측정 ≥5회(상향/하향 포함) →
   회차별 X/Y/Z Aptp·소음·거리 비교 → `MetricsConfig`의 축별 필터 컷오프·윈도우를 피팅 →
   골든 테스트 허용오차 확정. 병행하여 OTIS에 EVA의 Aptp 필터 스펙(ISO 18738/8041 가중 여부)
   문의 — 스펙 입수 시 피팅 대신 직접 구현.
2. **방향 검증**: p.4 도식 거치 상태에서 X/Y 채널이 EVA와 동일 축인지 크로스체크
   (placement_sheet의 `TODO: OI-1 확정 후 방향 검증` 해소).
3. **소음 보정(OI-4)**: 기준 소음계 대비 기기별 `calibrationOffsetDba` 산출, 기종별 테이블화.
4. **ID 관리(OI-2)**: OTIS의 Login ID 관리 방향 확정 수신 → `AuthRepository` 서버 구현 교체,
   관리자 활성/비활성 반영.
5. **기기 매트릭스(OI-3)**: 법인폰 + 협력업체 기종 목록 수신 → 샘플레이트/마이크 편차 확인.

산출물: 캘리브레이션 리포트(회차별 오차표), 확정 MetricsConfig, 갱신된 골든 테스트.

---

## 부록 A — 분석에서 발견된 이슈 → 해결 Phase 매핑

| 이슈 | 위치 | Phase |
|---|---|---|
| 전구간 단순 P2P로 3축 오판 (Z 90.8mg) | feature-ui `metrics.dart` | 1 |
| 속도 `max(0,·)` 클램프 → 하강 측정 거리 0 | feature-ui `calculateSpeedSeries` | 1 |
| 적분 루프 내 반올림 | feature-ui `metrics.dart` | 1 |
| 50Hz 하드코딩 윈도우 | develop `_estimatedWindowSize` | 1 |
| `DateTime.now()` 타임스탬프 지터 | develop `measurement_screen` | 2 |
| 폴백 조건 `isPaused != false` 死조건 → 라이브 0.00 고정 | feature-ui `measuring_screen` | 2 |
| `z×0.0098`을 속도로 표기 | feature-ui `measuring_screen` | 2 |
| 센서 이벤트마다 setState(50Hz) | develop | 2 |
| 네이티브 채널 미구현(빈 MainActivity) | feature-ui | 2 |
| 소음 캡처·런타임 권한 부재 | 양측 | 2 |
| 홈 입력값 미전달 / 지연값 미전달 / 카운트다운 미구현 / `/result/demo` 고정 | feature-ui | 3 |
| 지연 옵션 5/10/30/60 ≠ 문서 0/5/10/15 | feature-ui `start_screen` | 3 |
| 차트 진폭 임계선·`any(v>thr)` 오판 | feature-ui `result_screen` | 3 |
| 6,988pt×8차트 렌더 부하 | feature-ui `result_screen` | 3 |
| 히스토리 mock 고정·영속화 부재 | feature-ui | 3·4 |
| mock/AGENTS X↔Y 스왑 (문서: X 8.2, Y 12.9) | feature-ui | 3·6 |
| Acc 차트 mg값을 m/s² 라벨 | feature-ui | 1·3 |
| PDF placeholder·한글 폰트 미적용 | feature-ui `report_generator` | 4 |
| raw 자동 저장 부재 (develop은 명시적 미저장) | 양측 | 4 |
| 이메일 수신자 하드코딩·발송 TODO·설정 미영속 | feature-ui | 3·5 |
| 인증 mock·관리자 기능 부재 | feature-ui | 5·7 |
| `ScrollCacheExtent` API 유효성 미확인 | feature-ui | 0 |
| 패키지명 `com.example.*` | develop | 0 |
| 오디오 첨부 항목(요구사항 외) | feature-ui | 3 |

## 부록 B — 골든 데이터 카드

- 입력: `assets/sample/2024F1447R01.txt` (EVIMP1, 256Hz, 6,988샘플, 27.3s, 4컬럼 X/Y/Z[mg]+dBA)
- 출처: EVA메일 첨부(제번 2024F 1447R01, 럭키종합건설/송정동근생, 1→8층, Floor To Floor Run)
- 기대 출력(개발문서 p.5~7): X 8.2 / Y 12.9 / Z 22.2 mg · 소음 71.7 dBA · 거리 20 m · 최대속도 1.5 m/s
- 재현 확인된 중간값: 정속구간 = 11.6~22.0s(v>1.4m/s) · 주행구간 ≈ 7.0~26.6s ·
  적분 maxSpeed 1.509 m/s · 거리 21.0 m · 정속 소음 max 71.7 dBA

## 부록 C — develop 파일 이식 맵

| develop 소스 | 목적지 | 처리 |
|---|---|---|
| `models/sensor_sample.dart` | `domain/measure/sensor_sample.dart` | 병합(단위 mg·tsUs·noise 필드) |
| `models/vibration_result.dart` | `domain/models/measurement_result.dart` | 개념 병합(Max/A95 P2P, 판정 getter, mg 변환 상수) 후 원본 폐기 |
| `services/vibration_analyzer.dart` | `domain/measure/` 각 파일 | 기준선·구간검출·윈도우 P2P·percentile 이식, 3-sample MA·50Hz 가정 폐기 |
| `screens/measurement_screen.dart` | — | 카운트다운 타이머·wakelock·구독 수명주기 로직만 발췌 이식, 화면은 폐기 |
| `main.dart`, 테스트 | — | 폐기 |
