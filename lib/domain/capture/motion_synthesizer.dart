import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/model/sensor_sample.dart';

/// 목적: 스마트폰에서 실시간으로 들어오는 '가속도 원본(Raw)'과 '중력(Gravity)' 이벤트를 합쳐서 
///       우리가 원하는 순수 진동(Motion) 데이터로 합성해낸다.
///       안드로이드는 가속도와 중력 센서가 각각 다른 주기로 들어오기 때문에 둘의 시점을 맞춰주는 역할이 필요하다.
class MotionSynthesizer {
  NativeEvent? _lastGravity;

  /// 목적: 중력(Gravity) 값을 아직 받지 못해 순수 진동을 계산할 수 없어서 버려진 가속도 이벤트 횟수를 기록한다.
  int droppedNoGravityCount = 0;

  /// 목적: 센서에서 들어오는 이벤트를 받아서 중력(Gravity) 값을 저장해두거나,
  ///       가속도(Raw)가 들어올 때 기존에 저장된 중력을 빼서 순수한 진동 데이터(SensorSample)를 만든다.
  /// 인자: event — 센서에서 방금 들어온 원본 이벤트
  ///       noiseDba — 같은 시점의 소음 측정값 (단위: dBA)
  /// 반환: 계산이 완료된 순수 진동 데이터 객체(SensorSample). 가속도가 아니거나 중력이 미확보 상태면 null을 반환한다.
  /// 식: Motion(순수 진동) = Raw(가속도 원본) - Gravity(중력)
  /// 근거: 인용 — 안드로이드 공식 문서 기반 가속도-중력 분리 물리 공식
  SensorSample? onEvent(NativeEvent event, {required double noiseDba}) {
    switch (event.type) {
      case NativeEventType.gravity:
        _lastGravity = event;
        return null;
      case NativeEventType.linear:
        // OS 기본 제공 linear 가속도는 신뢰성이 떨어지므로 사용하지 않는다.
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
