import 'dart:math' as math;

import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 수정: 2026-10-10 11:48:41 · 박건준
/// 클래스: ChartAxisSpec
/// 목적: 차트 하나가 어떤 값을 어떤 세로축에 그리는지 담는다.
class ChartAxisSpec {
  /// 축을 부르는 이름. 그릴 시계열을 고를 때 쓴다
  final String key;

  /// 세로축 옆에 세로로 찍는 라벨. 원본 리포트 표기를 그대로 쓴다
  final String label;

  /// 세로축 범위를 데이터에 맞춰 정하는 규칙. 최소 범위와 넓히는 모양을
  /// 갖는다
  final ChartScale scale;

  /// 평균 기준선을 그을 때 값을 가져올 지표 행 이름. 기준선을 긋지 않는
  /// 축은 null
  final String? meanKey;

  /// 최댓값 표시점을 찍을 때 값을 가져올 지표 행 이름. 표시점을 찍지
  /// 않는 축은 null
  final String? peakKey;

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-10 11:48:41 · 박건준
  /// 함수: ChartAxisSpec
  /// 목적: 축 하나의 이름 · 라벨 · 범위 규칙을 그대로 담는 생성자.
  /// 인자: key — 축 이름
  ///       label — 세로축 라벨
  ///       scale — 세로축 범위 규칙
  ///       meanKey — 평균 기준선 값을 가져올 지표 행 이름. 기본 null
  ///       peakKey — 최댓값 표시점 값을 가져올 지표 행 이름. 기본 null
  const ChartAxisSpec({
    required this.key,
    required this.label,
    required this.scale,
    this.meanKey,
    this.peakKey,
  });

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-10 11:48:41 · 박건준
  /// 함수: rangeFor
  /// 목적: 그릴 값이 모두 들어가는 세로축 범위를 고른다. 규칙은
  ///       `ChartScale` 이 갖는다 — 결과 화면 그래프도 같은 규칙을 써야
  ///       PDF 와 화면이 같은 눈금을 보인다.
  /// 인자: values — 그릴 값 목록
  /// 반환: 고른 범위. 값이 없으면 최소 범위
  ChartAxisRange rangeFor(List<double> values) =>
      scale.rangeFor(values); // → 로직 이동: ChartScale.rangeFor()
}

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 수정: 2026-10-10 11:48:41 · 박건준
/// 클래스: ReportChartAxes
/// 목적: 차트 여덟 개의 축 사양을 모아 둔다. 축마다 최소 범위와 넓히는
///       모양을 정하고, 실제 범위는 데이터에 맞춰 `ChartScale` 이 낸다.
///       최소 범위는 원본 리포트 범위를 따른다 — 조용한 운행은 원본과
///       같은 눈금으로 보이고, 넘칠 때만 넓어져 잘리는 값이 없다.
///
///       단위는 축마다 다르다. 진동 세 축은 mg, 소음은 dBA, 위치는 m,
///       속도는 m/s, 가속도는 m/s2, 저크는 m/s3 이다.
class ReportChartAxes {
  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-23 01:10:00 · 박건준
  /// 변수: x
  /// 목적: X축(가로 진동) 차트의 세로축. 0 을 가운데 둔다. 차트는 지표 계산
  ///       전 신호 처리(기준선 0 맞춤 · 40Hz 저역 필터 · 100Hz 재표본)를
  ///       거친 시계열을 그린다.
  /// 근거: 인용 — 최소 범위는 원본 리포트 `sample_evimp.pdf`(2026-10-23
  ///       저장소에서 지움, 커밋 6bd171a 의 `docs/reference/`)의 X 진동
  ///       차트 범위 ±4 mg, 눈금 2 mg 이다.
  ///       측정 — 처리 후 오티스폰 · 개발폰 동시 측정 6쌍에서 ±4 mg 밖
  ///       표본 비율이 현재 앱 측정(최종1·2, 3·4)은 0.3~0.9%, 오티스폰은
  ///       0.1~1.0% 다. 초기 측정 1·2번만 9~11% 인데, 25~58 mg 충격이 섞인
  ///       측정이다. 이 표본들 때문에 축이 넓어진다
  static const ChartAxisSpec x = ChartAxisSpec(
    key: 'x',
    label: 'X-Vibration (milli-G)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -4.0, max: 4.0, tickStep: 2.0),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-10 11:48:41 · 박건준
  /// 변수: y
  /// 목적: Y축(가로 진동) 차트의 세로축. 0 을 가운데 둔다. 그리는 시계열은
  ///       `x` 와 같이 신호 처리를 거친 값이다.
  /// 근거: 인용 — 최소 범위는 원본 리포트의 Y 진동 차트 범위 ±10 mg, 눈금
  ///       5 mg 이다.
  ///       측정 — 픽스처(`test/fixtures/scipy/conditioning_expected_100hz.txt`,
  ///       2026-10-06 개발폰 처리 후)의 Y 는 -4.94 ~ 5.71 mg 이라 최소
  ///       범위 그대로 그려진다
  static const ChartAxisSpec y = ChartAxisSpec(
    key: 'y',
    label: 'Y-Vibration (milli-G)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -10.0, max: 10.0, tickStep: 5.0),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-23 01:10:00 · 박건준
  /// 변수: z
  /// 목적: 수직 진동 차트의 세로축. 0 을 가운데 둔다. 2026-10-15 부터는
  ///       가중(1Hz 고역 + Wk)으로 가감속이 빠진 시계열을 그려 대개 최소
  ///       범위 안이다. 그 전 예전 결과는 가감속이 섞여 범위를 넓힌다.
  /// 근거: 인용 — 최소 범위는 원본 리포트 `sample_evimp.pdf`(2026-10-23
  ///       저장소에서 지움, 커밋 6bd171a 의 `docs/reference/`)의 수직 진동
  ///       차트 범위 ±20 mg, 눈금 10 mg 이다
  static const ChartAxisSpec z = ChartAxisSpec(
    key: 'z',
    label: 'Vertical Vibration (milli-G)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -20.0, max: 20.0, tickStep: 10.0),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-10 11:48:41 · 박건준
  /// 변수: noise
  /// 목적: 소음 차트의 세로축. 데이터 최소 · 최대에 맞추고, 0 은
  ///       미측정이라 범위에 넣지 않는다.
  ///       평균 기준선과 최댓값 표시점도 이 축에만 붙는다. 값은 1쪽 표가
  ///       쓰는 것과 같은 지표에서 가져와, 차트와 표가 다른 숫자를 말하지
  ///       않게 한다.
  /// 근거: 인용 — 최소 범위는 원본 리포트의 소음 차트 눈금이 40 부터 54
  ///       까지 2 씩 놓인 것을 그대로 옮겼다. 이 범위만 눈금이 7칸이다.
  ///       측정 — `test/fixtures/app_measurement.xlsx` 의 `noiseDba` 열은
  ///       0 을 빼면 44.8 에서 63.0 dBA 사이라 최소 범위를 넘는다. 이
  ///       측정은 40 ~ 65 로 넓어진다
  static const ChartAxisSpec noise = ChartAxisSpec(
    key: 'noise',
    label: 'Noise Level (dBA)',
    meanKey: 'noise_avg',
    peakKey: 'noise_max',
    scale: ChartScale(
      minimum: ChartAxisRange(min: 40.0, max: 54.0, tickStep: 2.0),
      kind: ChartScaleKind.free,
      ignoreZeros: true,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-23 10:00:00 · 박건준
  /// 변수: position
  /// 목적: 위치(하부층 정지레벨 기준) 차트의 세로축. 데이터 양 끝에서 폭의
  ///       10% 씩 바깥을 틀 끝으로 두고(`ChartScaleKind.padded`), 가로축도
  ///       양쪽에 여백을 둔다. 0 이 틀 꼭짓점에 붙지 않는다(OTIS 3쪽과
  ///       같다). 최소 범위는 정지 측정(위치가 한 값)에만 쓴다.
  /// 근거: 인용 — 최소 범위는 파이썬 프로토타입 `AXES` 위치 축 첫 단계와
  ///       같다(2026-10-23 지움, 커밋 6bd171a 의
  ///       `pdf_report_dev/tune_report/charts.py`)
  static const ChartAxisSpec position = ChartAxisSpec(
    key: 'pos',
    label: 'pos (m)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: 0.0, max: 10.0, tickStep: 2.0),
      kind: ChartScaleKind.padded,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-23 10:00:00 · 박건준
  /// 변수: speed
  /// 목적: 속도 차트의 세로축. 위치와 같은 여백 규칙이다
  ///       (`ChartScaleKind.padded`). 하강이면 속도가 음수라 틀이 0 아래에
  ///       놓인다(`seriesOf()` 참고).
  /// 근거: 인용 — 최소 범위는 프로토타입 `AXES` 속도 축 첫 단계와 같다
  ///       (2026-10-23 지움, 커밋 6bd171a 의
  ///       `pdf_report_dev/tune_report/charts.py`)
  static const ChartAxisSpec speed = ChartAxisSpec(
    key: 'vel',
    label: 'vel (m/s)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: 0.0, max: 1.0, tickStep: 0.2),
      kind: ChartScaleKind.padded,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-22 10:30:00 · 박건준
  /// 변수: accel
  /// 목적: 수직 가속도 차트의 세로축. 0 을 가운데 두고 틀 = ±(데이터 최대
  ///       절댓값 x 1.2), 반올림 없음(`ChartScaleKind.paddedSymmetric`).
  ///       최소 범위는 데이터가 모두 0 일 때만 쓴다.
  /// 근거: 측정 — 2026-10-22 OTIS 리포트 3쪽 가속도 · 저크 차트 6개의 틀이
  ///       데이터 최대 절댓값의 1.20 ~ 1.22배(저크 3회만 1.34). 예전 "±0.6
  ///       을 넘으면 ±0.75 · ±1 로 넓힘" 을 바꾼다
  static const ChartAxisSpec accel = ChartAxisSpec(
    key: 'acc',
    label: 'acc (m/s^2)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -0.6, max: 0.6, tickStep: 0.3),
      kind: ChartScaleKind.paddedSymmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-22 10:30:00 · 박건준
  /// 변수: jerk
  /// 목적: 저크(가속도가 얼마나 빠르게 변하는지) 차트의 세로축. 가속도와
  ///       같은 0 대칭 여백 규칙이다(`accel` 근거 참고). 저크는 1.6Hz 저역
  ///       가속도를 미분한 값이라(`CaptureConfig.jerkLowpassHz`) 정상 운행이면
  ///       ±0.6 안이다.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관) · 2026-10-21
  ///       오티스폰 리포트 3쪽 저크 차트 범위 ±0.6, 눈금 0.2
  static const ChartAxisSpec jerk = ChartAxisSpec(
    key: 'jerk',
    label: 'jerk (m/s^3)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -0.6, max: 0.6, tickStep: 0.2),
      kind: ChartScaleKind.paddedSymmetric,
    ),
  );

  /// 작성: 2026-09-26 14:10:00 · 박건준
  /// 변수: all
  /// 목적: 축 사양 여덟 개를 모아 둔 것. 낱개 상수와 같은 값이며, 전부
  ///       훑어야 할 때 쓴다.
  static const List<ChartAxisSpec> all = <ChartAxisSpec>[
    x,
    y,
    z,
    noise,
    position,
    speed,
    accel,
    jerk,
  ];

  /// 작성: 2026-09-26 14:10:00 · 박건준
  /// 함수: longestSeriesLength
  /// 목적: 이 측정이 가진 시계열 중 가장 긴 것의 표본 수를 센다. 차트
  ///       여덟 개가 같은 가로축을 쓰게 하려고 둔다 — 축마다 제 시계열
  ///       길이로 폭을 잡으면, 비어 있는 축만 다른 시간대를 그리게 된다.
  /// 인자: result — 시계열을 가진 측정 결과
  /// 반환: 가장 긴 시계열의 표본 수. 시계열이 하나도 없으면 0
  static int longestSeriesLength(MeasurementResult result) {
    var longest = 0; // 여기까지 본 것 중 가장 긴 표본 수
    for (final spec in all) {
      // → 로직 이동: seriesOf()
      final length = seriesOf(spec, result).length; // 이 축의 표본 수
      if (length > longest) longest = length;
    }
    return longest;
  }

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 수정: 2026-10-21 15:20:00 · 박건준
  /// 함수: seriesOf
  /// 목적: 축 사양에 맞는 시계열을 측정 결과에서 꺼낸다. 어떤 축이 어떤
  ///       시계열을 그리는지 정하는 곳을 한 군데로 둔다. 리포트 차트와
  ///       결과 화면 그래프가 함께 쓴다.
  ///       속도는 부호 그대로 꺼낸다 — 하강이면 음수다. 위치는 하부층
  ///       정지레벨 기준이라 하강이면 운행 거리에서 0 으로 내려온다. OTIS
  ///       리포트 3쪽과 같다(2026-10-21, 2026-10-10 "속도는 크기로 그린다"
  ///       결정을 바꿈). 표의 최대 속도 · 운행 거리는 그대로 크기다.
  /// 인자: spec — 꺼낼 축의 사양
  ///       result — 시계열을 가진 측정 결과
  /// 반환: 그 축이 그릴 시계열. 아직 채워지지 않았으면 빈 목록
  static List<double> seriesOf(ChartAxisSpec spec, MeasurementResult result) {
    switch (spec.key) {
      case 'x':
        return result.xSeries;
      case 'y':
        return result.ySeries;
      case 'z':
        return result.zSeries;
      case 'noise':
        return result.noiseSeries;
      case 'pos':
        return result.positionSeries;
      case 'vel':
        return result.speedSeries;
      case 'acc':
        return result.accelSeries;
      case 'jerk':
        return result.jerkSeries;
    }
    throw ArgumentError.value(spec.key, 'spec.key', '모르는 축 이름이다');
  }

  /// 작성: 2026-10-11 19:20:58 · 박건준
  /// 함수: ptpOf
  /// 목적: 진동 세 축 차트에 적을 P2P 를 측정 결과에서 꺼낸다. 차트에서
  ///       다시 세지 않고 1쪽 표가 쓰는 같은 지표(`xPtp` · `yPtp` · `zPtp`)를
  ///       쓴다 — 두 곳에서 세면 차트와 표가 다른 숫자를 말하게 된다.
  /// 인자: spec — 축 사양
  ///       result — 지표를 가진 측정 결과
  /// 반환: P2P (mg). 진동 축이 아니거나 계산하지 않은 예전 결과면 null
  static double? ptpOf(ChartAxisSpec spec, MeasurementResult result) {
    switch (spec.key) {
      case 'x':
        return result.xPtp;
      case 'y':
        return result.yPtp;
      case 'z':
        return result.zPtp;
    }
    return null;
  }

  /// 작성: 2026-10-20 15:02:44 · 박건준
  /// 함수: a95Of
  /// 목적: 진동 세 축 차트에 점선으로 그을 A95 를 측정 결과에서 꺼낸다.
  ///       `ptpOf()` 와 같이 1쪽 표가 쓰는 지표(`xA95` · `yA95` · `zA95`)를
  ///       그대로 쓴다.
  /// 인자: spec — 축 사양
  ///       result — 지표를 가진 측정 결과
  /// 반환: A95 (mg). 진동 축이 아니거나 계산하지 않은 결과면 null
  static double? a95Of(ChartAxisSpec spec, MeasurementResult result) {
    switch (spec.key) {
      case 'x':
        return result.xA95;
      case 'y':
        return result.yA95;
      case 'z':
        return result.zA95;
    }
    return null;
  }

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: peakToPeakPair
  /// 목적: 최대 P2P 를 만든 두 지점을 찾는다. 운행 구간이 있으면 그 구간
  ///       안 최대 반주기 P2P(`HalfCycle.maximum()`)의 이웃 봉우리 · 골이고,
  ///       없으면(예전 결과) 시계열 전체의 최댓값 · 최솟값(`extremeIndices()`)
  ///       이다. 둘 중 값이 큰 쪽이 `high` 다.
  /// 인자: values — 그린 시계열 (줄이기 전)
  ///       result — 운행 구간을 가진 측정 결과
  /// 반환: (높은 쪽, 낮은 쪽) 첨자. 못 찾으면 null
  static ({int high, int low})? peakToPeakPair(
    List<double> values,
    MeasurementResult result,
  ) {
    final window = result.travelWindow; // 운행 구간, 예전 결과면 null
    if (window == null) {
      // → 로직 이동: extremeIndices()
      final at = extremeIndices(values); // 최댓값 · 최솟값 자리, 비면 null
      return at == null ? null : (high: at.maxIndex, low: at.minIndex);
    }
    if (window.startIndex >= values.length) return null;
    // → 로직 이동: HalfCycle.maximum()
    final best = HalfCycle.maximum(
      values,
      start: window.startIndex,
      end: math.min(window.endIndex, values.length - 1),
    ); // 최대 반주기 P2P, 못 만들면 null
    if (best == null) return null;
    return orderedPair(values, best); // → 로직 이동: orderedPair()
  }

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: orderedPair
  /// 목적: 반주기 P2P 의 두 봉우리 자리를 값이 큰 쪽 · 작은 쪽으로 가른다.
  /// 인자: values — 그린 시계열
  ///       best — 반주기 P2P
  /// 반환: (높은 쪽, 낮은 쪽) 첨자
  static ({int high, int low}) orderedPair(
    List<double> values,
    HalfCyclePeakToPeak best,
  ) {
    final first = best.firstIndex; // 앞 반주기 봉우리 자리
    final second = best.secondIndex; // 뒤 반주기 봉우리 자리
    return values[first] >= values[second]
        ? (high: first, low: second)
        : (high: second, low: first);
  }

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: verticalPairs
  /// 목적: 수직 차트에 찍을 두 쌍을 찾는다 — 정속 구간 최대(`zPtp`)와
  ///       가감속 구간 최대(`zJptp`)를 만든 봉우리 · 골. 지표와 같은 함수
  ///       (`MotionZones.steadyMaximum()` · `transientMaximum()`)로 찾아
  ///       차트 점과 표 값이 같은 반주기를 가리킨다.
  /// 인자: values — 그린 수직 시계열 (줄이기 전)
  ///       result — 정속 · 가감속 구간을 가진 측정 결과
  /// 반환: (정속 쌍, 가감속 쌍). 구간이 없는 결과(2026-10-21 전 · 구간을
  ///       못 정함)면 null. 쌍 하나를 못 찾으면 그 자리만 null
  static ({({int high, int low})? steady, ({int high, int low})? transient})?
  verticalPairs(List<double> values, MeasurementResult result) {
    final zones = result.motionZones; // 정속 · 가감속 구간, 없으면 null
    if (zones == null) return null;
    // → 로직 이동: MotionZones.steadyMaximum()
    final steady = zones.steadyMaximum(values); // 정속 최대, 없으면 null
    // → 로직 이동: MotionZones.transientMaximum()
    final transient = zones.transientMaximum(values); // 가감속 최대
    return (
      steady: steady == null ? null : orderedPair(values, steady),
      transient: transient == null ? null : orderedPair(values, transient),
    );
  }

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: indexInTravel
  /// 목적: 값이 처음 나온 자리를 운행 구간 안에서 찾는다. 구간이 없는 예전
  ///       결과는 시계열 전체에서 찾는다. 구간 밖에 같은 값이 먼저 있어도
  ///       지표를 낸 구간 안 자리를 고르기 위해서다.
  /// 인자: values — 그린 시계열
  ///       target — 찾을 값
  ///       result — 운행 구간을 가진 측정 결과
  /// 반환: 첨자. 못 찾으면 -1
  static int indexInTravel(
    List<double> values,
    double target,
    MeasurementResult result,
  ) {
    final window = result.travelWindow; // 운행 구간, 예전 결과면 null
    if (window == null) return values.indexOf(target);
    final end = math.min(window.endIndex, values.length - 1); // 구간 끝
    for (var i = window.startIndex; i <= end; i++) {
      if (values[i] == target) return i;
    }
    return -1;
  }
}
