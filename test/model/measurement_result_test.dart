import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/report/motion_zones.dart';
import 'package:vibration_checker/domain/report/travel_window.dart';
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
/// 수정: 2026-10-11 16:58:59 · nada
/// 함수: main
/// 목적: 측정 결과의 신호 처리 방식(`signalConditioning`)과 현장 정보 새
///       항목(하중 · 단위 · 해석 종류 · 우편번호 · 참고사항)이 JSON 저장 ·
///       복원을 거쳐 그대로 남는지, 그 필드가 없던 예전 파일은 null 로
///       읽히는지 시험한다.
void main() {
  test('현장 정보 새 항목이 JSON 쓰기 · 읽기 왕복에서 그대로 남는다', () {
    final original = _result().copyWith(
      load: 2000.0,
      loadUnit: 'kg',
      analysisType: '사이클 저크(가속도증가율) 테스트',
      postalCode: '10575',
      notes: '도어 쪽 소음 큼\n다음 점검 때 재측정',
      engineerName: '홍길동',
    ); // 저장할 결과
    final restored = MeasurementResult.fromJson(
      jsonEncode(original.toMap()),
    ); // 되읽은 결과

    expect(restored.load, 2000.0);
    expect(restored.loadUnit, 'kg');
    expect(restored.analysisType, '사이클 저크(가속도증가율) 테스트');
    expect(restored.postalCode, '10575');
    expect(restored.notes, '도어 쪽 소음 큼\n다음 점검 때 재측정');
    expect(restored.engineerName, '홍길동');
  });

  test('현장 정보 새 항목이 없는 예전 JSON 은 모두 null 로 읽는다', () {
    final legacy = _result().toMap()
      ..remove('load')
      ..remove('loadUnit')
      ..remove('analysisType')
      ..remove('postalCode')
      ..remove('notes')
      ..remove('engineerName'); // 이 필드들이 생기기 전 형태로 되돌린 표

    final restored = MeasurementResult.fromJson(jsonEncode(legacy)); // 되읽음

    expect(restored.load, isNull);
    expect(restored.loadUnit, isNull);
    expect(restored.analysisType, isNull);
    expect(restored.postalCode, isNull);
    expect(restored.notes, isNull);
    expect(restored.engineerName, isNull);
  });

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

  test('운행 구간과 그 실패 사유가 JSON 왕복에서 그대로 남는다', () {
    const window = TravelWindow(
      startIndex: 625,
      endIndex: 3955,
      startSec: 6.25,
      endSec: 39.55,
      startM: 0.503,
      endM: 56.593,
    ); // 운행 구간
    final withWindow = MeasurementResult.fromJson(
      jsonEncode(_result().copyWith(travelWindow: window).toMap()),
    ); // 구간이 있는 결과
    expect(withWindow.travelWindow!.startIndex, 625);
    expect(withWindow.travelWindow!.endSec, 39.55);
    expect(withWindow.travelWindowFailure, isNull);

    final failed = MeasurementResult.fromJson(
      jsonEncode(
        _result().copyWith(travelWindowFailure: '운행 거리가 1.0m 이하다').toMap(),
      ),
    ); // 구간을 못 정한 결과
    expect(failed.travelWindow, isNull);
    expect(failed.travelWindowFailure, '운행 거리가 1.0m 이하다');

    final legacy = _result().toMap()
      ..remove('travelWindow')
      ..remove('travelWindowFailure'); // 2026-10-15 이전 형태
    final old = MeasurementResult.fromJson(jsonEncode(legacy)); // 예전 결과
    expect(old.travelWindow, isNull);
    expect(old.travelWindowFailure, isNull);
  });

  test('정속 구간 · Jptp · 최대 위치가 JSON 왕복에서 그대로 남는다', () {
    const zones = MotionZones(
      runStartIndex: 300,
      runEndIndex: 2500,
      steadyStartIndex: 760,
      steadyEndIndex: 2030,
      sampleRate: 100,
    ); // 정속 · 가감속 구간
    final back = MeasurementResult.fromJson(
      jsonEncode(
        _result()
            .copyWith(
              zPtp: 19.3,
              zJptp: 17.9,
              zPtpPositionM: 18.0,
              motionZones: zones,
            )
            .toMap(),
      ),
    ); // 왕복한 결과
    expect(back.zJptp, 17.9);
    expect(back.zPtpPositionM, 18.0);
    expect(back.motionZones!.toMap(), zones.toMap());
    expect(back.motionZones!.steadyStartSec, 7.6);
    expect(back.motionZonesFailure, isNull);

    final failed = MeasurementResult.fromJson(
      jsonEncode(_result().copyWith(motionZonesFailure: '정속 없음').toMap()),
    ); // 구간을 못 정한 결과
    expect(failed.motionZones, isNull);
    expect(failed.motionZonesFailure, '정속 없음');

    final legacy = _result().toMap()
      ..remove('zJptp')
      ..remove('zPtpPositionM')
      ..remove('motionZones')
      ..remove('motionZonesFailure'); // 2026-10-21 이전 형태
    final old = MeasurementResult.fromJson(jsonEncode(legacy)); // 예전 결과
    expect(old.zJptp, isNull);
    expect(old.zPtpPositionM, isNull);
    expect(old.motionZones, isNull);
    expect(old.motionZonesFailure, isNull);
  });

  test('거치 방향과 그 중력 Z 가 JSON 왕복에서 남고 예전 파일은 null 이다', () {
    final back = MeasurementResult.fromJson(
      jsonEncode(
        _result()
            .copyWith(placement: 'faceUp', placementGravityZMg: 998.5)
            .toMap(),
      ),
    ); // 왕복한 결과
    expect(back.placement, 'faceUp');
    expect(back.placementKind, Placement.faceUp);
    expect(back.placementGravityZMg, 998.5);
    final speed = MeasurementResult.fromJson(
      jsonEncode(_result().copyWith(steadySpeedMps: 1.507).toMap()),
    ); // 정속 평균 속도를 실은 결과
    expect(speed.steadySpeedMps, 1.507);

    final legacy = _result().toMap()
      ..remove('placement')
      ..remove('placementGravityZMg')
      ..remove('steadySpeedMps'); // 2026-10-22 이전 형태
    final old = MeasurementResult.fromJson(jsonEncode(legacy)); // 예전 결과
    expect(old.placement, isNull);
    expect(old.placementKind, isNull);
    expect(old.placementGravityZMg, isNull);
    expect(old.steadySpeedMps, isNull);
  });

  test('기종 · 보정 · 정지 뒤 여유 · 기준선 출처가 왕복에서 남고 예전 파일은 '
      '경고를 띄우지 않는다', () {
    final back = MeasurementResult.fromJson(
      jsonEncode(
        _result()
            .copyWith(
              deviceManufacturer: 'samsung',
              deviceModel: 'SM-A536N',
              deviceCompensation: 'none',
              stopMarginSec: 0.46,
              zJptpClippedAtEnd: true,
              baselineSource: 'contaminated',
            )
            .toMap(),
      ),
    ); // 왕복한 결과
    expect(back.deviceManufacturer, 'samsung');
    expect(back.deviceModel, 'SM-A536N');
    expect(back.deviceCompensation, 'none');
    expect(back.stopMarginSec, 0.46);
    expect(back.zJptpClippedAtEnd, isTrue);
    expect(back.baselineSource, 'contaminated');
    expect(back.uncompensatedDevice, isTrue);
    expect(back.stoppedTooSoon, isTrue);
    expect(back.baselineContaminated, isTrue);

    final old = MeasurementResult.fromJson(
      jsonEncode(_result().toMap()),
    ); // 2026-10-23 전 형태(필드 없음)
    expect(old.deviceCompensation, isNull);
    expect(old.uncompensatedDevice, isFalse);
    expect(old.stoppedTooSoon, isFalse);
    expect(old.baselineContaminated, isFalse);
    expect(
      _result().copyWith(stopMarginSec: 1.0).stoppedTooSoon,
      isFalse,
      reason: '1초면 경고하지 않는다',
    );
  });

  test('측정 일시가 없거나 깨졌으면 지금 시각으로 채우지 않고 실패한다', () {
    final missing = _result().toMap()..remove('dateTime'); // 일시 없음
    final broken = _result().toMap()..['dateTime'] = '어제쯤'; // 일시 깨짐
    expect(
      () => MeasurementResult.fromJson(jsonEncode(missing)),
      throwsFormatException,
    );
    expect(
      () => MeasurementResult.fromJson(jsonEncode(broken)),
      throwsFormatException,
    );
    final normal = MeasurementResult.fromJson(
      jsonEncode(_result().toMap()),
    ); // 정상 결과
    expect(normal.dateTime, _result().dateTime);
  });
}
