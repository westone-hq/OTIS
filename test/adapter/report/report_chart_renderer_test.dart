import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart_renderer.dart';
import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/analysis/measurement_assembler.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';
import 'package:vibration_checker/domain/report/chart_series.dart';
import 'package:vibration_checker/domain/report/report_chart_page_layout.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

import '../../support/pdf_probe.dart';

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _outputPath
/// 목적: 그려 본 차트 쪽을 남겨 둘 자리. 축 눈금과 라벨이 겹치지 않는지는
///       숫자로 재기 어려워 눈으로 열어 봐야 한다. 시험이 끝나도 지우지
///       않는 이유가 그것이다.
const _outputPath = 'build/report_chart_test.pdf';

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
/// 수정: 2026-10-10 11:48:41 · nada
/// 함수: main
/// 목적: 차트 계층을 시험한다. 크게 셋을 본다.
///       1. 축마다 세로축 범위 — 최소 범위를 지키는지, 넘치면 넓어지는지,
///          축마다 넓히는 모양이 맞는지
///       2. 눈금 만들기 — 마지막 눈금이 축 위끝에 정확히 떨어지는지
///       3. 표본 줄이기 — 최댓값과 최솟값이 살아남는지
///       마지막으로 실제 PDF 를 한 장 그려 그리기 과정이 끝까지 도는지
///       확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('가로축은 2 · 3쪽 모두 양쪽 4% 여백이고 눈금은 30 · 45초 → 5초, 60초 넘으면 10초', () {
      ({double start, double span, double step}) of(double seconds) =>
          ReportChartRenderer.timeWindow((seconds * 100).round() + 1, 100);
      final t31 = of(31.4); // OTIS 예 31.4초
      expect(t31.start, closeTo(-1.256, 1e-6));
      expect(t31.start + t31.span, closeTo(32.656, 1e-6));
      expect(t31.step, 5);
      expect(of(44.5).step, 5);
      expect(of(60).step, 5);
      expect(of(61).step, 10);
      expect(of(10).step, 1);
      expect(ReportChartRenderer.timePaddingRatio, 0.04);
    });

    test('눈금 숫자는 한 축 안에서 소수 자리를 맞춘다', () {
      String f(double v, double step) =>
          ReportChartRenderer.formatTick(v, step);
      expect(
        <String>[
          for (final v in <double>[0, 0.5, 1, 1.5]) f(v, 0.5),
        ],
        <String>['0.0', '0.5', '1.0', '1.5'],
      );
      expect(
        <String>[
          for (final v in <double>[0.6, 0.4, 0, -0.2]) f(v, 0.2),
        ],
        <String>['0.6', '0.4', '0.0', '-0.2'],
      );
      expect(f(25, 5), '25');
      expect(f(40, 10), '40');
      expect(f(0.25, 0.25), '0.25');
      expect(f(-1e-17, 0.2), '0.0', reason: '−0 을 찍지 않는다');
      expect(ReportChartRenderer.tickDecimals(5), 0);
      expect(ReportChartRenderer.tickDecimals(0.5), 1);
      expect(ReportChartRenderer.tickDecimals(0.25), 2);
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

  group('reduceSeriesSegments — 0 구간 끊기', () {
    test('끊지 않으면 reduceSeries 와 같은 한 덩어리다', () {
      final values = _wave(5000, spikeIndex: 1200, spikeValue: 9.0);
      final whole = reduceSeries(values, columns: 300);
      final segments = reduceSeriesSegments(
        values,
        columns: 300,
        skipZeros: false,
      );

      expect(segments, hasLength(1));
      expect(
        segments.single.map((s) => s.index).toList(),
        whole.map((s) => s.index).toList(),
      );
    });

    test('0 구간에서 선을 끊고 0 은 그리지 않는다', () {
      final values = <double>[
        ...List<double>.filled(1000, 0.0), // 마이크 창이 차기 전
        ...List<double>.filled(2000, 50.0),
        ...List<double>.filled(500, 0.0), // 중간에 끊긴 구간
        ...List<double>.filled(1500, 60.0),
      ]; // 0 과 실측이 섞인 소음
      final segments = reduceSeriesSegments(
        values,
        columns: 300,
        skipZeros: true,
      );

      expect(segments, hasLength(2));
      for (final segment in segments) {
        expect(segment.map((s) => s.value), everyElement(isNot(0.0)));
      }
      expect(segments.first.first.index, 1000);
      expect(segments.last.first.index, 3500);
      // 값이 고른 칸은 칸 첫 자리 하나만 남으므로, 마지막 표본은 마지막
      // 칸(한 칸 = 16 표본) 안에 있으면 된다
      expect(
        segments.last.last.index,
        greaterThanOrEqualTo(values.length - values.length ~/ 300 - 1),
      );
    });

    test('한 칸에 0 과 실측이 섞이면 실측만으로 최소 · 최대를 낸다', () {
      // 5000 표본을 10칸으로 나누면 한 칸이 500 표본이다. 둘째 칸
      // (500 ~ 999) 앞 절반이 0 이고 뒤 절반이 실측이다
      final values = <double>[
        ...List<double>.filled(750, 0.0),
        for (var i = 0; i < 4250; i++) 40.0 + (i % 7),
      ];
      final segments = reduceSeriesSegments(
        values,
        columns: 10,
        skipZeros: true,
      );

      expect(segments, hasLength(1));
      final first = segments.single.take(2).map((s) => s.value); // 둘째 칸
      expect(first, everyElement(greaterThanOrEqualTo(40.0)));
    });
  });

  group('reduceSeries — 표본 줄이기', () {
    test('빈 시계열은 빈 목록이 된다', () {
      expect(reduceSeries(const <double>[], columns: 100), isEmpty);
    });

    test('칸 수의 두 배 이하면 줄이지 않고 그대로 옮긴다', () {
      final values = List<double>.generate(20, (i) => i.toDouble());

      final reduced = reduceSeries(values, columns: 10); // 줄인 결과

      expect(reduced.length, values.length);
      expect(reduced.map((s) => s.value).toList(), values);
    });

    test('최댓값과 최솟값이 살아남는다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 봉우리를 섞은 파형
      values[7000] = -17.0;
      final before = (
        min: values.reduce(math.min),
        max: values.reduce(math.max),
      ); // 줄이기 전 끝값

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과
      final after = (
        min: reduced.map((s) => s.value).reduce(math.min),
        max: reduced.map((s) => s.value).reduce(math.max),
      ); // 줄인 뒤 끝값

      expect(after.min, before.min);
      expect(after.max, before.max);
      expect(reduced.length, lessThan(values.length));
    });

    test('한 표본짜리 뾰족한 봉우리도 지워지지 않는다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 99.0,
      ); // 봉우리 하나만 아주 높은 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      expect(
        reduced.any((s) => s.index == 5000 && s.value == 99.0),
        isTrue,
        reason: '봉우리는 그 칸의 최댓값이라 반드시 남아야 한다',
      );
    });

    test('자리 번호가 커지는 차례를 지킨다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 시험용 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      for (var i = 1; i < reduced.length; i++) {
        expect(
          reduced[i].index,
          greaterThan(reduced[i - 1].index),
          reason: '$i 번째 표본이 앞 표본보다 앞쪽 자리로 돌아갔다',
        );
      }
    });

    test('남은 값은 모두 원래 시계열에 있던 값이다', () {
      // 평균을 냈다면 원래 없던 값이 섞여 나온다
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 시험용 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      for (final sample in reduced) {
        expect(sample.value, values[sample.index]);
      }
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

  group('차트 주석 — 소음 평균선과 최댓값 표시점', () {
    test('소음 축만 평균선과 표시점을 갖는다', () {
      expect(ReportChartAxes.noise.meanKey, 'noise_avg');
      expect(ReportChartAxes.noise.peakKey, 'noise_max');

      for (final spec in ReportChartAxes.all) {
        if (spec.key == 'noise') continue;
        expect(spec.meanKey, isNull, reason: '${spec.key} 는 평균선이 없다');
        expect(spec.peakKey, isNull, reason: '${spec.key} 는 표시점이 없다');
      }
    });

    test('가리키는 지표가 실제로 표에 있는 이름이다', () {
      // 이름이 어긋나면 조용히 아무것도 안 그린다. 표가 가진 이름과
      // 맞는지 못박아 둔다
      final metrics = ReportMetrics.from(_result()); // 표에 올리는 지표

      expect(metrics.byKey(ReportChartAxes.noise.meanKey!), isNotNull);
      expect(metrics.byKey(ReportChartAxes.noise.peakKey!), isNotNull);
    });

    test('주석이 붙으면 그만큼 내용이 늘어난다', () async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final noisy = _result().copyWith(
        noiseSeries: List<double>.generate(
          _rideSampleCount,
          (i) => 45.0 + (i == 3000 ? 12.0 : 0.0),
        ),
        noiseMax: 57.0,
      ); // 3000번째에 봉우리가 있는 소음

      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.noise,
        box: ReportChartPage.slots.first,
        result: noisy,
      );
      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });
  });

  group('ReportChartRenderer — 그리기', () {
    test('차트 네 개를 그린 PDF 가 만들어진다', () async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        'assets/report/NanumGothic-Regular.ttf',
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      final canvas = page.getGraphics(); // 그리기 도구
      final result = _result(); // 시험용 측정 결과
      final specs = <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
        ReportChartAxes.noise,
      ]; // 차트 쪽 첫 장에 놓이는 축 넷

      for (var i = 0; i < specs.length; i++) {
        renderer.draw(
          canvas,
          spec: specs[i],
          box: ReportChartPage.slots[i],
          result: result,
        );
      }

      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'PDF 머리말이 있어야 한다',
      );

      final file = File(_outputPath); // 눈으로 열어 볼 파일
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });

    test('시계열이 비어도 축 틀은 그린다', () async {
      // 소음처럼 아직 수집하지 않은 차트도 자리를 차지해야 한다. 아무것도
      // 그리지 않았다면 내용 길이가 거의 늘지 않는다
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        'assets/report/NanumGothic-Regular.ttf',
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽

      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.noise,
        box: ReportChartPage.slots.first,
        result: _result(),
      );
      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });
  });

  group('진동 P2P 표시', () {
    test('P2P 는 진동 세 축에서만 1쪽 표와 같은 지표를 꺼낸다', () {
      final result = _result().copyWith(xPtp: 14.2, yPtp: 10.6, zPtp: 108.4);

      expect(ReportChartAxes.ptpOf(ReportChartAxes.x, result), 14.2);
      expect(ReportChartAxes.ptpOf(ReportChartAxes.y, result), 10.6);
      expect(ReportChartAxes.ptpOf(ReportChartAxes.z, result), 108.4);
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.noise,
        ReportChartAxes.position,
        ReportChartAxes.speed,
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]) {
        expect(ReportChartAxes.ptpOf(spec, result), isNull, reason: spec.key);
      }
    });

    test('적는 숫자는 1쪽 표와 같은 규칙으로 다듬는다', () {
      final result = _result().copyWith(xPtp: 14.2125, zPtp: 108.3677);
      final metrics = ReportMetrics.from(result); // 1쪽 표 지표

      expect(ReportChartRenderer.ptpLabel(14.2125), 'ptp 14.2milli-G');
      expect(ReportChartRenderer.ptpLabel(108.3677), 'ptp 108milli-G');
      expect(
        metrics.vertMax.display,
        ReportChartRenderer.ptpLabel(108.3677).substring(4),
      );
    });

    test('P2P 가 있으면 빨간 표시점과 글자가 붙고, 없으면 붙지 않는다', () async {
      Future<String> drawX(MeasurementResult result) async {
        final document = PdfDocument(); // 만들어 낼 PDF 문서
        final fontBytes = await rootBundle.load(
          ReportLayout.regularFontAsset,
        ); // 글꼴 원본
        final renderer = ReportChartRenderer(
          font: PdfTtfFont(document, fontBytes),
        ); // 차트를 그릴 렌더러
        final page = PdfPage(
          document,
          pageFormat: PdfPageFormat(
            ReportLayout.pageWidthPt,
            ReportLayout.pageHeightPt,
          ),
        ); // 차트를 얹을 쪽
        renderer.draw(
          page.getGraphics(),
          spec: ReportChartAxes.x,
          box: ReportChartPage.slots.first,
          result: result,
        );
        final bytes = await document.save(); // 만든 PDF
        return pdfChartStreams(bytes).join();
      }

      final withPtp = await drawX(_result().copyWith(xPtp: 15.0)); // 새 결과
      final legacy = await drawX(_result()); // P2P 를 계산하지 않은 예전 결과

      expect(withPtp, contains(markerColorOperand));
      expect(legacy, isNot(contains(markerColorOperand)));
    });

    test('표시점 자리는 줄이기 전 원래 시계열의 최댓값 · 최솟값 자리다', () {
      final values = _wave(_rideSampleCount, spikeIndex: 4321, spikeValue: 9.0);
      values[777] = -9.5; // 줄이면 다른 칸 값과 섞일 수 있는 골
      final at = extremeIndices(values)!; // 표시점 자리

      expect(at.maxIndex, 4321);
      expect(at.minIndex, 777);
      final reduced = reduceSeries(values, columns: 300); // 그리는 표본
      expect(reduced.map((s) => s.index), containsAll(<int>[4321, 777]));
    });
  });

  group('운행 구간 점선 (2026-10-20)', () {
    const window = TravelWindow(
      startIndex: 2000,
      endIndex: 9000,
      startSec: 2000 / _sampleRate,
      endSec: 9000 / _sampleRate,
      startM: 0.5,
      endM: 56.5,
    ); // 시험용 운행 구간
    final box = ReportChartPage.slots.first; // 차트 자리
    final frameLeft = ReportLayout.xToPoints(box.x); // 축 틀 왼쪽 (포인트)
    final frameRight = ReportLayout.xToPoints(
      box.x + box.width,
    ); // 축 틀 오른쪽 (포인트)
    // 행 첨자가 축 틀 안 어느 가로 자리인지 렌더러와 같은 식으로 구한다
    double xOfIndex(int index) {
      const length = (_rideSampleCount - 1) / _sampleRate; // 측정 길이 (초)
      const start = -length * 0.04; // 가로축 왼쪽 끝 (초)
      const span = length * 1.08; // 가로축 폭 (초)
      return frameLeft +
          (frameRight - frameLeft) * (index / _sampleRate - start) / span;
    }

    // 차트 하나를 그려 그 쪽의 운행 구간 점선을 돌려준다
    Future<List<({double left, double y, double right})>> drawGuides(
      ChartAxisSpec spec,
      MeasurementResult result,
    ) async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(page.getGraphics(), spec: spec, box: box, result: result);
      final bytes = await document.save(); // 만든 PDF
      return guideLines(pdfChartStreams(bytes).join());
    }

    test('진동 차트는 A95 두 줄을 운행 구간에만 0 을 가운데 두고 긋는다', () async {
      final result = _result().copyWith(
        xA95: 4.0,
        travelWindow: window,
      ); // 구간 · A95 가 있는 결과
      final lines = await drawGuides(ReportChartAxes.x, result); // 그은 점선

      expect(lines.length, 2);
      for (final line in lines) {
        expect(line.left, closeTo(xOfIndex(2000), 0.01));
        expect(line.right, closeTo(xOfIndex(9000), 0.01));
      }
      final range = ReportChartAxes.x.rangeFor(result.xSeries); // 세로축
      final top = ReportLayout.yToPoints(box.y); // 축 틀 위 (포인트)
      final bottom = ReportLayout.yToPoints(box.y + box.height); // 아래
      double yOf(double value) =>
          bottom + (top - bottom) * (value - range.min) / range.span;
      expect(
        lines.map((l) => l.y),
        unorderedEquals(<Matcher>[
          closeTo(yOf(2.0), 0.01),
          closeTo(yOf(-2.0), 0.01),
        ]),
      );
    });

    test('A95 나 운행 구간이 없으면 진동 점선을 긋지 않는다', () async {
      final noA95 = _result().copyWith(travelWindow: window); // A95 없음
      final noWindow = _result().copyWith(xA95: 4.0); // 예전 결과

      expect(await drawGuides(ReportChartAxes.x, noA95), isEmpty);
      expect(await drawGuides(ReportChartAxes.x, noWindow), isEmpty);
    });

    test('소음 평균선은 운행 구간에만, 구간 없는 예전 결과는 폭 전체에 긋는다', () async {
      final noise = List<double>.filled(_rideSampleCount, 45.0); // 소음 (dBA)
      final windowed = _result().copyWith(
        noiseSeries: noise,
        travelWindow: window,
      ); // 구간이 있는 결과
      final legacy = _result().copyWith(noiseSeries: noise); // 예전 결과

      final inWindow = await drawGuides(ReportChartAxes.noise, windowed);
      expect(inWindow.length, 1);
      expect(inWindow.single.left, closeTo(xOfIndex(2000), 0.01));
      expect(inWindow.single.right, closeTo(xOfIndex(9000), 0.01));

      final full = await drawGuides(ReportChartAxes.noise, legacy);
      expect(full.single.left, closeTo(frameLeft, 0.01));
      expect(full.single.right, closeTo(frameRight, 0.01));
    });
  });

  group('수직 ptp · Jptp 표시 (2026-10-21)', () {
    const zones = MotionZones(
      runStartIndex: 1000,
      runEndIndex: 9000,
      steadyStartIndex: 3000,
      steadyEndIndex: 7000,
      sampleRate: _sampleRate,
    ); // 시험용 정속 · 가감속 구간
    const window = TravelWindow(
      startIndex: 1200,
      endIndex: 8800,
      startSec: 1200 / _sampleRate,
      endSec: 8800 / _sampleRate,
      startM: 0.5,
      endM: 56.5,
    ); // 시험용 운행 구간

    // 수직 차트 하나를 그려 그 쪽 내용 스트림을 돌려준다
    Future<String> drawZ(MeasurementResult result) async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.z,
        box: ReportChartPage.slots[2],
        result: result,
      );
      return pdfChartStreams(await document.save()).join();
    }

    // 정속 · 가감속 구간에 봉우리를 하나씩 둔 수직 시계열
    List<double> zWith({required int steadyAt, required int transientAt}) {
      final values = List<double>.generate(
        _rideSampleCount,
        (i) => i.isEven ? 1.0 : -1.0,
      ); // 잔잔한 진동 (mg)
      values[steadyAt] = 9.0;
      values[transientAt] = 12.0;
      return values;
    }

    test('Jptp 라벨 문구는 ptp 와 같은 숫자 규칙이다', () {
      expect(ReportChartRenderer.jptpLabel(17.14), 'Jptp 17.1milli-G');
      expect(ReportChartRenderer.jptpLabel(123.4), 'Jptp 123milli-G');
    });

    test('정속 쌍은 정속 구간, Jptp 쌍은 가감속 구간에서 찾는다', () {
      final values = zWith(steadyAt: 5000, transientAt: 2000);
      final result = _result().copyWith(motionZones: zones);
      final pairs = ReportChartAxes.verticalPairs(values, result)!;
      expect(pairs.steady!.high, 5000);
      expect(pairs.transient!.high, 2000);
      expect(ReportChartAxes.verticalPairs(values, _result()), isNull);
    });

    test('Jptp 가 있으면 글자 상자가 둘이고 서로 겹치지 않는다', () async {
      // 두 봉우리를 정속 경계 양쪽 바로 옆에 두어 글자가 같은 자리로 간다
      final values = zWith(steadyAt: 3002, transientAt: 2998);
      values[2998] = 9.0;
      final base = _result().copyWith(
        zSeries: values,
        travelWindow: window,
        motionZones: zones,
        zPtp: 10.0,
      ); // Jptp 없는 결과
      final one = labelBoxes(await drawZ(base)); // ptp 상자만
      final two = labelBoxes(
        await drawZ(base.copyWith(zJptp: 10.0)),
      ); // ptp · Jptp 상자

      expect(one.length, 1);
      expect(two.length, 2);
      final a = two[0];
      final b = two[1];
      final overlaps =
          a.left < b.left + b.width &&
          b.left < a.left + a.width &&
          a.bottom < b.bottom + b.height &&
          b.bottom < a.bottom + a.height; // 두 상자가 겹치는지
      expect(overlaps, isFalse, reason: '$a / $b');
    });
  });

  group('A95 글자 자리 (2026-10-22, 점선 오른쪽 끝)', () {
    const frame = (left: 50.0, bottom: 100.0, right: 250.0, top: 200.0);
    const width = 9.0; // 글자 폭 (포인트)
    const height = ReportChartRenderer.tickLabelSize; // 글자 세로
    const gap = ReportChartRenderer.labelGap; // 점선과 띄움
    ChartRect place({
      double spanRight = 200,
      List<ChartRect> avoid = const [],
    }) => ReportChartRenderer.placeA95Label(
      frame: frame,
      spanRight: spanRight,
      upperY: 160,
      lowerY: 140,
      width: width,
      avoid: avoid,
    );

    test('빈자리면 점선 오른쪽 끝 바깥, 아래 점선 바로 밑이다', () {
      final rect = place(); // 고른 자리
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 140 - gap - height);
    });

    test('ptp 상자가 그 자리를 차지하면 위 점선 위로 비킨다', () {
      final rect = place(
        avoid: [(left: 195, bottom: 125, width: 40, height: 15)],
      ); // 고른 자리
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 160 + gap);
    });

    test('바깥 두 자리가 막히면 점선 끝 안쪽으로 들어간다', () {
      final rect = place(
        avoid: [(left: 201, bottom: 100, width: 40, height: 100)],
      ); // 고른 자리
      expect(rect.left + width, 200, reason: '글자 끝 = 점선 끝');
      expect(rect.bottom, 140 - gap - height);
    });

    test('빨간 점도 피한다', () {
      const ring =
          ReportChartRenderer.markerRadius +
          ReportChartRenderer.markerRingWidth; // 점 반지름
      final rect = place(
        avoid: [
          (
            left: 205 - ring,
            bottom: 133 - ring,
            width: ring * 2,
            height: ring * 2,
          ),
        ],
      ); // 아래 바깥 자리에 점이 있음
      expect(rect.bottom, 160 + gap);
    });

    test('운행 구간이 기록 끝까지면 틀 안으로 밀어 넣는다', () {
      final rect = place(spanRight: 250); // 점선 끝 = 틀 오른쪽
      expect(
        rect.left + width,
        lessThanOrEqualTo(frame.right - ReportChartRenderer.labelInset),
      );
    });

    test('모두 막히면 첫 자리를 쓴다', () {
      final rect = place(
        avoid: [(left: 0, bottom: 0, width: 400, height: 400)],
      ); // 틀 전체를 덮음
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 140 - gap - height);
    });
  });

  group('운행 구간 · 반주기 표시점 (2026-10-15)', () {
    const window = TravelWindow(
      startIndex: 100,
      endIndex: 199,
      startSec: 1.0,
      endSec: 1.99,
      startM: 0.5,
      endM: 9.5,
    ); // 시험용 운행 구간

    test('표시점은 구간 안 최대 반주기 P2P 의 이웃 봉우리 · 골이다', () {
      final values = List<double>.filled(300, 0.0); // 진동 (mg)
      values[20] = 50.0; // 구간 밖 큰 봉우리 — 고르면 안 된다
      values[21] = -50.0;
      for (var i = 100; i < 200; i++) {
        values[i] = i.isEven ? 1.0 : -1.0;
      }
      values[150] = 6.0; // 구간 안 가장 큰 쌍: 6 + 1
      final result = _result().copyWith(
        sampleRate: 100,
        travelWindow: window,
      ); // 구간이 있는 결과
      final pair = ReportChartAxes.peakToPeakPair(values, result)!; // 두 지점

      expect(pair.high, 150);
      expect((pair.low - 150).abs(), 1, reason: '이웃한 골');
      final best = HalfCycle.maximum(values, start: 100, end: 199)!;
      expect(values[pair.high] + values[pair.low].abs(), best.value);
    });

    test('구간이 없는 예전 결과는 전체 최댓값 · 최솟값 자리다', () {
      final values = _wave(_rideSampleCount, spikeIndex: 4321, spikeValue: 9.0);
      values[777] = -9.5; // 가장 깊은 골
      final pair = ReportChartAxes.peakToPeakPair(values, _result())!;

      expect(pair.high, 4321);
      expect(pair.low, 777);
    });

    test('소음 최댓값 자리는 구간 안에서 찾는다', () {
      final values = List<double>.filled(300, 45.0); // 소음 (dBA)
      values[30] = 52.0; // 구간 밖 같은 값
      values[160] = 52.0; // 구간 안
      final windowed = _result().copyWith(travelWindow: window);

      expect(ReportChartAxes.indexInTravel(values, 52.0, windowed), 160);
      expect(ReportChartAxes.indexInTravel(values, 52.0, _result()), 30);
      expect(ReportChartAxes.indexInTravel(values, 99.0, windowed), -1);
    });

    test('가중 · 구간을 거친 기준 데이터도 8개 차트 모두 축 밖 표본이 없다', () {
      final lines = const LineSplitter()
          .convert(
            File('test/fixtures/records/ride_reference.txt').readAsStringSync(),
          )
          .where((line) => line.trim().isNotEmpty)
          .toList(); // 파일 줄
      final rows = <GridSample>[
        for (final line in lines.sublist(2))
          () {
            final f = line.trim().split(RegExp(r'\s+')); // 열 값
            return GridSample(
              xMg: double.parse(f[0]),
              yMg: double.parse(f[1]),
              zMg: double.parse(f[2]),
              noiseDba: double.parse(f[3]),
            );
          }(),
      ]; // 기준 데이터 격자 행
      final grid = GridResampleResult(
        samples: rows,
        t0Ns: 0,
        gridIntervalNs: 3906250,
        rawUsedCount: rows.length,
        gravityUsedCount: rows.length,
        droppedZeroCount: 0,
        droppedBackwardCount: 0,
        droppedLinearCount: 0,
        headTrimmedRows: 0,
        tailTrimmedRows: 0,
        rawMaxSpanNs: 0,
        gravityMaxSpanNs: 0,
        degenerateSpanCount: 0,
      ); // 256Hz 격자
      final result = MeasurementAssembler.assemble(
        grid: const SignalConditioner(
          config: CaptureConfig(),
        ).condition(grid).grid,
        site: const SiteInfo(
          jobNo: 'J',
          siteName: 'S',
          bottomFloor: '1',
          topFloor: '8',
          direction: SiteInfo.directionUp,
          model: SiteInfo.defaultModel,
        ),
        id: 'id',
        measuredAt: DateTime(2026, 1, 14),
      ).result!; // 앱과 같은 길로 만든 결과

      for (final spec in ReportChartAxes.all) {
        final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
        final range = spec.rangeFor(values); // 고른 세로축
        final outside = values
            .where((v) => !spec.scale.ignoreZeros || v != 0)
            .where((v) => !range.contains(v, v))
            .length; // 축 밖 표본 수
        expect(outside, 0, reason: spec.key);
      }
    });
  });
}
