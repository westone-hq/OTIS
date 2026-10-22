import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';

import '../../support/reference_records.dart';

/// 작성: 2026-10-21 13:10:00 · nada
/// 함수: _trapezoid
/// 목적: 사다리꼴 속도 운행 합성 신호를 만든다. 가속도는 반사인 꼴로
///       오르내려 1.6Hz 저역을 거쳐도 모양이 남는다.
/// 인자: steadySec — 정속 길이 (초). 0 이면 가속 직후 감속
///       sign — 1 이면 상승, -1 이면 하강
/// 반환: (속도 m/s, 저역 가속도 m/s²)
(List<double>, List<double>) _trapezoid({
  required double steadySec,
  int sign = 1,
}) {
  const fs = 100.0; // 표본 속도 (Hz)
  const restSec = 2.0; // 앞뒤 정지 (초)
  const rampSec = 2.0; // 가속 · 감속 길이 (초)
  const peakAccel = 0.6; // 가속 봉우리 (m/s²)
  final total = restSec * 2 + rampSec * 2 + steadySec; // 전체 길이 (초)
  final n = (total * fs).round(); // 표본 수
  final accel = List<double>.filled(n, 0.0); // 가속도 (m/s²)
  for (var i = 0; i < n; i++) {
    final t = i / fs; // 시각 (초)
    final decelStart = restSec + rampSec + steadySec; // 감속 시작 (초)
    if (t >= restSec && t < restSec + rampSec) {
      accel[i] = peakAccel * math.sin(math.pi * (t - restSec) / rampSec);
    } else if (t >= decelStart && t < decelStart + rampSec) {
      accel[i] = -peakAccel * math.sin(math.pi * (t - decelStart) / rampSec);
    }
    accel[i] *= sign;
  }
  final speed = List<double>.filled(n, 0.0); // 속도 (m/s)
  for (var i = 1; i < n; i++) {
    speed[i] = speed[i - 1] + accel[i] / fs;
  }
  return (speed, accel);
}

