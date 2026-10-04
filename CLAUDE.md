# OTIS 승강기 진동·소음 측정 앱 (vibration_checker)

일반 안드로이드 폰으로 승강기 진동(3축)·소음을 측정하고 OTIS TUNE 규격 PDF
리포트를 만들어 메일로 보내는 Flutter 앱. Android 우선, iOS 는 나중.

## 명령

```bash
flutter analyze                                   # 경고 0 유지
dart format --output=none --set-exit-if-changed lib test
flutter test                                      # 전부 통과 유지
```

## 구조

| 경로 | 역할 |
|---|---|
| `lib/model/` | 순수 자료형 (`MeasurementResult`, `SensorSample`) |
| `lib/domain/capture/` | 네이티브 이벤트 → 256Hz 격자 환산 (`GridResampler`) |
| `lib/domain/report/` | 리포트 좌표·임계값·지표 계산. 숫자는 여기에만 둔다 |
| `lib/domain/session/` | 화면 사이에 넘기는 이번 측정 상태 (`MeasurementSession`) |
| `lib/adapter/` | 플랫폼 경계 — 센서 채널, 파일·저장소, PDF 렌더링, 환경설정. 측정 한 번의 수집 절차는 `capture_session.dart`, 저장 절차는 `measurement_recorder.dart` |
| `lib/ui/core/` | 라우터, 디자인 토큰(`theme.dart`), 공용 위젯(`widgets/`) |
| `lib/ui/features/` | 화면별 폴더 (home · measure · history · result · settings · shared) |
| `android/app/src/main/kotlin/` | `MainActivity` · `SensorStreamHandler` · `NoiseCaptureHandler` |
| `pdf_report_dev/` | 리포트 좌표를 확정할 때 쓴 파이썬 프로토타입 (앱 빌드와 무관) |
| `docs/comment_rules.md` | 주석 규칙. **코드 작업 전 매번 다시 읽는다** |
| `docs/report_layout.json` | 리포트 좌표 정본. `report_layout_test` 가 Dart 상수와 대조한다 |
| `docs/reference/sample_evimp.pdf` | 원본 TUNE 리포트. 코드 주석의 `근거:` 가 가리킨다 |
| `docs/noise_otis_offset_notes.md` | 소음 dBA 오프셋 · OTIS 차이 · 남은 과제 |

## 관통 원칙

1. **재지 않은 값을 0 이나 빈 문자열로 채우지 않는다.** 미측정은 `null`.
   `MeasurementResult` 의 지표는 `double?`, 판정 게터는 `bool?` 이다.
2. **숫자는 한 곳에만 둔다.** 리포트 좌표는 `report_layout.dart`, 임계값은
   `report_thresholds.dart`, 화면 색·치수·글자는 `ui/core/theme.dart`.
3. **도달 불가 방어 분기 대신 `assert`** 를 쓰고 이유를 주석에 적는다.
4. **실패를 삼키지 않는다.** 변환 실패는 빈 결과가 아니라 사유를 올린다.
5. **주석은 `docs/comment_rules.md` 를 따른다.**

## UI 작업 규칙

- 색 · 치수 · 글자 스타일은 `AppColors` · `AppDims` · `AppText` 만 쓴다.
  필요한 값이 없으면 화면에 숫자를 쓰지 말고 `theme.dart` 에 토큰을 더한다.
  그림 하나에만 쓰는 치수는 그 파일 안 상수 묶음에 둔다
  (예: `placement_sheet.dart` 의 `_DiagramSize`).
- 현장 사용자 기준: 본문 18sp 이상, 캡션 16sp 이상, 터치 영역 56dp 이상,
  주 버튼 64dp.
- 공용 위젯(`lib/ui/core/widgets/`)을 먼저 찾아 쓴다.
  - `AppScrollBody` · `AppBottomBar` — 화면 본문 틀과 아래 고정 버튼 자리
  - `AppCard` — 회색 표면 카드, `AppNotice` — 안내 박스(danger · caution · alert)
  - `showAppConfirmDialog` — 제목 · 문구 · 버튼 한두 개 대화상자
  - `showAppSheet` — 바텀 시트, `showSuccessSnackBar` · `showErrorSnackBar`
  - `AppDialogButton` · `AppDialogIconButton` — 56dp 터치 영역을 지키는 버튼
- 화면은 `go_router` 경로(`ui/core/router.dart`)로만 오간다.
- 측정 · 저장 · 리포트 로직을 화면 파일에 새로 넣지 않는다. 화면은
  `CaptureSession` · `MeasurementRecorder` · `SiteInfo.validate()` 의 결과를
  받아 문구와 화면 이동만 고른다.
- 저장 결과 화면(`history_screen.dart`)은 새로 만들 예정이라 토큰 · 공용
  위젯 정리에서 빠져 있다.

## 작업 방식

- 작업은 함수 · 클래스 묶음 단위로 나눠 진행하고 묶음마다 리뷰를 받는다.
- 매 단계 끝에 "추가로 발견한 것"을 보고한다(없으면 "없음").
- 지시 범위 밖 파일은 읽기만 하고 고치지 않는다.

## 알려진 미해결

- 진동 필터 미확정 — 리포트의 진동 지표 4개가 비어 있고, 차트 X/Y 축을
  원본(±4/±10)보다 넓혀 두었다.
- 소음 dBA 오프셋 87.3 은 임시값. A가중 없음 (`noise_otis_offset_notes.md`).
- `docs/reference/sample_evimp.pdf` 는 축별 계수 분리 이전의 단일 계수로
  만들어졌다. 차이는 최대 0.14pt. 좌표가 아니라 참조 PDF 를 다시 만들어야 한다.
- 요구사항서(`Vibration_Checking_App_Development_20260630.pdf`)가 저장소에 없다.
- 결과 화면(`/result/:id`) · 서버 연동은 미구현이다. 로그인은 두지 않는다
  (수신 이메일은 기기당 하나).
- 소음 RMS 창(`WINDOW_SEC`) · 갱신 주기(`HOP_HZ`)는 OTIS 와 맞춰 보는
  실험값이다 (`NoiseCaptureHandler.kt`).
- `MeasurementResult` 의 정속 구간 필드(`constantSpeedRatio` 등)는 저장
  형식에만 있고 채우는 곳이 없다 — 정속 구간 알고리즘 미결.
