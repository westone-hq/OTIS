import 'dart:math' as math;

// `Matrix4` 는 세로 라벨을 돌려 찍을 때만 쓴다. pdf 패키지가 이 자료형을
// 내보내지 않아 Flutter 가 다시 내보내는 것을 가져온다 — 이렇게 하면
// `vector_math` 를 직접 의존성에 더하지 않아도 된다
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: ChartAxisRange
/// 목적: 세로축 한 단계의 아래끝 · 위끝과 눈금 간격을 담는다. 범위가 하나로
///       고정된 축은 이 단계를 하나만 갖고, 데이터에 따라 넓어지는 축은
///       좁은 것부터 차례로 여러 개 갖는다.
class ChartAxisRange {
  /// 축 아래끝. 단위는 그 축이 그리는 값의 단위를 따른다
  final double min;

  /// 축 위끝. 단위는 `min` 과 같다
  final double max;

  /// 눈금 사이 간격. 아래끝에서 위끝까지 나머지 없이 나누어떨어져야 한다
  final double tickStep;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: toleranceRatio
  /// 목적: 데이터가 이 단계 안에 든다고 볼 때 봐주는 여유를, 축 길이에
  ///       대한 비로 둔 것.
  /// 근거: 인용 — 파이썬 프로토타입
  ///       `pdf_report_dev/tune_report/charts.py` 의 `_resolve_ylim()` 이
  ///       쓰는 값과 같다
  static const double toleranceRatio = 0.02;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ChartAxisRange
  /// 목적: 축 한 단계의 범위와 눈금 간격을 그대로 담는 생성자.
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
  /// 함수: contains
  /// 목적: 데이터가 이 단계 안에 들어가는지 본다. 위치와 속도는 가속도를
  ///       적분(잘게 나눈 값을 더해 나가는 계산)해 만든 값이라, 0 이어야
  ///       할 자리가 쌓인 오차 때문에 아주 조금 음수로 나온다. 그만한
  ///       차이로 단계를 한 칸 올리면 축이 쓸데없이 넓어져 파형이 납작해
  ///       보이므로 여유를 두고 견준다.
  /// 인자: dataMin, dataMax — 그릴 데이터의 최솟값 · 최댓값
  /// 반환: 여유를 포함해 이 단계 안에 들어가면 true
  /// 식: tol = span x toleranceRatio
  ///     min - tol <= dataMin 이고 dataMax <= max + tol
  bool contains(double dataMin, double dataMax) {
    final tolerance = span * toleranceRatio; // 이 단계에서 봐주는 여유 폭
    return min - tolerance <= dataMin && dataMax <= max + tolerance;
  }

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

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: ChartAxisSpec
/// 목적: 차트 하나가 어떤 값을 어떤 세로축에 그리는지 담는다.
class ChartAxisSpec {
  /// 축을 부르는 이름. 그릴 시계열을 고를 때 쓴다
  final String key;

  /// 세로축 옆에 세로로 찍는 라벨. 원본 리포트 표기를 그대로 쓴다
  final String label;

