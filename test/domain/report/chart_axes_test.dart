import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _sampleRate
/// 목적: 시험에 쓰는 표본 주기 (Hz).
/// 근거: 인용 — 회귀 기준 측정 기록(`test/fixtures/records/ride_reference.txt`)이
///       이 주기로 기록돼 있다
const _sampleRate = 256.0;

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _rideSampleCount
/// 목적: 시험에 쓰는 표본 개수.
/// 근거: 인용 — 회귀 기준 측정 기록의 행 수와 같다. 줄이기가 실제 측정
///       크기에서 어떻게 도는지 보려고 같은 수를 쓴다
const _rideSampleCount = 11388;

/// 작성: 2026-09-17 10:05:00 · nada
/// 함수: _wave
/// 목적: 시험용 파형을 만든다. 사인파에 뾰족한 봉우리 하나를 섞어, 줄이기가
///       봉우리를 지우지 않는지 볼 수 있게 한다.
/// 인자: count — 만들 표본 개수
///       spikeIndex — 봉우리를 꽂을 자리
///       spikeValue — 봉우리 값
/// 반환: 시험용 시계열
List<double> _wave(
  int count, {
  required int spikeIndex,
  required double spikeValue,
}) {
  final values = List<double>.generate(
    count,
    (i) => math.sin(i / 40.0) * 3.0,
  ); // 바탕이 되는 사인파
  values[spikeIndex] = spikeValue;
  return values;
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 함수: _result
/// 목적: 차트를 그려 보려고 만드는 측정 결과. 소음만 비워 둔다 — 마이크
///       권한이 없는 측정을 흉내 내, 빈 시계열에서도 축 틀이 그려지는지
///       같이 확인하려는 것이다.
/// 반환: 차트 렌더링에 넣을 측정 결과
MeasurementResult _result() {
  final zWave = _wave(
    _rideSampleCount,
    spikeIndex: 5000,
    spikeValue: 18.0,
  ); // 수직 진동 파형
  return MeasurementResult(
    id: '20260917-100500',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    sampleRate: _sampleRate,
    xSeries: _wave(_rideSampleCount, spikeIndex: 100, spikeValue: 8.0),
    ySeries: _wave(_rideSampleCount, spikeIndex: 200, spikeValue: -12.0),
    zSeries: zWave,
    noiseSeries: const <double>[],
    positionSeries: List<double>.generate(
      _rideSampleCount,
      (i) => 57.09 * i / _rideSampleCount,
    ),
    speedSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(math.pi * i / _rideSampleCount) * 1.743390961,
    ),
    accelSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(2 * math.pi * i / _rideSampleCount) * 0.9,
    ),
    jerkSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(4 * math.pi * i / _rideSampleCount) * 1.2,
    ),
  );
}

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-22 23:40:00 · nada
/// 함수: main
/// 목적: 차트 축 사양을 시험한다(렌더러 시험에서 옮겼다).
///       1. 축마다 세로축 범위 — 최소 범위를 지키는지, 넘치면 넓어지는지,
///          축마다 넓히는 모양이 맞는지
///       2. 눈금 만들기 — 마지막 눈금이 축 위끝에 정확히 떨어지는지
///       3. 축마다 그릴 시계열 고르기
void main() {
  group('ChartAxisSpec.rangeFor — 축마다 세로축 범위', () {
    test('데이터가 비면 최소 범위를 쓴다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[]);

      expect(range.min, 0.0);
      expect(range.max, 10.0);
    });

    test('위치가 한 값뿐인 정지 측정은 최소 범위에 여백을 둔다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[0, 0]);

      expect(range.min, closeTo(-1.0, 1e-9));
      expect(range.max, closeTo(11.0, 1e-9));
      expect(range.ticks().first, 0.0);
    });

    test('여유를 더해도 최소 범위 안인 값은 원본 리포트 범위 그대로 보인다', () {
      final x = ReportChartAxes.x.rangeFor(const <double>[0.1]);
      final noise = ReportChartAxes.noise.rangeFor(const <double>[42.0, 52.0]);

      expect(<double>[x.min, x.max], const <double>[-4.0, 4.0]);
      expect(<double>[noise.min, noise.max], const <double>[40.0, 54.0]);
    });

    test('최소 범위를 넘는 진동은 축이 넓어져 잘리지 않는다', () {
      final range = ReportChartAxes.x.rangeFor(const <double>[-999.0, 999.0]);

      expect(range.min, lessThanOrEqualTo(-999.0));
      expect(range.max, greaterThanOrEqualTo(999.0));
    });

    test('3쪽 위치 · 속도 축은 OTIS 처럼 데이터 폭의 10% 씩 바깥이다', () {
      // OTIS 리포트 3쪽에서 잰 값(2026-10-21 점검 지시). 오차는 축 폭의 3%
      void expectRange(
        ChartAxisSpec spec,
        List<double> data,
        (double, double) otis,
        List<double> ticks,
      ) {
        final range = spec.rangeFor(data); // 고른 세로축
        final tolerance = range.span * 0.03; // 허용 오차
        expect(range.min, closeTo(otis.$1, tolerance), reason: '$data');
        expect(range.max, closeTo(otis.$2, tolerance), reason: '$data');
        final drawn = range.ticks(); // 찍는 눈금
        expect(drawn.length, ticks.length, reason: '$drawn');
        for (var i = 0; i < ticks.length; i++) {
          expect(drawn[i], closeTo(ticks[i], 1e-9), reason: '$drawn');
        }
        // 0 눈금이 틀 아래끝 안쪽에 있다(꼭짓점에 붙지 않는다)
        expect(range.min, lessThan(0));
      }

      expectRange(
        ReportChartAxes.position,
        const <double>[0, 24.9],
        (-2.4, 27.2),
        const <double>[0, 5, 10, 15, 20, 25],
      );
      expectRange(
        ReportChartAxes.speed,
        const <double>[0, 1.50],
        (-0.18, 1.64),
        const <double>[0, 0.5, 1.0, 1.5],
      );
      expectRange(
        ReportChartAxes.speed,
        const <double>[0, 1.75],
        (-0.18, 1.89),
        const <double>[0, 0.5, 1.0, 1.5],
      );
    });

    test('하강(위치 감소 · 속도 음수)도 같은 여백 규칙이다', () {
      final pos = ReportChartAxes.position.rangeFor(const <double>[24.9, 0]);
      final vel = ReportChartAxes.speed.rangeFor(const <double>[0, -1.50]);

      expect(pos.min, closeTo(-2.49, 1e-9));
      expect(pos.max, closeTo(27.39, 1e-9));
      expect(vel.min, closeTo(-1.65, 1e-9));
      expect(vel.max, closeTo(0.15, 1e-9));
      expect(vel.ticks(), const <double>[-1.5, -1.0, -0.5, 0.0]);
    });

    test('속도 차트는 부호 그대로 그리고 하강은 0 아래로 넓어진다', () {
      final result = _result().copyWith(
        speedSeries: const <double>[0.0, -0.5, -1.2, 0.3],
      ); // 하강이라 음수인 속도
      final drawn = ReportChartAxes.seriesOf(ReportChartAxes.speed, result);

      expect(drawn, const <double>[0.0, -0.5, -1.2, 0.3]);
      final range = ReportChartAxes.speed.rangeFor(drawn); // 고른 세로축
      expect(range.contains(-1.2, 0.3), isTrue);
      expect(range.min, lessThan(-1.2));
    });

    test('앱 실측 소음은 0 을 빼고 40 ~ 65 dBA 로 넓어진다', () {
      // `test/fixtures/app_measurement.xlsx` 의 `noiseDba` 열 양 끝값.
      // 앞쪽 0 은 마이크 창이 차기 전 미측정 구간이다
      final range = ReportChartAxes.noise.rangeFor(const <double>[
        0.0,
        44.8,
        63.0,
      ]);

      expect(range.min, 40.0);
      expect(range.max, closeTo(65.0, 1e-9));
    });

    test('축마다 넓히는 모양이 정해져 있다', () {
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
      ]) {
        expect(spec.scale.kind, ChartScaleKind.symmetric, reason: spec.key);
      }
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]) {
        expect(
          spec.scale.kind,
          ChartScaleKind.paddedSymmetric,
          reason: spec.key,
        );
      }
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.position,
        ReportChartAxes.speed,
      ]) {
        expect(spec.scale.kind, ChartScaleKind.padded, reason: spec.key);
      }
      expect(ReportChartAxes.noise.scale.kind, ChartScaleKind.free);
      expect(ReportChartAxes.noise.scale.ignoreZeros, isTrue);
    });

    test('가속도 · 저크 틀은 ±1.2 x 최대 절댓값이고 눈금은 틀 안 0.2 간격이다', () {
      // OTIS 3쪽 예: 가속도 최대 0.58 → ±0.70, 저크 0.61 → ±0.73
      for (final (spec, peak) in <(ChartAxisSpec, double)>[
        (ReportChartAxes.accel, 0.58),
        (ReportChartAxes.jerk, 0.61),
      ]) {
        final range = spec.rangeFor(<double>[-peak * 0.9, 0.1, peak]);
        expect(range.max, closeTo(peak * 1.2, peak * 1.2 * 0.01));
        expect(range.min, closeTo(-peak * 1.2, peak * 1.2 * 0.01));
        expect(
          range.ticks(),
          <double>[
            -0.6,
            -0.4,
            -0.2,
            0.0,
            0.2,
            0.4,
            0.6,
          ].map((v) => closeTo(v, 1e-9)).toList(),
        );
      }
      // 음수 쪽이 크면 그 절댓값으로 대칭이다
      final down = ReportChartAxes.accel.rangeFor(const <double>[-0.5, 0.2]);
      expect(down.max, closeTo(0.6, 1e-9));
      expect(down.min, closeTo(-0.6, 1e-9));
      // 모두 0 이면 최소 범위
      final still = ReportChartAxes.jerk.rangeFor(const <double>[0, 0]);
      expect(<double>[still.min, still.max], const <double>[-0.6, 0.6]);
    });
  });

  group('ChartAxisRange.ticks — 눈금 만들기', () {
    test('소음 최소 범위는 40 부터 54 까지 2 씩 놓인다', () {
      final ticks = ReportChartAxes.noise.scale.minimum.ticks();

      expect(ticks, const <double>[40, 42, 44, 46, 48, 50, 52, 54]);
    });

    test('마지막 눈금은 어느 축의 최소 범위에서도 위끝에 정확히 떨어진다', () {
      for (final spec in ReportChartAxes.all) {
        final minimum = spec.scale.minimum; // 이 축의 최소 범위
        final ticks = minimum.ticks(); // 그 눈금

        expect(ticks.first, minimum.min, reason: '${spec.key} 첫 눈금');
        expect(ticks.last, minimum.max, reason: '${spec.key} 마지막 눈금');
      }
    });

    test('이진수로 안 떨어지는 간격에서도 오차가 쌓이지 않는다', () {
      // 0.2 씩 다섯 번은 거듭 더하면 1.0 에서 벗어난다
      final ticks = ReportChartAxes.speed.scale.minimum.ticks();

      expect(ticks.length, 6);
      expect(ticks.last, 1.0);
    });
  });

  group('ReportChartAxes.seriesOf — 시계열 고르기', () {
    test('축마다 짝이 되는 시계열을 꺼낸다', () {
      final result = _result(); // 시험용 측정 결과

      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.z, result),
        result.zSeries,
      );
      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.speed, result),
        result.speedSeries,
      );
    });

    test('아직 수집하지 않은 소음은 빈 목록이 나온다', () {
      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.noise, _result()),
        isEmpty,
      );
    });

    test('모르는 축 이름은 조용히 넘어가지 않고 실패한다', () {
      const unknown = ChartAxisSpec(
        key: '없는축',
        label: '없는 축',
        scale: ChartScale(
          minimum: ChartAxisRange(min: 0, max: 1, tickStep: 1),
          kind: ChartScaleKind.free,
        ),
      ); // 사양에 없는 축

      expect(
        () => ReportChartAxes.seriesOf(unknown, _result()),
        throwsArgumentError,
      );
    });
  });
}
