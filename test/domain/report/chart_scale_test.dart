import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';

/// 작성: 2026-10-10 11:38:05 · nada
/// 변수: _vibrationX
/// 목적: 원본 리포트 X 진동 범위(±4 mg, 눈금 2)를 최소로 둔 대칭 축.
const ChartScale _vibrationX = ChartScale(
  minimum: ChartAxisRange(min: -4.0, max: 4.0, tickStep: 2.0),
  kind: ChartScaleKind.symmetric,
);

/// 작성: 2026-10-10 11:38:05 · nada
/// 변수: _vibrationZ
/// 목적: 원본 리포트 수직 진동 범위(±20 mg, 눈금 10)를 최소로 둔 대칭 축.
const ChartScale _vibrationZ = ChartScale(
  minimum: ChartAxisRange(min: -20.0, max: 20.0, tickStep: 10.0),
  kind: ChartScaleKind.symmetric,
);

/// 작성: 2026-10-10 11:38:05 · nada
/// 변수: _noise
/// 목적: 원본 리포트 소음 범위(40~54 dBA, 눈금 2)를 최소로 두고 0 을
///       미측정으로 보는 자유 축.
const ChartScale _noise = ChartScale(
  minimum: ChartAxisRange(min: 40.0, max: 54.0, tickStep: 2.0),
  kind: ChartScaleKind.free,
  ignoreZeros: true,
);

/// 작성: 2026-10-10 11:38:05 · nada
/// 변수: _position
/// 목적: 0~10 m(눈금 2)를 최소로 둔, 0 을 한쪽 끝으로 하는 축.
const ChartScale _position = ChartScale(
  minimum: ChartAxisRange(min: 0.0, max: 10.0, tickStep: 2.0),
  kind: ChartScaleKind.zeroAnchored,
);

/// 작성: 2026-10-10 11:38:05 · nada
/// 변수: _speed
/// 목적: 0~1 m/s(눈금 0.2)를 최소로 둔, 0 을 한쪽 끝으로 하는 축.
const ChartScale _speed = ChartScale(
  minimum: ChartAxisRange(min: 0.0, max: 1.0, tickStep: 0.2),
  kind: ChartScaleKind.zeroAnchored,
);

/// 작성: 2026-10-10 11:38:05 · nada
/// 함수: _expectRange
/// 목적: 범위의 아래끝 · 위끝 · 눈금 간격을 한 번에 견준다. 넓힌 범위는
///       간격의 배수를 곱해 만들어 1e-12 수준 오차가 있을 수 있다.
/// 인자: range — 견줄 범위
///       min, max, step — 기대하는 아래끝 · 위끝 · 눈금 간격
void _expectRange(ChartAxisRange range, double min, double max, double step) {
  expect(range.min, closeTo(min, 1e-9), reason: '아래끝');
  expect(range.max, closeTo(max, 1e-9), reason: '위끝');
  expect(range.tickStep, closeTo(step, 1e-9), reason: '눈금 간격');
}

/// 작성: 2026-10-10 11:38:05 · nada
/// 함수: _expectWellFormed
/// 목적: 넓힌 범위가 지켜야 할 모양을 확인한다.
///       - 두 끝이 눈금 간격의 배수다
///       - 칸 수가 상한(`ChartScale.maxTickCells`) 안이다
///       - 마지막 눈금이 위끝에 떨어진다
/// 인자: range — 확인할 범위
void _expectWellFormed(ChartAxisRange range) {
  final lowCells = range.min / range.tickStep; // 아래끝까지의 칸 수
  final highCells = range.max / range.tickStep; // 위끝까지의 칸 수
  expect(lowCells, closeTo(lowCells.roundToDouble(), 1e-9), reason: '아래끝');
  expect(highCells, closeTo(highCells.roundToDouble(), 1e-9), reason: '위끝');
  expect(range.ticks().length - 1, lessThanOrEqualTo(ChartScale.maxTickCells));
  expect(range.ticks().last, closeTo(range.max, 1e-9));
}

