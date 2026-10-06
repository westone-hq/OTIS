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
| `lib/domain/capture/` | 네이티브 이벤트 → 256Hz 격자 환산 (`GridResampler`), 지표 계산 전 신호 처리 (`SignalConditioner`). 수집 · 처리 수치는 `CaptureConfig` |
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

## 진동 신호 처리

저장 절차(`MeasurementRecorder.record()`)는 이 순서로 진행한다.

```
GridResampler.resample()        256Hz 격자, 두 센서가 겹친 구간 앞뒤 0.5초 버림
  ├─▶ raw.txt (EVIMP1, 256Hz)    필터 · 기준선 보정 없음. 원시 보존용
  └─▶ SignalConditioner.condition()
        1. 기준선 0 맞춤          첫 1초 평균을 X · Y · Z 마다 뺀다
        2. 40Hz 저역              4차 버터워스, 양방향(영위상)
        3. 256Hz → 100Hz 재표본   25/64 다상 FIR, 카이저 창 β 5.0
        소음 열은 거르지 않고 100Hz 시각에 선형 보간한다
      ─▶ MeasurementAssembler.assemble()   지표 · 리포트 · result.json
```

- **설정 상수**: `CaptureConfig` 의 `conditionedRateHz`(100) ·
  `lowpassCutoffHz`(40) · `lowpassOrder`(4) · `baselineWindowMs`(1000).
  재표본 비 · 기준선 행 수 · 최소 측정 길이(`minimumRecordMs`, 2초)는 같은
  클래스의 게터가 유도한다. SciPy 정의를 따르는 알고리즘 상수(`halfLenPerRate`
  10, `kaiserBeta` 5.0)는 `signal_conditioner.dart` 의 `PolyphaseResampler` 에
  있다. 차수가 홀수이거나 차단 주파수가 100Hz 의 절반 이상이면 `ArgumentError`.
- **실패**: `RecordFailure.conditioningFailed`. 원인은
  `RecordOutcome.conditioningCause` 로 가른다 — 격자가 기준선 구간보다 짧으면
  `ConditioningFailure.gridTooShort`(측정 화면이 "N초 이상 측정" 안내),
  설정 오류면 `invalidConfig`. 실패해도 `raw.txt` 는 이미 써 두어 남는다.
- **meta.txt**: 기존 집계 뒤에 `conditioning` · `baselineX/Y/Zmg` ·
  `baselineStdX/Y/Zmg`(기준선 구간 모표준편차, 판정에 안 씀) ·
  `conditionedRateHz` · `conditionedRowCount` 줄을 덧붙인다. 실패면
  `conditioningFailureReason` 한 줄만.
- **result.json**: `signalConditioning` 에 처리 방식 문자열
  (`baseline+lp40bw4zp+rs100`, `SignalConditioner.methodLabel`). 이 처리 전
  예전 결과는 null 이고 지표가 원시 256Hz 기준이다. 화면에는 보이지 않는다.
- **정본과 픽스처**: 처리 결과는 SciPy 1.18.1 과 같아야 한다
  (`test/domain/capture/signal_conditioner_test.dart`). 픽스처는
  `test/fixtures/` 에 있고, 만드는 스크립트는 저장소에 없다.
  - `conditioning_input_dev_256hz.txt` — 2026-10-06 개발폰 실측
    (`RAW_1_20261006-091841`, 앱이 앞뒤 0.5초 버림) EVIMP1 9,439행
  - `conditioning_expected_100hz.txt` — 위 입력의 X · Y · Z 에 아래를 적용한
    3,688행. `#` 머리말 한 줄
  - `conditioning_unit_cases.json` — 300표본 `input`, 그 `filtfilt` 출력,
    `input` 을 바로 재표본한 `resample_25_64`, 계수 `sos`

  ```python
  x = x - x[:256].mean()                                  # 축마다 첫 1초 평균
  sos = scipy.signal.butter(4, 40, fs=256, output='sos')
  y = scipy.signal.sosfiltfilt(sos, x)                    # padtype='odd', padlen 기본
  y100 = scipy.signal.resample_poly(y, 25, 64)            # window=('kaiser', 5.0), padtype='constant'
  ```

## 관통 원칙

1. **재지 않은 값을 0 이나 빈 문자열로 채우지 않는다.** 미측정은 `null`.
   `MeasurementResult` 의 지표는 `double?`, 판정 게터는 `bool?` 이다.
2. **숫자는 한 곳에만 둔다.** 리포트 좌표는 `report_layout.dart`, 임계값은
   `report_thresholds.dart`, 화면 색·치수·글자는 `ui/core/theme.dart`,
   수집 · 신호 처리 수치는 `capture_config.dart`.
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

- 2026-10-07 결정으로 진동 지표 · 리포트는 기준선 0 맞춤 + 40Hz 저역(4차
  버터워스, 양방향) + 100Hz 재표본 후 값으로 낸다(2026-10-04 "진동 필터를
  넣지 않는다" 결정을 바꿈, 처리는 위 "진동 신호 처리"). 근거는 오티스폰 ·
  개발폰 동시 측정 6쌍이다 — 개발폰 Z 가 정지 상태에서 −2 ~ −4mg 에 떠 있고,
  오티스폰(100Hz)이 담지 못하는 50Hz 위 성분이 개발폰 최대 P2P 를 키웠다.
  `raw.txt` 와 `native_raw.txt` 는 처리 전 값이다. 정속 구간 감지는 여전히
  넣지 않는다. 최대 P2P 는 처리 후 시계열의 최대 − 최소, 평균(A95)은 같은
  시계열에서 반주기 P2P 의 95백분위(최근접 순위)로 낸다. Z 에는 운행 가감속이
  섞여 적색 기준을 늘 넘는다. EVA 가 따르는 ISO 18738 방식(ISO 8041 가중,
  출발 · 정지 0.5m 제외 구간)은 조사만 해 두었다. 차트 X/Y 축은 처리 후
  원본 범위(±4/±10)로 되돌렸다(처리 후 ±4 밖 표본 0.3~0.9%).
- 신호 처리 남은 과제
  - 26.5Hz 봉우리가 개발폰에서 1.25~2.1배 크다. 40Hz 아래라 이 처리로 줄지
    않는다.
  - 차단 주파수 40Hz 는 비교 측정을 더 모아 조정할 수 있다.
  - `pdf_report_dev` 프로토타입에는 이 처리를 넣지 않았다.
  - 이 처리 전에 저장한 결과(`signalConditioning` 이 null)는 원시 256Hz
    지표라 새 결과와 기준이 다르다.
- 격자는 두 센서가 겹친 구간의 앞뒤를 0.5초씩 버리고 만든다(2026-10-05,
  `CaptureConfig.edgeTrimMs`). 시작 · 종료 입력(볼륨키) 충격을 빼려는 것이고,
  볼륨키 충격 길이는 실기기 확인 전이다. 원본 기록(`native_raw.txt`)은 자르지
  않는다. 기준선 1초까지 남아야 하므로 측정은 2초 이상이어야 저장된다.
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
