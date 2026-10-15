# OTIS V-Check — 승강기 진동·소음 측정 앱 (vibration_checker)

일반 안드로이드 폰으로 승강기 진동(3축)·소음을 측정하고 OTIS TUNE 규격 PDF
리포트를 만들어 메일로 보내는 Flutter 앱. 앱 이름(홈 화면 아이콘 아래 ·
`MaterialApp` title)은 "OTIS V-Check"(2026-10-13). 패키지 이름
`com.otis.vibration_checker` 는 바꾸지 않는다 — 바꾸면 다른 앱으로 취급돼
업데이트가 이어지지 않는다. Android 우선, iOS 는 나중.

## 명령

```bash
flutter analyze                                   # 경고 0 유지
dart format --output=none --set-exit-if-changed lib test
flutter test                                      # 전부 통과 유지
# 화면 · 리포트 캡처(screenshot 태그, 평소 건너뜀). SHOT_DIR 에 PNG · PDF 를 쓴다
flutter test --tags screenshot --run-skipped test/screenshots
```

## 구조

| 경로 | 역할 |
|---|---|
| `lib/model/` | 순수 자료형 (`MeasurementResult`) |
| `lib/domain/capture/` | 네이티브 이벤트 → 256Hz 격자 환산 (`GridResampler`), 지표 계산 전 신호 처리 (`SignalConditioner`), ISO 8041 주파수 가중 (`RideWeighting`). 수집 · 처리 수치는 `CaptureConfig` |
| `lib/domain/report/` | 리포트 좌표·임계값·지표 계산. 운행 구간(`TravelWindow`) · 반주기 P2P(`HalfCycle`)도 여기. 숫자는 여기에만 둔다 |
| `lib/domain/session/` | 화면 사이에 넘기는 이번 측정 상태 (`MeasurementSession`) |
| `lib/domain/time/` | 사람이 읽는 시각을 한국 시간(UTC+9)으로 맞추는 `KoreaTime` |
| `lib/domain/update/` | 앱 안 업데이트 — version.json 읽기(`UpdateInfo`) · 판정(`UpdateDecision`) · 배포 주소와 시간 값(`UpdateConfig`) |
| `lib/adapter/` | 플랫폼 경계 — 센서 채널, 파일·저장소, PDF 렌더링, 환경설정. 측정 한 번의 수집 절차는 `capture_session.dart`, 저장 절차는 `measurement_recorder.dart`. 업데이트 확인은 `update_checker.dart`, 내려받기 · 설치 통로는 `update_installer.dart` |
| `lib/ui/core/` | 라우터, 디자인 토큰(`theme.dart`), 공용 위젯(`widgets/`) |
| `lib/ui/features/` | 화면별 폴더 (home · measure · history · result · settings · shared · update) |
| `android/app/src/main/kotlin/` | `MainActivity` · `SensorStreamHandler` · `NoiseCaptureHandler` · `UpdateInstaller`(APK 내려받기 · SHA-256 확인 · `PackageInstaller` 설치) |
| `pdf_report_dev/` | 리포트 좌표를 확정할 때 쓴 파이썬 프로토타입 (앱 빌드와 무관) |
| `tool/` | 기기에서 뽑은 소음 진단 PCM 을 오프라인으로 재계산 · A 가중 비교하는 파이썬 도구(`compare_noise_pcm.py`). 앱 빌드와 무관 |
| `docs/comment_rules.md` | 주석 규칙. **코드 작업 전 매번 다시 읽는다** |
| `docs/report_layout.json` | 리포트 좌표 정본. `report_layout_test` 가 Dart 상수와 대조한다 |
| `docs/reference/sample_evimp.pdf` | 원본 TUNE 리포트. 코드 주석의 `근거:` 가 가리킨다 |
| `docs/reference/H6N1AP65.pdf` | 원본 TUNE 리포트(실제 현장). 머리말 표기(하중 · 제품 · 주소)의 근거. **H6N1AP65.pdf 는 저장소 밖 보관**(`.gitignore`) — 실제 엔지니어명 · 현장명이 들어 있다. 시험 픽스처로 쓰지 않는다 |
| `docs/noise_otis_offset_notes.md` | 소음 dBA 오프셋 · OTIS 차이 · 남은 과제 |
| `docs/noise_pcm_diagnostics.md` | 소음 진단 PCM · CSV 산출물의 자리 · 형식, `tool/` 로 재계산하는 법 |
| `docs/release.md` | 릴리스 서명 키 보관 · `android/key.properties` · 서명 확인(인증서 지문). 키가 없으면 릴리스 빌드가 멈춘다 |
| `assets/icon/` | 앱 아이콘 원본 · OTIS 시안. `dart run flutter_launcher_icons` 로 `mipmap-*` 를 만든다. 앱 자산 목록에는 넣지 않는다 |

