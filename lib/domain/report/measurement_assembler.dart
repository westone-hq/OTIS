import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/ride_weighting.dart';
import 'package:vibration_checker/domain/report/half_cycle.dart';
import 'package:vibration_checker/domain/report/travel_window.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/model/worker.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

/// 작성: 2026-09-15 13:08:37 · nada
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

  /// 작성: 2026-09-15 13:08:37 · nada
  /// 함수: MeasurementAssembleResult.success
  /// 목적: 변환에 성공한 결과를 담는 생성자.
  /// 인자: result — 변환된 측정 결과
  const MeasurementAssembleResult.success(MeasurementResult this.result)
    : failureReason = null;

  /// 작성: 2026-09-15 13:08:37 · nada
  /// 함수: MeasurementAssembleResult.failure
  /// 목적: 변환하지 못한 사유만 담는 생성자.
  /// 인자: failureReason — 변환하지 못한 사유
  const MeasurementAssembleResult.failure(String this.failureReason)
    : result = null;

  /// 작성: 2026-09-15 13:08:37 · nada
  /// 함수: isSuccess
  /// 목적: 변환에 성공했는지 알려준다.
  /// 반환: `result`가 채워져 있고 사유가 없으면 true
  bool get isSuccess => failureReason == null && result != null;
}

