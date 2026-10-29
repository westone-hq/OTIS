# OTIS V-Check — 승강기 진동·소음 측정 앱 (vibration_checker)

일반 안드로이드 폰으로 승강기 진동(3축)·소음을 측정하고 OTIS TUNE 규격 PDF
리포트를 만들어 메일로 보내는 Flutter 앱. 앱 이름(홈 화면 아이콘 아래 ·
`MaterialApp` title)은 "OTIS V-Check"(2026-10-13). 패키지 이름
`com.otis.vibration_checker` 는 바꾸지 않는다 — 바꾸면 다른 앱으로 취급돼
업데이트가 이어지지 않는다. Android 우선, iOS 는 나중.

## 문서 지도

작업 전에 이 파일과 `docs/comment_rules.md`, 그리고 고칠 곳에 해당하는 spec 을
읽는다.

| 문서 | 담는 것 |
|---|---|
| `docs/comment_rules.md` | 주석 규칙. **코드 작업 전 매번 다시 읽는다** |
| `docs/spec/signal_processing.md` | 진동 처리 순서, 설정 상수, result.json · meta.txt 형식, SciPy 정본과 픽스처 |
| `docs/spec/report.md` | 리포트 1쪽 머리말 · 지표 표, 2 · 3쪽 차트 축 · 표시점, 서식 이미지 |
| `docs/release.md` | 릴리스 서명 키 보관 · `android/key.properties` · 서명 확인 |
| `docs/release_automation.md` · `admin/` | 관리자 엑셀 입력 · Actions의 새 버전 준비 · Secrets 최초 설정 · 릴리스 초안 |
| `docs/report_layout.json` | 리포트 좌표 정본. `report_layout_test` 가 Dart 상수와 대조한다 |
| `docs/reference/` · `docs/test_up/` · `docs/test_dn/` · `every_set_compare.png` | OTIS 원본 리포트 · 원시 기록과 우리 앱 결과 비교 자료. 원본 리포트(엔지니어명 · 현장명 포함)까지 공개 저장소에 올린다(2026-10-28 사용자 결정) |
| `docs/uml/` | 유스케이스 · 액티비티 · 시퀀스 다이어그램(HTML) |

## 명령

```bash
flutter analyze                                   # 경고 0 유지
dart format --output=none --set-exit-if-changed lib test
flutter test                                      # 전부 통과 유지
flutter build apk --debug                         # Kotlin 컴파일 확인
# 화면 · 리포트 캡처(screenshot 태그, 평소 건너뜀). SHOT_DIR 에 PNG · PDF 를 쓴다
flutter test --tags screenshot --run-skipped test/screenshots
```

SciPy 정본 픽스처는 `tool/fixtures/gen_conditioning_fixtures.py` 가 만든다
(아나콘다 파이썬, 모드별 명령은 스크립트 머리 주석과
`docs/spec/signal_processing.md` "정본과 픽스처").

## 구조

