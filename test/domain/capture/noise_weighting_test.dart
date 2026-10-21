import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/noise_offset.dart';
import 'package:vibration_checker/domain/report/noise_slow.dart';

/// 작성: 2026-10-22 12:00:00 · nada
/// 변수: _kotlinPath
/// 목적: 소음을 계산하는 안드로이드 코드 경로. 코틀린은 단위 시험 틀이
///       없어, 이 시험이 소스의 상수를 읽어 SciPy 정본과 견준다.
const String _kotlinPath =
    'android/app/src/main/kotlin/com/otis/vibration_checker/'
    'NoiseCaptureHandler.kt';

/// 작성: 2026-10-22 12:00:00 · nada
/// 함수: _constant
/// 목적: 코틀린 소스에서 `private const val 이름 = 값` 의 값을 읽는다.
/// 인자: source — 코틀린 소스
///       name — 상수 이름
/// 반환: 값 (실수)
double _constant(String source, String name) {
  final match = RegExp(
    'const val $name = ([-0-9.]+)',
  ).firstMatch(source); // 상수 줄
  expect(match, isNotNull, reason: name);
  return double.parse(match!.group(1)!);
}

/// 작성: 2026-10-22 12:00:00 · nada
/// 함수: _sos
/// 목적: 코틀린 소스에서 A 가중 계수 배열(`private val 이름 = arrayOf(…)`)을
///       읽는다.
/// 인자: source — 코틀린 소스
///       name — 배열 이름
/// 반환: 단마다 [b0 b1 b2 a0 a1 a2]
List<List<double>> _sos(String source, String name) {
  final start = source.indexOf('private val $name = arrayOf('); // 배열 시작
  expect(start, greaterThanOrEqualTo(0), reason: name);
  final end = source.indexOf('\n        )\n', start); // 배열 끝
  final body = source.substring(start, end); // 배열 본문
  return <List<double>>[
    for (final row in RegExp(r'doubleArrayOf\(([^)]*)\)').allMatches(body))
      row
          .group(1)!
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .map(double.parse)
          .toList(),
  ];
}

/// 작성: 2026-10-22 12:00:00 · nada
/// 수정: 2026-10-22 16:20:00 · nada
/// 함수: main
/// 목적: 소음 계산(안드로이드 `NoiseCaptureHandler`)의 2026-10-22 설정을
///       SciPy 정본(`noise_weighting_cases.json`, `--noise` 모드)과 견준다.
///       - 48000 · 44100Hz A 가중 계수
///       - Fast(0.125초) 지수평활 — 앱과 같은 식(홉마다 a = exp(−홉/fs/τ), 첫
///         값은 그대로)으로 계산한 응답이 SciPy `lfilter` 와 같은지
///       - Dart 쪽 시정수(`kNoiseTimeWeightSec`)가 코틀린과 같은지
///       - 소음 최대에 쓰는 Dart Slow(1초) 평활(`NoiseSlow.series()`)이 SciPy
///         정본과 같은지
void main() {
  final source = File(_kotlinPath).readAsStringSync(); // 코틀린 소스
  final cases =
      jsonDecode(
            File('test/fixtures/noise_weighting_cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>; // SciPy 픽스처

  test('표본 속도는 48000 우선, 못 열면 44100', () {
    expect(_constant(source, 'PREFERRED_SAMPLE_RATE'), 48000);
    expect(_constant(source, 'FALLBACK_SAMPLE_RATE'), 44100);
  });

  test('A 가중 계수가 표본 속도마다 SciPy 와 같다', () {
    for (final (rate, name) in <(String, String)>[
      ('44100', 'A_WEIGHTING_SOS'),
      ('48000', 'A_WEIGHTING_SOS_48000'),
    ]) {
      final kotlin = _sos(source, name); // 코틀린 계수
      final scipy = <List<double>>[
        for (final row
            in (cases[rate] as Map<String, dynamic>)['sos'] as List<dynamic>)
          [for (final v in row as List<dynamic>) (v as num).toDouble()],
      ]; // SciPy 계수
      expect(kotlin.length, scipy.length, reason: rate);
      for (var i = 0; i < scipy.length; i++) {
        for (var j = 0; j < 6; j++) {
          expect(
            kotlin[i][j],
            closeTo(scipy[i][j], 1e-15),
            reason: '$rate $i $j',
          );
        }
      }
    }
  });

  test('수집 평활은 Fast 0.125초이고 Dart · 코틀린이 같다', () {
    expect(_constant(source, 'FAST_TIME_WEIGHT_SEC'), 0.125);
    expect(kNoiseTimeWeightSec, _constant(source, 'FAST_TIME_WEIGHT_SEC'));
    expect(cases['timeWeightSec'], kNoiseTimeWeightSec);
    expect(source, isNot(contains(' TIME_WEIGHT_SEC')));
  });

  test('앱 식의 Fast 평활 응답이 SciPy lfilter 와 같다', () {
    final hopHz = _constant(source, 'HOP_HZ').toInt(); // 홉 빈도
    final tau = _constant(source, 'FAST_TIME_WEIGHT_SEC'); // 시정수 (초)
    for (final rate in <int>[44100, 48000]) {
      final c = cases['$rate'] as Map<String, dynamic>; // 이 속도 픽스처
      final hop = rate ~/ hopHz; // 홉 표본 수 (코틀린 `sampleRate / HOP_HZ`)
      expect(hop, c['hop'], reason: '$rate');
      final alpha = math.exp(-(hop / rate) / tau); // 코틀린 식 그대로
      expect(alpha, closeTo((c['alpha'] as num).toDouble(), 1e-15));
      final input = [for (final v in c['input'] as List) (v as num).toDouble()];
      final expected = [
        for (final v in c['smoothed'] as List) (v as num).toDouble(),
      ];
      double? state; // 코틀린 `fastWeightedMeanSquare`
      for (var i = 0; i < input.length; i++) {
        final previous = state; // 앞 홉 평활값
        state = previous == null
            ? input[i]
            : alpha * previous + (1 - alpha) * input[i];
        expect(state, closeTo(expected[i], 1e-9), reason: '$rate $i');
      }
    }
  });

  test('처리 방식 표시에 Fast · 표본 속도 · 최대 Slow 를 남긴다', () {
    expect(noiseMethodLabel(48000), 'noise(A,fast,+105.2,48000Hz)');
    expect(noiseMethodLabel(44100), 'noise(A,fast,+105.2,44100Hz)');
    expect(noiseMethodLabel(null), 'noise(A,fast,+105.2)');
    expect(NoiseSlow.methodLabel, 'noisemax(slow1.0s)');
  });

  test('소음 최대용 Slow(1초) 평활이 SciPy 정본과 같다', () {
    expect(cases['slowTimeWeightSec'], CaptureConfig.noiseMaxSlowSec);
    final c = cases['slow'] as Map<String, dynamic>; // Slow 픽스처
    final input = [for (final v in c['input'] as List) (v as num).toDouble()];
    final expected = [for (final v in c['slow'] as List) (v as num).toDouble()];
    final slow = NoiseSlow.series(
      input,
      (c['fs'] as num).toDouble(),
    ); // 앱 Slow 열
    expect(slow.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(slow[i], closeTo(expected[i], 1e-9), reason: '$i');
    }
    // 0(미측정)은 0 그대로, 첫 측정 표본은 평활 없이 그대로다
    expect(slow.first, 0);
    expect(slow[20], 50.0);
    expect(slow[320], 0);
  });
}
