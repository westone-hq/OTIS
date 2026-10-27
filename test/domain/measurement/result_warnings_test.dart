import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/measurement/result_warnings.dart';

/// 작성: 2026-10-22 23:00:00 · 박건준
/// 함수: _result
/// 목적: 경고 판정에 넘길 측정 결과. 시계열은 비우고 지표만 채운다.
/// 반환: 시험용 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260114-110359',
    jobNo: 'J-1',
    siteName: '현장',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    model: 'Gen2',
    load: 2000.0,
    loadUnit: 'kg',
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

/// 작성: 2026-10-22 23:00:00 · 박건준
/// 수정: 2026-10-27 12:00:00 · 박건준
/// 함수: main
/// 목적: 결과 화면 경고 문구(`resultWarnings()`)의 차례와 문구를 시험한다.
///       거치 · 미보정 기종 경고는 2026-10-27 에 없앴다.
void main() {
  test('결과 경고는 정지 직후 종료 · 출발 직후 움직임 두 가지뿐이다', () {
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
    ); // 예전에 네 경고가 모두 걸리던 결과
    expect(all, hasLength(2));
    expect(all[0], '정지 후 1초 이상 기다린 뒤 종료하세요 — 끝부분 값이 부정확할 수 있습니다');
    expect(all[1], startsWith('시작 후 2초 기다린 뒤 출발하세요'));
    expect(
      resultWarnings(
        base.copyWith(
          placement: 'tilted',
          deviceCompensation: 'none',
          stopMarginSec: 3.0,
          baselineSource: 'startShortened',
        ),
      ),
      isEmpty,
      reason: '기울어진 거치 · 미보정 기종은 경고하지 않는다',
    );
  });
}