| 경로 | 역할 |
|---|---|
| `lib/domain/` | 순수 Dart — Flutter · `dart:io` · 플랫폼을 모른다 |
| `  config/` | 숫자 한 곳: 수집 · 신호 처리 `CaptureConfig`, 소음 `noise_config` |
| `  dsp/` | 이 앱 규칙을 모르는 필터 부품(SciPy 대응): `SosSection` · `Butterworth` · `PolyphaseResampler` · `AnalogBiquad` · `Units` |
| `  capture/` | 측정 중: 네이티브 이벤트, 256Hz 격자 환산(`GridResampler`), 거치 판정, 측정 중 속도 |
| `  analysis/` | 측정 뒤 격자 → 지표, 처리 순서대로: `SignalConditioner` · `Kinematics` · `RideWeighting` · `DeviceResponse` · `TravelWindow` · `HalfCycle` · `MotionZones` · `MeasurementAssembler`(조립만) |
| `  measurement/` | `MeasurementResult`(result.json 자료형) · 결과 경고 문구(`result_warnings`) |
| `  session/` | 현장 정보 `SiteInfo` · 화면 사이 측정 상태 `MeasurementSession` |
| `  report/` | 리포트 표현 규칙: 좌표(`report_layout` · `report_page1_layout` · `report_chart_page_layout`) · 임계값 · 지표 행 · 차트 축(`chart_scale` · `chart_axes`) · 시계열 줄이기(`chart_series`) |
| `  mail/` | 메일 제목 · 본문 · 첨부 이름(`MailComposer`) |
| `  auth/` · `update/` · `time/` | 작업자 명단 · 로그인 상태, 앱 안 업데이트 판정, 한국 시각(`KoreaTime`) |
| `lib/adapter/` | 바깥 하나를 감싼다: `sensor/`(센서 채널) · `storage/`(환경설정 · 로그인 · 측정 저장소 · `EvimpWriter`(raw.txt) · `MetaWriter`(meta.txt)) · `update/`(확인 · 설치 통로) · `report/`(PDF 렌더러) |
| `lib/service/` | 여러 adapter 와 domain 을 순서대로 부르는 절차: `CaptureSession`(수집) · `MeasurementRecorder`(저장) · `MailService`(메일) |
| `lib/ui/core/` | 라우터, 디자인 토큰(`theme.dart`), 공용 위젯(`widgets/`) |
| `lib/ui/features/` | 화면별 폴더 (home(+`widgets/` 입력 칸 묶음) · measure · result(+비교 시트 · 메일 시트) · login · history · settings · update) |
| `android/…/vibration_checker/` | `MainActivity`(패키지 루트, 매니페스트) · `sensor/`(`SensorMethodHandler` 측정 통로 · `SensorStreamHandler`) · `noise/`(`NoiseCaptureHandler` · `NoiseAudioEncoder` M4A) · `update/`(`UpdateInstaller`) |
| `test/` | lib 와 같은 모양 + `architecture/`(층 규칙) · `screenshots/` · `support/` · `fixtures/records`(실측 EVIMP1) · `fixtures/scipy`(SciPy 생성물) |
| `tool/` | `import_workers.py`(작업자 명단), `fixtures/gen_conditioning_fixtures.py`(SciPy 정본 픽스처) |
| `assets/` | 리포트 서식 이미지 · 한글 폰트(`report/`), 로그인 작업자 명단(`workers/workers.json`, `admin/workers.xlsx`에서 `tool/import_workers.py` 로 만든다. 루트에 받은 원본 엑셀은 `.gitignore`. 실명이 평문으로 공개 저장소 · APK 에 들어간다, 2026-10-18 사용자 결정) |
| `design/icon/` | 앱 아이콘 원본 · OTIS 시안. `dart run flutter_launcher_icons` 로 `mipmap-*` 를 만든다. 앱 자산 목록에는 넣지 않는다 |
| `design/report_logo/` | 리포트 로고 원본(2172 x 724). 앱 자산 `assets/report/otis_v_check.png` 는 이것을 960 x 320 으로 줄인 것이다 |

## 층 규칙

`test/architecture/layer_rules_test.dart` 가 lib 의 import 로 고정한다.

```
domain     → domain 만   (flutter · dart:io · dart:ui · adapter · service · ui 금지)
domain/dsp → dsp 만       (다른 domain 폴더도 금지)
adapter    → domain · adapter
service    → adapter · domain · service
ui         → 제한 없음    (여러 단계 절차는 service 로)
```

import 는 모두 `package:vibration_checker/...` 로 쓴다(`always_use_package_imports`).
시험 도우미(`test/support/`)만 상대 경로다.

## 관통 원칙

1. **재지 않은 값을 0 이나 빈 문자열로 채우지 않는다.** 미측정은 `null`.
   `MeasurementResult` 의 지표는 `double?`, 판정 게터는 `bool?` 이다.
2. **숫자는 한 곳에만 둔다.** 리포트 좌표는 `report_layout.dart` ·
   `report_page1_layout.dart` · `report_chart_page_layout.dart`, 임계값은
   `report_thresholds.dart`, 화면 색·치수·글자는 `ui/core/theme.dart`,
   수집 · 신호 처리 수치는 `capture_config.dart`, 소음 수치는
   `noise_config.dart`, 단위 환산은 `dsp/units.dart`.
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
  - `AppScrollBody` · `AppBottomBar` — 화면 본문 틀과 아래 고정 버튼 자리.
    입력 바로 뒤에 누를 버튼(로그인)은 `liftAboveKeyboard: true` 로 키보드 위에
    올린다(입력칸이 많은 홈은 끈 채로, 2026-10-22)
  - `AppCard` — 회색 표면 카드, `AppNotice` — 안내 박스(danger · caution · alert)
  - `showAppConfirmDialog` — 제목 · 문구 · 버튼 한두 개 대화상자
  - `showAppSheet` — 바텀 시트, `showSuccessSnackBar` · `showErrorSnackBar`
  - `AppDialogButton` · `AppDialogIconButton` — 56dp 터치 영역을 지키는 버튼
