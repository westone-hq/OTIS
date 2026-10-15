import 'dart:math' as math;

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-11 15:34:38 · nada
/// 클래스: ChartAxisRange
/// 목적: 세로축 하나의 아래끝 · 위끝과 눈금 간격을 담는다. 리포트
///       차트(`report_chart.dart`)와 결과 화면 그래프가 같은 범위를 쓰도록
///       그리기 도구에 기대지 않는 이 파일에 둔다.
class ChartAxisRange {
  /// 축 아래끝. 단위는 그 축이 그리는 값의 단위를 따른다
  final double min;

  /// 축 위끝. 단위는 `min` 과 같다
  final double max;

  /// 눈금 사이 간격. 아래끝에서 위끝까지 나머지 없이 나누어떨어져야 한다
  final double tickStep;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ChartAxisRange
  /// 목적: 축 범위와 눈금 간격을 그대로 담는 생성자.
  /// 인자: min, max — 축 아래끝 · 위끝
  ///       tickStep — 눈금 사이 간격
  const ChartAxisRange({
    required this.min,
    required this.max,
    required this.tickStep,
  });

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: span
  /// 목적: 축 아래끝에서 위끝까지의 길이.
  double get span => max - min;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-11 15:34:38 · nada
  /// 함수: contains
  /// 목적: 값이 이 범위 안에 들어가는지 본다. 범위 끝을 조금이라도 넘으면
  ///       밖으로 본다 — 안으로 봐주면 그 값이 축 틀에 눌려 잘린다.
  ///       2026-10-10 검증에서 축 길이 2% 를 봐주던 판정
  ///       (`toleranceRatio`, 지웠다) 때문에 실측 정속 1.005 m/s 가
  ///       0 ~ 1 m/s 축 위 틀선에 눌렸다. 그 여유는 적분 오차로 0 아래로
  ///       살짝 내려가는 위치 · 속도 때문에 두었는데, 이제 속도는 크기를
  ///       그리고 위치는 누적 크기라 0 아래 값이 없다.
  /// 인자: dataMin, dataMax — 견줄 값의 최솟값 · 최댓값
  /// 반환: 범위 안에 들어가면 true
  /// 식: min <= dataMin 이고 dataMax <= max
  bool contains(double dataMin, double dataMax) =>
      min <= dataMin && dataMax <= max;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ticks
  /// 목적: 눈금 값을 아래끝부터 차례로 만든다. 간격을 거듭 더하지 않고
  ///       번호에 곱해 더하는 이유는, 0.2 처럼 이진수로 딱 떨어지지 않는
  ///       간격을 거듭 더하면 오차가 쌓여 마지막 눈금이 위끝에서 벗어나기
  ///       때문이다.
  /// 반환: 아래끝부터 위끝까지의 눈금 값 목록
  /// 식: tick_i = min + i x tickStep,  i = 0 .. round(span / tickStep)
  List<double> ticks() {
    final count = (span / tickStep).round(); // 눈금이 나누는 칸 수
    return List<double>.generate(count + 1, (i) => min + i * tickStep);
  }
}

/// 작성: 2026-10-10 11:38:05 · nada
/// 수정: 2026-10-11 19:20:58 · nada
/// 클래스: ChartScaleKind
/// 목적: 데이터에 맞춰 넓힐 때 축을 어떤 모양으로 넓히는지.
///       - `symmetric` — 0 을 가운데 둔다. 위아래로 흔들리는 진동 ·
///         가속도 · 저크. 위로 큰 값과 아래로 큰 값을 같은 눈으로 견주게
///         한다
///       - `zeroAnchored` — 0 을 아래끝으로 둔다. 위치 · 속도(크기).
///         정지가 축 바닥에 붙어 있어야 운행이 어디까지 갔는지 읽힌다
///       - `free` — 데이터 최소 · 최대에 맞춘다. 소음. 0 dBA 부터 그리면
///         파형이 위쪽 띠에 납작하게 붙는다. 넓힐 때 최소 범위의 자리가
///         아니라 폭만 지킨다 — 70 ~ 90 dBA 현장이 40 dBA 까지 끌려 내려가
///         파형이 위쪽에 납작해지지 않게 한다(2026-10-11 사용자 결정)
enum ChartScaleKind { symmetric, zeroAnchored, free }

