import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-10-07 02:22:28 · nada
/// 함수: _result
/// 목적: 시험용 측정 결과를 만든다. 시계열은 짧게, 지표는 0 이 아닌 값으로
///       둬 저장 · 복원에서 빠진 값이 없는지 보이게 한다.
/// 인자: signalConditioning — 신호 처리 방식. 처리 전 예전 측정이면 null
/// 반환: 시험용 측정 결과
MeasurementResult _result({String? signalConditioning}) {
  return MeasurementResult(
    id: '20261007-022228',
    jobNo: '2025F 1234R01',
    siteName: '시험 현장',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    dateTime: DateTime(2026, 10, 7, 2, 22, 28),
    xPtp: 14.2,
    zA95: 6.2,
    xSeries: const [1.0, 2.0],
    ySeries: const [3.0, 4.0],
    zSeries: const [5.0, 6.0],
    noiseSeries: const [55.0, 56.0],
    positionSeries: const [0.0, 0.1],
    speedSeries: const [0.0, 1.0],
    accelSeries: const [0.0, 0.5],
    jerkSeries: const [0.0, 0.2],
    sampleRate: 100.0,
    signalConditioning: signalConditioning,
  );
}

/// 작성: 2026-10-07 02:22:28 · nada
/// 함수: main
/// 목적: 측정 결과의 신호 처리 방식(`signalConditioning`)이 JSON 저장 ·
///       복원을 거쳐 그대로 남는지, 그 필드가 없던 예전 파일은 null 로
///       읽히는지 시험한다.
void main() {
  test('신호 처리 방식이 JSON 쓰기 · 읽기 왕복에서 그대로 남는다', () {
    final original = _result(
      signalConditioning: 'baseline+lp40bw4zp+rs100',
    ); // 저장할 결과
    final restored = MeasurementResult.fromJson(
      jsonEncode(original.toMap()),
    ); // 되읽은 결과

    expect(restored.signalConditioning, 'baseline+lp40bw4zp+rs100');
    expect(restored.sampleRate, 100.0);
    expect(restored.xPtp, 14.2);
    expect(restored.zA95, 6.2);
    expect(restored.xSeries, original.xSeries);
  });

  test('신호 처리 방식 필드가 없는 예전 JSON 은 null 로 읽는다', () {
    final legacy = _result().toMap()
      ..remove('signalConditioning')
      ..['sampleRate'] = 256.0; // 이 필드가 생기기 전 형태로 되돌린 표
    expect(legacy.containsKey('signalConditioning'), isFalse);

    final restored = MeasurementResult.fromJson(jsonEncode(legacy)); // 되읽음

    expect(restored.signalConditioning, isNull);
    expect(restored.sampleRate, 256.0);
  });
}
