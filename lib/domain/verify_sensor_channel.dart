import 'dart:async';

import 'package:flutter/services.dart';

import 'measure/sample_rate.dart';

enum VerifyMode { fastest, fixed, requested128, requested64 }

/// 검증 전용 센서 채널 (측정용 [SensorChannelManager]와 분리).
///
/// Android 측정 방식별 MethodChannel/EventChannel을 선택한다.
/// - fastest: FASTEST(≈3~7ms)
/// - fixed: 1000µs와 3000µs 동시 수신
/// - requested128: 128Hz Core 하나만 단독 실행
/// - requested64: 64Hz Core 하나만 단독 실행
class VerifySensorChannel {
  VerifySensorChannel(VerifyMode mode)
    : _method = MethodChannel(_methodChannelName(mode)),
      _event = EventChannel(_eventChannelName(mode));

  final MethodChannel _method;
  final EventChannel _event;

  Stream<dynamic>? _stream;

  static String _methodChannelName(VerifyMode mode) => switch (mode) {
    VerifyMode.fastest => 'com.otis.vibration_checker/verify_fastest_method',
    VerifyMode.fixed => 'com.otis.vibration_checker/verify_fixed_method',
    VerifyMode.requested128 => 'com.otis.vibration_checker/verify_128_method',
    VerifyMode.requested64 => 'com.otis.vibration_checker/verify_64_method',
  };

  static String _eventChannelName(VerifyMode mode) => switch (mode) {
    VerifyMode.fastest => 'com.otis.vibration_checker/verify_fastest_stream',
    VerifyMode.fixed => 'com.otis.vibration_checker/verify_fixed_stream',
    VerifyMode.requested128 => 'com.otis.vibration_checker/verify_128_stream',
    VerifyMode.requested64 => 'com.otis.vibration_checker/verify_64_stream',
  };

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
