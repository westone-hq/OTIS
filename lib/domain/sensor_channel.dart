import 'dart:async';
import 'package:flutter/services.dart';

import 'measure/sensor_sample.dart';
export 'measure/sensor_sample.dart';

/// P11 · 안드로이드 Kotlin 센서 채널 관리자 (구조 및 인터페이스 정의)
/// - 나중에 UI(S4 MeasuringScreen) 및 기능 모듈 통합을 고려하여 설계된 뼈대 구조
/// 
/// [기술적 대비 및 주의사항]
/// 1. S22 샘플링 주파수 보간:
///    - 안드로이드 SensorManager에서 SENSOR_DELAY_FASTEST 또는 3906㎲(256Hz) 요청 시
///      하드웨어가 약 400~500Hz 콜백을 생성할 수 있음.
///    - OS 콜백 지연 불균일성을 보완하기 위해 네이티브 또는 Dart 스트림 수신 단에서
///      타임스탬프 기반 선형 보간(Linear Interpolation) 적용 예정.
/// 2. 마이크 소음(dBA) 물리 보정:
///    - AudioRecord 버퍼 RMS 계산 후 dBA 환산 시 계측기와의 오차 보정을 위해
///      startCapture 시 [calibrationOffsetDba] 파라미터로 기준 오프셋 주입 구조 마련.
class SensorChannelManager {
  static const MethodChannel _methodChannel =
      MethodChannel('com.otis.vibration_checker/sensors_method');
  static const EventChannel _eventChannel =
      EventChannel('com.otis.vibration_checker/sensors_stream');

  Stream<SensorSample>? _sampleStream;

  /// 256Hz 가속도 + dBA 소음 복합 센서 스트림 수신
  Stream<SensorSample> get sensorStream {
    _sampleStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) {
            return SensorSample.fromMap(event);
          }
          return const SensorSample(tsUs: 0, x: 0, y: 0, z: 0, noiseDba: 0);
        });
    return _sampleStream!;
  }

  /// 하드웨어 센서(가속도계, 마이크) 사용 가능 여부 확인
  Future<bool> checkSensorsAvailable() async {
    try {
      final bool? available =
          await _methodChannel.invokeMethod<bool>('checkAvailable');
      return available ?? false;
    } catch (_) {
      // 네이티브 모듈 구현 전 fallback (테스트/목업용)
      return true;
    }
  }

  /// 센서 캡처 시작 (목표 샘플링 주파수 및 소음 오프셋 주입)
  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
  }) async {
    try {
      await _methodChannel.invokeMethod('startCapture', {
        'sampleRate': targetSampleRate,
        'calibrationOffset': calibrationOffsetDba,
      });
    } catch (_) {
      // 구현 전 fallback (위젯 및 모듈 통합 테스트 시 안전한 진행)
    }
  }

  /// 센서 캡처 중단
  Future<void> stopCapture() async {
    try {
      await _methodChannel.invokeMethod('stopCapture');
    } catch (_) {
      // fallback
    }
  }
}
