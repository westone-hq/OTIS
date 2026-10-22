import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/measurement/result_warnings.dart';

/// 작성: 2026-10-22 23:00:00 · nada
/// 함수: _result
/// 목적: 경고 판정에 넘길 측정 결과. 시계열은 비우고 지표만 채운다.
/// 반환: 시험용 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260114-110359',
    jobNo: 'J-1',
    siteName: '현장',
    address: '서울시',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    model: 'Gen2',
    load: 2000.0,
    loadUnit: 'kg',
    postalCode: '06236',
    dateTime: DateTime(2026, 1, 14, 11),
    xPtp: 26.0,
    yPtp: 5.0,
    zPtp: 8.0,
    noiseMax: 45.0,
    distance: 57.1,
    maxSpeed: 1.74,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-10-22 23:00:00 · nada
/// 함수: main
/// 목적: 결과 화면 경고 문구(`resultWarnings()`)의 차례와 문구를 시험한다.
void main() {
  test('결과 경고는 거치 · 정지 직후 종료 · 출발 직후 움직임 · 미보정 기종 순이다', () {
    final base = _result(); // 경고가 없는 예전 결과
    expect(resultWarnings(base), isEmpty, reason: '예전 결과');
    final all = resultWarnings(
      base.copyWith(
        placement: 'faceUp',
        placementGravityZMg: 998.0,
        stopMarginSec: 0.27,
        baselineSource: 'contaminated',
        deviceModel: 'SM-A536N',
        deviceCompensation: 'none',
      ),
    ); // 네 경고가 모두 걸린 결과
    expect(all, hasLength(4));
    expect(all[0], startsWith('화면 위 거치로 측정됨'));
    expect(all[1], '정지 후 1초 이상 기다린 뒤 종료하세요 — 끝부분 값이 부정확할 수 있습니다');
    expect(all[2], startsWith('시작 후 2초 기다린 뒤 출발하세요'));
    expect(all[3], startsWith('미보정 기종(SM-A536N)'));
    final unknown = resultWarnings(
      base.copyWith(deviceCompensation: 'none'),
    ); // 기종을 모르는 측정
    expect(unknown.single, startsWith('미보정 기종(기종 미확인)'));
    expect(
      resultWarnings(
        base.copyWith(
          deviceModel: 'SM-S901N',
          deviceCompensation: 'lp25.0bw2zp',
          stopMarginSec: 3.0,
          baselineSource: 'startShortened',
        ),
      ),
      isEmpty,
      reason: '보정한 개발폰 · 정지 뒤 3초 · 줄인 기준선',
    );
  });
}