/// 작성: 2026-10-10 11:38:05 · nada
/// 함수: main
/// 목적: 세로축 범위 규칙을 시험한다. 비었을 때와 최소 범위 안일 때 최소
///       범위를 그대로 쓰는지, 넘칠 때 모든 값과 여유를 담는지, 대칭 · 0
///       시작 · 자유 모양을 지키는지, 눈금이 나누어떨어지는지 본다.
void main() {
  group('ChartScale.rangeFor — 최소 범위', () {
    test('값이 없으면 최소 범위를 그대로 쓴다', () {
      _expectRange(_vibrationX.rangeFor(const <double>[]), -4, 4, 2);
    });

    test('최소 범위 안의 값은 원본 리포트 눈금 그대로 보인다', () {
      _expectRange(
        _vibrationX.rangeFor(const <double>[-3.9, 0.2, 3.9]),
        -4,
        4,
        2,
      );
      _expectRange(_noise.rangeFor(const <double>[41.0, 53.5]), 40, 54, 2);
    });

    test('소음의 0 은 미측정이라 범위에 넣지 않는다', () {
      _expectRange(
        _noise.rangeFor(const <double>[0.0, 0.0, 41.0, 53.5]),
        40,
        54,
        2,
      );
      _expectRange(_noise.rangeFor(const <double>[0.0, 0.0]), 40, 54, 2);
    });

    test('적분 오차로 0 아래로 살짝 내려간 위치는 축을 넓히지 않는다', () {
      // 최소 범위 0~10 의 여유 폭은 0.2
      _expectRange(_position.rangeFor(const <double>[-0.003, 9.79]), 0, 10, 2);
    });
  });

  group('ChartScale.rangeFor — 넘칠 때', () {
    // 아래 값들은 `test/fixtures/app_measurement.xlsx` 의 양 끝값이다.
    // 진동은 신호 처리 전 값이라 처리 후보다 크다
    test('X 진동 -7.892 ~ 5.649 mg 은 ±10 mg, 눈금 5 가 된다', () {
      final range = _vibrationX.rangeFor(const <double>[-7.892, 5.649]);
      _expectRange(range, -10, 10, 5);
    });

    test('수직 진동 -54.78 ~ 26.75 mg 은 ±75 mg, 눈금 25 가 된다', () {
      final range = _vibrationZ.rangeFor(const <double>[-54.78, 26.75]);
      _expectRange(range, -75, 75, 25);
    });

    test('소음 44.8 ~ 63.0 dBA 는 최소 범위 아래끝을 지키고 40 ~ 65 가 된다', () {
      final range = _noise.rangeFor(const <double>[0.0, 44.8, 63.0]);
      _expectRange(range, 40, 65, 5);
    });

    test('양수 쪽 속도 0 ~ 1.74 m/s 는 0 ~ 2, 눈금 0.5 가 된다', () {
      final range = _speed.rangeFor(const <double>[-0.004, 1.74]);
      _expectRange(range, 0, 2, 0.5);
    });

    test('운행 거리 57.09 m 는 0 ~ 60, 눈금 10 이 된다', () {
      final range = _position.rangeFor(const <double>[-0.003, 57.09]);
      _expectRange(range, 0, 60, 10);
    });

    test('모든 값이 범위 안에 들고 양 끝에 여유가 남는다', () {
      const values = <double>[-13.2, 4.0, 31.7]; // 최소 범위를 넘는 진동
      final range = _vibrationZ.rangeFor(values);
      final pad = 2 * 31.7 * ChartScale.headroomRatio; // 큰 쪽 끝에 둘 여유
      expect(range.min, lessThanOrEqualTo(-31.7 - pad));
      expect(range.max, greaterThanOrEqualTo(31.7 + pad));
      _expectWellFormed(range);
    });
  });

  group('ChartScale.rangeFor — 축 모양', () {
    test('대칭 축은 한쪽으로만 넘쳐도 0 을 가운데 둔다', () {
      final range = _vibrationX.rangeFor(const <double>[-1.0, 9.0]);
      expect(range.min, closeTo(-range.max, 1e-9));
      expect(range.ticks(), contains(closeTo(0.0, 1e-9)));
    });

    test('음수 쪽 속도는 0 이 위끝이 된다', () {
      final range = _speed.rangeFor(const <double>[-1.74, 0.004]);
      _expectRange(range, -2, 0, 0.5);
    });

    test('음수 쪽 속도라도 최소 범위 안이면 뒤집은 최소 범위를 쓴다', () {
      final range = _speed.rangeFor(const <double>[-0.6, 0.0]);
      _expectRange(range, -1, 0, 0.2);
    });

    test('자유 축은 0 을 품지 않는다', () {
      final range = _noise.rangeFor(const <double>[72.0, 88.0]);
      expect(range.min, greaterThan(0.0));
      expect(range.max, greaterThanOrEqualTo(88.0));
    });
  });

  group('ChartScale.rangeFor — 눈금', () {
    test('넓힌 범위는 어느 크기에서도 눈금이 나누어떨어지고 6칸을 넘지 않는다', () {
      for (final peak in <double>[
        4.3,
        5.0,
        7.7,
        12.0,
        19.99,
        20.0,
        33.3,
        99.0,
        150.0,
        1234.5,
      ]) {
        _expectWellFormed(_vibrationX.rangeFor(<double>[-peak, peak]));
        _expectWellFormed(_noise.rangeFor(<double>[45.0, 54.0 + peak]));
        _expectWellFormed(_position.rangeFor(<double>[0.0, 10.0 + peak]));
      }
    });
  });
}