## 화면 흐름

```
홈(현장 정보, 입력 즉시 저장) ─▶ 시작(대기 시간 · 거치 안내)
  ─[마이크 권한 확인]─▶ 측정(카운트다운 → 수집, 볼륨키로 종료)
  ─▶ 결과(/result/:id: 지표 · 결과 비교 · 메일 · 테스트 재실행)
홈 ─▶ 저장 결과 목록(history) ─▶ 결과
홈 ─▶ 설정(엔지니어 이름 · 수신 이메일 목록 · 앱 버전 · 업데이트 확인)
```

- 앱 안 업데이트(2026-10-13, 절차는 `docs/release.md`): 홈이 앱 실행마다
  한 번, 설정이 "업데이트 확인" 으로 배포 저장소(GitHub Releases)의
  version.json 을 3초 안에 받아 본다. 못 받으면 조용히 넘어간다 —
  인터넷이 없는 기계실에서도 측정은 막지 않는다. 선택 업데이트는 "나중에"
  를 누르면 같은 번호를 하루 동안 다시 묻지 않고, 필수(빌드 < minimum)는
  닫을 수 없다. 측정 · 결과 화면에서는 확인 · 설치하지 않는다. 설치는
  `PackageInstaller` 세션이고 FileProvider 를 쓰지 않는다.

- 홈 현장 정보(2026-10-08 · 10-11): 제번 · 현장명 · 우편번호(숫자 5자리) ·
  주소 · 최하층 / 최상층 · 운전 방향 · 기종 · 하중(kg 고정, 2026-10-13 —
  `SiteInfo.loadUnit`. 단위를 고를 수 있던 빌드의 lb 결과는 리포트에
  "파운드" 로 찍고, 재실행 때는 하중을 빈 칸으로 되살린다) · 해석
  종류(분석 내용, 5가지) · 추가 참고사항. 참고사항만 선택이고
  나머지는 `SiteInfo.validate()` 가 필수로 본다. 하중 판정은
  `SiteInfo.parseLoad()` 한 곳에서 하고 저장 변환도 같은 함수를 쓴다.
  입력은 바뀔 때마다 기기에 저장하되 참고사항은 저장하지 않아 측정마다 빈
  칸에서 시작한다. 해석 종류는 기록 · 리포트 표시만 하고 계산은 같다.
- 결과 화면 "테스트 재실행"은 되살린 현장 정보가 `validate()` 에 걸리면
  (하중 · 우편번호를 받기 전 예전 결과, lb 결과) 홈에서 채우라고 안내만
  하고 재지 않는다.
- 엔지니어 이름은 설정에 기기 단위로 두고(`PrefsStore`), 측정을 저장하는
  시점 값을 결과(`engineerName`)에 싣는다. 나중에 설정을 바꿔도 예전
  리포트 이름은 그대로다.
