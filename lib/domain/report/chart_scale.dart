import 'dart:math' as math;

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-10 11:38:05 · nada
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
  /// 변수: toleranceRatio
  /// 목적: 데이터가 이 범위 안에 든다고 볼 때 봐주는 여유를, 축 길이에
  ///       대한 비로 둔 것.
  /// 근거: 인용 — 파이썬 프로토타입
  ///       `pdf_report_dev/tune_report/charts.py` 의 `_resolve_ylim()` 이
  ///       쓰는 값과 같다
  static const double toleranceRatio = 0.02;

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

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 함수: tolerance
  /// 목적: 이 범위에서 봐주는 여유 폭. 단위는 `min` 과 같다.
  double get tolerance => span * toleranceRatio;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 수정: 2026-10-10 11:38:05 · nada
  /// 함수: contains
  /// 목적: 데이터가 이 범위 안에 들어가는지 본다. 위치와 속도는 가속도를
  ///       적분(잘게 나눈 값을 더해 나가는 계산)해 만든 값이라, 0 이어야
  ///       할 자리가 쌓인 오차 때문에 아주 조금 음수로 나온다. 그만한
  ///       차이로 축을 넓히면 파형이 쓸데없이 납작해 보이므로 여유를 두고
  ///       견준다.
  /// 인자: dataMin, dataMax — 그릴 데이터의 최솟값 · 최댓값
  /// 반환: 여유를 포함해 이 범위 안에 들어가면 true
  /// 식: min - tolerance <= dataMin 이고 dataMax <= max + tolerance
  bool contains(double dataMin, double dataMax) =>
      min - tolerance <= dataMin && dataMax <= max + tolerance;

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
/// 클래스: ChartScaleKind
/// 목적: 데이터에 맞춰 넓힐 때 축을 어떤 모양으로 넓히는지.
///       - `symmetric` — 0 을 가운데 둔다. 위아래로 흔들리는 진동 ·
///         가속도 · 저크. 위로 큰 값과 아래로 큰 값을 같은 눈으로 견주게
///         한다
///       - `zeroAnchored` — 0 을 한쪽 끝으로 둔다. 위치 · 속도. 정지가
///         축 끝에 붙어 있어야 운행이 어디까지 갔는지 읽힌다. 값이 음수
///         쪽에 있으면 0 이 위끝이 된다. 속도는 부호를 지우지 않아
///         (`MeasurementAssembler._deriveKinematics()`) 운행 방향 한쪽이
///         음수로 나온다
/// 근거: 미확인 — 상승 · 하강 중 어느 쪽 속도가 음수인지는 실측으로
///       확인하지 않았다. 이 파일은 부호만 보고 방향은 가리지 않는다
///       - `free` — 데이터 최소 · 최대에 맞춘다. 소음. 0 dBA 부터 그리면
///         파형이 위쪽 띠에 납작하게 붙는다
enum ChartScaleKind { symmetric, zeroAnchored, free }

/// 작성: 2026-10-10 11:38:05 · nada
/// 클래스: ChartScale
/// 목적: 차트 하나의 세로축 범위를 데이터에 맞춰 정하는 규칙. 순서대로
///       정한다.
///       1. 그릴 값이 없으면 최소 범위를 그대로 쓴다. 축 틀과 눈금은
///          그려야 해서 범위가 하나는 있어야 한다
///       2. 값이 최소 범위 안에 들면 최소 범위를 그대로 쓴다. 조용한
///          운행은 원본 TUNE 리포트와 같은 눈금으로 보인다
///       3. 넘치면 데이터 양 끝에 여유를 더하고 최소 범위와 합친 뒤, 눈금
///          간격에 맞춰 바깥으로 반올림한다. 잘리는 값이 없게 하는 것이
///          목적이다
///
///       숫자(여유 비 · 눈금 칸 수 · 간격 후보)는 이 클래스 상수에만 둔다.
class ChartScale {
  /// 데이터가 이 안에 들면 그대로 쓰고, 넘쳐도 이보다 좁아지지 않는 범위.
  /// `zeroAnchored` 축은 0 이상 쪽으로 적고, 값이 음수 쪽이면 뒤집어 쓴다
  final ChartAxisRange minimum;

