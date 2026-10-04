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
| `lib/model/` | 순수 자료형 (`MeasurementResult`) |
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

## 화면 흐름

```
홈(현장 정보, 입력 즉시 저장) ─▶ 시작(대기 시간 · 거치 안내)
  ─[마이크 권한 확인]─▶ 측정(카운트다운 → 수집, 볼륨키로 종료)
  ─▶ 결과(/result/:id: 지표 · 결과 비교 · 메일 · 테스트 재실행)
홈 ─▶ 저장 결과 목록(history) ─▶ 결과
홈 ─▶ 설정(수신 이메일 목록 · 앱 버전)
```

- 측정 화면은 끝나면 결과 화면으로 바뀐다(`pushReplacement`). 실패 · 중단이면
  측정을 시작한 화면으로 돌아간다(`pop`).
- 마이크 권한은 측정 화면에 들어가기 전에 `ensureMicPermission()` 이 받는다.
  측정 중에는 휴대폰이 뒤집혀 있어 권한 창을 누를 수 없다.
- 바텀 시트는 `showAppSheet()` 로만 띄운다. 아래쪽 시스템 막대를 비켜 준다.

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

## 작업 방식

- 작업은 함수 · 클래스 묶음 단위로 나눠 진행하고 묶음마다 리뷰를 받는다.
- 매 단계 끝에 "추가로 발견한 것"을 보고한다(없으면 "없음").
- 지시 범위 밖 파일은 읽기만 하고 고치지 않는다.

## 알려진 미해결

- 진동 필터 · 정속 구간 감지는 넣지 않는다(2026-10-04 결정). 진동 최대 P2P 는
  필터 없는 원시 값(전체 구간 최대 − 최소)으로 내서 레퍼런스폰 · 개발폰 · EVA
  를 견준다. Z 에는 운행 가감속이 섞여 적색 기준을 늘 넘는다. 평균(A95)도
  같은 원시 시계열 전체에서 반주기 P2P 의 95백분위(최근접 순위)로 낸다.
  EVA 가 따르는 ISO 18738 방식(ISO 8041 가중, 출발 · 정지 0.5m 제외 구간)은
  조사만 해 두었다.
  차트 X/Y 축은 원본(±4/±10)보다 넓혀 두었다.
- `ride_reference.txt` 와 원본 TUNE 리포트는 레퍼런스폰 산출물이다(EVA 아님).
  리포트 적색 기준은 요구사항서(Z 15, X·Y 10)를 따르는데, 레퍼런스폰 리포트
  서식에는 다른 값(수직 30/21, 수평 25.5/13.5)이 찍혀 있다 — 미확인.
- 소음 dBA 오프셋 87.3 은 임시값. A가중 없음 (`noise_otis_offset_notes.md`).
- `docs/reference/sample_evimp.pdf` 는 축별 계수 분리 이전의 단일 계수로
  만들어졌다. 차이는 최대 0.14pt. 좌표가 아니라 참조 PDF 를 다시 만들어야 한다.
- 요구사항서(`Vibration_Checking_App_Development_20260630.pdf`)가 저장소에 없다.
- 서버 연동은 미구현이다. 로그인은 두지 않는다(수신 이메일은 기기에 목록으로
  둔다).
- 소음 RMS 창(`WINDOW_SEC`) · 갱신 주기(`HOP_HZ`)는 OTIS 와 맞춰 보는
  실험값이다 (`NoiseCaptureHandler.kt`).