- 리포트 1쪽 머리말: 하중 "2000 킬로그램", 측정 = 해석 종류, 주소 "주소,
  우편번호", 제품 "엘리베이터, 기종"(기종 쉼표는 리포트에서만 공백),
  엔지니어 = 저장 시점 이름(2 · 3쪽 엔지니어 칸도 같다), 층 정보
  "Start Floor : 1, Stop Floor : 8". 값이 없는 칸은
  "미입력"(`ReportPage1.placeholder`).
  넘칠 수 있는 칸은 오른쪽 여백을 넘으면 글자를 줄여 한 줄을 지킨다.
- 리포트 1쪽 Performance Metrics(2026-10-15): 진동 값 단위는 "milli-G"
  (`ReportMetric.vibrationUnit`, 저장 값 · 앱 화면은 mg 그대로). 수평 두
  행은 X · Y 중 큰 값 하나만 적고 내역을 붙이지 않는다. 황색 · 적색 칸은
  위에서부터 57/60 · 72/75 · 14/21 · 20/30 · 9/13.5 · 17/25.5 · 0/0 · 0/0
  (`ReportThresholds`). 맨 왼쪽 원은 황색 기준 이하 초록, 넘으면 노랑, 적색
  기준을 넘으면 빨강, 값이 없으면 회색이고 최대 속도 · 운행 거리는 원이
  없다. 분석 자료 표의 "Machine으로 부터 진동" · "Belts" 는 서식 글자를
  덮고 "권상기 머신으로 부터 진동" · "로우프" 로 찍는다.
- 저장 결과 목록은 결과 파일을 읽지 못한 측정(측정 일시가 없거나 깨짐 등)을
  그 한 건만 "읽을 수 없는 결과" 로 보여 주고 지울 수 있게 한다
  (`MeasurementRepository.listEntries()`, 2026-10-15). 측정 일시를 "지금"
  으로 채워 읽지 않는다(`MeasurementResult.fromMap` 은 `FormatException`).
- 리포트 값 칸 소수 자리: 최대 속도 둘째 자리(1.74m/s), 나머지 첫째 자리,
  100 이상은 정수(`ReportMetric._decimalsByUnit`).
- 사람이 읽는 시각(리포트 머리말 · 측정 ID · 저장 결과 목록 · 결과 화면 ·
  메일 제목)은 기기 시간대와 상관없이 한국 시간이다(`KoreaTime.of()`,
  2026-10-15). 저장 값(`dateTime`)은 그대로 둔다.

- 측정 화면은 끝나면 결과 화면으로 바뀐다(`pushReplacement`). 실패 · 중단이면
  측정을 시작한 화면으로 돌아간다(`pop`).
- 마이크 권한은 측정 화면에 들어가기 전에 `ensureMicPermission()` 이 받는다.
  측정 중에는 휴대폰이 뒤집혀 있어 권한 창을 누를 수 없다.
- 바텀 시트는 `showAppSheet()` 로만 띄운다. 아래쪽 시스템 막대를 비켜 준다.
- 소음 측정은 시작할 때마다 마이크 원본 PCM과 계산 과정(읽기 · 계산 ·
  센서에 붙인 시각)을 기기 외장 저장소(`noise_diagnostics/<측정시각>_
  <부팅시각>/`)에 디버그 플래그 없이 항상 남긴다(`NoiseDiagnostics`,
  new/dB 기능). 마이크를 계속 열어 두므로 대화가 담길 수 있고, 분석 후
  수동 정리가 필요하다(`docs/noise_pcm_diagnostics.md`). 2026-10-14 기준
  이 동작을 유지하기로 했다.
