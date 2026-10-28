import 'dart:math' as math;

import 'package:vibration_checker/domain/analysis/device_response.dart';
import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/analysis/kinematics.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/analysis/ride_weighting.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/auth/worker.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-09-15 13:08:37 · 박건준
/// 클래스: MeasurementAssembleResult
/// 목적: 캡처 결과를 측정 결과 모델로 바꾼 결과를 담는다. 성공이면
///       `result`에 모델이, 실패면 `failureReason`에 사유가 들어가고
///       둘 중 하나만 채워진다.
///       실패를 빈 모델로 바꿔 돌려주지 않는다. 값이 전부 비어 있는
///       모델은 아직 재지 못한 정상 측정과 생김새가 같아서, 받는 쪽이
///       변환이 실패했다는 사실 자체를 알 수 없게 된다.
class MeasurementAssembleResult {
  /// 변환된 측정 결과. 변환하지 못했으면 null
  final MeasurementResult? result;

  /// 변환하지 못한 사유. 변환했으면 null
  final String? failureReason;

  /// 운행 거리 · 최대 속도를 적분한 움직인 구간. 저장 절차가 집계 파일
  /// (meta.txt)에 적는다. 정지 측정이거나 변환하지 못했으면 null
  final MotionWindow? motion;

  /// 작성: 2026-09-15 13:08:37 · 박건준
  /// 수정: 2026-10-20 14:05:12 · 박건준
  /// 함수: MeasurementAssembleResult.success
  /// 목적: 변환에 성공한 결과를 담는 생성자.
  /// 인자: result — 변환된 측정 결과
  ///       motion — 움직인 구간. 정지 측정이면 null
  const MeasurementAssembleResult.success(
    MeasurementResult this.result, {
    this.motion,
  }) : failureReason = null;

  /// 작성: 2026-09-15 13:08:37 · 박건준
  /// 수정: 2026-10-20 14:05:12 · 박건준
  /// 함수: MeasurementAssembleResult.failure
  /// 목적: 변환하지 못한 사유만 담는 생성자.
  /// 인자: failureReason — 변환하지 못한 사유
  const MeasurementAssembleResult.failure(String this.failureReason)
    : result = null,
      motion = null;

  /// 작성: 2026-09-15 13:08:37 · 박건준
  /// 함수: isSuccess
  /// 목적: 변환에 성공했는지 알려준다.
  /// 반환: `result`가 채워져 있고 사유가 없으면 true
  bool get isSuccess => failureReason == null && result != null;
}

