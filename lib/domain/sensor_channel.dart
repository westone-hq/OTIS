import 'dart:async';
import 'package:flutter/services.dart';

import 'measure/sample_rate.dart';
import 'measure/sensor_sample.dart';
export 'measure/sensor_sample.dart';

/// P11 · 안드로이드 Kotlin 센서 채널 관리자 (구조 및 인터페이스 정의)
/// - 나중에 UI(S4 MeasuringScreen) 및 기능 계층 통합을 고려하여 설계된 뼈대 구조
///
/// [기술적 대비 및 주의사항]
/// 1. S22 샘플링 주파수 보간:
///    - 분석용 목표 간격은 [SampleRate] (기본 256Hz ≈ 3906µs) 단일 정의.
///      Flutter가 startCapture(sampleRate)로 넘기고, 네이티브가 1e9/rate ns로 리샘플한다.
///      하드웨어 콜백은 FASTEST 등으로 더 빠를 수 있으며, OS 간격은 불규칙할 수 있음.
/// 2. 마이크 소음(dBA) 물리 보정:
///    - AudioRecord 버퍼 RMS 계산 후 dBA 환산 시 계측기와의 오차 보정을 위해
///      startCapture 시 [calibrationOffsetDba] 파라미터로 기준 오프셋 주입 구조 마련.
class SensorChannelManager {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.otis.vibration_checker/sensors_method',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.otis.vibration_checker/sensors_stream',
  );

  final bool useMock;

  SensorChannelManager({this.useMock = false});

  Stream<SensorSample>? _sampleStream;

  /// 256Hz 가속도 + dBA 소음 복합 센서 스트림 수신 (단건 Map 및 32샘플 배칭 List<Map> 모두 지원)
  Stream<SensorSample> get sensorStream {
    _sampleStream ??= _eventChannel
        .receiveBroadcastStream()
        .expand<SensorSample>((event) {
          if (event is List) {
            return event.map(
              (e) => e is Map
                  ? SensorSample.fromMap(e)
                  : const SensorSample(tsUs: 0, x: 0, y: 0, z: 0, noiseDba: 0),
            );
          } else if (event is Map) {
            return [SensorSample.fromMap(event)];
          }
          return const [];
        });
    return _sampleStream!;
  }

  /// 하드웨어 센서(가속도계, 마이크) 사용 가능 여부 확인
  Future<bool> checkSensorsAvailable() async {
    if (useMock) return false;
    try {
      final bool? available = await _methodChannel.invokeMethod<bool>(
        'checkAvailable',
      );
      return available ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 마이크 권한 요청
  Future<bool> requestAudioPermission() async {
    if (useMock) return true;
    try {
      final bool? granted = await _methodChannel.invokeMethod<bool>(
        'requestAudioPermission',
      );
      return granted ?? false;
    } catch (_) {
      return true;
    }
  }

  /// 센서 캡처 시작 (목표 샘플링 주파수 및 소음 오프셋 주입)
  Future<void> startCapture({
    int targetSampleRate = SampleRate.hz,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {
    try {
      await _methodChannel.invokeMethod('startCapture', {
        'sampleRate': targetSampleRate,
        'calibrationOffset': calibrationOffsetDba,
        'micDbfsToDbaOffset': micDbfsToDbaOffset,
      });
    } catch (_) {}
  }

  /// 센서 캡처 중단.
  /// 반환: {native3to7, native1to3} 임시 파일 경로 (없으면 해당 키 없음)
  Future<Map<String, String>> stopCapture() async {
    try {
      final dynamic raw = await _methodChannel
          .invokeMethod('stopCapture')
          .timeout(const Duration(milliseconds: 2000));
      if (raw is Map) {
        final out = <String, String>{};
        for (final e in raw.entries) {
          final v = e.value;
          if (v is String && v.isNotEmpty) {
            out[e.key.toString()] = v;
          }
        }
        return out;
      }
      // 구버전: 단일 String 경로 → 1to3로 취급
      if (raw is String && raw.isNotEmpty) {
        return {'native1to3': raw};
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