- 메일은 PDF 리포트와 로우 데이터(`raw.txt`, 256Hz 격자 · 필터 · 기준선
  보정 전)를 고른 만큼 붙인다. 둘 다 기본 체크이고, `raw.txt` 가 없는 측정은
  본문에 "누락:" 줄로 밝힌다. 위 소음 진단 산출물도 "데시벨 산출물"(CSV ·
  메타데이터)과 "마이크 원본(audio.pcm)"으로 나눠 선택해 붙일 수 있으나
  둘 다 기본 체크가 아니다 — 마이크 원본은 용량이 크고 대화가 담길 수
  있어서다. 가장 최근 진단 폴더만 찾으며, 없으면 같은 방식으로 "누락:"
  줄로 밝힌다. 추가 참고사항이 있으면 본문 첨부 목록 앞에
  "[참고사항]" 머리줄과 함께 넣는다. 안드로이드 원본(`native_raw.txt`)은 기기의
  측정 폴더에만 남기고 보내지 않는다(2026-10-08). 안드로이드 원본은
  측정이 실패해도 그 측정 폴더로 옮기고, 저장하지 않는 중단(뒤로가기 · 앱
  전환 · 센서 무응답)이면 바로 지운다(`CaptureSession.discard()`).
- 거치는 화면을 아래로, 출입구를 바라보고 섰을 때 휴대폰 위쪽이 왼쪽이다
  (2026-10-07, 오티스폰도 같이 바꿈). 격자 환산의 Y · Z 부호 뒤집기는 예전
  (위쪽 오른쪽) 때 정한 그대로 쓴다 — 두 기기가 함께 돌아 부호 관계가 같다.

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
            4. 운동 · 최대 속도 · 운행 거리   가중 전 Z 전체에서 (`_deriveKinematics`)
            5. 주파수 가중 (RideWeighting)   X·Y Wd, Z 1Hz 고역(2차, 양방향) + Wk
            6. 운행 구간 (TravelWindow)      출발 · 정지 0.5 m 제외, 운행 1 m 이하면 실패
            7. 반주기 P2P (HalfCycle)        구간 안 최대 P2P · A95, 구간 안 소음 최대 · 평균
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
  `conditioningFailureReason` 한 줄만. 그 뒤에 `weighting` 과
  `travelWindowStart/EndSec` · `travelWindowStart/EndM`(구간을 못 정하면
  `travelWindowFailureReason`) 줄을 덧붙인다.
- **result.json**: `signalConditioning` 에 처리 방식 문자열
  (`baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)`,
  `SignalConditioner.methodLabel` + `RideWeighting.methodLabel`) 과
  `travelWindow`(첨자 · 초 · m) 또는 `travelWindowFailure`. `+iso18738` 이
  없는 2026-10-15 전 결과는 가중 없이 전체 구간에서 낸 지표이고(그대로 읽고
  차트 점도 그때 정의로 찍는다), `signalConditioning` 이 null 인 더 예전
  결과는 원시 256Hz 기준이다. 시계열 `x/y/zSeries` 는 지표를 낸 그 값(가중
  뒤)이라 차트도 같은 값을 그린다. 화면에는 보이지 않는다.
- **가중 · 구간 상수**: `CaptureConfig.rideVerticalHighpassHz`(1.0) ·
  `rideVerticalHighpassOrder`(2) · `travelEdgeExclusionM`(0.5) ·
  `minimumTravelM`(1.0). ISO 8041 가중 상수(0.4 Hz 대역 제한, Wd 2 Hz/0.63,
  Wk 12.5 Hz/0.63 · 2.37 → 3.35 Hz/0.91)는 `ride_weighting.dart` 에 있다.
  가중 필터는 한 방향(인과), 1 Hz 고역만 양방향이다.