/// 작성: 2026-10-10 11:38:05 · nada
/// 수정: 2026-10-11 19:20:58 · nada
/// 클래스: ChartScale
/// 목적: 차트 하나의 세로축 범위를 데이터에 맞춰 정하는 규칙. 순서대로
///       정한다.
///       1. 그릴 값이 없으면 최소 범위를 그대로 쓴다. 축 틀과 눈금은
///          그려야 해서 범위가 하나는 있어야 한다
///       2. 데이터 양 끝에 여유를 더한다. 값이 축 끝에 닿으면 읽기
///          어렵다(2026-10-11 사용자 지시 "여유는 늘 둔다")
///       3. 여유를 더한 범위가 최소 범위 안에 들면 최소 범위를 그대로
///          쓴다. 조용한 운행은 원본 TUNE 리포트와 같은 눈금으로 보인다
///       4. 넘치면 넓힌다. `symmetric` · `zeroAnchored` 는 최소 범위와
///          합치고, `free` 는 데이터만으로 잡되 폭이 최소 범위 폭보다
///          좁으면 가운데를 지킨 채 그 폭까지 넓힌다. 그 뒤 눈금 간격에
///          맞춰 바깥으로 반올림한다. 잘리는 값이 없게 하는 것이 목적이다
///
///       숫자(여유 비 · 눈금 칸 수 · 간격 후보)는 이 클래스 상수에만 둔다.
class ChartScale {
  /// 여유를 더한 데이터가 이 안에 들면 그대로 쓰고, 넘쳐도 이보다
  /// 좁아지지 않는 범위
  final ChartAxisRange minimum;

  /// 넘칠 때 넓히는 모양
  final ChartScaleKind kind;