- 화면은 `go_router` 경로(`ui/core/router.dart`)로만 오간다.
- 측정 · 저장 · 리포트 · 메일 로직을 화면 파일에 새로 넣지 않는다. 화면은
  `CaptureSession` · `MeasurementRecorder` · `MailService` · `SiteInfo.validate()`
  의 결과를 받아 문구와 화면 이동만 고른다.

## 작업 방식

- 작업은 함수 · 클래스 묶음 단위로 나눠 진행하고 묶음마다 리뷰를 받는다.
- 매 단계 끝에 "추가로 발견한 것"을 보고한다(없으면 "없음").
- 지시 범위 밖 파일은 읽기만 하고 고치지 않는다.
- 커밋할 때 `git add .` · `git add -A` 를 쓰지 않고 파일 경로를 하나씩
  지정하며, 커밋 전에 `git diff --cached --stat` 으로 들어가는 파일을
  확인한다(2026-10-11, 저장소 밖에 둘 파일이 섞이지 않게).
- 결정을 바꾸면 커밋 메시지에 날짜와 근거를 남기고, 지금 동작은 해당 spec 을
  고친다. 확인받지 못한 것은 해당 코드 주석의 `미확인:` 과 커밋 메시지에
  적고 권장안으로 진행한다. 결정 이력 · 미확인 목록 문서(`decisions.md` ·
  `pending_checks.md`)는 2026-10-28 지웠다.

## 병합 절차

작업 브랜치는 따로 말하지 않아도 작업이 끝나면 이 절차로 확인한 뒤 main 에
병합한다(2026-10-22 사용자 지시).

1. **자동 확인** — 하나라도 실패하면 병합하지 않고 보고한다.
   - `flutter analyze` 경고 0, `dart format` 변경 0, `flutter test` 전부
     통과(캡처 태그 제외), `flutter build apk --debug` 성공.
   - 기준 기록 회귀: 실측 픽스처(`test/fixtures/records/` 의 ride_reference ·
     conditioning_input_dev_256hz)로 낸 지표 고정값(`measurement_assembler_test`
     · `motion_zones_test` · `kinematics_test` · `stop_margin_test`)이 바뀌면
     이유를 적는다. 이 브랜치에서 의도적으로 바꾼 값은 "바뀜(의도)", 그 밖에
     바뀐 값은 "바뀜(의도 아님)" 으로 나눈다. 의도 아님이 하나라도 있으면
     병합하지 않는다.
2. **리포트 눈 확인** — ride_reference 로 PDF 를 만들어
   (`test/screenshots/report_pdf_shots_test.dart`) 쪽마다 PNG(110 dpi)로 보고
   직접 확인한다: 글자 잘림 · 겹침, 축 밖으로 나간 선, 빈 차트, 신호등 색과
   값의 불일치, 표시점과 글자 상자의 위치.
3. **예전 데이터 호환** — 이 브랜치 전에 저장된 result.json(시험 픽스처나
   main 에서 만든 결과)을 이 브랜치에서 열어 결과 화면 · 저장 목록 · PDF 가
   오류 없이 나오는지 확인한다.
4. **커밋 정리** — `git status` 가 깨끗한지 본다. `작업메모_*.md` 는 커밋하지
   않는다(`.gitignore`). 커밋은 파일 경로를 하나씩 지정한다.
5. **병합** — main 을 최신으로 한 뒤 `git merge --no-ff <브랜치>`. 병합 커밋
   메시지에 브랜치 요약(묶음별 한 줄)과 남은 실기기 확인 항목 번호를 적는다.
   충돌이 나면 스스로 풀지 말고 멈추고 보고한다. 병합 뒤 main 에서 1번을 한
   번 더 돌린다. push 하지 않고 브랜치는 지우지 않는다.
6. **보고(짧게)** — 병합 커밋 해시, 1 · 3번 결과, 2번에서 본 문제(없으면
   "없음"), 회귀 표에서 바뀐 값, 남은 실기기 확인 항목.

병합하지 않고 멈추는 경우: 1 · 3번 실패, 의도하지 않은 지표 변화, 2번에서
고객에게 보이는 깨짐, 병합 충돌, 사용자가 결정하라고 남겨 둔 항목이 아직
열려 있을 때, 실기기 확인이 필요하다고 표시한 Kotlin 변경. 그 밖에 실기기에서만
확인할 수 있는 항목은 병합을 막지 않는다.
