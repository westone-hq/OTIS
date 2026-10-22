import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/dsp/sos_section.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';

import '../../support/reference_records.dart';

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: _cases
/// 목적: SciPy 로 만든 저크 · 가속도 차트 저역 픽스처를 읽는다
///       (`tool/fixtures/gen_conditioning_fixtures.py --jerk`).
/// 반환: 픽스처 표
Map<String, dynamic> _cases() =>
    jsonDecode(
          File('test/fixtures/scipy/jerk_unit_cases.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: _doubles
/// 목적: JSON 숫자 목록을 실수 목록으로 바꾼다.
/// 인자: raw — JSON 에서 읽은 목록
/// 반환: 실수 목록
List<double> _doubles(Object? raw) =>
    (raw as List<dynamic>).map((v) => (v as num).toDouble()).toList();

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: _expectSections
/// 목적: 설계한 2차 구간 계수가 SciPy 계수 행과 같은지 본다.
/// 인자: actual — Dart 가 설계한 구간
///       expected — SciPy `sos` 행 [b0 b1 b2 a0 a1 a2] 목록
void _expectSections(List<SosSection> actual, List<dynamic> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    final row = _doubles(expected[i]); // SciPy 한 구간
    final s = actual[i]; // Dart 한 구간
    for (final (a, e) in <(double, double)>[
      (s.b0, row[0]),
      (s.b1, row[1]),
      (s.b2, row[2]),
      (s.a1, row[4]),
      (s.a2, row[5]),
    ]) {
      expect(a, closeTo(e, 1e-12), reason: '구간 $i');
    }
  }
}

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: main
/// 목적: 저크 처리(1.6Hz 4차 버터워스 양방향 → 중앙 차분)와 차트 가속도
///       (10Hz 4차 양방향)를 시험한다.
///       - 필터 계수 · 출력이 SciPy 정본과 같은지
///       - 2026-10-21 동시 측정 · ride_reference 의 저크 봉우리가 OTIS
///         리포트 차트와 같은 값(±0.08)인지
///       - 정지 측정 구간 저크 차트에 축 밖 표본이 없는지
///       하강(dev_down3) 봉우리는 `otis_1021_descent_test.dart` 가 본다.
void main() {
  test('1.6Hz 4차 저역 계수 · 양방향 출력이 SciPy 와 같다', () {
    final cases = _cases(); // SciPy 픽스처
    final fs = (cases['fs'] as num).toDouble(); // 표본 속도 (Hz)
    final sections = Butterworth.lowpass(
      order: CaptureConfig.jerkLowpassOrder,
      cutoffHz: CaptureConfig.jerkLowpassHz,
      sampleRateHz: fs,
    ); // Dart 가 설계한 구간
    _expectSections(sections, cases['sos_jerk'] as List<dynamic>);

    final smooth = Butterworth.filtfilt(
      sections,
      _doubles(cases['input']),
    ); // 양방향 출력
    final expected = _doubles(cases['smooth_jerk']); // SciPy 출력
    for (var i = 0; i < smooth.length; i++) {
      expect(smooth[i], closeTo(expected[i], 1e-9), reason: '$i');
    }
  });

  test('차트 가속도 10Hz 4차 저역 계수 · 양방향 출력이 SciPy 와 같다', () {
    final cases = _cases(); // SciPy 픽스처
    final sections = Butterworth.lowpass(
      order: CaptureConfig.accelChartLowpassOrder,
      cutoffHz: CaptureConfig.accelChartLowpassHz,
      sampleRateHz: (cases['fs'] as num).toDouble(),
    ); // Dart 가 설계한 구간
    _expectSections(sections, cases['sos_acc_chart'] as List<dynamic>);
    final out = Butterworth.filtfilt(sections, _doubles(cases['input']));
    final expected = _doubles(cases['acc_chart']); // SciPy 출력
    for (var i = 0; i < out.length; i++) {
      expect(out[i], closeTo(expected[i], 1e-9), reason: '$i');
    }
  });

  group('2026-10-21 동시 측정 저크 봉우리 (OTIS 차트와 ±0.08)', () {
    const targets = <String, (double, double)>{
      'dev_up1': (0.56, -0.63),
      'dev_up2': (0.55, -0.63),
      'otis_up1': (0.55, -0.61),
      'otis_up2': (0.55, -0.60),
      'otis_down3': (0.57, -0.66),
    }; // 기록 → (최대, 최소) m/s³

    for (final entry in targets.entries) {
      test(entry.key, () {
        final result = assembleRecord(otis1021Records[entry.key]!).result!;
        final jerk = result.jerkSeries; // 저크 (m/s³)
        expect(jerk.reduce(math.max), closeTo(entry.value.$1, 0.08));
        expect(jerk.reduce(math.min), closeTo(entry.value.$2, 0.08));
      });
    }

    test('ride_reference (원본 H6N1AP65)', () {
      final result = assembleRecord(rideReferencePath).result!;
      expect(result.jerkSeries.reduce(math.max), closeTo(0.79, 0.08));
      expect(result.jerkSeries.reduce(math.min), closeTo(-0.59, 0.08));
    });
  });

  test('저크 · 가속도 차트에 축 밖 표본이 없다', () {
    for (final path in <String>[...otis1021Records.values, rideReferencePath]) {
      final result = assembleRecord(path).result!;
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.jerk,
        ReportChartAxes.accel,
      ]) {
        final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
        final range = spec.rangeFor(values); // 고른 세로축
        expect(
          values.where((v) => !range.contains(v, v)),
          isEmpty,
          reason: '$path ${spec.key}',
        );
      }
    }
  });
}