- **정본과 픽스처**: 처리 결과는 SciPy 1.18.1 과 같아야 한다
  (`test/domain/capture/signal_conditioner_test.dart`). 픽스처는
  `test/fixtures/` 에 있고 `pdf_report_dev/gen_conditioning_fixtures.py` 가
  만든다(저장소 루트에서 `python pdf_report_dev/gen_conditioning_fixtures.py
  test/fixtures/conditioning_input_dev_256hz.txt test/fixtures`).
  - `conditioning_input_dev_256hz.txt` — 2026-10-06 개발폰 실측
    (`RAW_1_20261006-091841`, 앱이 앞뒤 0.5초 버림) EVIMP1 9,439행. 스크립트의
    입력이며 스크립트가 만들지 않는다
  - `conditioning_expected_100hz.txt` — 위 입력의 X · Y · Z 에 아래를 적용한
    3,688행. `#` 머리말 한 줄(원래 파일은 `RAW_1_…` 에서 만들어 머리말의 입력
    파일 이름만 다르다)
  - `conditioning_unit_cases.json` — 10Hz + 60Hz 합성 신호 300표본 `input`,
    그 `filtfilt` 출력, `input` 을 바로 재표본한 `resample_25_64`, 계수 `sos`.
    값을 소수 12자리로 반올림해 저장하므로, 다시 만들거나 반올림한 `input`
    으로 다시 계산하면 1e-12 대 차이가 날 수 있다(시험 기준 1e-9)
  - `weighting_unit_cases.json` · `weighting_expected_metrics.json`
    (2026-10-15) — 가중 계수 · 출력과, ride_reference · 개발폰 기록을 앱과
    같은 길로 계산한 구간 · 지표. `--weighting` 모드로 만들고 위 세 파일은
    건드리지 않는다(`python pdf_report_dev/gen_conditioning_fixtures.py
    --weighting test/fixtures/ride_reference.txt
    test/fixtures/conditioning_input_dev_256hz.txt test/fixtures`).
    `ride_weighting_test` · `measurement_assembler_test` 가 1e-9 · 1e-6 으로
    대조한다

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
- 커밋할 때 `git add .` · `git add -A` 를 쓰지 않고 파일 경로를 하나씩
  지정하며, 커밋 전에 `git diff --cached --stat` 으로 들어가는 파일을
  확인한다(2026-10-11, 저장소 밖에 둘 파일이 섞이지 않게).

## 알려진 미해결

- 진동 지표 결정 이력
  - 2026-10-07: 기준선 0 맞춤 + 40Hz 저역(4차 버터워스, 양방향) + 100Hz
    재표본 후 값으로 낸다(2026-10-04 "진동 필터를 넣지 않는다" 결정을 바꿈).
    근거는 오티스폰 · 개발폰 동시 측정 6쌍 — 개발폰 Z 가 정지 상태에서
    −2 ~ −4mg 에 떠 있고, 오티스폰(100Hz)이 담지 못하는 50Hz 위 성분이 개발폰
    최대 P2P 를 키웠다
  - 2026-10-15: 원본 리포트(ISO 18738 방식)와 같은 길로 바꾼다 — 가중
    (X·Y Wd, Z 1Hz 고역 + Wk), 운행 구간(출발 · 정지 0.5 m 제외), 최대
    P2P = 반주기 P2P 의 최댓값(예전 "전체 최대 − 최소" 를 버림). 2026-10-07
    "전체 구간 · 가중 없음" 결정을 바꾼다. 원본 리포트를 만든 기록
    (ride_reference)에서 원본 대비 수직 5.53/3.71(원본 6.1/3.6) · 수평
    11.07/5.01(11.3/4.8) · 소음 45.3/48.7(45.5/48.7), 신호등 8행 모두 원본과
    같다. 예전 방식은 수직 127 · 수평 48.3 으로 정상 승강기가 늘 빨강이었다
  - 수직 처리는 ride_reference 비교로 골랐다(1Hz 고역만 6.97/4.23 — A95 가
    ±15% 밖, Wk 만 9.06/3.74 — 최대가 밖, 고역 + Wk 5.53/3.71). 원본
    (레퍼런스폰 앱)이 실제로 쓴 수직 처리는 미확인이다. 비교 기록이 한 건뿐이다
  - `raw.txt` 와 `native_raw.txt` 는 처리 전 값이다. 정속 구간 감지는 넣지
    않는다(운행 구간은 거리로만 정한다). A95 백분위는 최근접 순위다(표준의
    보간 방식 미확인)
