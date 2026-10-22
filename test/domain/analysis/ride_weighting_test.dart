import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/analysis/ride_weighting.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/dsp/sos_section.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _cases
/// 목적: SciPy 로 만든 가중 필터 기대값을 읽는다
///       (`tool/fixtures/gen_conditioning_fixtures.py --weighting`).
/// 반환: 항목 이름을 열쇠로 하는 표
Map<String, dynamic> _cases() =>
    jsonDecode(
          File(
            'test/fixtures/scipy/weighting_unit_cases.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _doubles
/// 목적: JSON 숫자 목록을 실수 목록으로 바꾼다.
/// 인자: raw — JSON 에서 읽은 목록
/// 반환: 실수 목록
List<double> _doubles(Object? raw) =>
    (raw as List<dynamic>).map((v) => (v as num).toDouble()).toList();

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _expectSections
/// 목적: 2차 구간 목록이 SciPy `sos` 행렬([b0 b1 b2 1 a1 a2])과 같은지 본다.
/// 인자: actual — Dart 가 만든 구간
///       expected — SciPy 행렬
///       label — 실패 문구 머리
void _expectSections(List<SosSection> actual, Object? expected, String label) {
  final rows = expected as List<dynamic>; // SciPy 행 목록
  expect(actual.length, rows.length, reason: '$label 구간 수');
  for (var i = 0; i < rows.length; i++) {
    final row = _doubles(rows[i]); // SciPy 한 행
    final s = actual[i]; // Dart 한 구간
    const eps = 1e-12; // 계수 허용 오차
    expect(s.b0, closeTo(row[0], eps), reason: '$label[$i].b0');
    expect(s.b1, closeTo(row[1], eps), reason: '$label[$i].b1');
    expect(s.b2, closeTo(row[2], eps), reason: '$label[$i].b2');
    expect(row[3], closeTo(1.0, eps), reason: '$label[$i].a0');
    expect(s.a1, closeTo(row[4], eps), reason: '$label[$i].a1');
    expect(s.a2, closeTo(row[5], eps), reason: '$label[$i].a2');
  }
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: ISO 8041 가중(`RideWeighting`)과 버터워스 고역을 시험한다.
///       - 계수와 출력이 SciPy 정본(`bilinear` · `butter` · `sosfilt` ·
///         `sosfiltfilt`)과 같은지
///       - 가중 크기 응답이 ISO 2631-1 표 값과 맞는지
///       - 승강기 가감속처럼 느린 계단이 수직 최대 P2P 에 들어가지 않는지
///       - 가중을 걸 수 없는 짧거나 성긴 격자를 가려내는지
void main() {
  group('SciPy 정본과 대조', () {
    test('Wd · Wk · 1Hz 고역 계수가 같다', () {
      final cases = _cases(); // 기대값
      final fs = (cases['fs'] as num).toDouble(); // 표본 속도
      _expectSections(RideWeighting.wd(fs), cases['sos_wd'], 'wd');
      _expectSections(RideWeighting.wk(fs), cases['sos_wk'], 'wk');
      _expectSections(
        Butterworth.highpass(order: 2, cutoffHz: 1.0, sampleRateHz: fs),
        cases['sos_hp1'],
        'hp1',
      );
    });

    test('수평 · 수직 가중 출력이 같다', () {
      final cases = _cases(); // 기대값
      final fs = (cases['fs'] as num).toDouble(); // 표본 속도
      final input = _doubles(cases['input']); // 합성 입력
      final wd = RideWeighting.horizontal(input, fs); // 수평 가중
      final vertical = RideWeighting.vertical(input, fs); // 수직 가중
      final expectedWd = _doubles(cases['wd']); // SciPy 수평
      final expectedVertical = _doubles(cases['vertical']); // SciPy 수직
      for (var i = 0; i < input.length; i++) {
        expect(wd[i], closeTo(expectedWd[i], 1e-9), reason: 'wd[$i]');
        expect(
          vertical[i],
          closeTo(expectedVertical[i], 1e-9),
          reason: 'vertical[$i]',
        );
      }
    });
  });

  test('가중 크기 응답이 ISO 2631-1 표 값과 맞는다', () {
    // 디지털 필터의 정상상태 사인 응답을 재서 표 값과 견준다. 쌍선형
    // 변환은 주파수가 높을수록 휘어(100Hz 표본에서 Wd 8Hz 가 −2.2%) 3% 안을
    // 본다. 아날로그 식 자체는 표 값과 소수 셋째 자리까지 같다
    const fs = 100.0; // 표본 속도
    double gain(List<SosSection> sections, double hz) {
      final n = (40 * fs).round(); // 40초
      final x = List<double>.generate(
        n,
        (i) => math.sin(2 * math.pi * hz * i / fs),
      ); // 사인 입력
      final y = RideWeighting.sosfilt(sections, x); // 출력
      var peak = 0.0; // 뒤 절반의 최대 크기
      for (var i = n ~/ 2; i < n; i++) {
        peak = math.max(peak, y[i].abs());
      }
      return peak;
    }

    final wdTable = <double, double>{0.5: 0.853, 1: 1.011, 2: 0.890, 8: 0.253};
    for (final entry in wdTable.entries) {
      expect(
        gain(RideWeighting.wd(fs), entry.key),
        closeTo(entry.value, entry.value * 0.03),
        reason: 'Wd ${entry.key}Hz',
      );
    }
    final wkTable = <double, double>{0.5: 0.418, 1: 0.482};
    for (final entry in wkTable.entries) {
      expect(
        gain(RideWeighting.wk(fs), entry.key),
        closeTo(entry.value, entry.value * 0.03),
        reason: 'Wk ${entry.key}Hz',
      );
    }
  });

  test('느린 계단(가감속)은 수직 최대 P2P 에 들어가지 않는다', () {
    // 5Hz 진동 3 mg 위에 1초에 걸쳐 60 mg 오르는 계단(승강기 출발 가속과
    // 같은 꼴)을 얹는다. 가중 전 최대 − 최소는 계단을 담아 60 을 넘지만,
    // 가중 뒤 최대 반주기 P2P 는 계단 없는 진동만의 값과 거의 같아야 한다.
    // 계단이 꺾이는 곳의 남은 흔들림으로 11% 쯤 커져 15% 안을 본다
    const fs = 100.0; // 표본 속도
    const n = 3000; // 30초
    List<double> wave({required bool withStep}) =>
        List<double>.generate(n, (i) {
          final t = i / fs; // 시각 (초)
          final ramp = t < 10
              ? 0.0
              : t < 11
              ? 30 * (1 - math.cos(math.pi * (t - 10)))
              : 60.0; // 부드러운 계단 (mg)
          return 3 * math.sin(2 * math.pi * 5 * t) + (withStep ? ramp : 0.0);
        });

    final stepped = RideWeighting.vertical(wave(withStep: true), fs);
    final plain = RideWeighting.vertical(wave(withStep: false), fs);
    final withStep = HalfCycle.maximum(stepped, start: 500, end: 2500)!.value;
    final without = HalfCycle.maximum(plain, start: 500, end: 2500)!.value;

    expect(withStep, closeTo(without, without * 0.15));
    expect(withStep, lessThan(15.0), reason: '계단 60 mg 가 섞이지 않는다');
  });

  test('짧거나 성긴 격자는 가중을 걸 수 없다고 알린다', () {
    expect(RideWeighting.canApply(4449, 100), isTrue);
    expect(RideWeighting.canApply(3, 256), isFalse, reason: '덧붙임보다 짧다');
    expect(RideWeighting.canApply(4000, 20), isFalse, reason: 'Wk 를 못 담는다');
  });
}
