import 'dart:async';

import 'package:flutter/services.dart';

import 'measure/sample_rate.dart';

enum VerifyMode { fastest, fixed }

/// 검증 전용 센서 채널 (측정용 [SensorChannelManager]와 분리).
///
/// Android 핵심도 두 파일/두 채널로 분리되어 서로 모드를 관리하지 않는다.
/// - fastest: FASTEST(≈3~7ms)
/// - fixed: 1000µs와 3000µs 동시 수신
/// - 각 요청 스트림을 독립적으로 [SampleRate.hz] (256)로 선형 보간
class VerifySensorChannel {
  VerifySensorChannel(VerifyMode mode)
    : _method = MethodChannel(
        mode == VerifyMode.fastest
            ? 'com.otis.vibration_checker/verify_fastest_method'
            : 'com.otis.vibration_checker/verify_fixed_method',
      ),
      _event = EventChannel(
        mode == VerifyMode.fastest
            ? 'com.otis.vibration_checker/verify_fastest_stream'
            : 'com.otis.vibration_checker/verify_fixed_stream',
      );

  final MethodChannel _method;
  final EventChannel _event;

  Stream<dynamic>? _stream;

  /// lane별 stats 이벤트를 그대로 흘려보낸다.
  Stream<dynamic> get events {
    _stream ??= _event.receiveBroadcastStream();
    return _stream!;
  }

  Future<void> start({int targetSampleRate = SampleRate.hz}) async {
    await _method.invokeMethod('start', {'sampleRate': targetSampleRate});
  }

  /// Android가 모든 파일을 flush한 뒤 임시 경로를 한 Map으로 반환한다.
  Future<Map<String, String>> stop() async {
    final dynamic raw = await _method.invokeMethod('stop');
    if (raw is! Map) return {};
    final paths = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String && value.isNotEmpty) {
        paths[entry.key.toString()] = value;
      }
    }
    return paths;
  }
}