- 리포트 차트 세로축(2026-10-10 · 10-11, `lib/domain/report/chart_scale.dart`):
  원본 리포트 범위(X ±4 · Y ±10 · Z ±20 · 소음 40~54 · 위치 0~10 · 속도
  0~1 · 가속도 ±0.6 · 저크 ±0.5)를 최소 범위로 두고, 데이터 양 끝에 10% 씩
  여유를 더한 범위가 그 안이면 그대로, 넘치면 1 · 2 · 2.5 · 5 × 10ⁿ 눈금
  (6칸 이하)으로 넓힌다. 진동 · 가속도 · 저크는 0 가운데, 위치 · 속도는 0
  아래끝(속도는 크기를 그린다, 저장 값은 부호 그대로), 소음은 넓힐 때 폭
  14 dB 만 지키고 0(미측정) 구간은 선을 끊는다. 개발폰 · 레퍼런스폰 · 하강
  가정 3자료 × 8차트 모두 축 밖 표본 0%. X · Y · Z 차트에는 최댓값 ·
  최솟값 자리에 흰 테를 두른 굵은 빨간 점을 찍고, 최댓값 점 옆(오른쪽,
  자리가 없으면 왼쪽)에 흰 상자 · 굵은 빨간 글자로 "P2P 값 milli-G"(1쪽
  표와 같은 지표)를 적는다. 소음 최댓값도 같은 방식이다(2026-10-15).
  가로축은 가장 긴 시계열의 마지막 표본까지 담는다(`_timeSpan()`).
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
  판정 기준은 2026-10-15 사용자 지시로 원본 리포트 서식의 황색 · 적색 값을
  쓴다(요구사항서 값 Z 15 · X·Y 10 · 소음 50 에서 바꿈). 앱 화면의 초과
  표시(결과 · 저장 결과 목록)도 같은 적색 기준(Z 30, X·Y 25.5, 소음 75)을
  쓴다. 그 값이 무엇을 근거로 정해졌는지는 미확인이다.
- 소음 dBA 오프셋 87.3 은 임시값. A가중 없음 (`noise_otis_offset_notes.md`).
- `docs/reference/sample_evimp.pdf` 는 축별 계수 분리 이전의 단일 계수로
  만들어졌다. 차이는 최대 0.14pt. 좌표가 아니라 참조 PDF 를 다시 만들어야 한다.
- 요구사항서(`Vibration_Checking_App_Development_20260630.pdf`)가 저장소에 없다.
- 앱 안 업데이트(2026-10-13)의 배포 저장소 주인(westone / OTIS)이 미정이다.
  `UpdateConfig.releaseRepository` 에 권장안을 넣어 두었고, 저장소가 없으면
  확인이 조용히 실패한다. 실기기 설치 경로(설치 허용 · 서명 충돌 · 설치 뒤
  재시작)는 확인 전이다(`docs/pending_checks.md`).
- 릴리스 서명 키(2026-10-13)로 바꾸기 전 디버그 키로 서명해 깐 기기는 한
  번 지우고 새로 깔아야 한다. 기기의 측정 결과도 지워지므로 먼저 옮긴다.
- 서버 연동은 미구현이다. 로그인은 두지 않는다(수신 이메일은 기기에 목록으로
  둔다).
- 소음 RMS 창(`WINDOW_SEC`) · 갱신 주기(`HOP_HZ`)는 OTIS 와 맞춰 보는
  실험값이다 (`NoiseCaptureHandler.kt`). 2026-10-12 부터 IEC 61672-1 "Fast"
  시정수(`FAST_TIME_WEIGHT_SEC`, 0.125초)로 평균 제곱값을 지수평활해 낸다.