  /// 좁은 것부터 차례로 늘어놓은 범위 단계. 하나뿐이면 고정 축이다
  final List<ChartAxisRange> steps;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ChartAxisSpec
  /// 목적: 축 하나의 이름 · 라벨 · 범위 단계를 그대로 담는 생성자.
  /// 인자: key — 축 이름
  ///       label — 세로축 라벨
  ///       steps — 좁은 것부터 늘어놓은 범위 단계
  const ChartAxisSpec({
    required this.key,
    required this.label,
    required this.steps,
  });

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: rangeFor
  /// 목적: 데이터가 들어가는 가장 좁은 단계를 고른다.
  ///       - 데이터가 비면 가장 좁은 단계를 쓴다. 축 틀과 눈금은 그려야
  ///         해서 범위가 하나는 있어야 한다
  ///       - 어느 단계에도 안 들어가면 가장 넓은 단계를 쓴다. 그리지 않고
  ///         비우는 것보다 잘린 채로라도 보여 주는 편이 낫다
  ///       고정 축은 단계가 하나뿐이라 어느 갈래로 가도 같은 범위가 나온다.
  /// 인자: values — 그릴 값 목록
  /// 반환: 고른 범위 단계
  ChartAxisRange rangeFor(List<double> values) {
    if (values.isEmpty) return steps.first;

    var dataMin = values.first; // 지금까지 본 가장 작은 값
    var dataMax = values.first; // 지금까지 본 가장 큰 값
    for (final value in values) {
      if (value < dataMin) dataMin = value;
      if (value > dataMax) dataMax = value;
    }

    for (final step in steps) {
      if (step.contains(dataMin, dataMax)) return step;
    }
    return steps.last;
  }
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 클래스: ReportChartAxes
/// 목적: 차트 여덟 개의 축 사양을 모아 둔다. 축 범위와 눈금 간격 숫자는
///       전부 이 파일에만 있고, 그리는 쪽은 여기서 꺼내 쓴다. 범위를
///       고치려면 이 묶음만 고치면 된다.
///
///       단위는 축마다 다르다. 진동 세 축은 mg, 소음은 dBA, 위치는 m,
///       속도는 m/s, 가속도는 m/s2, 저크는 m/s3 이다.
class ReportChartAxes {
  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: x
  /// 목적: X축(가로 진동) 차트의 세로축.
  /// 근거: 미정 — 원본 리포트의 범위는 ±4 mg 인데, 그 값은 저역통과
  ///       필터(빠르게 흔들리는 성분을 깎아 내는 계산)를 거친 파형을
  ///       담기 위한 것이다. 필터를 아직 정하지 못해 지금은 거르지 않은
  ///       원시 데이터를 그리는데, 이를 원본 범위에 넣으면 표본의 8%
  ///       넘게가 축 밖으로 잘려 파형이 뭉개진다. 잘리지 않을 만큼만
  ///       임시로 넓혀 둔다. 필터가 정해지면 원본 범위로 되돌린다.
  ///       잘리는 비율은 `pdf_report_dev/tune_report/charts.py` 의
  ///       `ORIGINAL_VIBRATION_YLIM` 주석에서 옮겨 적었다
  static const ChartAxisSpec x = ChartAxisSpec(
    key: 'x',
    label: 'X-Vibration (milli-g)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: -10.0, max: 10.0, tickStep: 5.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: y
  /// 목적: Y축(가로 진동) 차트의 세로축.
  /// 근거: 미정 — 원본 리포트의 범위는 ±10 mg 다. 넓힌 이유와 되돌릴
  ///       시점은 `x` 와 같다
  static const ChartAxisSpec y = ChartAxisSpec(
    key: 'y',
    label: 'Y-Vibration (milli-g)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: -15.0, max: 15.0, tickStep: 5.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: z
  /// 목적: 수직 진동 차트의 세로축.
  /// 근거: 인용 — 원본 리포트 `docs/reference/sample_evimp.pdf` 의 수직
  ///       진동 차트 눈금이다. 이 축은 원본 그대로 쓴다
  static const ChartAxisSpec z = ChartAxisSpec(
    key: 'z',
    label: 'Vertical Vibration (milli-g)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: -20.0, max: 20.0, tickStep: 10.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: noise
  /// 목적: 소음 차트의 세로축. 단계형이다. 첫 단계를 원본 리포트와 똑같이
  ///       둬서, 조용한 운행은 원본과 같은 눈금으로 보이고 넘칠 때만
  ///       위 단계로 올라간다. 어느 단계에서나 눈금은 여덟 개다.
  /// 근거: 인용 — 첫 단계는 원본 리포트의 소음 차트 눈금이 40 부터 54 까지
  ///       2 씩 놓인 것을 그대로 옮겼다.
  ///       측정 — 위 두 단계를 더한 이유는 앱 실측이 원본 범위를 크게
  ///       넘기 때문이다. `test/fixtures/app_measurement.xlsx` 의
  ///       `noiseDba` 열은 44.8 에서 63.0 dBA 사이이고, 40~54 하나만 두면
  ///       값이 있는 표본 3,866 개 중 3,544 개(91.7%)가 축 밖으로 잘린다.
  ///       35~70 단계에서는 하나도 잘리지 않는다. 25~95 는 그보다 시끄러운
  ///       현장을 위해 한 칸 더 둔 것이다
  static const ChartAxisSpec noise = ChartAxisSpec(
    key: 'noise',
    label: 'Noise Level (dBA)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: 40.0, max: 54.0, tickStep: 2.0),
      ChartAxisRange(min: 35.0, max: 70.0, tickStep: 5.0),
      ChartAxisRange(min: 25.0, max: 95.0, tickStep: 10.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: position
  /// 목적: 누적 이동량 차트의 세로축. 운행 거리가 현장마다 크게 달라
  ///       단계형으로 둔다.
  /// 근거: 인용 — 파이썬 프로토타입 `charts.py` 의 `AXES` 위치 축 단계와
  ///       같다. 눈금 간격은 어느 단계에서도 눈금이 다섯 칸을 넘지 않게
  ///       맞췄다 — 차트 높이가 낮아 그보다 촘촘하면 라벨이 겹친다
  static const ChartAxisSpec position = ChartAxisSpec(
    key: 'pos',
    label: 'pos (m)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: 0.0, max: 10.0, tickStep: 2.0),
      ChartAxisRange(min: 0.0, max: 25.0, tickStep: 5.0),
      ChartAxisRange(min: 0.0, max: 50.0, tickStep: 10.0),
      ChartAxisRange(min: 0.0, max: 100.0, tickStep: 20.0),
      ChartAxisRange(min: 0.0, max: 150.0, tickStep: 30.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: speed
  /// 목적: 속도 차트의 세로축. 기종마다 정격 속도가 달라 단계형으로 둔다.
  /// 근거: 인용 — 프로토타입 `charts.py` 의 `AXES` 속도 축 단계와 같다
  static const ChartAxisSpec speed = ChartAxisSpec(
    key: 'vel',
    label: 'vel (m/s)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: 0.0, max: 1.0, tickStep: 0.2),
      ChartAxisRange(min: 0.0, max: 2.0, tickStep: 0.5),
      ChartAxisRange(min: 0.0, max: 4.0, tickStep: 1.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: accel
  /// 목적: 수직 가속도 차트의 세로축. 단계형이다.
  /// 근거: 인용 — 프로토타입 `charts.py` 의 `AXES` 가속도 축 단계와 같다
  static const ChartAxisSpec accel = ChartAxisSpec(
    key: 'acc',
    label: 'acc (m/s^2)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: -0.6, max: 0.6, tickStep: 0.3),
      ChartAxisRange(min: -1.0, max: 1.0, tickStep: 0.5),
      ChartAxisRange(min: -2.0, max: 2.0, tickStep: 1.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 변수: jerk
  /// 목적: 저크(가속도가 얼마나 빠르게 변하는지) 차트의 세로축. 단계형이다.
  /// 근거: 인용 — 프로토타입 `charts.py` 의 `AXES` 저크 축 단계와 같다
  /// 미구현: 저크는 거르지 않은 가속도를 그대로 미분해 만든 값이라 빠르게
  ///       흔들리는 성분이 남아 있다. 원본 리포트의 저크 곡선은 저역통과
  ///       필터를 거친 뒤 미분한 것이라 훨씬 매끈하다. 이 차트는 지금
  ///       모양만 참고할 수 있고, X · Y 진동 축과 함께 필터가 정해질 때
  ///       같이 정리한다
  static const ChartAxisSpec jerk = ChartAxisSpec(
    key: 'jerk',
    label: 'jerk (m/s^3)',
    steps: <ChartAxisRange>[
      ChartAxisRange(min: -0.5, max: 0.5, tickStep: 0.25),
      ChartAxisRange(min: -1.5, max: 1.5, tickStep: 0.5),
      ChartAxisRange(min: -3.0, max: 3.0, tickStep: 1.0),
    ],
  );

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: seriesOf
  /// 목적: 축 사양에 맞는 시계열을 측정 결과에서 꺼낸다. 어떤 축이 어떤
  ///       시계열을 그리는지 정하는 곳을 한 군데로 둔다.
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
  if (values.length <= columns * 2) {
    return List<ChartSample>.generate(
      values.length,
      (index) => ChartSample(index, values[index]),
    );
  }

  final reduced = <ChartSample>[]; // 칸마다 최대 두 점씩 담을 결과
  for (var column = 0; column < columns; column++) {
    final start = values.length * column ~/ columns; // 이 칸의 첫 자리
    final end = values.length * (column + 1) ~/ columns; // 다음 칸의 첫 자리
    // 표본이 칸 수의 두 배를 넘을 때만 여기까지 오므로 빈 칸은 생기지
    // 않는다. 도달하지 않을 갈래를 두는 대신 확인만 해 둔다
    assert(start < end, '표본보다 칸이 많아 빈 칸이 생겼다');

    var minIndex = start; // 이 칸에서 가장 작은 값의 자리
    var maxIndex = start; // 이 칸에서 가장 큰 값의 자리
    for (var index = start + 1; index < end; index++) {
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

  /// 격자 점선의 켠 길이와 끈 길이 (포인트)
  static const List<double> gridDashPattern = <double>[1.2, 1.2];

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
  /// 변수: tickLabelDecimals
  /// 목적: 눈금 라벨을 만들 때 일단 남길 소수 자리 수. 뒤따르는 0 은
  ///       지우므로 실제로 찍히는 자리 수는 이보다 적을 수 있다.
  /// 근거: 측정 — 축 단계에 쓰는 간격 중 가장 잘게 나뉜 것이 저크의
  ///       0.25 라 두 자리면 모든 눈금이 정확히 표기된다
  static const int tickLabelDecimals = 2;

  /// 눈금 라벨과 축 라벨에 쓰는 글꼴
  final PdfFont font;

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: ReportChartRenderer
  /// 목적: 글자를 찍는 데 쓸 글꼴을 담는 생성자.
  /// 인자: font — 눈금 라벨과 축 라벨에 쓸 글꼴
  const ReportChartRenderer({required this.font});

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: draw
  /// 목적: 차트 한 개를 주어진 자리에 그린다. 순서대로 한다.
  ///       1. 그릴 시계열을 꺼내고, 거기에 맞는 세로축 범위를 고른다
  ///       2. 축 틀 · 격자 · 눈금 · 라벨을 그린다
  ///       3. 시계열이 비어 있지 않으면 파형을 얹는다
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
      timeSpanSec: _timeSpan(values.length, result.sampleRate),
    ); // 이 차트의 축 틀과 값 옮기기
    final valueTicks = range.ticks(); // 세로축 눈금 값
    final timeTicks = _timeTicks(frame.timeSpanSec); // 가로축 눈금 시각 (초)

    _drawGrid(canvas, frame, valueTicks, timeTicks);
    _drawFrame(canvas, frame);
    _drawValueAxis(canvas, frame, valueTicks, spec.label);
    _drawTimeAxis(canvas, frame, timeTicks);
    if (values.isNotEmpty) {
      _drawSeries(canvas, frame, values, box.width, result.sampleRate);
    }
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _timeSpan
  /// 목적: 가로축이 담을 시간 폭을 정한다. 마지막 표본이 축 오른쪽 끝에
  ///       딱 붙으면 파형 끝이 축 틀 선에 묻히므로 여유를 둔다.
  /// 인자: sampleCount — 표본 개수
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
  /// 함수: _drawSeries
  /// 목적: 파형을 꺾은선으로 얹는다.
  ///       1. 표본을 가로 픽셀 열 수만큼으로 줄인다
  ///       2. 축 틀 밖으로 나가는 부분을 잘라 낸다. 고른 단계보다 큰 값이
  ///          섞여 있으면 선이 옆 차트 자리까지 뻗기 때문이다
  ///       3. 줄인 표본을 차례로 이어 긋는다
  ///       자르기와 선 모양 설정은 그리기 도구에 그대로 남으므로, 저장한
  ///       상태를 되돌려 다음 차트에 새지 않게 한다.
  /// 인자: canvas — 그리기 도구
  ///       frame — 축 틀과 값 옮기기
  ///       values — 그릴 시계열
  ///       columnCount — 줄일 때 나눌 칸 수. 축 틀의 가로 픽셀 수다
  ///       sampleRate — 표본 주기 (Hz)
  /// 식: t = index / sampleRate
  void _drawSeries(
    PdfGraphics canvas,
    _ChartFrame frame,
    List<double> values,
    int columnCount,
    double sampleRate,
  ) {
    // → 로직 이동: reduceSeries()
    final samples = reduceSeries(values, columns: columnCount); // 줄인 표본

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

    for (var i = 0; i < samples.length; i++) {
      final x = frame.xOfTime(samples[i].index / sampleRate); // 표본의 가로 자리
      final y = frame.yOfValue(samples[i].value); // 표본의 세로 자리
      if (i == 0) {
        canvas.moveTo(x, y);
      } else {
        canvas.lineTo(x, y);
      }
    }

    canvas
      ..strokePath()
      ..restoreContext();
  }

  /// 작성: 2026-09-17 10:05:00 · nada
  /// 함수: _drawText
  /// 목적: 글자 한 덩이를 찍는다. 세로 자리를 글자가 앉는 선이 아니라
  ///       글자 덩이의 한가운데로 받아, 눈금 자리에 맞춰 놓기 쉽게 한다.
  /// 인자: canvas — 그리기 도구
  ///       text — 찍을 문구
  ///       size — 글자 크기 (포인트)
  ///       x — 찍기 시작할 가로 자리 (포인트)
  ///       centerY — 글자 덩이의 세로 한가운데 (포인트)
  /// 식: baseline = centerY - (top + bottom) / 2 x size
  ///     `top` 과 `bottom` 은 글꼴이 알려 주는 글자 덩이의 아래 · 위 끝이다.
  ///     글자 크기 1 을 기준으로 한 값이라 크기를 곱해 쓴다
  void _drawText(
    PdfGraphics canvas, {
    required String text,
    required double size,
    required double x,
    required double centerY,
  }) {
    final metrics = font.stringMetrics(text); // 이 문구가 차지하는 넓이
    final baseline =
        centerY - (metrics.top + metrics.bottom) / 2 * size; // 글자가 앉는 선
    canvas
      ..setFillColor(reportPdfColor(ReportColors.text))
      ..drawString(font, size, text, x, baseline);
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
  /// 함수: _widthOf
  /// 목적: 문구를 그 크기로 찍었을 때의 너비를 구한다. 가운데 맞춤과 오른쪽
  ///       맞춤에 쓴다.
  /// 인자: text — 잴 문구
  ///       size — 글자 크기 (포인트)
  /// 반환: 문구 너비 (포인트)
  double _widthOf(String text, double size) =>
      font.stringMetrics(text).advanceWidth * size;

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
