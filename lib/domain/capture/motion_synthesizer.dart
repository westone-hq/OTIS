import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

/// raw 와 gravity 원본 이벤트로 motion 샘플을 합성한다.
///
/// motion = raw − gravity (RD-6). gravity 는 raw 보다 드물게 도착할 수 있으므로
/// 가장 최근 gravity 값을 유지해 붙인다 (영점 유지, zero-order hold).
/// linear 이벤트는 사용하지 않는다 (RD-6).
class MotionSynthesizer {
  NativeEvent? _lastGravity;

  /// gravity 미확보 상태에서 도착해 폐기한 raw 이벤트 수.
  /// 측정 시작 직후 gravity 첫 이벤트 이전 구간에서만 증가하는 것이 정상이다
  int droppedNoGravityCount = 0;

  /// 목적: 원본 이벤트 1건을 받아 합성 샘플을 만든다.
  /// 인자: event — 원본 이벤트
  ///       noiseDba — 해당 시점 소음값 (데시벨)
  /// 반환: raw 이벤트이고 gravity 확보 상태면 SensorSample, 그 외 null.
  ///       gravity 미확보 raw 는 폐기하고 droppedNoGravityCount 로 센다.
  ///       반환 샘플의 tsUs 는 raw 이벤트의 실제 센서 시각이다 (보간 격자 아님)
  /// 식:   motionMg = rawMg − gravityMg (축별)
  /// 근거: 측정 — Raw − Gravity = Motion 파이프라인 (기준파일 2024F1447R01 검증)
  SensorSample? onEvent(NativeEvent event, {required double noiseDba}) {
    switch (event.type) {
      case NativeEventType.gravity:
        _lastGravity = event;
        return null;
      case NativeEventType.linear:
        // RD-6: linear 는 검증되지 않아 사용하지 않는다
        return null;
      case NativeEventType.accel:
        final gravity = _lastGravity;
        if (gravity == null) {
          droppedNoGravityCount++;
          return null;
        }
        return SensorSample(
          tsUs: event.tsUs,
          x: event.xMg - gravity.xMg,
          y: event.yMg - gravity.yMg,
          z: event.zMg - gravity.zMg,
          noiseDba: noiseDba,
          rawX: event.xMg,
          rawY: event.yMg,
          rawZ: event.zMg,
          gravityX: gravity.xMg,
          gravityY: gravity.yMg,
          gravityZ: gravity.zMg,
        );
    }
  }

  /// 목적: 새 측정 시작 시 유지 상태를 비운다.
  void reset() {
    _lastGravity = null;
    droppedNoGravityCount = 0;
  }
}