/// 작성: 2026-09-15 13:08:37 · 박건준
/// 수정: 2026-10-22 22:40:00 · 박건준
/// 클래스: MeasurementAssembler
/// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산 결과와 현장
///       정보를 리포트가 쓰는 측정 결과 모델로 바꾼다. 진동 시계열은
///       가중해 싣고(소음은 그대로), 아래 지표를 새로 계산한다.
///
///       수직 진동에서 가속도 · 속도 · 누적 이동량 · 저크를 만들고,
///       최대 속도와 운행 거리를 거기서 뽑는다.
///
///       받는 격자는 지표 계산 전 신호 처리(`SignalConditioner`)를 거친
///       100Hz 격자다 — 기준선 0 맞춤, 40Hz 저역(4차 버터워스, 양방향),
///       256Hz → 100Hz 재표본. 수치는 `CaptureConfig` 에 있다. 오티스폰
///       (OTIS iOS 앱)과 같은 주파수 범위에서 지표를 견주려는 것이다
///       (2026-10-07 결정).
///       진동 지표는 원본 리포트(ISO 18738 방식)와 같은 길로 낸다
///       (2026-10-15, 2026-10-07 "전체 구간 · 최대 − 최소" 결정을 바꿈).
///       1. 운동(속도 · 위치 · 가속도 · 저크)과 최대 속도 · 운행 거리는
///          가중 전 수직 진동에서 움직인 구간만 적분해 낸다(2026-10-20,
///          `Kinematics.derive()`)
///       2. 진동에 주파수 가중(`RideWeighting`)을 건다 — 수평 Wd, 수직
///          1Hz 고역 + Wk. 가감속이 빠져 Z 가 늘 적색을 넘던 문제가 없다.
///          수직은 그 뒤 기종 응답 보정(`DeviceResponse`, 2026-10-22)을 건다.
///          보정 표에 있는 기종의 기록에만 걸고 오티스폰 기록에는 걸지
///          않는다(2026-10-21 2차의 모든 기록 20Hz 저역을 바꿈)
///       3. 위치에서 운행 구간(`TravelWindow`, 출발 · 정지 0.5 m 제외)을
///          정한다
///       4. 구간 안 가중 시계열의 반주기 P2P(`HalfCycle`)에서 최대 P2P 와
///          A95 를, 구간 안 소음에서 최대를 낸다
///       5. 수직 최대(`zPtp`)는 정속 구간, 가감속 최대(`zJptp`)는 그 밖
///          운행에서 낸다(`MotionZones`, 2026-10-21). 수직 A95 는 4 그대로
///       운행 구간을 정하지 못하면(운행 1 m 이하 등) 진동 · 소음 지표를
///       비우고 사유(`travelWindowFailure`)를 남긴다. 정속 구간을 정하지
///       못하면 수직 최대 · 가감속 최대만 비우고 사유(`motionZonesFailure`)를
///       남긴다
///
///       소음 두 값의 계약
///         소음은 격자 행마다 `GridSample.noiseDba` 에 실려 온다. 격자와
///         같은 주기로 갱신되므로 표본과 표본 사이에서 봉우리를 잃지
///         않는다. 다만 수집 계층이 Fast(0.125초) 평활한 값을 내보내므로
///         그보다 짧은 소리는 평탄해지는데, 이는 시간가중 특성이지 격자가
///         잃은 것이 아니다.
///         - `noiseSeries` 는 격자에 정렬된 값 그대로이고 차트가 쓴다
///         - `noiseMax` 는 그 시계열의 운행 구간 안 최대다
///         - 소음 평균은 모든 표본이 있어야 나오므로 시계열에서 낸다.
///           `ReportMetrics` 가 같은 운행 구간(`travelWindow`)으로 그
///           몫을 맡는다
///
///       소음 0 은 값이 아니라 미측정 표시다. 수집 계층은 마이크 권한이
///       없거나 첫 창이 아직 차지 않았을 때 0 을 내보낸다. 실내 소음이
///       0 dBA 로 잴 일은 없으므로 0 을 그대로 최대에 넣으면, 권한을
///       거부한 측정이 "소음 정상"으로 찍힌다. 최대도 평균도 0 인 표본을
///       빼고 센다.
///
///       비운 자리를 0 으로 채우지 않는다. `GridResampleResult` 가
///       격자에서 같은 이유로 값 채우기를 막아둔 것과 같은 규칙이다 —
///       재지 않은 값을 0 으로 넣으면 실제로 0 이 나온 측정과 구분할 수
///       없게 된다.
class MeasurementAssembler {
  /// 작성: 2026-09-15 13:08:37 · 박건준
  /// 수정: 2026-10-27 11:00:00 · 박건준
  /// 함수: assemble
  /// 목적: 격자 환산 결과 한 건을 측정 결과 모델 한 건으로 바꾼다.
  ///       - 환산이 실패했으면 바꾸지 않고 그 사유를 그대로 올린다.
  ///         실패를 빈 결과로 바꿔 삼키지 않는다
  ///       - 격자 행이 `Kinematics.minimumRows` 개보다 적거나 격자 간격이 0 이하면
  ///         변환하지 않고 사유를 올린다
  ///       - 층수는 현장 정보에 층 표기(지하 "B1")로 들어오므로 층 번호로
  ///         바꾼다(`SiteInfo.parseFloor()`, 지하는 음수). 바꿀 수 없으면
  ///         사유를 올린다. 부르는 쪽이 이미 확인하고
  ///         있지만, 이 함수만 보고도 잘못된 값이 들어오지 않는다고
  ///         말할 수 있어야 해서 여기서 다시 본다
  ///       - 진동 시계열 세 개와 샘플레이트, 현장 정보를 채운다
  ///       - 가중 전 수직 진동에서 파생 물리량 네 개와 최대 속도 · 운행
  ///         거리를 만든다. `Kinematics.derive()` 참고. 적분한 움직인
  ///         구간은 결과와 함께 돌려줘 저장 절차가 집계 파일에 적게 한다
  ///       - 진동 세 축에 가중을 걸어(`RideWeighting`) 그 값을 시계열로
  ///         싣는다. 수직은 가중 뒤 기종 응답 보정(`DeviceResponse.apply()`)을
  ///         건다(보정 표에 있는 기종만). 가중을 걸 수 없는 격자
  ///         (`RideWeighting.canApply()`,
  ///         아주 짧거나 성김)는 가중 없이 싣고 지표는 비운 채 사유를
  ///         남긴다
  ///       - 운행 구간(`TravelWindow.of()`)을 정해 그 안에서 진동 최대
  ///         P2P · A95(`HalfCycle`)와 소음 최대를 낸다. 못 정하면 그 일곱
  ///         지표를 null 로 두고 사유를 싣는다
  ///       - 수직 최대 P2P 는 정속 구간(`MotionZones.of()`) 안에서, 가감속
  ///         최대(`zJptp`)는 그 밖 운행에서 내고, 수직 최대가 나온 위치를
  ///         함께 싣는다. 정속을 못 정하면 그 셋을 null 로 두고 사유를 싣는다
  ///       - `site.model`(기종)도 함께 옮긴다. 비어 있으면 null 로 둔다.
  ///         이걸 실어 두면 리포트가 측정 결과 하나만 받으면 되고
  ///         현장 정보를 따로 들고 다니지 않아도 된다
  ///       - 하중 · 하중 단위 · 해석 종류 · 참고사항도 옮긴다. 주소 ·
  ///         우편번호는 받지 않아(2026-10-27) 결과에 싣지 않는다.
  ///         앞뒤 공백을 지우고, 비어 있으면 null 로 둔다(재지 않은 값을
  ///         빈 문자열로 채우지 않는다). 하중은 홈 화면 검사와 같은
  ///         기준(`SiteInfo.parseLoad()`)으로 숫자로 바꾼다. 비어 있지
  ///         않은데 바꿀 수 없으면 층수처럼 사유를 올린다. 단위는 늘
  ///         `SiteInfo.loadUnit`(kg)이고, 하중이 없으면 단위도 뜻이 없어
  ///         null 로 둔다
  ///       - 로그인한 작업자(성명 · 사번 · 업체명 · 관리팀)는 현장 정보가
  ///         아니라 로그인 상태라 따로 받는다. 성명이 엔지니어 이름이다
  ///       - 소음 시계열을 격자에서 그대로 옮기고, 운행 구간 안 0 이 아닌
  ///         표본의 최대를 `noiseMax` 에 담는다. 쓸 표본이 하나도 없으면 null 로
  ///         둔다. 자세한 까닭은 클래스 주석의 소음 계약을 본다
  /// 인자: grid — 격자 환산 결과
  ///       site — 홈 화면에서 입력받은 현장 정보
  ///       id — 이 측정의 식별자. 저장 파일명과 같은 시각 문자열을 쓴다
  ///       measuredAt — 측정 시각. `grid.t0Ns` 는 단조시계(기기가 켜진
  ///       뒤 흐른 시간만 세는 시계) 값이라 벽시계 시각으로 쓸 수 없어
  ///       따로 받는다
  ///       worker — 저장 시점에 로그인해 있던 작업자. 없으면 null
  ///       deviceManufacturer, deviceModel — 측정한 휴대폰 제조사 · 기종
  ///       이름(`Build.MANUFACTURER` · `Build.MODEL`). 모르거나 외부
  ///       기록(오티스폰 EVIMP1)이면 null — 기종 응답 보정을 걸지 않는다
  /// 반환: 변환된 측정 결과, 또는 변환하지 못한 사유
  /// 식: sampleRate = 1,000,000,000 / gridIntervalNs
  static MeasurementAssembleResult assemble({
    required GridResampleResult grid,
    required SiteInfo site,
    required String id,
    required DateTime measuredAt,
    Worker? worker,
    String? deviceManufacturer,
    String? deviceModel,
  }) {
    if (grid.failureReason != null) {
      return MeasurementAssembleResult.failure(grid.failureReason!);
    }
    if (grid.samples.length < Kinematics.minimumRows) {
      return MeasurementAssembleResult.failure(
        '격자 행이 ${Kinematics.minimumRows}개보다 적어 변환할 수 없다: ${grid.samples.length}행',
      );
    }
    if (grid.gridIntervalNs <= 0) {
      return MeasurementAssembleResult.failure(
        '격자 간격이 0 이하라 샘플레이트를 구할 수 없다: ${grid.gridIntervalNs}ns',
      );
    }
    final gridRate = 1000000000 / grid.gridIntervalNs; // 격자 표본 속도 (Hz)
    // 차트용 가속도 저역(10Hz) · 기종 응답 보정 저역은 표본 속도의 절반보다
    // 낮아야 설계된다. 실제 격자(100Hz)는 늘 맞고, 어긋난 시험 격자를
    // 예외로 죽이지 않고 사유와 함께 돌려보낸다
    // → 로직 이동: DeviceResponse.filterFor()
    final compensation = DeviceResponse.filterFor(deviceModel); // 없으면 null
    final highestCutoff = math.max(
      CaptureConfig.accelChartLowpassHz,
      compensation?.lowpassHz ?? 0,
    ); // 이 함수가 설계하는 저역 가운데 가장 높은 차단 (Hz)
    if (gridRate <= 2 * highestCutoff) {
      return MeasurementAssembleResult.failure(
        '표본 속도가 저역 차단 ${highestCutoff}Hz 의 두 배 이하다: '
        '${gridRate.toStringAsFixed(1)}Hz',
      );
    }

    // → 로직 이동: SiteInfo.parseFloor()
    final bottomFloor = SiteInfo.parseFloor(site.bottomFloor); // 층 번호
    // → 로직 이동: SiteInfo.parseFloor()
    final topFloor = SiteInfo.parseFloor(site.topFloor); // 층 표기가 아니면 null
    if (bottomFloor == null || topFloor == null) {
      return MeasurementAssembleResult.failure(
        '층수를 층 번호로 바꿀 수 없다: '
        '최하층 "${site.bottomFloor}", 최상층 "${site.topFloor}"',
      );
    }

    final hasLoad = site.load.trim().isNotEmpty; // 하중을 입력했는지
    // → 로직 이동: SiteInfo.parseLoad()
    final load = SiteInfo.parseLoad(site.load); // 하중 숫자, 못 바꾸면 null
    if (hasLoad && load == null) {
      return MeasurementAssembleResult.failure(
        '하중을 0 보다 큰 숫자로 바꿀 수 없다: "${site.load}"',
      );
    }
    final notes = site.notes.trim(); // 참고사항. 비었으면 null 로 둔다

    final xSeries = <double>[]; // X축 진동 시계열 (mg)
    final ySeries = <double>[]; // Y축 진동 시계열 (mg)
    final zSeries = <double>[]; // Z축 진동 시계열 (mg)
    final noiseSeries = <double>[]; // 소음 시계열 (dBA). 0 은 미측정
    for (final sample in grid.samples) {
      xSeries.add(sample.xMg);
      ySeries.add(sample.yMg);
      zSeries.add(sample.zMg);
      noiseSeries.add(sample.noiseDba);
    }

    final sampleRate = 1000000000 / grid.gridIntervalNs; // 실측 샘플레이트 (Hz)
    final model = site.model.trim(); // 기종. 비어 있으면 아래에서 null 로 둔다
    // → 로직 이동: Kinematics.derive()
    final motion = Kinematics.derive(zSeries, sampleRate); // 파생 물리량 묶음

    // → 로직 이동: RideWeighting.canApply()
    final canWeight = // 가중을 걸 만큼 격자가 길고 촘촘한지
    RideWeighting.canApply(
      xSeries.length,
      sampleRate,
    );
    final xWeighted = canWeight
        // → 로직 이동: RideWeighting.horizontal()
        ? RideWeighting.horizontal(xSeries, sampleRate)
        : xSeries; // 지표 · 차트에 쓸 X (mg)
    final yWeighted = canWeight
        // → 로직 이동: RideWeighting.horizontal()
        ? RideWeighting.horizontal(ySeries, sampleRate)
        : ySeries; // 지표 · 차트에 쓸 Y (mg)
    // → 로직 이동: RideWeighting.vertical()
    final zRide = canWeight
        ? RideWeighting.vertical(zSeries, sampleRate)
        : zSeries; // 가중한 Z (mg). 가중을 걸 수 없으면 그대로
    final zWeighted = canWeight && compensation != null
        // → 로직 이동: DeviceResponse.apply()
        ? DeviceResponse.apply(compensation, zRide, sampleRate)
        : zRide; // 지표 · 차트에 쓸 Z (mg). 표에 있는 기종이면 보정 뒤

    // 가중하지 못한 시계열로 지표를 내지 않는다 — 기준이 원본 리포트의
    // 가중 지표 기준이라 견줄 수 없다
    final travel = canWeight
        // → 로직 이동: TravelWindow.of()
        ? TravelWindow.of(motion.travelled, sampleRate)
        : TravelWindowResult.failure(
            '가중을 걸 수 없는 격자다: ${xSeries.length}행, '
            '${sampleRate.toStringAsFixed(1)}Hz',
          ); // 운행 구간
    final window = travel.window; // 정한 구간, 못 정했으면 null
    final start = window?.startIndex ?? 0; // 구간 첫 첨자
    final end = window?.endIndex ?? 0; // 구간 끝 첨자 (포함)
    // → 로직 이동: HalfCycle.maximum()
    double? maxOf(List<double> series) => window == null
        ? null
        : HalfCycle.maximum(series, start: start, end: end)?.value;
    // → 로직 이동: HalfCycle.a95()
    double? a95Of(List<double> series) =>
        window == null ? null : HalfCycle.a95(series, start: start, end: end);
    // 수직 최대는 정속 구간, 가감속 최대는 그 밖 운행에서 낸다(OTIS 리포트
    // `a_z,ptp` · `a_z,Jptp`). 운행 구간을 못 정한 결과는 다른 지표처럼
    // 비운다
    final zoning = canWeight
        // → 로직 이동: MotionZones.of()
        ? MotionZones.of(motion.speed, motion.accelSmooth, sampleRate)
        : MotionZonesResult.failure(
            travel.failureReason ?? '가중을 걸 수 없는 격자다',
          ); // 정속 · 가감속 구간
    final zones = zoning.zones; // 정한 구간, 못 정했으면 null
    final steadyPeak = window == null
        ? null
        // → 로직 이동: MotionZones.steadyMaximum()
        : zones?.steadyMaximum(zWeighted); // 정속 구간 수직 최대
    final transientPeak = window == null
        ? null
        // → 로직 이동: MotionZones.transientMaximum()
        : zones?.transientMaximum(zWeighted); // 가감속 구간 수직 최대
    final resolvedNoiseMax = window == null
        ? null
        // → 로직 이동: _peakIgnoringZeros()
        : _peakIgnoringZeros(
            noiseSeries.sublist(start, end + 1),
          ); // 구간 소음 최대 (dBA). 쓸 표본이 없으면 null

    return MeasurementAssembleResult.success(
      MeasurementResult(
        id: id,
        jobNo: site.jobNo,
        siteName: site.siteName,
        bottomFloor: bottomFloor,
        topFloor: topFloor,
        direction: site.direction,
        model: model.isEmpty ? null : model,
        load: load,
        loadUnit: load == null ? null : SiteInfo.loadUnit,
        analysisType: site.analysisType,
        notes: notes.isEmpty ? null : notes,
        engineerName: worker?.name,
        employeeId: worker?.employeeId,
        company: worker?.company,
        team: worker?.team,
        dateTime: measuredAt,
        xSeries: xWeighted,
        ySeries: yWeighted,
        zSeries: zWeighted,
        noiseSeries: noiseSeries,
        noiseMax: resolvedNoiseMax,
        positionSeries: motion.position,
        speedSeries: motion.speed,
        accelSeries: motion.accelChart,
        jerkSeries: motion.jerk,
        xPtp: maxOf(xWeighted),
        yPtp: maxOf(yWeighted),
        zPtp: steadyPeak?.value,
        zJptp: transientPeak?.value,
        zPtpPositionM: steadyPeak == null
            ? null
            // → 로직 이동: _positionAtPeak()
            : _positionAtPeak(steadyPeak, zWeighted, motion.position),
        motionZones: zones,
        motionZonesFailure: zoning.failureReason,
        // → 로직 이동: _steadySpeed()
        steadySpeedMps: zones == null
            ? null
            : _steadySpeed(zones, motion.speed),
        deviceManufacturer: deviceManufacturer,
        deviceModel: deviceModel,
        // → 로직 이동: DeviceResponse.compensationLabel()
        deviceCompensation: DeviceResponse.compensationLabel(deviceModel),
        // → 로직 이동: _stopMargin()
        stopMarginSec: _stopMargin(motion.speed, sampleRate),
        // → 로직 이동: MotionZones.transientPadClippedAtEnd()
        zJptpClippedAtEnd: zones?.transientPadClippedAtEnd(zWeighted.length),
        xA95: a95Of(xWeighted),
        yA95: a95Of(yWeighted),
        zA95: a95Of(zWeighted),
        maxSpeed: motion.maxSpeed,
        distance: motion.distance,
        sampleRate: sampleRate,
        travelWindow: window,
        travelWindowFailure: travel.failureReason,
      ),
      motion: motion.motion,
    );
  }

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: _stopMargin
  /// 목적: 운행 끝부터 기록 끝까지의 시간을 낸다. 운행 끝은 속도 크기가
  ///       `CaptureConfig.zoneRunSpeedMps` 를 넘은 마지막 행이다(정속 ·
  ///       가감속 구간의 운행과 같은 정의). 짧으면 결과 화면이 "정지 후
  ///       1초 이상 기다린 뒤 종료" 를 알린다(`CaptureConfig.minimumStopMarginMs`).
  /// 인자: speed — 속도 시계열 (m/s, 부호 그대로)
  ///       sampleRate — 표본 속도 (Hz)
  /// 반환: 여유 (초). 움직임이 없으면 null
  /// 식: (n − 1 − 운행 끝 첨자) / sampleRate
  static double? _stopMargin(List<double> speed, double sampleRate) {
    for (var i = speed.length - 1; i >= 0; i--) {
      if (speed[i].abs() > CaptureConfig.zoneRunSpeedMps) {
        return (speed.length - 1 - i) / sampleRate;
      }
    }
    return null;
  }

