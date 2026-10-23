import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart_renderer.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';

import '../../support/reference_records.dart';

/// 작성: 2026-10-23 12:30:00 · 박건준
/// 함수: _wave
/// 목적: 최대 절댓값이 정확히 `peak` 인 흔들림 시계열을 만든다. 거의 정지한
///       기록의 가속도 · 저크를 흉내 낸다.
/// 인자: peak — 최대 절댓값 (m/s² 또는 m/s³)
/// 반환: 100Hz 10초 분량 시계열. 마지막 표본이 `-peak` 다
List<double> _wave(double peak) => <double>[
  for (var i = 0; i < 999; i++) 0.8 * peak * math.sin(2 * math.pi * i / 37),
  -peak,
];

/// 작성: 2026-10-23 12:30:00 · 박건준
/// 함수: _labels
/// 목적: 축 사양이 시계열에 고른 범위의 눈금 라벨을 렌더러와 같은 규칙으로
///       만든다(`ReportChartRenderer.formatTick()`).
/// 인자: spec — 축 사양
///       values — 그릴 시계열
/// 반환: 아래부터 차례로 놓인 눈금 라벨
List<String> _labels(ChartAxisSpec spec, List<double> values) {
  final range = spec.rangeFor(values); // 고른 세로축
  return <String>[
    for (final tick in range.ticks())
      ReportChartRenderer.formatTick(tick, range.tickStep),
  ];
}

/// 작성: 2026-10-23 12:30:00 · 박건준
/// 함수: main
/// 목적: 리포트 3쪽 가속도 · 저크 축의 눈금 라벨을 본다(2026-10-23).
///       - 거의 정지한 기록(최대 절댓값 0.001 · 0.01 · 0.024 · 0.03)에서도
///         이웃 라벨이 같은 숫자로 겹치지 않는다
///       - 운행 기록(ride_reference · 개발폰 처리 픽스처)은 정지 바닥
///         (`ReportChartAxes.motionlessPeak`)에 걸리지 않아 틀 · 눈금이
///         바닥 없는 규칙과 같다
void main() {
  group('거의 정지한 기록의 3쪽 눈금', () {
    for (final peak in <double>[0.001, 0.01, 0.024, 0.03]) {
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]) {
        test('${spec.key} 최대 절댓값 $peak', () {
          final labels = _labels(spec, _wave(peak)); // 눈금 라벨
          expect(labels.length, greaterThanOrEqualTo(3), reason: '$labels');
          for (var i = 1; i < labels.length; i++) {
            expect(labels[i], isNot(labels[i - 1]), reason: '$labels');
          }
          // 한 축 안의 소수 자리는 같다(`formatTick()` 맞춤)
          final decimals = labels
              .map((l) => l.contains('.') ? l.split('.').last.length : 0)
              .toSet(); // 라벨마다 소수 자리 수
          expect(decimals.length, 1, reason: '$labels');
          // 범위 밖 표본이 없다
          final range = spec.rangeFor(_wave(peak)); // 고른 세로축
          expect(range.contains(-peak, peak), isTrue);
        });
      }
    }

    test('바닥에 걸린 틀은 ±0.03 이고 눈금은 0.01 간격이다', () {
      final range = ReportChartAxes.accel.rangeFor(_wave(0.01)); // 고른 축
      expect(range.min, closeTo(-0.03, 1e-12));
      expect(range.max, closeTo(0.03, 1e-12));
      expect(range.tickStep, closeTo(0.01, 1e-12));
      expect(_labels(ReportChartAxes.accel, _wave(0.01)), <String>[
        '-0.03',
        '-0.02',
        '-0.01',
        '0.00',
        '0.01',
        '0.02',
        '0.03',
      ]);
    });
  });

  group('운행 기록의 3쪽 축은 바닥 없는 규칙과 같다', () {
    for (final entry in <String, String>{
      'ride_reference': rideReferencePath,
      'conditioning_input_dev_256hz':
          'test/fixtures/records/conditioning_input_dev_256hz.txt',
    }.entries) {
      test(entry.key, () {
        final result = assembleRecord(entry.value).result!; // 운행 결과
        for (final spec in <ChartAxisSpec>[
          ReportChartAxes.accel,
          ReportChartAxes.jerk,
        ]) {
          final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
          final peak = values.fold<double>(
            0,
            (m, v) => math.max(m, v.abs()),
          ); // 최대 절댓값
          expect(
            peak,
            greaterThan(ReportChartAxes.motionlessPeak),
            reason: '${spec.key} $peak',
          );
          final floorless = ChartScale(
            minimum: spec.scale.minimum,
            kind: spec.scale.kind,
          ).rangeFor(values); // 바닥 없는 규칙의 범위
          final range = spec.rangeFor(values); // 앱이 고른 범위
          expect(range.min, floorless.min, reason: spec.key);
          expect(range.max, floorless.max, reason: spec.key);
          expect(range.tickStep, floorless.tickStep, reason: spec.key);
        }
      });
    }
  });
}
