import 'dart:math' as math;

// `Matrix4` 는 세로 라벨을 돌려 찍을 때만 쓴다. pdf 패키지가 이 자료형을
// 내보내지 않아 Flutter 가 다시 내보내는 것을 가져온다 — 이렇게 하면
// `vector_math` 를 직접 의존성에 더하지 않아도 된다
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';
import 'package:vibration_checker/domain/report/half_cycle.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-10 11:48:41 · nada
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
  /// 함수: rangeFor
  /// 목적: 그릴 값이 모두 들어가는 세로축 범위를 고른다. 규칙은
  ///       `ChartScale` 이 갖는다 — 결과 화면 그래프도 같은 규칙을 써야
  ///       PDF 와 화면이 같은 눈금을 보인다.
  /// 인자: values — 그릴 값 목록
  /// 반환: 고른 범위. 값이 없으면 최소 범위
  ChartAxisRange rangeFor(List<double> values) =>
      scale.rangeFor(values); // → 로직 이동: ChartScale.rangeFor()
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-10 11:48:41 · nada
/// 클래스: ReportChartAxes
/// 목적: 차트 여덟 개의 축 사양을 모아 둔다. 축마다 최소 범위와 넓히는
///       모양을 정하고, 실제 범위는 데이터에 맞춰 `ChartScale` 이 낸다.
///       최소 범위는 원본 리포트 범위를 따른다 — 조용한 운행은 원본과
///       같은 눈금으로 보이고, 넘칠 때만 넓어져 잘리는 값이 없다.
///
///       단위는 축마다 다르다. 진동 세 축은 mg, 소음은 dBA, 위치는 m,
///       속도는 m/s, 가속도는 m/s2, 저크는 m/s3 이다.
class ReportChartAxes {
  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
  /// 변수: x
  /// 목적: X축(가로 진동) 차트의 세로축. 0 을 가운데 둔다. 차트는 지표 계산
  ///       전 신호 처리(기준선 0 맞춤 · 40Hz 저역 필터 · 100Hz 재표본)를
  ///       거친 시계열을 그린다.
  /// 근거: 인용 — 최소 범위는 원본 리포트 `docs/reference/sample_evimp.pdf`
  ///       의 X 진동 차트 범위 ±4 mg, 눈금 2 mg 이다.
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
  /// 변수: y
  /// 목적: Y축(가로 진동) 차트의 세로축. 0 을 가운데 둔다. 그리는 시계열은
  ///       `x` 와 같이 신호 처리를 거친 값이다.
  /// 근거: 인용 — 최소 범위는 원본 리포트의 Y 진동 차트 범위 ±10 mg, 눈금
  ///       5 mg 이다.
  ///       측정 — 픽스처(`test/fixtures/conditioning_expected_100hz.txt`,
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 변수: z
  /// 목적: 수직 진동 차트의 세로축. 0 을 가운데 둔다. 2026-10-15 부터는
  ///       가중(1Hz 고역 + Wk)으로 가감속이 빠진 시계열을 그려 대개 최소
  ///       범위 안이다. 그 전 예전 결과는 가감속이 섞여 범위를 넓힌다.
  /// 근거: 인용 — 최소 범위는 원본 리포트 `docs/reference/sample_evimp.pdf`
  ///       의 수직 진동 차트 범위 ±20 mg, 눈금 10 mg 이다
  static const ChartAxisSpec z = ChartAxisSpec(
    key: 'z',
    label: 'Vertical Vibration (milli-G)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -20.0, max: 20.0, tickStep: 10.0),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-21 15:20:00 · nada
  /// 변수: position
  /// 목적: 위치(하부층 정지레벨 기준) 차트의 세로축. 0 을 한쪽 끝으로
  ///       둔다. 운행 거리가 현장마다 크게 달라 대부분 넓어진다.
  /// 근거: 인용 — 최소 범위는 파이썬 프로토타입 `charts.py` 의 `AXES` 위치
  ///       축 첫 단계와 같다
  static const ChartAxisSpec position = ChartAxisSpec(
    key: 'pos',
    label: 'pos (m)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: 0.0, max: 10.0, tickStep: 2.0),
      kind: ChartScaleKind.zeroAnchored,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-21 15:20:00 · nada
  /// 변수: speed
  /// 목적: 속도 차트의 세로축. 0 을 한쪽 끝으로 둔다. 하강이면 속도가
  ///       음수라 0 아래로 넓어진다(`seriesOf()` 참고).
  /// 근거: 인용 — 최소 범위는 프로토타입 `charts.py` 의 `AXES` 속도 축 첫
  ///       단계와 같다
  static const ChartAxisSpec speed = ChartAxisSpec(
    key: 'vel',
    label: 'vel (m/s)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: 0.0, max: 1.0, tickStep: 0.2),
      kind: ChartScaleKind.zeroAnchored,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
  /// 변수: accel
  /// 목적: 수직 가속도 차트의 세로축. 0 을 가운데 둔다.
  /// 근거: 인용 — 최소 범위는 프로토타입 `charts.py` 의 `AXES` 가속도 축
  ///       첫 단계와 같다
  static const ChartAxisSpec accel = ChartAxisSpec(
    key: 'acc',
    label: 'acc (m/s^2)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -0.6, max: 0.6, tickStep: 0.3),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-21 10:05:00 · nada
  /// 변수: jerk
  /// 목적: 저크(가속도가 얼마나 빠르게 변하는지) 차트의 세로축. 0 을
  ///       가운데 둔다. 저크는 1.6Hz 저역 가속도를 미분한 값이라
  ///       (`CaptureConfig.jerkLowpassHz`) 정상 운행이면 ±0.6 안이다.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관) · 2026-10-21
  ///       오티스폰 리포트 3쪽 저크 차트 범위 ±0.6, 눈금 0.2
  static const ChartAxisSpec jerk = ChartAxisSpec(
    key: 'jerk',
    label: 'jerk (m/s^3)',
    scale: ChartScale(
      minimum: ChartAxisRange(min: -0.6, max: 0.6, tickStep: 0.2),
      kind: ChartScaleKind.symmetric,
    ),
  );

  /// 작성: 2026-09-26 14:10:00 · nada
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

  /// 작성: 2026-09-26 14:10:00 · nada
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

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-21 15:20:00 · nada
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

  /// 작성: 2026-10-11 19:20:58 · nada
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

  /// 작성: 2026-10-20 15:02:44 · nada
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

  /// 작성: 2026-10-15 16:50:04 · nada
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

  /// 작성: 2026-10-21 13:10:00 · nada
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

  /// 작성: 2026-10-21 13:10:00 · nada
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

  /// 작성: 2026-10-15 16:50:04 · nada
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

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: ChartSample
/// 목적: 줄이기를 거쳐 남은 표본 하나. 값과 함께 원래 시계열에서의 자리를
///       갖는다 — 가로 자리를 시각으로 되돌리려면 자리 번호가 있어야 한다.
class ChartSample {
  /// 원래 시계열에서의 자리 번호 (0 부터)
  final int index;

  /// 그 자리의 값. 단위는 그 시계열의 단위를 따른다
  final double value;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ChartSample
  /// 목적: 표본 하나의 자리와 값을 그대로 담는 생성자.
  /// 인자: index — 원래 시계열에서의 자리 번호
  ///       value — 그 자리의 값
  const ChartSample(this.index, this.value);
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-11 15:34:38 · nada
/// 함수: reduceSeries
/// 목적: 시계열을 가로 칸 수만큼으로 나눠, 칸마다 가장 작은 값과 가장 큰
///       값만 남긴다.
///       - 표본이 1만 개를 넘는데 차트 가로는 그보다 훨씬 좁다. 전부
///         찍으면 파일만 무거워지고 한 칸에 여러 점이 겹쳐 그려진다
///       - 평균을 내지 않는다. 평균을 내면 봉우리와 골이 깎여 사라지는데,
///         진동 차트는 그 끝값이 곧 읽을 거리다
///       - 한 칸에서 두 점을 내보낼 때는 원래 나온 차례를 지킨다. 차례를
///         뒤집으면 없던 되돌림이 생겨 파형 모양이 달라진다
/// 인자: values — 줄일 시계열. 비어 있으면 빈 목록을 돌려준다
///       columns — 나눌 칸 수. 차트 가로 픽셀 수를 넘긴다
/// 반환: 자리 번호가 커지는 차례로 놓인 표본 목록. 원래 목록의 최솟값과
///       최댓값은 반드시 들어 있다. 표본이 칸 수의 두 배 이하면 줄이지
///       않고 그대로 옮겨 담는다
List<ChartSample> reduceSeries(List<double> values, {required int columns}) {
  assert(columns > 0, '칸 수는 차트 가로 픽셀 수라 0 이하가 될 수 없다');
  if (values.isEmpty) return const <ChartSample>[];
  // → 로직 이동: _reduceRun()
  return _reduceRun(values, 0, values.length, columns);
}

/// 작성: 2026-10-11 15:34:38 · nada
/// 함수: reduceSeriesSegments
/// 목적: 시계열을 줄이되, 0 을 미측정으로 보는 시계열(소음)은 0 구간에서
///       끊어 실측 구간마다 따로 줄인다. 0 구간에 선을 그으면 재지 않은
///       값을 그린 것이 된다(관통 원칙 1). 한 칸 안에 0 과 실측이 섞이면
///       실측만으로 최소 · 최대를 낸다. 칸 나누기는 `reduceSeries()` 와
///       같아, 끊지 않을 때는 그 결과 한 덩어리와 같다.
/// 인자: values — 줄일 시계열
///       columns — 나눌 칸 수. 차트 가로 픽셀 수를 넘긴다
///       skipZeros — 0 을 미측정으로 보고 끊을지
/// 반환: 이어 그릴 구간 목록. 구간마다 자리 번호가 커지는 차례로 놓인
///       표본이고, 구간끼리도 차례대로다. 그릴 표본이 없으면 빈 목록
List<List<ChartSample>> reduceSeriesSegments(
  List<double> values, {
  required int columns,
  required bool skipZeros,
}) {
  assert(columns > 0, '칸 수는 차트 가로 픽셀 수라 0 이하가 될 수 없다');
  final segments = <List<ChartSample>>[]; // 모아 갈 구간
  var runStart = -1; // 지금 이어지는 실측 구간의 첫 자리, 구간 밖이면 -1
  for (var index = 0; index <= values.length; index++) {
    final valid =
        index < values.length &&
        !(skipZeros && values[index] == 0.0); // 이 자리를 그릴지
    if (valid && runStart < 0) runStart = index;
    if (!valid && runStart >= 0) {
      // → 로직 이동: _reduceRun()
      segments.add(_reduceRun(values, runStart, index, columns));
      runStart = -1;
    }
  }
  return segments;
}

/// 작성: 2026-10-11 15:34:38 · nada
/// 함수: _reduceRun
/// 목적: 시계열의 한 구간 [start, end) 를 줄인다. 칸 경계는 시계열 전체를
///       `columns` 칸으로 나눈 자리를 그대로 쓰고, 이 구간과 겹치는
///       칸마다 겹친 부분의 최소 · 최대만 남긴다. 전체 표본이 칸 수의 두
///       배 이하면 구간을 줄이지 않고 옮겨 담는다.
/// 인자: values — 시계열 전체
///       start, end — 줄일 구간의 첫 자리와 끝 다음 자리. start < end
///       columns — 나눌 칸 수
/// 반환: 자리 번호가 커지는 차례로 놓인 표본 목록
List<ChartSample> _reduceRun(
  List<double> values,
  int start,
  int end,
  int columns,
) {
  assert(start < end, '빈 구간을 줄이려 했다: $start ~ $end');
  if (values.length <= columns * 2) {
    return <ChartSample>[
      for (var index = start; index < end; index++)
        ChartSample(index, values[index]),
    ];
  }

  final reduced = <ChartSample>[]; // 칸마다 최대 두 점씩 담을 결과
  for (var column = 0; column < columns; column++) {
    final columnStart = values.length * column ~/ columns; // 이 칸의 첫 자리
    final columnEnd = values.length * (column + 1) ~/ columns; // 다음 칸 첫 자리
    final from = math.max(columnStart, start); // 구간과 겹친 첫 자리
    final to = math.min(columnEnd, end); // 구간과 겹친 끝 다음 자리
    if (from >= to) continue;

    var minIndex = from; // 겹친 부분에서 가장 작은 값의 자리
    var maxIndex = from; // 겹친 부분에서 가장 큰 값의 자리
    for (var index = from + 1; index < to; index++) {
      if (values[index] < values[minIndex]) minIndex = index;
      if (values[index] > values[maxIndex]) maxIndex = index;
    }

    final first = math.min(minIndex, maxIndex); // 둘 중 먼저 나온 쪽
    final second = math.max(minIndex, maxIndex); // 둘 중 나중에 나온 쪽
    reduced.add(ChartSample(first, values[first]));
    if (second != first) {
      reduced.add(ChartSample(second, values[second]));
    }
  }
  return reduced;
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: _ChartFrame
/// 목적: 차트 한 개의 축 틀이 PDF 위 어디에 놓이는지와, 값을 그 안의
///       자리로 옮기는 계산을 함께 담는다. 옮기는 식을 한 곳에 두어야
///       격자 · 눈금 · 파형이 서로 어긋나지 않는다.
class _ChartFrame {
  /// 축 틀 왼쪽 끝 (PDF 포인트)
  final double left;

  /// 축 틀 오른쪽 끝 (PDF 포인트)
  final double right;

  /// 축 틀 위쪽 끝 (PDF 포인트, 아래쪽이 0 이라 `bottom` 보다 크다)
  final double top;

  /// 축 틀 아래쪽 끝 (PDF 포인트)
  final double bottom;

  /// 이 차트가 쓰기로 고른 세로축 범위
  final ChartAxisRange range;

  /// 가로축이 담는 시간 폭 (초)
  final double timeSpanSec;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _ChartFrame
  /// 목적: 축 틀의 네 끝과 두 축의 범위를 그대로 담는 생성자.
  /// 인자: left, right — 축 틀 좌우 끝 (포인트)
  ///       top, bottom — 축 틀 위아래 끝 (포인트)
  ///       range — 세로축 범위
  ///       timeSpanSec — 가로축이 담는 시간 폭 (초)
  const _ChartFrame({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.range,
    required this.timeSpanSec,
  });

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: centerX
  /// 목적: 축 틀 가로 한가운데 (PDF 포인트).
  double get centerX => (left + right) / 2;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: centerY
  /// 목적: 축 틀 세로 한가운데 (PDF 포인트).
  double get centerY => (top + bottom) / 2;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: xOfTime
  /// 목적: 시각을 축 틀 안의 가로 자리로 옮긴다.
  /// 인자: seconds — 측정 시작부터의 시각 (초)
  /// 반환: PDF 가로 자리 (포인트)
  /// 식: x = left + (right - left) x (seconds / timeSpanSec)
  double xOfTime(double seconds) =>
      left + (right - left) * (seconds / timeSpanSec);

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: yOfValue
  /// 목적: 측정값을 축 틀 안의 세로 자리로 옮긴다.
  /// 인자: value — 옮길 값. 단위는 그 축의 단위를 따른다
  /// 반환: PDF 세로 자리 (포인트)
  /// 식: y = bottom + (top - bottom) x (value - range.min) / range.span
  double yOfValue(double value) =>
      bottom + (top - bottom) * ((value - range.min) / range.span);
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: ReportChartRenderer
/// 목적: 파형 차트 하나를 PDF 캔버스에 직접 그린다. 그리기 도구를 저수준
///       그대로 쓰고 위젯 계층을 거치지 않는다 — 1쪽(`report_page1.dart`)
///       과 같은 방식이다.
///
///       그리는 차례는 격자 · 축 틀 · 눈금과 라벨 · 파형이다. 격자를 먼저
///       깔아야 파형이 그 위에 올라온다.
///
///       아래 크기 · 굵기 상수는 PDF 포인트 단위다. 자리를 담은
///       `ReportLayout` 이 서식 이미지 픽셀을 쓰는 것과 다른데, 이 값들은
///       파이썬 프로토타입이 원본 리포트와 맞춰 포인트로 찾아낸 것이라
///       옮기면서 단위를 바꾸지 않았다.
class ReportChartRenderer {
  /// 축 틀 선 굵기 (포인트)
  static const double frameLineWidth = 0.4;

  /// 격자 선 굵기 (포인트)
  static const double gridLineWidth = 0.3;

  /// 파형 선 굵기 (포인트)
  static const double seriesLineWidth = 0.35;

  /// 평균 기준선 굵기 (포인트)
  static const double guideLineWidth = 0.4;

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 수정: 2026-10-20 15:02:44 · nada
  /// 변수: guideDashPattern
  /// 목적: 운행 구간 점선(진동 A95 두 줄, 소음 평균 한 줄)의 켠 길이와 끈
  ///       길이 (포인트).
  /// 근거: 측정 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관) 2쪽을
  ///       600dpi 로 그려 붉은 점선을 재니 X · 소음 차트 모두 점 2.28pt ·
  ///       빈칸 2.28pt 다(2026-10-20)
  static const List<double> guideDashPattern = <double>[2.3, 2.3];

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 변수: markerRadius
  /// 목적: 표시점(P2P 최댓값 · 최솟값, 소음 최댓값)의 반지름 (포인트).
  ///       파형 선(0.35)보다 훨씬 굵게 둬 한눈에 보이게 한다.
  /// 근거: 인용 — 2026-10-15 사용자 지시 "눈에 띄게 굵은 점". 예전 값
  ///       0.8(프로토타입 `charts.py` 지름 1.6)은 파형에 묻혀 잘 보이지
  ///       않았다. 미정 — 굵기 자체는 눈으로 골랐다
  static const double markerRadius = 2.2;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: markerRingWidth
  /// 목적: 표시점 둘레에 두르는 흰 테 굵기 (포인트). 빨간 점이 파란 파형
  ///       위에 놓여도 테두리로 갈라져 보이게 한다.
  /// 근거: 미정 — 눈으로 골랐다
  static const double markerRingWidth = 0.7;

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 변수: markerLabelSize
  /// 목적: 표시점 옆에 적는 값의 글자 크기 (포인트). 눈금 라벨(5.0)보다
  ///       크게 두고 굵은 글꼴(`labelFont`)로 적는다.
  /// 근거: 인용 — 2026-10-15 사용자 지시 "값도 잘 보여야 해". 예전 값
  ///       5.2 는 작아 읽기 어려웠다. 미정 — 크기 자체는 눈으로 골랐다
  static const double markerLabelSize = 7.5;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: labelGap
  /// 목적: 표시점 가장자리와 값 상자 사이 간격 (포인트).
  /// 근거: 미정 — 눈금 라벨 간격(`tickLabelGap`)과 비슷하게 잡았다
  static const double labelGap = 2.0;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: labelPadding
  /// 목적: 값 글자와 그 뒤 흰 상자 테두리 사이 여백 (포인트). 상자가
  ///       파형을 가려 글자가 선과 겹쳐 보이지 않게 한다.
  /// 근거: 미정 — 눈으로 골랐다
  static const double labelPadding = 1.2;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: labelBorderWidth
  /// 목적: 값 상자 테두리(빨강) 굵기 (포인트).
  /// 근거: 미정 — 축 틀 선(`frameLineWidth`)과 같은 굵기
  static const double labelBorderWidth = 0.4;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: labelInset
  /// 목적: 값 상자가 축 틀 선에서 안쪽으로 떨어지는 최소 거리 (포인트).
  ///       상자가 틀 밖으로 나가 잘리지 않게 한다.
  /// 근거: 미정 — `labelGap` 보다 조금 작게 잡았다
  static const double labelInset = 1.5;

  /// 격자 점선의 켠 길이와 끈 길이 (포인트)
  static const List<double> gridDashPattern = <double>[1.2, 1.2];

  /// 작성: 2026-10-20 15:02:44 · nada
  /// 변수: a95Label
  /// 목적: 진동 A95 점선 왼쪽에 적는 글자. 원본 리포트 표기를 그대로 쓴다.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf 2쪽 X · Y · 수직 차트
  static const String a95Label = 'A95';

  /// 눈금 표시선이 축 틀 밖으로 나오는 길이 (포인트)
  static const double tickLength = 2.0;

  /// 눈금 표시선과 눈금 라벨 사이 간격 (포인트)
  static const double tickLabelGap = 1.5;

  /// 눈금 라벨 글자 크기 (포인트)
  static const double tickLabelSize = 5.0;

  /// 축 라벨 글자 크기 (포인트)
  static const double axisLabelSize = 5.6;

  /// 축 라벨과 눈금 라벨 사이 간격 (포인트)
  static const double axisLabelGap = 2.0;

  /// 가로축 라벨 문구. 원본 리포트 표기를 그대로 쓴다
  static const String timeAxisLabel = 'Time (s)';

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: minTimeSpanSec
  /// 목적: 가로축이 담는 가장 짧은 시간 폭 (초).
  /// 근거: 인용 — 프로토타입 `charts.py` 의 `render_chart_page()` 가 쓰는
  ///       하한과 같다. 측정이 아주 짧거나 비었을 때 축 폭이 0 이 되어
  ///       나누기가 무너지는 것을 막는다
  static const double minTimeSpanSec = 1.0;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: timeHeadroom
  /// 목적: 마지막 표본이 축 오른쪽 끝에 닿지 않도록 두는 여유 배수.
  /// 근거: 인용 — 프로토타입 `charts.py` 가 쓰는 값과 같다
  static const double timeHeadroom = 1.02;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: timeTickTarget
  /// 목적: 가로축 눈금이 나눌 칸 수의 목표.
  /// 근거: 미확인 — 원본 리포트의 가로축 눈금 간격은 측정 길이에 따라
  ///       달라져 고정값을 옮겨 적을 수 없다. 차트 가로 폭에 라벨이
  ///       겹치지 않는 선에서 이 수를 골랐다
  static const int timeTickTarget = 6;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:48:41 · nada
  /// 변수: tickLabelDecimals
  /// 목적: 눈금 라벨을 만들 때 일단 남길 소수 자리 수. 뒤따르는 0 은
  ///       지우므로 실제로 찍히는 자리 수는 이보다 적을 수 있다.
  /// 근거: 측정 — 최소 범위 간격 중 가장 잘게 나뉜 것이 저크의 0.25 다.
  ///       넓힌 축은 최소 범위보다 넓고, 최소 범위 폭이 가장 좁은 저크도
  ///       1.0 이라 6칸으로 나눠도 간격이 0.1 아래로 내려가지 않는다.
  ///       0.1 · 0.2 · 0.25 모두 두 자리면 정확히 표기된다
  static const int tickLabelDecimals = 2;

  /// 눈금 라벨과 축 라벨에 쓰는 글꼴
  final PdfFont font;

  /// 표시점 옆 값(P2P · 소음 최댓값)에 쓰는 글꼴. 굵은 글꼴을 받는다
  final PdfFont labelFont;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: ReportChartRenderer
  /// 목적: 글자를 찍는 데 쓸 글꼴을 담는 생성자.
  /// 인자: font — 눈금 라벨과 축 라벨에 쓸 글꼴
  ///       labelFont — 표시점 옆 값에 쓸 글꼴. 안 주면 `font`
  const ReportChartRenderer({required this.font, PdfFont? labelFont})
    : labelFont = labelFont ?? font;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-20 15:02:44 · nada
  /// 함수: draw
  /// 목적: 차트 한 개를 주어진 자리에 그린다. 순서대로 한다.
  ///       1. 그릴 시계열을 꺼내고, 거기에 맞는 세로축 범위를 고른다
  ///       2. 축 틀 · 격자 · 눈금 · 라벨을 그린다
  ///       3. 시계열이 비어 있지 않으면 파형을 얹고, 소음 평균선 ·
  ///          최댓값, 진동 세 축 A95 점선과 최대 P2P 표시를 붙인다
  ///
  ///       시계열이 비어도 축 틀까지는 그린다. 자리를 통째로 비우면 나중에
  ///       그 값이 붙었을 때 서식이 바뀐 것처럼 보인다. 지금은 소음이 그
  ///       상태다.
  /// 인자: canvas — 그리기 도구
  ///       spec — 그릴 축의 사양
  ///       box — 축 틀이 놓일 자리 (서식 이미지 픽셀)
  ///       result — 시계열과 표본 주기를 가진 측정 결과
  void draw(
    PdfGraphics canvas, {
    required ChartAxisSpec spec,
    required LayoutPlotBox box,
    required MeasurementResult result,
  }) {
    // → 로직 이동: ReportChartAxes.seriesOf()
    final values = ReportChartAxes.seriesOf(spec, result); // 이 차트가 그릴 값
    // → 로직 이동: ChartAxisSpec.rangeFor()
    final range = spec.rangeFor(values); // 값에 맞춰 고른 세로축 범위
    final frame = _ChartFrame(
      left: ReportLayout.xToPoints(box.x),
      right: ReportLayout.xToPoints(box.x + box.width),
      top: ReportLayout.yToPoints(box.y),
      bottom: ReportLayout.yToPoints(box.y + box.height),
      range: range,
      timeSpanSec: _timeSpan(
        // → 로직 이동: ReportChartAxes.longestSeriesLength()
        ReportChartAxes.longestSeriesLength(result),
        result.sampleRate,
      ),
    ); // 이 차트의 축 틀과 값 옮기기
    final valueTicks = range.ticks(); // 세로축 눈금 값
    final timeTicks = _timeTicks(frame.timeSpanSec); // 가로축 눈금 시각 (초)

    _drawGrid(canvas, frame, valueTicks, timeTicks);
    _drawFrame(canvas, frame);
    _drawValueAxis(canvas, frame, valueTicks, spec.label);
    _drawTimeAxis(canvas, frame, timeTicks);
    if (values.isNotEmpty) {
      _drawSeries(
        canvas,
        frame,
        values,
        box.width,
        result.sampleRate,
        skipZeros: spec.scale.ignoreZeros,
      );
      _drawAnnotations(canvas, frame, spec, values, result);
      _drawA95Band(canvas, frame, spec, result); // → 로직 이동: _drawA95Band()
      _drawPeakToPeak(canvas, frame, spec, values, result);
    }
  }

  /// 작성: 2026-10-11 19:20:58 · nada
  /// 수정: 2026-10-20 15:02:44 · nada
  /// 함수: ptpLabel
  /// 목적: 진동 차트 표시점 옆에 적을 최대 P2P 문구를 만든다. 숫자 표기 ·
  ///       단위는 1쪽 표와 같은 규칙(`ReportMetric.display`,
  ///       `ReportMetric.vibrationUnit`)을 써 두 곳이 같게 보인다. 머리말은
  ///       원본 리포트 차트 표기(`a_x,ptp`)의 소문자 "ptp" 를 쓴다.
  /// 인자: ptp — 최대 P2P (mg)
  /// 반환: "ptp 14.2milli-G" 꼴 문구
  /// 근거: 인용 — 2026-10-20 사용자 지시 "오티스 pdf 에 나오는 p2p 용어
  ///       소문자 ptp 로". 원본 TUNE 리포트 H6N1AP65.pdf 2쪽 "a_x,ptp"
  static String ptpLabel(double ptp) =>
      // → 로직 이동: _vibrationLabel()
      _vibrationLabel('ptp', ptp);

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 함수: jptpLabel
  /// 목적: 수직 차트 가감속 구간 최대 옆에 적을 문구를 만든다. 숫자 표기는
  ///       `ptpLabel()` 과 같다.
  /// 인자: jptp — 가감속 구간 최대 P2P (mg)
  /// 반환: "Jptp 17.1milli-G" 꼴 문구
  /// 근거: 인용 — 2026-10-21 점검 지시. OTIS 리포트 2쪽 수직 차트
  ///       "a_z,Jptp"
  static String jptpLabel(double jptp) =>
      // → 로직 이동: _vibrationLabel()
      _vibrationLabel('Jptp', jptp);

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 함수: _vibrationLabel
  /// 목적: 머리말 뒤에 1쪽 표와 같은 규칙으로 다듬은 진동 값을 붙인다.
  /// 인자: prefix — 머리말 ("ptp", "Jptp")
  ///       value — 진동 값 (mg)
  /// 반환: "머리말 값milli-G" 꼴 문구
  static String _vibrationLabel(String prefix, double value) {
    final metric = ReportMetric(
      key: 'p2p',
      value: value,
      unit: ReportMetric.vibrationUnit,
      verdict: ReportVerdict.none,
    ); // 표와 같은 규칙으로 숫자를 다듬을 지표
    return '$prefix ${metric.display}';
  }

  /// 작성: 2026-10-11 19:20:58 · nada
  /// 수정: 2026-10-21 13:10:00 · nada
  /// 함수: _drawPeakToPeak
  /// 목적: 진동 세 축 차트에 최대 P2P 를 만든 두 지점을 표시하고 값을 적는다.
  ///       - 두 지점(`ReportChartAxes.peakToPeakPair()`)에 굵은 빨간 점
  ///         (`_drawMarker()`).
  ///         운행 구간이 있는 결과는 지표와 같은 정의 — 최대 반주기 P2P 를
  ///         만든 이웃 봉우리 · 골 — 이고, 그 전 예전 결과는 시계열 전체의
  ///         최댓값 · 최솟값이다(그때 지표 정의)
  ///       - 높은 쪽 점 옆(오른쪽, 자리가 없으면 왼쪽)에 "ptp 값" 을 흰
  ///         상자에 굵게 적는다(`_drawSideLabel()`). 값은 1쪽 표와 같은
  ///         지표다(`ReportChartAxes.ptpOf()`)
  ///       - 수직 차트는 정속 구간 최대(`zPtp`) 쌍에 "ptp", 가감속 구간
  ///         최대(`zJptp`) 쌍에 "Jptp" 를 함께 적는다(OTIS 리포트와 같다).
  ///         두 글자 상자가 겹치면 뒤 상자를 위 · 아래로 옮긴다. 정속 ·
  ///         가감속 구간이 없는 2026-10-21 전 결과는 예전처럼 하나만 적는다
  ///       P2P 가 없는 축(진동 축이 아님, 구간을 못 정한 결과, 예전 결과)은
  ///       바로 돌아간다. 0 으로 채우지 않는다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       spec — 그리는 축의 사양
  ///       values — 그린 시계열 (줄이기 전)
  ///       result — 지표와 표본 주기를 가진 측정 결과
  /// 근거: 인용 — 2026-10-15 사용자 지시 "굵은 점으로 표시하고 그 선
  ///       왼쪽이든 오른쪽이든 가능한 부분에 값 표시", 2026-10-15 점검 지시
  ///       "빨간 점 두 개는 최대 반주기 P2P 를 만든 이웃 봉우리 · 골 쌍"
  void _drawPeakToPeak(
    PdfGraphics canvas,
    _ChartFrame frame,
    ChartAxisSpec spec,
    List<double> values,
    MeasurementResult result,
  ) {
    // → 로직 이동: ReportChartAxes.ptpOf()
    final ptp = ReportChartAxes.ptpOf(spec, result); // 적을 P2P, 없으면 null
    final vertical = spec.key == 'z'
        // → 로직 이동: ReportChartAxes.verticalPairs()
        ? ReportChartAxes.verticalPairs(values, result)
        : null; // 수직 정속 · 가감속 쌍, 구간 없는 결과 · 다른 축이면 null
    final at = vertical == null
        // → 로직 이동: ReportChartAxes.peakToPeakPair()
        ? ReportChartAxes.peakToPeakPair(values, result)
        : vertical.steady; // ptp 두 지점, 못 찾으면 null

    _Box? taken; // 이미 적은 글자 상자. 다음 글자가 피한다
    if (ptp != null && at != null) {
      // → 로직 이동: _drawPair()
      taken = _drawPair(canvas, frame, values, result, at, ptpLabel(ptp));
    }
    final jptp = result.zJptp; // 가감속 구간 최대, 없으면 null
    final jat = vertical?.transient; // Jptp 두 지점, 없으면 null
    if (jptp != null && jat != null) {
      // → 로직 이동: _drawPair()
      _drawPair(
        canvas,
        frame,
        values,
        result,
        jat,
        jptpLabel(jptp), // → 로직 이동: jptpLabel()
        avoid: taken,
      );
    }
  }

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 함수: _drawPair
  /// 목적: 반주기 P2P 두 지점에 빨간 점을 찍고 높은 쪽 옆에 문구를 적는다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       values — 그린 시계열 (줄이기 전)
  ///       result — 표본 주기를 가진 측정 결과
  ///       at — (높은 쪽, 낮은 쪽) 첨자
  ///       text — 적을 문구
  ///       avoid — 피할 글자 상자. 없으면 null
  /// 반환: 적은 글자 상자
  _Box _drawPair(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> values,
    MeasurementResult result,
    ({int high, int low}) at,
    String text, {
    _Box? avoid,
  }) {
    for (final index in <int>[at.low, at.high]) {
      // → 로직 이동: _drawMarker()
      _drawMarker(
        canvas,
        frame.xOfTime(index / result.sampleRate),
        frame.yOfValue(values[index]),
      );
    }
    // → 로직 이동: _drawSideLabel()
    return _drawSideLabel(
      canvas,
      frame,
      text,
      anchorX: frame.xOfTime(at.high / result.sampleRate),
      anchorY: frame.yOfValue(values[at.high]),
      avoid: avoid,
    );
  }

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 함수: _drawMarker
  /// 목적: 표시점 하나를 굵은 빨간 원으로 찍는다. 흰 테를 먼저 깔고 그
  ///       위에 빨간 원을 얹어, 파란 파형 위에서도 점이 갈라져 보이게 한다.
  /// 인자: canvas — 그리기 도구
  ///       x, y — 점 중심 (포인트)
  void _drawMarker(PdfGraphics canvas, double x, double y) {
    const ring = markerRadius + markerRingWidth; // 흰 테 반지름 (포인트)
    canvas
      ..setFillColor(PdfColors.white)
      ..drawEllipse(x, y, ring, ring)
      ..fillPath()
      ..setFillColor(reportPdfColor(ReportColors.chartMarker))
      ..drawEllipse(x, y, markerRadius, markerRadius)
      ..fillPath();
  }

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 수정: 2026-10-21 13:10:00 · nada
  /// 함수: _drawSideLabel
  /// 목적: 표시점 옆에 값을 흰 상자에 빨간 굵은 글자로 적는다.
  ///       - 가로: 점 오른쪽에 둔다. 상자가 축 틀 오른쪽을 넘으면 점
  ///         왼쪽에 둔다. 왼쪽도 넘으면(차트가 아주 좁음) 틀 안으로 밀어
  ///         넣는다
  ///       - 세로: 점과 같은 높이 가운데에 두되 틀 위 · 아래를 넘으면 틀
  ///         안으로 밀어 넣는다. 최댓값 점은 축 위 끝 가까이 있기 쉬워,
  ///         그대로 두면 글자가 틀 밖으로 잘린다
  ///       - 흰 상자와 빨간 테두리를 깔아 파형 선이 글자와 겹쳐 보이지
  ///         않게 한다
  ///       - 피할 상자(`avoid`)가 있으면 겹치지 않는 자리를 차례로 찾는다:
  ///         같은 높이 → 한 칸 아래 → 한 칸 위(각각 오른쪽 먼저). 모두
  ///         겹치면 같은 높이 오른쪽에 둔다
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       text — 적을 문구
  ///       anchorX, anchorY — 옆에 붙을 표시점 중심 (포인트)
  ///       avoid — 겹치지 않게 피할 상자. 없으면 null
  /// 반환: 적은 상자
  _Box _drawSideLabel(
    PdfGraphics canvas,
    _ChartFrame frame,
    String text, {
    required double anchorX,
    required double anchorY,
    _Box? avoid,
  }) {
    final textWidth = _widthOf(text, markerLabelSize, labelFont); // 글자 폭
    final boxWidth = textWidth + labelPadding * 2; // 상자 가로 (포인트)
    const boxHeight = markerLabelSize + labelPadding * 2; // 상자 세로 (포인트)
    const reach = markerRadius + markerRingWidth + labelGap; // 점에서 띄움
    final minLeft = frame.left + labelInset; // 상자 왼쪽 끝 하한
    final maxLeft = frame.right - labelInset - boxWidth; // 상자 왼쪽 끝 상한

    // 상자 왼쪽 끝을 고른다. 오른쪽이면 점 오른쪽에 두되 틀을 넘으면
    // 왼쪽에 둔다
    double leftOf({required bool right}) {
      var left = right ? anchorX + reach : anchorX - reach - boxWidth;
      if (right && left > maxLeft) left = anchorX - reach - boxWidth;
      return left.clamp(minLeft, math.max(minLeft, maxLeft)).toDouble();
    }

    // 상자 세로 가운데를 틀 안으로 밀어 넣는다
    double centerOf(double y) => y
        .clamp(
          frame.bottom + labelInset + boxHeight / 2,
          frame.top - labelInset - boxHeight / 2,
        )
        .toDouble();

    const step = boxHeight + labelGap; // 위 · 아래로 옮길 한 칸 (포인트)
    var left = leftOf(right: true); // 상자 왼쪽 끝
    var centerY = centerOf(anchorY); // 상자 세로 가운데
    if (avoid != null) {
      for (final (dy, right) in <(double, bool)>[
        (0, true),
        (0, false),
        (-step, true),
        (-step, false),
        (step, true),
        (step, false),
      ]) {
        final candidate = _Box(
          left: leftOf(right: right),
          bottom: centerOf(anchorY + dy) - boxHeight / 2,
          width: boxWidth,
          height: boxHeight,
        ); // 이 자리에 둔 상자
        if (!candidate.overlaps(avoid)) {
          left = candidate.left;
          centerY = candidate.bottom + boxHeight / 2;
          break;
        }
      }
    }

    canvas
      ..setFillColor(PdfColors.white)
      ..setStrokeColor(reportPdfColor(ReportColors.chartMarker))
      ..setLineWidth(labelBorderWidth)
      ..drawRect(left, centerY - boxHeight / 2, boxWidth, boxHeight)
      ..fillAndStrokePath();
    _drawText(
      canvas,
      text: text,
      size: markerLabelSize,
      x: left + labelPadding,
      centerY: centerY,
      color: ReportColors.chartMarker,
      font: labelFont,
    );
    return _Box(
      left: left,
      bottom: centerY - boxHeight / 2,
      width: boxWidth,
      height: boxHeight,
    );
  }

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 수정: 2026-10-20 15:02:44 · nada
  /// 함수: _drawAnnotations
  /// 목적: 원본 리포트가 소음 차트에 붙이는 표시 둘을 그린다.
  ///       - 평균 자리에 가로로 긋는 붉은 점선 한 줄. 평균을 낸 운행
  ///         구간에만 긋는다(`_travelSpan()`, 원본과 같다). 구간이 없는
  ///         예전 결과는 차트 폭 전체다
  ///       - 최댓값이 나온 자리에 굵은 빨간 점(`_drawMarker()`), 그 옆에
  ///         "최대 값"(`_drawSideLabel()`). P2P 표시와 같은 규칙이다
  ///         (2026-10-15 사용자 지시). 최댓값은 운행 구간 안에서 낸 값이라
  ///         자리도 그 구간 안에서 찾는다
  ///         (`ReportChartAxes.indexInTravel()`)
  ///       값은 이 자리에서 다시 세지 않고 1쪽 표가 쓰는 지표에서 꺼낸다.
  ///       같은 값을 두 곳에서 세면 차트와 표가 다른 숫자를 말하게 된다.
  ///       그릴 것이 없는 축은 사양에 지표 이름이 없어 바로 돌아간다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       spec — 그리는 축의 사양
  ///       values — 그린 시계열
  ///       result — 지표를 낼 측정 결과
  void _drawAnnotations(
    PdfGraphics canvas,
    _ChartFrame frame,
    ChartAxisSpec spec,
    List<double> values,
    MeasurementResult result,
  ) {
    final meanKey = spec.meanKey; // 평균을 가져올 지표 이름, 없으면 null
    final peakKey = spec.peakKey; // 최댓값을 가져올 지표 이름, 없으면 null
    if (meanKey == null && peakKey == null) return;

    // → 로직 이동: ReportMetrics.from()
    final metrics = ReportMetrics.from(result); // 표에 올리는 지표 여덟 개

    canvas
      ..saveContext()
      ..drawRect(
        frame.left,
        frame.bottom,
        frame.right - frame.left,
        frame.top - frame.bottom,
      )
      ..clipPath();

    final mean = meanKey == null
        ? null
        : metrics.byKey(meanKey)?.value; // 평균 (그 축의 단위)
    if (mean != null) {
      final span = _travelSpan(frame, result); // → 로직 이동: _travelSpan()
      // → 로직 이동: _drawGuideLine()
      _drawGuideLine(canvas, span.left, span.right, frame.yOfValue(mean));
    }

    final peak = peakKey == null
        ? null
        : metrics.byKey(peakKey); // 최댓값 지표, 없으면 null
    final peakValue = peak?.value; // 최댓값 (그 축의 단위)
    // 표가 말하는 최댓값이 시계열 어디에서 나왔는지 찾는다. 못 찾으면
    // 점을 찍지 않는다 — 엉뚱한 자리에 찍고 다른 값을 적느니 비운다
    final at = peakValue == null
        ? -1
        // → 로직 이동: ReportChartAxes.indexInTravel()
        : ReportChartAxes.indexInTravel(
            values,
            peakValue,
            result,
          ); // 최댓값 자리, 없으면 -1
    if (peakValue != null && at >= 0) {
      final x = frame.xOfTime(at / result.sampleRate); // 표시점의 가로 자리
      final y = frame.yOfValue(peakValue); // 표시점의 세로 자리
      canvas.restoreContext(); // 점 · 상자는 틀 선에 걸쳐도 잘리지 않게
      _drawMarker(canvas, x, y); // → 로직 이동: _drawMarker()
      // → 로직 이동: _drawSideLabel()
      _drawSideLabel(
        canvas,
        frame,
        '최대 ${peak!.display}',
        anchorX: x,
        anchorY: y,
      );
      return;
    }

    canvas.restoreContext();
  }

  /// 작성: 2026-10-20 15:02:44 · nada
  /// 함수: _drawA95Band
  /// 목적: 진동 세 축 차트에 A95 를 붉은 가로 점선 두 줄로 표시한다. 0 을
  ///       가운데 두고 ±A95/2 높이에, 지표를 낸 운행 구간 시작부터 끝까지
  ///       길게 긋는다. 첫 줄 왼쪽 아래에 "A95" 를 적는다. 원본 리포트와
  ///       같은 모양이다. 두 줄 사이 폭이 1쪽 표의 A95 다.
  ///       진동 축이 아니거나, A95 가 없거나(예전 결과 · 구간을 못 정한
  ///       결과), 운행 구간이 없으면 긋지 않는다. 0 으로 채워 긋지 않는다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       spec — 그리는 축의 사양
  ///       result — 지표와 운행 구간을 가진 측정 결과
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf 2쪽. X 차트 점선이 ±2.4,
  ///       수직 차트가 ±1.8 로 1쪽 A95(수평 4.8 · 수직 3.6)의 절반이고, 약
  ///       6.5 ~ 40초(운행 구간)에만 그어져 있다. 2026-10-20 사용자 지시
  ///       "운행구간 점선 표시 다시 살려주자. 점선은 가로로 길게"
  void _drawA95Band(
    PdfGraphics canvas,
    _ChartFrame frame,
    ChartAxisSpec spec,
    MeasurementResult result,
  ) {
    // → 로직 이동: ReportChartAxes.a95Of()
    final a95 = ReportChartAxes.a95Of(spec, result); // 그을 A95, 없으면 null
    if (a95 == null || result.travelWindow == null) return;
    final span = _travelSpan(frame, result); // → 로직 이동: _travelSpan()
    final upper = frame.yOfValue(a95 / 2); // 위 점선 세로 자리
    final lower = frame.yOfValue(-a95 / 2); // 아래 점선 세로 자리
    for (final y in <double>[upper, lower]) {
      // → 로직 이동: _drawGuideLine()
      _drawGuideLine(canvas, span.left, span.right, y);
    }

    final width = _widthOf(a95Label, tickLabelSize); // 글자 폭
    final x = math.max(
      frame.left + labelInset,
      span.left - labelGap - width,
    ); // 글자 왼쪽 끝. 점선 시작 왼쪽에 두되 틀 밖으로 나가지 않게 한다
    final centerY = math.max(
      frame.bottom + labelInset + tickLabelSize / 2,
      lower - tickLabelSize / 2,
    ); // 글자 세로 가운데. 아래 점선 바로 밑
    // → 로직 이동: _drawText()
    _drawText(
      canvas,
      text: a95Label,
      size: tickLabelSize,
      x: x,
      centerY: centerY,
    );
  }

  /// 작성: 2026-10-20 15:02:44 · nada
  /// 함수: _travelSpan
  /// 목적: 운행 구간 점선을 그을 가로 범위를 고른다. 지표를 낸 운행 구간
  ///       (`MeasurementResult.travelWindow`)의 시작 · 끝 행 시각이고, 구간이
  ///       없는 예전 결과는 차트 폭 전체다. 틀 밖으로 나가지 않게 자른다.
  /// 인자: frame — 축 틀과 값 옮기기
  ///       result — 운행 구간과 표본 주기를 가진 측정 결과
  /// 반환: 왼쪽 · 오른쪽 끝 (포인트)
  ({double left, double right}) _travelSpan(
    _ChartFrame frame,
    MeasurementResult result,
  ) {
    final window = result.travelWindow; // 운행 구간, 예전 결과면 null
    if (window == null) return (left: frame.left, right: frame.right);
    final left = frame.xOfTime(
      window.startIndex / result.sampleRate,
    ); // 구간 시작 가로 자리
    final right = frame.xOfTime(
      window.endIndex / result.sampleRate,
    ); // 구간 끝 가로 자리
    return (
      left: left.clamp(frame.left, frame.right).toDouble(),
      right: right.clamp(frame.left, frame.right).toDouble(),
    );
  }

  /// 작성: 2026-10-20 15:02:44 · nada
  /// 함수: _drawGuideLine
  /// 목적: 붉은 가로 점선 한 줄을 긋는다. 다 그은 뒤 점선 무늬를 실선으로
  ///       되돌린다 — 무늬 설정이 남으면 다음에 긋는 선까지 점선이 된다.
  /// 인자: canvas — 그리기 도구
  ///       left, right — 선 왼쪽 · 오른쪽 끝 (포인트)
  ///       y — 선 세로 자리 (포인트)
  void _drawGuideLine(PdfGraphics canvas, double left, double right, double y) {
    canvas
      ..setStrokeColor(reportPdfColor(ReportColors.chartGuide))
      ..setLineWidth(guideLineWidth)
      ..setLineDashPattern(guideDashPattern)
      ..moveTo(left, y)
      ..lineTo(right, y)
      ..strokePath()
      ..setLineDashPattern();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _timeSpan
  /// 목적: 가로축이 담을 시간 폭을 정한다. 마지막 표본이 축 오른쪽 끝에
  ///       딱 붙으면 파형 끝이 축 틀 선에 묻히므로 여유를 둔다.
  ///
  ///       표본 수는 그리는 축의 것이 아니라 측정 전체에서 가장 긴
  ///       시계열의 것을 받는다. 축마다 제 길이로 폭을 잡으면, 마이크
  ///       권한이 꺼져 소음이 빈 측정에서 소음 차트만 다른 시간대를
  ///       그린다 — 위 세 차트가 0~45초인데 소음만 0~1초가 된다.
  /// 인자: sampleCount — 측정 전체에서 가장 긴 시계열의 표본 개수
  ///       sampleRate — 표본 주기 (Hz)
  /// 반환: 가로축이 담을 시간 폭 (초). 표본이 하나 이하면 하한을 쓴다
  /// 식: span = max(minTimeSpanSec, (sampleCount - 1) / sampleRate x
  ///     timeHeadroom)
  double _timeSpan(int sampleCount, double sampleRate) {
    if (sampleCount < 2) return minTimeSpanSec;
    final lastSecond = (sampleCount - 1) / sampleRate; // 마지막 표본의 시각
    return math.max(minTimeSpanSec, lastSecond * timeHeadroom);
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _timeTicks
  /// 목적: 가로축 눈금 시각을 0 부터 만든다. 측정 길이가 현장마다 달라
  ///       간격을 고정할 수 없으므로, 목표 칸 수로 나눈 값을 1 · 2 · 5 와
  ///       10의 거듭제곱을 곱한 수 중 그보다 크거나 같은 가장 작은 것으로
  ///       올린다. 이렇게 하면 어떤 길이에서도 눈금이 읽기 좋은 수로
  ///       떨어진다.
  /// 인자: span — 가로축이 담는 시간 폭 (초)
  /// 반환: 0 부터 `span` 을 넘지 않는 마지막 눈금까지의 시각 목록 (초)
  /// 식: rough = span / timeTickTarget
  ///     step  = 10^floor(log10(rough)) x {1, 2, 5, 10} 중 rough 이상인 최솟값
  List<double> _timeTicks(double span) {
    final rough = span / timeTickTarget; // 목표대로 나눴을 때의 거친 간격
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble(); // rough 와 자릿수가 같은 10의 거듭제곱
    final normalized = rough / magnitude; // 거친 간격을 1~10 으로 줄인 값

    var multiplier = 10.0; // 자릿수에 곱할 수. 못 고르면 자릿수를 올린다
    for (final candidate in <double>[1.0, 2.0, 5.0]) {
      if (normalized <= candidate) {
        multiplier = candidate;
        break;
      }
    }

    final step = magnitude * multiplier; // 눈금 사이 간격 (초)
    final count = span ~/ step; // 축 안에 들어가는 눈금 칸 수
    return List<double>.generate(count + 1, (i) => i * step);
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawGrid
  /// 목적: 눈금 자리마다 점선을 긋는다. 축 틀과 파형보다 먼저 그려 뒤로
  ///       깔리게 한다. 다 그린 뒤 점선 무늬를 실선으로 되돌리는 이유는,
  ///       그리기 도구의 무늬 설정이 그대로 남아 다음에 긋는 선까지
  ///       점선이 되기 때문이다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       valueTicks — 세로축 눈금 값
  ///       timeTicks — 가로축 눈금 시각 (초)
  void _drawGrid(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> valueTicks,
    List<double> timeTicks,
  ) {
    canvas
      ..setStrokeColor(reportPdfColor(ReportColors.chartGrid))
      ..setLineWidth(gridLineWidth)
      ..setLineDashPattern(gridDashPattern);

    for (final tick in valueTicks) {
      final y = frame.yOfValue(tick); // 이 눈금의 세로 자리
      canvas
        ..moveTo(frame.left, y)
        ..lineTo(frame.right, y);
    }
    for (final tick in timeTicks) {
      final x = frame.xOfTime(tick); // 이 눈금의 가로 자리
      canvas
        ..moveTo(x, frame.bottom)
        ..lineTo(x, frame.top);
    }

    canvas
      ..strokePath()
      ..setLineDashPattern();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawFrame
  /// 목적: 축 틀 네모를 긋는다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  void _drawFrame(PdfGraphics canvas, _ChartFrame frame) {
    canvas
      ..setStrokeColor(reportPdfColor(ReportColors.text))
      ..setLineWidth(frameLineWidth)
      ..drawRect(
        frame.left,
        frame.bottom,
        frame.right - frame.left,
        frame.top - frame.bottom,
      )
      ..strokePath();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawValueAxis
  /// 목적: 세로축의 눈금 표시선 · 눈금 라벨 · 축 라벨을 축 틀 왼쪽에
  ///       그린다. 축 라벨은 눈금 라벨 중 가장 넓은 것을 기준으로 더
  ///       왼쪽에 놓는다 — 그래야 어떤 범위에서도 겹치지 않는다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       ticks — 세로축 눈금 값
  ///       label — 세로로 찍을 축 라벨
  void _drawValueAxis(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> ticks,
    String label,
  ) {
    canvas
      ..setStrokeColor(reportPdfColor(ReportColors.text))
      ..setLineWidth(frameLineWidth);
    for (final tick in ticks) {
      final y = frame.yOfValue(tick); // 이 눈금의 세로 자리
      canvas
        ..moveTo(frame.left - tickLength, y)
        ..lineTo(frame.left, y);
    }
    canvas.strokePath();

    final labelRight = frame.left - tickLength - tickLabelGap; // 라벨 오른쪽 끝
    var widest = 0.0; // 눈금 라벨 중 가장 넓은 것의 너비 (포인트)
    for (final tick in ticks) {
      final text = _formatTick(tick); // 이 눈금에 찍을 문구
      final width = _widthOf(text, tickLabelSize); // 그 문구의 너비
      if (width > widest) widest = width;
      _drawText(
        canvas,
        text: text,
        size: tickLabelSize,
        x: labelRight - width,
        centerY: frame.yOfValue(tick),
      );
    }

    _drawRotatedText(
      canvas,
      text: label,
      size: axisLabelSize,
      centerX: labelRight - widest - axisLabelGap - axisLabelSize / 2,
      centerY: frame.centerY,
    );
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawTimeAxis
  /// 목적: 가로축의 눈금 표시선 · 눈금 라벨 · 축 라벨을 축 틀 아래에
  ///       그린다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       ticks — 가로축 눈금 시각 (초)
  void _drawTimeAxis(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> ticks,
  ) {
    canvas
      ..setStrokeColor(reportPdfColor(ReportColors.text))
      ..setLineWidth(frameLineWidth);
    for (final tick in ticks) {
      final x = frame.xOfTime(tick); // 이 눈금의 가로 자리
      canvas
        ..moveTo(x, frame.bottom - tickLength)
        ..lineTo(x, frame.bottom);
    }
    canvas.strokePath();

    // 눈금 라벨이 놓일 띠의 세로 한가운데. 글자 크기 한 줄만큼을 자리로
    // 잡아 두고 그 가운데에 맞춘다
    final tickLabelCenterY =
        frame.bottom - tickLength - tickLabelGap - tickLabelSize / 2;
    for (final tick in ticks) {
      final text = _formatTick(tick); // 이 눈금에 찍을 문구
      _drawText(
        canvas,
        text: text,
        size: tickLabelSize,
        x: frame.xOfTime(tick) - _widthOf(text, tickLabelSize) / 2,
        centerY: tickLabelCenterY,
      );
    }

    _drawText(
      canvas,
      text: timeAxisLabel,
      size: axisLabelSize,
      x: frame.centerX - _widthOf(timeAxisLabel, axisLabelSize) / 2,
      centerY:
          tickLabelCenterY -
          tickLabelSize / 2 -
          axisLabelGap -
          axisLabelSize / 2,
    );
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-11 15:34:38 · nada
  /// 함수: _drawSeries
  /// 목적: 파형을 꺾은선으로 얹는다.
  ///       1. 표본을 가로 픽셀 열 수만큼으로 줄인다. 0 을 미측정으로 보는
  ///          축(소음)은 0 구간에서 끊어 실측 구간만 남긴다
  ///       2. 축 틀 밖으로 나가는 부분을 잘라 낸다. 축 범위는 모든 값을
  ///          담게 고르므로 보통은 잘릴 것이 없고, 계산이 어긋났을 때 선이
  ///          옆 차트 자리까지 뻗지 않게 막는 몫이다
  ///       3. 구간마다 줄인 표본을 차례로 이어 긋는다. 구간 사이는 잇지
  ///          않는다
  ///       자르기와 선 모양 설정은 그리기 도구에 그대로 남으므로, 저장한
  ///       상태를 되돌려 다음 차트에 새지 않게 한다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       values — 그릴 시계열
  ///       columnCount — 줄일 때 나눌 칸 수. 축 틀의 가로 픽셀 수다
  ///       sampleRate — 표본 주기 (Hz)
  ///       skipZeros — 0 을 미측정으로 보고 선을 끊을지
  /// 식: t = index / sampleRate
  void _drawSeries(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> values,
    int columnCount,
    double sampleRate, {
    required bool skipZeros,
  }) {
    // → 로직 이동: reduceSeriesSegments()
    final segments = reduceSeriesSegments(
      values,
      columns: columnCount,
      skipZeros: skipZeros,
    ); // 이어 그릴 구간마다 줄인 표본

    canvas
      ..saveContext()
      ..drawRect(
        frame.left,
        frame.bottom,
        frame.right - frame.left,
        frame.top - frame.bottom,
      )
      ..clipPath()
      ..setStrokeColor(reportPdfColor(ReportColors.chartLine))
      ..setLineWidth(seriesLineWidth)
      ..setLineJoin(PdfLineJoin.miter)
      ..setLineCap(PdfLineCap.butt);

    for (final samples in segments) {
      for (var i = 0; i < samples.length; i++) {
        final x = frame.xOfTime(samples[i].index / sampleRate); // 가로 자리
        final y = frame.yOfValue(samples[i].value); // 세로 자리
        if (i == 0) {
          canvas.moveTo(x, y);
        } else {
          canvas.lineTo(x, y);
        }
      }
    }

    canvas
      ..strokePath()
      ..restoreContext();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: _drawText
  /// 목적: 글자 한 덩이를 찍는다. 세로 자리를 글자가 앉는 선이 아니라
  ///       글자 덩이의 한가운데로 받아, 눈금 자리에 맞춰 놓기 쉽게 한다.
  /// 인자: canvas — 그리기 도구
  ///       text — 찍을 문구
  ///       size — 글자 크기 (포인트)
  ///       x — 찍기 시작할 가로 자리 (포인트)
  ///       centerY — 글자 덩이의 세로 한가운데 (포인트)
  ///       color — 글자색 (0xRRGGBB). 안 주면 본문 글자색
  ///       font — 쓸 글꼴. 안 주면 눈금 · 축 라벨 글꼴(`font`)
  /// 식: baseline = centerY - (top + bottom) / 2 x size
  ///     `top` 과 `bottom` 은 글꼴이 알려 주는 글자 덩이의 아래 · 위 끝이다.
  ///     글자 크기 1 을 기준으로 한 값이라 크기를 곱해 쓴다
  void _drawText(
    PdfGraphics canvas, {
    required String text,
    required double size,
    required double x,
    required double centerY,
    int color = ReportColors.text,
    PdfFont? font,
  }) {
    final face = font ?? this.font; // 이번에 쓸 글꼴
    final metrics = face.stringMetrics(text); // 이 문구가 차지하는 넓이
    final baseline =
        centerY - (metrics.top + metrics.bottom) / 2 * size; // 글자가 앉는 선
    canvas
      ..setFillColor(reportPdfColor(color))
      ..drawString(face, size, text, x, baseline);
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawRotatedText
  /// 목적: 글자 한 덩이를 왼쪽으로 90도 돌려 세로로 찍는다. 그리기 도구에는
  ///       글자를 돌려 찍는 기능이 없어 좌표를 통째로 돌린다. 돌린 좌표가
  ///       뒤이어 그리는 것에까지 걸리면 안 되므로, 이 함수 안에서만
  ///       걸었다가 바로 되돌린다.
  /// 인자: canvas — 그리기 도구
  ///       text — 찍을 문구
  ///       size — 글자 크기 (포인트)
  ///       centerX — 돌려 세운 글자 덩이의 가로 한가운데 (포인트)
  ///       centerY — 돌려 세운 글자 덩이의 세로 한가운데 (포인트)
  /// 식: 좌표를 돌리면 글자가 나아가는 쪽이 위가 되고, 글자 덩이의 두께는
  ///     왼쪽으로 뻗는다. 그래서 옮길 자리는 아래와 같다.
  ///     tx = centerX + (top + bottom) / 2 x size
  ///     ty = centerY - 문구 너비 / 2
  void _drawRotatedText(
    PdfGraphics canvas, {
    required String text,
    required double size,
    required double centerX,
    required double centerY,
  }) {
    final metrics = font.stringMetrics(text); // 이 문구가 차지하는 넓이
    final tx = centerX + (metrics.top + metrics.bottom) / 2 * size; // 옮길 가로 자리
    final ty = centerY - metrics.advanceWidth * size / 2; // 옮길 세로 자리

    canvas
      ..saveContext()
      ..setTransform(
        Matrix4.identity()
          ..translateByDouble(tx, ty, 0.0, 1.0)
          ..rotateZ(math.pi / 2),
      )
      ..setFillColor(reportPdfColor(ReportColors.text))
      ..drawString(font, size, text, 0, 0)
      ..restoreContext();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: _widthOf
  /// 목적: 문구를 그 크기로 찍었을 때의 너비를 구한다. 가운데 맞춤과 오른쪽
  ///       맞춤, 값 상자 크기에 쓴다.
  /// 인자: text — 잴 문구
  ///       size — 글자 크기 (포인트)
  ///       face — 잴 글꼴. 안 주면 눈금 · 축 라벨 글꼴(`font`)
  /// 반환: 문구 너비 (포인트)
  double _widthOf(String text, double size, [PdfFont? face]) =>
      (face ?? font).stringMetrics(text).advanceWidth * size;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _formatTick
  /// 목적: 눈금 값을 라벨 문구로 만든다. 뒤따르는 0 과 남은 소수점을 지워
  ///       40 은 `40`, 0.25 는 `0.25` 로 찍는다. 0 자리가 아주 작은 음수로
  ///       계산돼 `-0` 이 되는 것도 `0` 으로 되돌린다.
  /// 인자: value — 눈금 값
  /// 반환: 눈금에 찍을 문구
  String _formatTick(double value) {
    var text = value.toStringAsFixed(tickLabelDecimals); // 소수 자리를 고정한 문구
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text == '-0' ? '0' : text;
  }
}

/// 작성: 2026-10-21 13:10:00 · nada
/// 클래스: _Box
/// 목적: 차트에 적은 글자 상자 하나의 자리 (포인트, PDF 좌표라 아래가 작다).
///       두 글자 상자가 겹치는지 보는 데 쓴다.
class _Box {
  /// 왼쪽 끝
  final double left;

  /// 아래 끝
  final double bottom;

  /// 가로
  final double width;

  /// 세로
  final double height;

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 함수: _Box
  /// 목적: 상자 자리를 그대로 담는다.
  /// 인자: left, bottom — 왼쪽 · 아래 끝
  ///       width, height — 가로 · 세로
  const _Box({
    required this.left,
    required this.bottom,
    required this.width,
    required this.height,
  });

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 함수: overlaps
  /// 목적: 다른 상자와 겹치는지 본다. 변이 맞닿기만 하면 겹치지 않는다.
  /// 인자: other — 견줄 상자
  /// 반환: 겹치면 true
  bool overlaps(_Box other) =>
      left < other.left + other.width &&
      other.left < left + width &&
      bottom < other.bottom + other.height &&
      other.bottom < bottom + height;
}