/// 작성: 2026-09-15 13:08:37 · nada
/// 수정: 2026-10-15 16:50:04 · nada
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
///          가중 전 수직 진동 전체에서 낸다
///       2. 진동에 주파수 가중(`RideWeighting`)을 건다 — 수평 Wd, 수직
///          1Hz 고역 + Wk. 가감속이 빠져 Z 가 늘 적색을 넘던 문제가 없다
///       3. 위치에서 운행 구간(`TravelWindow`, 출발 · 정지 0.5 m 제외)을
///          정한다
///       4. 구간 안 가중 시계열의 반주기 P2P(`HalfCycle`)에서 최대 P2P 와
///          A95 를, 구간 안 소음에서 최대를 낸다
///       운행 구간을 정하지 못하면(운행 1 m 이하 등) 진동 · 소음 지표를
///       비우고 사유(`travelWindowFailure`)를 남긴다
///
///       소음 두 값의 계약
///         소음은 격자 행마다 `GridSample.noiseDba` 에 실려 온다. 격자와
///         같은 주기로 갱신되므로 표본과 표본 사이에서 봉우리를 잃지
///         않는다. 다만 수집 계층이 1초 창으로 고른 값을 내보내므로 그
///         창보다 짧은 소리는 평탄해지는데, 이는 Slow 특성을 쓰기로 한
///         결과이지 격자가 잃은 것이 아니다.
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
  /// 작성: 2026-09-15 13:08:37 · nada
  /// 수정: 2026-10-18 09:41:12 · nada
  /// 함수: assemble
  /// 목적: 격자 환산 결과 한 건을 측정 결과 모델 한 건으로 바꾼다.
  ///       - 환산이 실패했으면 바꾸지 않고 그 사유를 그대로 올린다.
  ///         실패를 빈 결과로 바꿔 삼키지 않는다
  ///       - 격자 행이 `_minimumRows` 개보다 적거나 격자 간격이 0 이하면
  ///         변환하지 않고 사유를 올린다
  ///       - 층수는 현장 정보에 문자열로 들어오므로 숫자로 바꾼다.
  ///         바꿀 수 없으면 사유를 올린다. 부르는 쪽이 이미 확인하고
  ///         있지만, 이 함수만 보고도 잘못된 값이 들어오지 않는다고
  ///         말할 수 있어야 해서 여기서 다시 본다
  ///       - 진동 시계열 세 개와 샘플레이트, 현장 정보를 채운다
  ///       - 가중 전 수직 진동에서 파생 물리량 네 개와 최대 속도 · 운행
  ///         거리를 만든다. `_deriveKinematics()` 참고
  ///       - 진동 세 축에 가중을 걸어(`RideWeighting`) 그 값을 시계열로
  ///         싣는다. 가중을 걸 수 없는 격자(`RideWeighting.canApply()`,
  ///         아주 짧거나 성김)는 가중 없이 싣고 지표는 비운 채 사유를
  ///         남긴다
  ///       - 운행 구간(`TravelWindow.of()`)을 정해 그 안에서 진동 최대
  ///         P2P · A95(`HalfCycle`)와 소음 최대를 낸다. 못 정하면 그 일곱
  ///         지표를 null 로 두고 사유를 싣는다
  ///       - `site.model`(기종)도 함께 옮긴다. 비어 있으면 null 로 둔다.
  ///         이걸 실어 두면 리포트가 측정 결과 하나만 받으면 되고
  ///         현장 정보를 따로 들고 다니지 않아도 된다
  ///       - 하중 · 하중 단위 · 해석 종류 · 우편번호 · 참고사항도 옮긴다.
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
  /// 반환: 변환된 측정 결과, 또는 변환하지 못한 사유
  /// 식: sampleRate = 1,000,000,000 / gridIntervalNs
  static MeasurementAssembleResult assemble({
    required GridResampleResult grid,
    required SiteInfo site,
    required String id,
    required DateTime measuredAt,
    Worker? worker,
  }) {
    if (grid.failureReason != null) {
      return MeasurementAssembleResult.failure(grid.failureReason!);
    }
    if (grid.samples.length < _minimumRows) {
      return MeasurementAssembleResult.failure(
        '격자 행이 $_minimumRows개보다 적어 변환할 수 없다: ${grid.samples.length}행',
      );
    }
    if (grid.gridIntervalNs <= 0) {
      return MeasurementAssembleResult.failure(
        '격자 간격이 0 이하라 샘플레이트를 구할 수 없다: ${grid.gridIntervalNs}ns',
      );
    }

    final bottomFloor = int.tryParse(site.bottomFloor.trim()); // 숫자가 아니면 null
    final topFloor = int.tryParse(site.topFloor.trim()); // 숫자가 아니면 null
    if (bottomFloor == null || topFloor == null) {
      return MeasurementAssembleResult.failure(
        '층수를 숫자로 바꿀 수 없다: '
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
    final postalCode = site.postalCode.trim(); // 우편번호. 비었으면 null 로 둔다
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
    // → 로직 이동: _deriveKinematics()
    final motion = _deriveKinematics(zSeries, sampleRate); // 파생 물리량 묶음

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
    final zWeighted = canWeight
        // → 로직 이동: RideWeighting.vertical()
        ? RideWeighting.vertical(zSeries, sampleRate)
        : zSeries; // 지표 · 차트에 쓸 Z (mg)

    // 가중하지 못한 시계열로 지표를 내지 않는다 — 기준이 원본 리포트의
    // 가중 지표 기준이라 견줄 수 없다
    final travel = canWeight
        // → 로직 이동: TravelWindow.of()
        ? TravelWindow.of(motion.position, sampleRate)
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
        address: site.address.trim(),
        bottomFloor: bottomFloor,
        topFloor: topFloor,
        direction: site.direction,
        model: model.isEmpty ? null : model,
        load: load,
        loadUnit: load == null ? null : SiteInfo.loadUnit,
        analysisType: site.analysisType,
        postalCode: postalCode.isEmpty ? null : postalCode,
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
        accelSeries: motion.accel,
        jerkSeries: motion.jerk,
        xPtp: maxOf(xWeighted),
        yPtp: maxOf(yWeighted),
        zPtp: maxOf(zWeighted),
        xA95: a95Of(xWeighted),
        yA95: a95Of(yWeighted),
        zA95: a95Of(zWeighted),
        maxSpeed: motion.maxSpeed,
        distance: motion.distance,
        sampleRate: sampleRate,
        travelWindow: window,
        travelWindowFailure: travel.failureReason,
      ),
    );
  }

  /// 작성: 2026-09-15 21:38:58 · nada
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

  /// 작성: 2026-09-15 19:14:22 · nada
  /// 변수: _minimumRows
  /// 목적: 변환에 필요한 최소 격자 행 수. 이보다 적으면 변환하지 않고
  ///       사유를 올린다.
  ///       3 인 이유는 저크를 가운데 차분(앞뒤 값의 차이를 그 사이
  ///       간격으로 나누는 계산)으로 구하기 때문이다. 가운데 점 하나를
  ///       구하려면 앞뒤가 있어야 해서 최소 세 점이 필요하다.
  ///       행이 그보다 적으면 파생 물리량이 전부 0 으로 나오는데, 그러면
  ///       재서 0 이 나온 측정과 잴 것이 없어서 0 인 측정을 구분할 수
  ///       없게 된다.
  static const int _minimumRows = 3;

  /// 작성: 2026-09-15 14:32:07 · nada
  /// 변수: _mgToMetersPerSecondSquared
  /// 목적: mg(밀리지) → m/s² 환산 계수
  /// 근거: 표준 — 국제단위계(SI) 표준 중력 9.80665 m/s², 그 1/1000
  static const double _mgToMetersPerSecondSquared = 9.80665e-3;

  /// 작성: 2026-09-15 14:32:07 · nada
  /// 수정: 2026-10-11 15:34:38 · nada
  /// 함수: _deriveKinematics
  /// 목적: 수직 진동 시계열에서 가속도 · 속도 · 누적 이동량 · 저크와
  ///       최대 속도 · 운행 거리를 만든다. 순서대로 한다.
  ///       1. 진동값(mg)을 가속도(m/s²)로 바꾸고 전체 평균을 뺀다
  ///       2. 가속도를 더해 나가 속도를 만들고, 전체 구간의 선형 추세를
  ///          빼 시작과 끝이 0 이 되게 맞춘다
  ///       3. 속도의 절댓값을 더해 나가 누적 이동량을 만든다
  ///       4. 가속도의 변화율로 저크를 만든다
  ///
  ///       2단계의 두 보정을 왜 하는가
  ///         - 센서에 남은 아주 작은 치우침도 적분하면 시간에 비례해
  ///           쌓인다. 44초 측정이면 위치가 수십 미터씩 어긋난다
  ///         - 승강기는 서 있다 출발해 서면서 끝나므로 양 끝 속도는
  ///           0 이어야 한다. 평균을 빼 일정한 치우침을 없애고, 남은
  ///           선형 성분은 두 끝을 잇는 직선을 빼서 없앤다
  ///
  ///       누적 이동량은 속도의 절댓값을 더한다. 방향을 그대로 더하면
  ///       위로 갔다 내려온 측정에서 0 에 가까운 값이 나와, 실제로 얼마나
  ///       움직였는지를 알 수 없게 된다.
  /// 인자: zSeries — 수직 진동 시계열 (mg). `_minimumRows` 개 이상이어야
  ///       한다. 부르기 전에 `assemble()`이 확인한다
  ///       sampleRate — 실측 샘플레이트 (Hz). 0 보다 커야 한다
  /// 반환: 파생 물리량과 최대 속도 · 운행 거리를 담은 묶음
  /// 식: accel(i) = zSeries(i) x 9.80665e-3 - 평균
  ///     speed(i) = (누적합 accel(0..i)) x dt - 두 끝을 잇는 직선
  ///     position(i) = (누적합 |speed(0..i)|) x dt
  ///     jerk(i) = (accel(i+1) - accel(i-1)) / (2 x dt)
  /// 미구현: 저크를 가속도에서 바로 미분한다. 받는 `zSeries` 는 지표 계산
  ///       전 신호 처리(`SignalConditioner`)에서 40Hz 저역(낮은 주파수만
  ///       통과시키고 빠른 흔들림을 걸러내는 처리)을 거친 값이라, 미분하면
  ///       수 Hz 이상 흔들림이 그대로 남은 곡선이 나온다. 원본 리포트의
  ///       저크 곡선은 훨씬 매끈하다. 저크만 더 낮게 거르는 처리가 정해질
  ///       때 바꾼다. 그때까지 저크 차트는 형태만 참고한다.
  ///       미확인: 원본 리포트가 저크를 어떤 차단 주파수로 걸렀는지
  static _Kinematics _deriveKinematics(
    List<double> zSeries,
    double sampleRate,
  ) {
    final n = zSeries.length; // 격자 행 수
    // 부르는 쪽의 `_minimumRows` 가드가 이 조건을 보장한다. 방어 분기로
    // 받아내지 않고 `assert` 로 두는 이유는, 분기로 두면 가드를 거치지
    // 않고 부르는 코드가 생겼을 때 speed[0] = 0.0 같은 대체값이 잘못을
    // 덮어 터져야 할 자리에서 안 터지기 때문이다. 게다가 도달할 수 없는
    // 분기는 시험할 수 없어 그대로 썩는다. `assert` 는 계약을 코드에
    // 남기고 디버그 실행에서 곧바로 실패하며 릴리스 빌드에서는 지워져
    // 비용이 없다
    assert(n >= _minimumRows, '격자 행이 $_minimumRows개보다 적다: $n행');
    final dt = 1.0 / sampleRate; // 행 사이 시간 간격 (초)

    final accel = List<double>.generate(
      n,
      (i) => zSeries[i] * _mgToMetersPerSecondSquared,
    ); // 가속도 시계열 (m/s²)

    var accelSum = 0.0; // 평균을 구하려고 모으는 가속도 합
    for (final value in accel) {
      accelSum += value;
    }
    final accelMean = accelSum / n; // 가속도 전체 평균 (m/s²)
    for (var i = 0; i < n; i++) {
      accel[i] -= accelMean;
    }

    final speed = List<double>.filled(n, 0.0); // 속도 시계열 (m/s)
    var running = 0.0; // 여기까지 더한 가속도 누적합
    for (var i = 0; i < n; i++) {
      running += accel[i];
      speed[i] = running * dt;
    }
    final first = speed[0]; // 보정 전 첫 속도
    final last = speed[n - 1]; // 보정 전 마지막 속도
    for (var i = 0; i < n; i++) {
      speed[i] -= first + (last - first) * i / (n - 1);
    }

    final position = List<double>.filled(n, 0.0); // 누적 이동량 시계열 (m)
    var travelled = 0.0; // 여기까지 더한 속도 절댓값 누적합
    for (var i = 0; i < n; i++) {
      travelled += speed[i].abs();
      position[i] = travelled * dt;
    }

    final jerk = List<double>.filled(n, 0.0); // 저크 시계열 (m/s³)
    jerk[0] = (accel[1] - accel[0]) / dt;
    jerk[n - 1] = (accel[n - 1] - accel[n - 2]) / dt;
    for (var i = 1; i < n - 1; i++) {
      jerk[i] = (accel[i + 1] - accel[i - 1]) / (2 * dt);
    }

    var maxSpeed = 0.0; // 속도 절댓값의 최대 (m/s)
    for (final value in speed) {
      final magnitude = value.abs(); // 방향을 뺀 속도 크기
      if (magnitude > maxSpeed) maxSpeed = magnitude;
    }

    var minPosition = position[0]; // 누적 이동량의 최솟값 (m)
    var maxPosition = position[0]; // 누적 이동량의 최댓값 (m)
    for (final value in position) {
      if (value < minPosition) minPosition = value;
      if (value > maxPosition) maxPosition = value;
    }

    return _Kinematics(
      accel: accel,
      speed: speed,
      position: position,
      jerk: jerk,
      maxSpeed: maxSpeed,
      distance: maxPosition - minPosition,
    );
  }
}