  /// 값 0 을 미측정으로 보고 범위 계산에서 뺄지. 소음이 그렇다 — 마이크
  /// 창이 차기 전이나 권한이 없을 때 0 으로 들어온다
  final bool ignoreZeros;

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 수정: 2026-10-11 19:20:58 · nada
  /// 변수: headroomRatio
  /// 목적: 데이터 양 끝에 하나씩 더하는 여유를, 데이터가 차지하는 폭에
  ///       대한 비로 둔 것. 양 끝을 합치면 20% 다. 최소 범위를 쓸 때도
  ///       이 여유가 들어가는지 본다.
  /// 근거: 인용 — 2026-10-11 사용자 결정 — 넉넉하게. 처음 5% 에서는 가장
  ///       좁은 여유가 축 길이의 4.7% 라 선이 틀선에 붙어 보였다
  static const double headroomRatio = 0.10;

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 변수: maxTickCells
  /// 목적: 넓힌 축의 눈금이 나누는 칸 수의 상한.
  /// 근거: 인용 — 2026-10-10 사용자 지시. 차트 높이가 198 픽셀로 낮아
  ///       그보다 촘촘하면 눈금 라벨이 겹친다
  static const int maxTickCells = 6;

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 변수: stepMantissas
  /// 목적: 눈금 간격 후보. 이 수에 10 의 거듭제곱을 곱한 것만 쓴다 —
  ///       눈금 라벨이 읽기 좋은 수로 떨어진다. 작은 것부터 늘어놓는다.
  /// 근거: 인용 — 2026-10-10 사용자 지시 "1 · 2 · 2.5 · 5 × 10^n"
  static const List<double> stepMantissas = <double>[1.0, 2.0, 2.5, 5.0];

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 변수: _roundingSlack
  /// 목적: 값을 눈금 간격으로 나눈 몫을 올림 · 내림할 때 봐주는 차이.
  ///       20 / 0.2 가 100.00000000000001 로 계산돼 한 칸 더 올라가는
  ///       것처럼, 이진수로 딱 떨어지지 않는 간격에서 생기는 오차를 덮는다.
  /// 근거: 표준 — 배정도 실수의 상대 오차는 1e-16 수준이라 1e-9 는
  ///       오차보다 충분히 크고 실제 값 차이보다 충분히 작다
  static const double _roundingSlack = 1e-9;

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 함수: ChartScale
  /// 목적: 축 하나의 최소 범위와 넓히는 모양을 그대로 담는 생성자.
  /// 인자: minimum — 최소 범위
  ///       kind — 넓히는 모양
  ///       ignoreZeros — 0 을 미측정으로 볼지. 기본 false
  const ChartScale({
    required this.minimum,
    required this.kind,
    this.ignoreZeros = false,
  });

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 수정: 2026-10-11 19:20:58 · nada
  /// 함수: rangeFor
  /// 목적: 그릴 값에 맞는 세로축 범위를 정한다. 순서는 클래스 주석과 같다.
  /// 인자: values — 그릴 값 목록. 단위는 그 축의 단위를 따른다
  /// 반환: 모든 값이 들어가는 범위. 값이 없으면 최소 범위
  ChartAxisRange rangeFor(List<double> values) {
    double? low; // 여기까지 본 가장 작은 값, 아직 없으면 null
    double? high; // 여기까지 본 가장 큰 값, 아직 없으면 null
    for (final value in values) {
      if (ignoreZeros && value == 0.0) continue;
      if (low == null || value < low) low = value;
      if (high == null || value > high) high = value;
    }
    if (low == null || high == null) return minimum;

    // → 로직 이동: _paddedBounds()
    final padded = _paddedBounds(low, high); // 여유를 더한 아래끝 · 위끝
    // → 로직 이동: ChartAxisRange.contains()
    if (minimum.contains(padded.low, padded.high)) return minimum;

    if (kind == ChartScaleKind.free) {
      final center = (padded.low + padded.high) / 2; // 데이터 가운데
      final half = math.max(
        (padded.high - padded.low) / 2,
        minimum.span / 2,
      ); // 폭의 절반. 최소 범위 폭보다 좁아지지 않는다
      // → 로직 이동: _niceRange()
      return _niceRange(center - half, center + half);
    }
    // → 로직 이동: _niceRange()
    return _niceRange(
      math.min(padded.low, minimum.min),
      math.max(padded.high, minimum.max),
    );
  }

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 수정: 2026-10-11 15:34:38 · nada
  /// 함수: _paddedBounds
  /// 목적: 축의 양 끝을 모양에 맞춰 잡고 여유를 더한다.
  ///       - `symmetric` — 큰 쪽 절댓값으로 위아래를 같게 잡는다
  ///       - `zeroAnchored` — 아래끝은 0 이다. 0 아래 값이 들어오면(그릴
  ///         값이 크기라 생기지 않는다) 잘리지 않게 그만큼 내리고 여유를
  ///         더한다
  ///       - `free` — 데이터 최소 · 최대 그대로 잡는다
  /// 인자: low, high — 그릴 값의 최솟값 · 최댓값
  /// 반환: 여유를 더한 아래끝 · 위끝
  /// 식: pad = (위끝 - 아래끝) x headroomRatio, 0 인 아래끝에는 더하지 않는다
  ({double low, double high}) _paddedBounds(double low, double high) {
    switch (kind) {
      case ChartScaleKind.symmetric:
        final peak = math.max(low.abs(), high.abs()); // 큰 쪽 절댓값
        final pad = 2 * peak * headroomRatio; // 한쪽 끝에 더할 여유
        return (low: -(peak + pad), high: peak + pad);
      case ChartScaleKind.zeroAnchored:
        final bottom = math.min(low, 0.0); // 0 이거나 그보다 아래인 아래끝
        final top = math.max(high, 0.0); // 0 이거나 그보다 위인 위끝
        final pad = (top - bottom) * headroomRatio; // 한쪽 끝에 더할 여유
        return (low: bottom < 0.0 ? bottom - pad : 0.0, high: top + pad);
      case ChartScaleKind.free:
        final pad = (high - low) * headroomRatio; // 한쪽 끝에 더할 여유
        return (low: low - pad, high: high + pad);
    }
  }

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 함수: _niceRange
  /// 목적: 아래끝 · 위끝을 품는 범위 중 눈금 간격이 읽기 좋은 수로
  ///       떨어지는 것을 고른다. 간격 후보를 작은 것부터 대 보고, 끝을
  ///       간격의 배수로 바깥으로 반올림했을 때 칸 수가 상한 안에 드는 첫
  ///       간격을 쓴다 — 칸이 많을수록 파형을 읽기 쉬워서다.
  ///       `symmetric` 축은 위아래 칸 수를 같게 맞춰 0 이 늘 가운데
  ///       눈금에 오게 한다.
  /// 인자: low, high — 품어야 할 아래끝 · 위끝. `low` < `high`
  /// 반환: 끝이 눈금 간격의 배수인 범위
  /// 식: magnitude = 10^floor(log10((high - low) / maxTickCells))
  ///     step = magnitude x m,  m 은 `stepMantissas` 를 차례로, 다 안 되면
  ///     magnitude 를 10 배 해 다시
  ///     아래 칸 번호 = floor(low / step), 위 칸 번호 = ceil(high / step)
  ChartAxisRange _niceRange(double low, double high) {
    // 넓힐 때만 여기로 오고, 넓힌 범위는 최소 범위를 품으므로 폭이 0
    // 이하가 될 수 없다. 도달하지 않을 갈래 대신 확인만 해 둔다
    assert(low < high, '넓힐 범위의 폭이 0 이하다: $low ~ $high');

    final rough = (high - low) / maxTickCells; // 칸을 다 썼을 때의 간격
    var magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble(); // rough 와 자릿수가 같은 10의 거듭제곱
    while (true) {
      for (final mantissa in stepMantissas) {
        final step = magnitude * mantissa; // 대 볼 눈금 간격
        final top = (high / step - _roundingSlack).ceil(); // 위끝 칸 번호
        final bottom = kind == ChartScaleKind.symmetric
            ? -top
            : (low / step + _roundingSlack).floor(); // 아래끝 칸 번호
        if (top - bottom <= maxTickCells) {
          return ChartAxisRange(
            min: bottom * step,
            max: top * step,
            tickStep: step,
          );
        }
      }
      magnitude *= 10;
    }
  }
}

