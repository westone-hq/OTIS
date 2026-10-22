import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/report/motion_zones.dart';

import '../../support/otis_1021_records.dart';

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
/// 함수: main
/// 목적: 정속 · 가감속 구간 판정(`MotionZones.of()`)과 그 구간에서 낸 수직
///       지표를 시험한다.
///       - 합성 사다리꼴 운행: 정속 시작 · 끝, 하강, 정속 없음 · 운행 없음
///       - 2026-10-21 동시 측정 6건 · ride_reference: 점검 참고값과 ±0.3초
///       - 정속 구간 저크가 잔잔한지 (RMS < 0.05 m/s³)
///       - 수직 ptp · Jptp · A95 가 지금 계산값과 ±2% (OTIS · 원본 대비는
///         시험 주석 · 작업메모 표로만 남긴다)
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

  group('실측 기록의 정속 구간 (점검 참고값과 ±0.3초)', () {
    const reference = <String, (double, double)>{
      'otis_up1': (7.6, 20.3),
      'otis_up2': (5.8, 18.6),
      'otis_down3': (5.7, 18.4),
      'dev_up1': (8.4, 21.1),
      'dev_up2': (5.6, 18.3),
      'dev_down3': (7.5, 20.2),
    }; // 기록 → (정속 시작, 끝) 초
    final paths = <String, String>{
      ...otis1021Records,
      'ride_reference': rideReferencePath,
    }; // 기록 이름 → 경로

    for (final entry in <String, (double, double)>{
      ...reference,
      'ride_reference': (8.8, 37.3),
    }.entries) {
      test(entry.key, () {
        final result = assembleRecord(paths[entry.key]!).result!;
        final zones = result.motionZones!;
        expect(zones.steadyStartSec, closeTo(entry.value.$1, 0.3));
        expect(zones.steadyEndSec, closeTo(entry.value.$2, 0.3));
        expect(result.motionZonesFailure, isNull);
      });
    }

    test('정속 구간 저크는 잔잔하다 (RMS < 0.05 m/s³)', () {
      for (final path in paths.values) {
        final result = assembleRecord(path).result!;
        final zones = result.motionZones!;
        var sum = 0.0; // 저크 제곱합
        for (var i = zones.steadyStartIndex; i <= zones.steadyEndIndex; i++) {
          sum += result.jerkSeries[i] * result.jerkSeries[i];
        }
        final rms = math.sqrt(
          sum / (zones.steadyEndIndex - zones.steadyStartIndex + 1),
        ); // 정속 구간 저크 RMS
        expect(rms, lessThan(0.05), reason: path);
      }
    });
  });

  group('수직 ptp · Jptp · A95 회귀 (지금 계산값 ±2%)', () {
    // 수직 경로 = 가중 뒤 기종 응답 보정(2026-10-23, `DeviceResponse`).
    // dev_* 는 개발폰(갤럭시 S22)이라 2차 25Hz 저역을 걸고, otis_* ·
    // ride_reference 는 외부 기록이라 걸지 않는다(그 전 2026-10-21 2차 ~
    // 10-22 는 모든 기록에 4차 20Hz 저역).
    // 참고 표(개발폰 ÷ 오티스폰 같은 운행 / OTIS PDF · 원본):
    //   기록         ptp / Jptp / A95       OTIS PDF(원본)
    //   1021 상승1   18.75 / 18.13 / 14.71   20.5 / 17.1 / 15.4
    //   1021 상승2   21.28 / 17.11 / 14.75   19.6 / 19.1 / 15.0
    //   1021 하강3   15.40 / 40.33 / 8.56    13.2 / 32.6 / 9.5
    //   1022 상승    26.31 / 19.54 / 17.71   26.4 / 23.4 / 19.3
    //   1022 하강    17.31 / 23.94 / 11.18   21.0 / 26.4 / 9.7
    //   ride_ref     5.53 / 19.12 / 3.71     6.1 / 18.9 / 3.6
    // Jptp 는 운행 앞뒤 0.4초를 넣는다(`CaptureConfig.zoneTransientPaddingMs`).
    // dev_down3 는 화면을 위로 놓고 기록돼 Z 를 뒤집어 읽는다(P2P 는 같다)
    const pinned = <String, (double, double, double)>{
      'dev_up1': (18.75, 18.13, 14.71),
      'otis_up1': (19.33, 17.91, 14.21),
      'dev_up2': (21.28, 17.11, 14.75),
      'otis_up2': (19.56, 17.31, 14.33),
      'dev_down3': (15.40, 40.33, 8.56),
      'otis_down3': (14.68, 38.39, 8.50),
      'dev_up_1022': (26.31, 19.54, 17.71),
      'otis_up_1022': (25.68, 19.96, 17.06),
      'dev_down_1022': (17.31, 23.94, 11.18),
      'otis_down_1022': (19.37, 24.38, 10.42),
      'ride_reference': (5.53, 19.12, 3.71),
    }; // 기록 → (ptp, Jptp, A95) mg
    final paths = <String, String>{
      ...otis1021Records,
      ...records1022,
      'ride_reference': rideReferencePath,
    }; // 기록 이름 → 경로

    for (final entry in pinned.entries) {
      test(entry.key, () {
        final result = assembleRecord(
          paths[entry.key]!,
          flipVertical: faceUpRecords.contains(entry.key),
          deviceModel: deviceModelOf(entry.key),
        ).result!;
        final (ptp, jptp, a95) = entry.value;
        expect(result.zPtp, closeTo(ptp, ptp * 0.02), reason: 'ptp');
        expect(result.zJptp, closeTo(jptp, jptp * 0.02), reason: 'Jptp');
        expect(result.zA95, closeTo(a95, a95 * 0.02), reason: 'A95');
        // 수직 최대는 정속 구간 안에서 났으므로 그 위치도 운행 안이다
        expect(result.zPtpPositionM, inInclusiveRange(0, result.distance!));
      });
    }
  });

  test('정속 구간 평균 속도를 결과에 남긴다(표시 안 함, 2026-10-22)', () {
    // 2026-10-21 파이썬 계산(작업메모)과 같은 값. OTIS 표시값은 1.50 · 1.75
    const expected = <String, double>{
      'otis_up1': 1.522,
      'otis_up2': 1.512,
      'otis_down3': 1.480,
      'dev_up1': 1.507,
      'dev_up2': 1.503,
      'dev_down3': 1.517,
      'ride_reference': 1.732,
    }; // 기록 → 정속 평균 (m/s)
    final paths = <String, String>{
      ...otis1021Records,
      'ride_reference': rideReferencePath,
    }; // 기록 이름 → 경로
    for (final entry in expected.entries) {
      final result = assembleRecord(
        paths[entry.key]!,
        flipVertical: faceUpRecords.contains(entry.key),
      ).result!;
      expect(
        result.steadySpeedMps,
        closeTo(entry.value, 0.002),
        reason: entry.key,
      );
      expect(result.steadySpeedMps!, lessThan(result.maxSpeed!));
    }
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