  /// 넘칠 때 넓히는 모양
  final ChartScaleKind kind;

  /// 값 0 을 미측정으로 보고 범위 계산에서 뺄지. 소음이 그렇다 — 마이크
  /// 창이 차기 전이나 권한이 없을 때 0 으로 들어온다
  final bool ignoreZeros;

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 변수: headroomRatio
  /// 목적: 넓힐 때 데이터 양 끝에 하나씩 더하는 여유를, 데이터가 차지하는
  ///       폭에 대한 비로 둔 것. 양 끝을 합치면 10% 다.
  /// 근거: 인용 — 2026-10-10 사용자 지시 "축 길이의 10%"
  static const double headroomRatio = 0.05;

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

    // → 로직 이동: _floorFor()
    final floor = _floorFor(low, high); // 이 데이터에 쓸 최소 범위
    if (floor.contains(low, high)) return floor;

    // → 로직 이동: _paddedBounds()
    final padded = _paddedBounds(low, high, floor.tolerance); // 여유를 더한 끝
    // → 로직 이동: _niceRange()
    return _niceRange(
      math.min(padded.low, floor.min),
      math.max(padded.high, floor.max),
    );
  }

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 함수: _floorFor
  /// 목적: 이 데이터에 견줄 최소 범위를 고른다. `zeroAnchored` 축에서 값이
  ///       음수 쪽에 있으면 최소 범위를 0 아래로 뒤집는다 — 음수 쪽으로
  ///       나오는 방향의 속도가 그렇다. 뒤집지 않으면 0 위쪽 빈 칸이 축
  ///       절반을 차지한다.
  /// 인자: low, high — 그릴 값의 최솟값 · 최댓값
  /// 반환: 견줄 최소 범위
  ChartAxisRange _floorFor(double low, double high) {
    if (kind != ChartScaleKind.zeroAnchored || -low <= high) return minimum;
    return ChartAxisRange(
      min: -minimum.max,
      max: -minimum.min,
      tickStep: minimum.tickStep,
    );
  }

  /// 작성: 2026-10-10 11:38:05 · nada
  /// 함수: _paddedBounds
  /// 목적: 넓힐 축의 양 끝을 모양에 맞춰 잡고 여유를 더한다.
  ///       - `symmetric` — 큰 쪽 절댓값으로 위아래를 같게 잡는다
  ///       - `zeroAnchored` — 0 을 한쪽 끝으로 잡는다. 반대쪽으로 여유
  ///         폭(`tolerance`)보다 작게 넘은 값은 적분 오차로 보고 0 에
  ///         붙인다. 그 쪽에는 여유를 더하지 않는다
  ///       - `free` — 데이터 최소 · 최대 그대로 잡는다
  /// 인자: low, high — 그릴 값의 최솟값 · 최댓값
  ///       tolerance — 최소 범위가 봐주는 여유 폭
  /// 반환: 여유를 더한 아래끝 · 위끝
  /// 식: pad = (위끝 - 아래끝) x headroomRatio, 0 에 붙인 끝에는 더하지 않는다
  ({double low, double high}) _paddedBounds(
    double low,
    double high,
    double tolerance,
  ) {
    switch (kind) {
      case ChartScaleKind.symmetric:
        final peak = math.max(low.abs(), high.abs()); // 큰 쪽 절댓값
        final pad = 2 * peak * headroomRatio; // 한쪽 끝에 더할 여유
        return (low: -(peak + pad), high: peak + pad);
      case ChartScaleKind.zeroAnchored:
        final bottom = low < -tolerance ? low : 0.0; // 0 에 붙인 아래끝
        final top = high > tolerance ? high : 0.0; // 0 에 붙인 위끝
        final pad = (top - bottom) * headroomRatio; // 한쪽 끝에 더할 여유
        return (
          low: bottom == 0.0 ? 0.0 : bottom - pad,
          high: top == 0.0 ? 0.0 : top + pad,
        );
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
