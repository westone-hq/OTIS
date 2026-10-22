import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';

import '../../support/reference_records.dart';

/// 작성: 2026-10-22 19:00:00 · nada
/// 수정: 2026-10-23 01:00:00 · nada
/// 함수: main
/// 목적: 운행 끝 뒤 여유(`MeasurementResult.stopMarginSec`)와 Jptp 정지 쪽
///       넓힘이 기록 끝에 막혔는지(`zJptpClippedAtEnd`)를 시험한다.
///       - 합성 구간: 운행 끝 + 넓힘(0.4초)이 마지막 행을 넘으면 막힌다
///       - ride_reference: 정지 뒤 여유 3.57초(점검 표 ±0.02초), 막히지
///         않고 경고 대상도 아니다
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

  test('ride_reference 의 정지 뒤 여유 (점검 표 ±0.02초)', () {
    final result = assembleRecord(rideReferencePath).result!;
    expect(result.stopMarginSec, closeTo(3.57, 0.02));
    expect(result.zJptpClippedAtEnd, isFalse);
    expect(result.stoppedTooSoon, isFalse);
  });
}