/// 작성: 2026-10-21 13:10:00 · nada
/// 수정: 2026-10-23 01:00:00 · nada
/// 함수: main
/// 목적: 정속 · 가감속 구간 판정(`MotionZones.of()`)과 그 구간에서 낸 수직
///       지표를 시험한다.
///       - 합성 사다리꼴 운행: 정속 시작 · 끝, 하강, 정속 없음 · 운행 없음
///       - ride_reference: 정속 구간이 점검 참고값과 ±0.3초
///       - 정속 구간 저크가 잔잔한지 (RMS < 0.05 m/s³)
///       - 수직 ptp · Jptp · A95 가 지금 계산값과 ±2%
void main() {
  group('합성 운행', () {
    test('사다리꼴: 정속은 가속이 끝난 뒤부터 감속이 시작되기 전까지다', () {
      final (speed, accel) = _trapezoid(steadySec: 5);
      final zones = MotionZones.of(speed, accel, 100).zones!;
      // 가속 2 ~ 4초, 정속 4 ~ 9초, 감속 9 ~ 11초. 반사인 끝자락이
      // 0.03 m/s² 아래로 내려가는 자리에서 정속이 시작된다
      expect(zones.steadyStartSec, closeTo(4.0, 0.05));
      expect(zones.steadyEndSec, closeTo(9.0, 0.05));
      expect(zones.runStartIndex, lessThan(zones.steadyStartIndex));
      expect(zones.runEndIndex, greaterThan(zones.steadyEndIndex));
    });

    test('하강(속도 · 가속도 부호가 반대)도 같은 구간이다', () {
      final (up, upAccel) = _trapezoid(steadySec: 5);
      final (down, downAccel) = _trapezoid(steadySec: 5, sign: -1);
      final a = MotionZones.of(up, upAccel, 100).zones!;
      final b = MotionZones.of(down, downAccel, 100).zones!;
      expect(b.steadyStartIndex, a.steadyStartIndex);
      expect(b.steadyEndIndex, a.steadyEndIndex);
      expect(b.runStartIndex, a.runStartIndex);
      expect(b.runEndIndex, a.runEndIndex);
    });

    test('정속이 없으면(가속 직후 감속) 실패 사유를 낸다', () {
      final (speed, accel) = _trapezoid(steadySec: 0);
      final result = MotionZones.of(speed, accel, 100);
      expect(result.zones, isNull);
      expect(result.failureReason, contains('정속'));
    });

    test('정속이 1초보다 짧으면 실패한다', () {
      final (speed, accel) = _trapezoid(steadySec: 0.5);
      expect(MotionZones.of(speed, accel, 100).zones, isNull);
    });

    test('움직이지 않으면 운행이 없다는 사유를 낸다', () {
      final still = List<double>.filled(500, 0.0); // 정지
      final result = MotionZones.of(still, still, 100);
      expect(result.zones, isNull);
      expect(result.failureReason, contains('운행이 없다'));
    });

    test('toMap → fromMap 이 같은 구간을 되살린다', () {
      final (speed, accel) = _trapezoid(steadySec: 5);
      final zones = MotionZones.of(speed, accel, 100).zones!;
      final back = MotionZones.fromMap(zones.toMap());
      expect(back.toMap(), zones.toMap());
    });

    test('구간 첨자가 빠진 표는 FormatException', () {
      expect(
        () => MotionZones.fromMap(<String, dynamic>{'sampleRate': 100.0}),
        throwsFormatException,
      );
    });
  });

  group('원본 리포트 기록(ride_reference)의 정속 구간 (점검 참고값과 ±0.3초)', () {
    test('정속 구간이 8.8 ~ 37.3초다', () {
      final result = assembleRecord(rideReferencePath).result!;
      final zones = result.motionZones!;
      expect(zones.steadyStartSec, closeTo(8.8, 0.3));
      expect(zones.steadyEndSec, closeTo(37.3, 0.3));
      expect(result.motionZonesFailure, isNull);
    });

    test('정속 구간 저크는 잔잔하다 (RMS < 0.05 m/s³)', () {
      final result = assembleRecord(rideReferencePath).result!;
      final zones = result.motionZones!;
      var sum = 0.0; // 저크 제곱합
      for (var i = zones.steadyStartIndex; i <= zones.steadyEndIndex; i++) {
        sum += result.jerkSeries[i] * result.jerkSeries[i];
      }
      final rms = math.sqrt(
        sum / (zones.steadyEndIndex - zones.steadyStartIndex + 1),
      ); // 정속 구간 저크 RMS
      expect(rms, lessThan(0.05));
    });
  });

  test('ride_reference 수직 ptp · Jptp · A95 회귀 (지금 계산값 ±2%)', () {
    // 수직 경로 = 가중 뒤 기종 응답 보정(`DeviceResponse`). ride_reference 는
    // 외부 기록이라 보정을 걸지 않는다. 원본 리포트 값은 6.1 / 18.9 / 3.6
    // 이다. Jptp 는 운행 앞뒤 0.4초를 넣는다
    // (`CaptureConfig.zoneTransientPaddingMs`)
    final result = assembleRecord(rideReferencePath).result!;
    expect(result.zPtp, closeTo(5.53, 5.53 * 0.02), reason: 'ptp');
    expect(result.zJptp, closeTo(19.12, 19.12 * 0.02), reason: 'Jptp');
    expect(result.zA95, closeTo(3.71, 3.71 * 0.02), reason: 'A95');
    // 수직 최대는 정속 구간 안에서 났으므로 그 위치도 운행 안이다
    expect(result.zPtpPositionM, inInclusiveRange(0, result.distance!));
  });

  test('정속 구간 평균 속도를 결과에 남긴다(표시 안 함, 2026-10-22)', () {
    final result = assembleRecord(rideReferencePath).result!;
    expect(result.steadySpeedMps, closeTo(1.732, 0.002));
    expect(result.steadySpeedMps!, lessThan(result.maxSpeed!));
  });

  test('구간 판정 상수는 점검 지시 값이다', () {
    expect(CaptureConfig.zoneRunSpeedMps, 0.05);
    expect(CaptureConfig.zonePeakRatio, 0.5);
    expect(CaptureConfig.zoneSteadyAccelMps2, 0.03);
    expect(CaptureConfig.zoneMinimumSteadyMs, 1000);
    expect(CaptureConfig.zoneTransientPaddingMs, 400);
    expect(
      MotionZones.methodLabel,
      'zones(v>0.05,pk0.5,a<0.03,min1000ms,jpad400ms)',
    );
  });
}
