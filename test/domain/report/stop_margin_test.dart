import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/motion_zones.dart';

import '../../support/otis_1021_records.dart';

/// 작성: 2026-10-22 19:00:00 · nada
/// 함수: main
/// 목적: 운행 끝 뒤 여유(`MeasurementResult.stopMarginSec`)와 Jptp 정지 쪽
///       넓힘이 기록 끝에 막혔는지(`zJptpClippedAtEnd`)를 시험한다.
///       - 합성 구간: 운행 끝 + 넓힘(0.4초)이 마지막 행을 넘으면 막힌다
///       - 실측 11건: 2026-10-22 4건은 정지 뒤 1초를 못 채워 경고 대상이고,
///         개발폰 상승만 넓힘이 막힌다(2026-10-22 점검 표와 같다)
void main() {
  test('운행 끝 뒤 넓힘이 마지막 행을 넘으면 막혔다고 알린다', () {
    const zones = MotionZones(
      runStartIndex: 100,
      runEndIndex: 970,
      steadyStartIndex: 300,
      steadyEndIndex: 800,
      sampleRate: 100,
    ); // 넓힘 40행
    expect(zones.transientPadClippedAtEnd(1011), isFalse, reason: '끝 1010');
    expect(zones.transientPadClippedAtEnd(1010), isTrue, reason: '끝 1009');
  });

  group('실측 기록의 정지 뒤 여유 (점검 표 ±0.02초)', () {
    // 기록 → (여유 초, Jptp 넓힘 막힘)
    const expected = <String, (double, bool)>{
      'dev_up1': (6.60, false),
      'dev_up2': (6.79, false),
      'dev_down3': (8.37, false),
      'otis_up1': (7.55, false),
      'otis_up2': (7.53, false),
      'otis_down3': (9.58, false),
      'ride_reference': (3.57, false),
      'dev_up_1022': (0.27, true),
      'otis_up_1022': (0.63, false),
      'dev_down_1022': (0.46, false),
      'otis_down_1022': (0.98, false),
    };
    final paths = <String, String>{
      ...otis1021Records,
      ...records1022,
      'ride_reference': rideReferencePath,
    }; // 기록 이름 → 경로

    for (final entry in expected.entries) {
      test(entry.key, () {
        final result = assembleRecord(
          paths[entry.key]!,
          flipVertical: faceUpRecords.contains(entry.key),
          deviceModel: deviceModelOf(entry.key),
        ).result!;
        final (margin, clipped) = entry.value;
        expect(result.stopMarginSec, closeTo(margin, 0.02));
        expect(result.zJptpClippedAtEnd, clipped);
        expect(result.stoppedTooSoon, margin < 1.0);
      });
    }
  });
}