  /// 작성: 2026-10-22 15:00:00 · 박건준
  /// 수정: 2026-10-28 10:30:00 · 박건준
  /// 함수: _steadySpeed
  /// 목적: 정속 구간 평균 속도 크기를 낸다. 표시하지 않고 결과 파일에만 남겨
  ///       다른 현장에서 OTIS 최대 속도 표시 규칙을 견줄 때 쓴다.
  /// 인자: zones — 정속 · 가감속 구간
  ///       speed — 속도 시계열 (m/s, 부호 그대로)
  /// 반환: 평균 속도 크기 (m/s)
  /// 식: mean(|speed(i)|),  i = 정속 시작 .. 정속 끝
  /// 근거: 측정 — 2026-10-21 비교 7건에서 이 값을 0.05 단위로 반올림하면
  ///       OTIS 표시값(1.50 · 1.75)과 모두 같았다. 다만 OTIS 값이 두 가지뿐이고
  ///       경계 여유가 0.003 이라 근거가 약하다
  static double _steadySpeed(MotionZones zones, List<double> speed) {
    var sum = 0.0; // 정속 구간 속도 크기 합
    for (var i = zones.steadyStartIndex; i <= zones.steadyEndIndex; i++) {
      sum += speed[i].abs();
    }
    return sum / (zones.steadyEndIndex - zones.steadyStartIndex + 1);
  }

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: _positionAtPeak
  /// 목적: 반주기 P2P 가 나온 순간의 위치를 고른다. 두 봉우리 가운데 크기가
  ///       큰 쪽 자리의 위치다 — 차트 빨간 점 옆 글자가 붙는 자리와 같다.
  /// 인자: peak — 반주기 P2P
  ///       series — 그 P2P 를 낸 진동 시계열 (mg)
  ///       position — 위치 시계열 (m)
  /// 반환: 위치 (m)
  static double _positionAtPeak(
    HalfCyclePeakToPeak peak,
    List<double> series,
    List<double> position,
  ) {
    final at = series[peak.firstIndex].abs() >= series[peak.secondIndex].abs()
        ? peak.firstIndex
        : peak.secondIndex; // 큰 봉우리 자리
    return position[at];
  }

  /// 작성: 2026-09-15 21:38:58 · 박건준
  /// 함수: _peakIgnoringZeros
  /// 목적: 소음 표본 중 가장 큰 값을 찾되 0 인 표본은 빼고 센다. 0 은
  ///       값이 아니라 미측정 표시라서다 — 클래스 주석의 소음 계약을
  ///       본다. 평균 쪽에서 같은 규칙을 쓰는 곳은 `ReportMetrics` 의
  ///       `_withoutWarmupZeros()` 다.
  /// 인자: series — 살펴볼 소음 표본 목록 (dBA)
  /// 반환: 0 이 아닌 표본 중 최댓값. 쓸 표본이 하나도 없으면 null — 잴
  ///       것이 없는데 0 을 돌려주면 실제로 0 이 나온 측정과 구분할 수
  ///       없고, 기준치와 견줘 "정상" 으로 찍힌다
  static double? _peakIgnoringZeros(List<double> series) {
    double? peak; // 여기까지 본 것 중 가장 큰 값. 아직 없으면 null
    for (final value in series) {
      if (value == 0) continue;
      if (peak == null || value > peak) peak = value;
    }
    return peak;
  }
}
