# 진동 신호 처리 사양 — 처리 순서 · result.json · meta.txt · 픽스처

코드는 `lib/domain/analysis/`(격자 → 지표), `lib/domain/dsp/`(필터 부품),
수치는 `lib/domain/config/capture_config.dart` 에 있다.

저장 절차(`MeasurementRecorder.record()`)는 이 순서로 진행한다.

```
GridResampler.resample()        256Hz 격자, 두 센서가 겹친 구간 앞뒤 0.5초 버림
  ├─▶ raw.txt (EVIMP1, 256Hz)    필터 · 기준선 보정 없음, 축별 전체 평균만 뺌(OTIS 관례). 원본은 native_raw.txt
  └─▶ SignalConditioner.condition()
        1. 기준선 0 맞춤          첫 1초 평균을 X · Y · Z 마다 뺀다(그 안에서 움직였으면 움직임 앞까지 · 끝 정지 1초)
        2. 40Hz 저역              4차 버터워스, 양방향(영위상)
        3. 256Hz → 100Hz 재표본   25/64 다상 FIR, 카이저 창 β 5.0
        소음 열은 거르지 않고 100Hz 시각에 선형 보간한다
      ─▶ MeasurementAssembler.assemble()   지표 · 리포트 · result.json
            4. 운동 · 최대 속도 · 운행 거리   가중 전 Z 의 움직인 구간만 적분 (`Kinematics.derive()`)
               저크                           가속도 → 1.6Hz 4차 버터워스 양방향 → 중앙 차분
               가속도 차트(표시용)             가속도 → 10Hz 4차 버터워스 양방향
            5. 주파수 가중 (RideWeighting)   X·Y Wd, Z 1Hz 고역(2차, 양방향) + Wk
               기종 응답 보정 (DeviceResponse)  Z 만, 보정 표에 있는 기종만 (갤럭시 S22 SM-S901…: 2차 25Hz 저역 양방향)
            6. 운행 구간 (TravelWindow)      출발 · 정지 0.5 m 제외, 운행 1 m 이하면 실패
            7. 반주기 P2P (HalfCycle)        구간 안 최대 P2P · A95, 구간 안 소음 최대 · 평균
            8. 정속 · 가감속 (MotionZones)   수직 최대 = 정속 구간 최대, Jptp = 가감속 구간 최대
```

- **설정 상수**: `CaptureConfig` 의 `conditionedRateHz`(100) ·
  `lowpassCutoffHz`(40) · `lowpassOrder`(4) · `baselineWindowMs`(1000).
  재표본 비 · 기준선 행 수 · 최소 측정 길이(`minimumRecordMs`, 2초)는 같은
  클래스의 게터가 유도한다. SciPy 정의를 따르는 알고리즘 상수(`halfLenPerRate`
  10, `kaiserBeta` 5.0)는 `dsp/polyphase_resampler.dart` 의 `PolyphaseResampler` 에
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
  `travelWindowFailureReason`) 줄을, 그 뒤에 `kinematics` 와
  `motionWindowStart/EndSec`(정지 측정이면 `motionWindow: none`, 여유가 기록
  앞 · 끝에서 잘렸으면 `motionWindowClippedAtStart/End: true`) 줄을 덧붙인다.
  운행 구간 줄 뒤에는 `zones` 와 `steadyStart/EndSec` · `zJptpClippedAtEnd`
  (못 정하면 `zonesFailureReason`) 줄과 `stopMarginSec` 이 붙는다. 가중 줄
  아래에 `deviceManufacturer` · `deviceModel` · `deviceCompensation`, 신호 처리
  줄에 `baselineSource` · `baselineStartSec` · `baselineSec` 이 있다
  (2026-10-22).
