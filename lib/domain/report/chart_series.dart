import 'dart:math' as math;

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 클래스: ChartSample
/// 목적: 줄이기를 거쳐 남은 표본 하나. 값과 함께 원래 시계열에서의 자리를
///       갖는다 — 가로 자리를 시각으로 되돌리려면 자리 번호가 있어야 한다.
class ChartSample {
  /// 원래 시계열에서의 자리 번호 (0 부터)
  final int index;

  /// 그 자리의 값. 단위는 그 시계열의 단위를 따른다
  final double value;

  /// 작성: 2026-09-17 10:05:00 · 박건준
  /// 함수: ChartSample
  /// 목적: 표본 하나의 자리와 값을 그대로 담는 생성자.
  /// 인자: index — 원래 시계열에서의 자리 번호
  ///       value — 그 자리의 값
  const ChartSample(this.index, this.value);
}

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 수정: 2026-10-11 15:34:38 · 박건준
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

/// 작성: 2026-10-11 15:34:38 · 박건준
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

/// 작성: 2026-10-11 15:34:38 · 박건준
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