/// 작성: 2026-09-15 14:32:07 · nada
/// 클래스: _Kinematics
/// 목적: 수직 진동에서 뽑아낸 파생 물리량과 거기서 나온 두 지표를 한
///       묶음으로 담는다. `_deriveKinematics()` 가 만들어 돌려준다.
class _Kinematics {
  /// 가속도 시계열 (m/s²). 전체 평균을 뺀 값
  final List<double> accel;

  /// 속도 시계열 (m/s). 적분한 뒤 선형 추세를 빼 양 끝이 0 인 값
  final List<double> speed;

  /// 누적 이동량 시계열 (m). 방향과 무관하게 움직인 거리
  final List<double> position;

  /// 저크 시계열 (m/s³)
  final List<double> jerk;

  /// 최대 속도 (m/s). 속도 절댓값의 최대
  final double maxSpeed;

  /// 운행 거리 (m). 누적 이동량의 최대 - 최소
  final double distance;

  /// 작성: 2026-09-15 14:32:07 · nada
  /// 함수: _Kinematics
  /// 목적: 파생 물리량과 두 지표를 그대로 담는 생성자.
  /// 인자: accel — 가속도 시계열 (m/s²)
  ///       speed — 속도 시계열 (m/s)
  ///       position — 누적 이동량 시계열 (m)
  ///       jerk — 저크 시계열 (m/s³)
  ///       maxSpeed — 최대 속도 (m/s)
  ///       distance — 운행 거리 (m)
  const _Kinematics({
    required this.accel,
    required this.speed,
    required this.position,
    required this.jerk,
    required this.maxSpeed,
    required this.distance,
  });
}