- **result.json**: `signalConditioning` 에 처리 방식 문자열
  (`baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)+devcomp(SM-S901N,lp25.0bw2zp)+motion(v>0.05,pad500ms)
  +jerk(lp1.6bw4zp)+acc(lp10.0bw4zp)+zones(v>0.05,pk0.5,a<0.03,min1000ms,jpad400ms)
  +noise(A,fast,+105.2,48000Hz)`,
  `SignalConditioner.methodLabel` + `RideWeighting.methodLabel` +
  `DeviceResponse.methodLabel(기종)` +
  `Kinematics.kinematicsMethodLabel` + `jerkMethodLabel` +
  `accelChartMethodLabel` + `MotionZones.methodLabel` +
  `noiseMethodLabel(마이크 표본 속도)`) 과
  `travelWindow`(첨자 · 초 · m) 또는 `travelWindowFailure`, `motionZones`
  (첨자 · 초) 또는 `motionZonesFailure`, `zJptp` · `zPtpPositionM`. `+zones`
  가 없는 2026-10-21 전 결과의 `zPtp` 는 운행 구간 전체 최대이고 Jptp ·
  위치가 없다. 2026-10-21 2차 ~ 10-22 결과는 `+devcomp` 자리에 `+zlp(20.0bw4zp)`
  가 있고 모든 기록의 수직에 20Hz 4차 저역을 건 값이다(그대로 읽는다). 그
  전 결과는 둘 다 없고 수직 저역이 없다. 2026-10-22 부터 기종
  (`deviceManufacturer` · `deviceModel`), 보정(`deviceCompensation`, 표에 없는
  기종이면 "none"), 정지 뒤 여유(`stopMarginSec`), Jptp 넓힘 막힘
  (`zJptpClippedAtEnd`), 기준선 출처(`baselineSource`)를 싣는다. `+motion` 이 없는
  2026-10-20 전 결과는 기록 전체를 적분한 예전 거리 · 최대 속도다. `+jerk`
  가 없는 2026-10-21 전 결과의 저크는 40Hz 가속도를 그대로 미분해 ±10 ~ 20
  m/s³ 로 크다(그대로 읽고 그린다). `+acc` 가 없는 결과의 `accelSeries` 는
  거르지 않은 가속도다(지금은 10Hz 저역을 건 차트 표시용). `+iso18738` 이
  없는 2026-10-15 전 결과는 가중 없이 전체 구간에서 낸 지표이고(그대로 읽고
  차트 점도 그때 정의로 찍는다), `signalConditioning` 이 null 인 더 예전
  결과는 원시 256Hz 기준이다. 시계열 `x/y/zSeries` 는 지표를 낸 그 값(가중
  뒤)이라 차트도 같은 값을 그린다. 화면에는 보이지 않는다.
- **가중 · 구간 상수**: `CaptureConfig.rideVerticalHighpassHz`(1.0) ·
  `rideVerticalHighpassOrder`(2) · `deviceResponseByModelPrefix`(기종 응답
  보정 표, `SM-S901` → 2차 25Hz) · `travelEdgeExclusionM`(0.5) ·
  `minimumTravelM`(1.0) · `motionSpeedThresholdMps`(0.05) ·
  `motionPaddingMs`(500) · `jerkLowpassHz`(1.6) · `jerkLowpassOrder`(4) ·
  `accelChartLowpassHz`(10) · `accelChartLowpassOrder`(4, 차트 표시용) ·
  `zoneRunSpeedMps`(0.05) · `zonePeakRatio`(0.5) · `zoneSteadyAccelMps2`(0.03)
  · `zoneMinimumSteadyMs`(1000, 정속 · 가감속 구간) · `zoneTransientPaddingMs`
  (400, Jptp 구간 넓힘) · `minimumStopMarginMs`(1000, 정지 뒤 여유 경고) ·
  `baselineMotionAccelMps2`(0.03) · `baselineMinimumMs`(300, 기준선 구간
  고르기). 저크
  저역은 OTIS 리포트 저크 차트 4개와 RMSE 0.02 ~ 0.03 m/s³ 로 맞춘 값이다
  (2026-10-21). 저크 필터의 양 끝 덧댐(15행) 때문에 조립은 16행 미만 격자를
  사유와 함께 돌려보낸다. ISO 8041 가중 상수(0.4 Hz 대역 제한, Wd 2 Hz/0.63,
  Wk 12.5 Hz/0.63 · 2.37 → 3.35 Hz/0.91)는 `ride_weighting.dart` 에 있다.
  가중 필터는 한 방향(인과), 1 Hz 고역만 양방향이다.
- **정본과 픽스처**: 처리 결과는 SciPy 1.18.1 과 같아야 한다
  (`test/domain/analysis/signal_conditioner_test.dart`). 픽스처는
  `test/fixtures/` 에 있고 `tool/fixtures/gen_conditioning_fixtures.py` 가
  만든다(저장소 루트에서 `python tool/fixtures/gen_conditioning_fixtures.py
  test/fixtures/records/conditioning_input_dev_256hz.txt test/fixtures/scipy`).
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
    건드리지 않는다(`python tool/fixtures/gen_conditioning_fixtures.py
    --weighting test/fixtures/records/ride_reference.txt
    test/fixtures/records/conditioning_input_dev_256hz.txt test/fixtures/scipy`).
    `ride_weighting_test` · `measurement_assembler_test` 가 1e-9 · 1e-6 으로
    대조한다. `weighting_expected_metrics.json` 은 2026-10-20 움직인 구간
    적분으로 다시 만들었다 — 이 PC 에 SciPy 1.18.1 이 없어 아나콘다 1.16.3
    으로 만들었고(파일의 `scipy` 값), 가중 단위 픽스처를 같이 만들어 보니
    1.18.1 판과 1e-12 안에서 같아 그 파일은 되돌렸다

  ```python
  x = x - x[:256].mean()                                  # 축마다 첫 1초 평균
  sos = scipy.signal.butter(4, 40, fs=256, output='sos')
  y = scipy.signal.sosfiltfilt(sos, x)                    # padtype='odd', padlen 기본
  y100 = scipy.signal.resample_poly(y, 25, 64)            # window=('kaiser', 5.0), padtype='constant'
  ```