/// 작성: 2026-10-11 19:20:58 · nada
/// 수정: 2026-10-15 16:50:04 · nada
/// 함수: extremeIndices
/// 목적: 시계열에서 최댓값과 최솟값이 처음 나온 자리를 찾는다. 운행 구간이
///       없는 예전 결과(P2P 가 최대 − 최소였던 때)의 차트에서 P2P 를 만든 두
///       지점을 표시하는 데 쓴다. 새 결과는 `HalfCycle.maximum()` 의 두
///       자리를 쓴다(`ReportChartAxes.peakToPeakPair()`). 표시는 줄이기
///       (`reduceSeries()`) 전 원래 자리 번호로 잡아야 시각이 맞는다. 같은
///       값이 여러 곳이면 첫 번째다. 리포트 차트와 결과 화면 그래프가 함께
///       쓰도록 그리기 도구에 기대지 않는 이 파일에 둔다.
/// 인자: values — 원래 시계열
/// 반환: 최댓값 자리와 최솟값 자리 (0 부터). 비어 있으면 null
({int maxIndex, int minIndex})? extremeIndices(List<double> values) {
  if (values.isEmpty) return null;
  var maxIndex = 0; // 여기까지 본 가장 큰 값의 자리
  var minIndex = 0; // 여기까지 본 가장 작은 값의 자리
  for (var index = 1; index < values.length; index++) {
    if (values[index] > values[maxIndex]) maxIndex = index;
    if (values[index] < values[minIndex]) minIndex = index;
  }
  return (maxIndex: maxIndex, minIndex: minIndex);
}
