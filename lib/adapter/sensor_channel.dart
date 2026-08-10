import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'package:vibration_checker/domain/capture/native_event.dart';

export 'package:vibration_checker/model/sensor_sample.dart';

/// 목적: 플러터(UI)와 안드로이드(하드웨어) 사이에서 센서 데이터를 주고받는 다리 역할을 한다.
///       안드로이드에서 가속도와 중력 센서 데이터를 묶음(배치)으로 쏴주면,
///       이곳에서 받아서 1. 원본 그대로 저장할 수 있게 넘겨주고, 2. 화면이나 분석 엔진이 쓸 수 있게 순수 진동(Motion)으로 조립해서 넘겨준다.
class SensorChannelManager {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.otis.vibration_checker/sensors_method',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.otis.vibration_checker/sensors_stream',
  );

  final bool useMock;

  SensorChannelManager({this.useMock = false});

  Stream<NativeEvent>? _parsedStream;

  /// 목적: 안드로이드에서 쏴준 데이터 중 형태가 깨졌거나 이상해서 버린 데이터의 개수
  int droppedMapCount = 0;

  /// 목적: 방금 측정 시작 시도 중 에러가 났다면 그 에러 내용을 담아둔다. (정상이면 null)
  Object? lastCaptureError;

  /// 목적: 측정을 끝냈을 때, 안드로이드가 저장해준 원본 텍스트 파일의 위치(경로)를 기억한다.
  String? lastRecordPath;

  /// 목적: 안드로이드에서 무더기로 던져주는 데이터를 센서 이벤트로 풀어서 물흐르듯(Stream) 계속 내보낸다.
  Stream<NativeEvent> get _events {
    _parsedStream ??= _eventChannel
        .receiveBroadcastStream()
        .expand<NativeEvent>((batch) {
          final items = batch is List ? batch : <dynamic>[batch];
          final parsed = <NativeEvent>[];
          for (final item in items) {
            if (item is! Map) {
              droppedMapCount++;
              continue;
            }
            final event = NativeEvent.fromChannelMap(item);
            if (event == null) {
              droppedMapCount++;
              continue;
            }
            parsed.add(event);
          }
          return parsed;
        })
        .asBroadcastStream();
    return _parsedStream!;
  }

  /// 목적: 가공되지 않은 센서 원본(Raw) 데이터만 흘려보내는 파이프(스트림). 텍스트 파일 저장용으로 쓰인다.
  Stream<NativeEvent> get nativeEventStream {
    return _events;
  }

  /// 목적: 이 스마트폰에 우리가 필요한 센서(가속도, 중력)가 멀쩡히 달려있는지 안드로이드에 물어본다.
  Future<bool> checkSensorsAvailable() async {
    if (useMock) return false;
    try {
      final bool? available = await _methodChannel.invokeMethod<bool>(
        'checkAvailable',
      );
      return available ?? false;
    } catch (error, stack) {
      // 원인을 삼키지 않고 로그로 남긴다. 반환 동작(false)은 유지.
      developer.log(
        'checkSensorsAvailable 실패',
        name: 'SensorChannel',
        error: error,
        stackTrace: stack,
      );
      lastCaptureError = error;
      return false;
    }
  }

  /// 목적: 소음 측정을 위해 폰의 마이크 사용 권한을 사용자에게 물어본다.
  Future<bool> requestAudioPermission() async {
    if (useMock) return true;
    try {
      final bool? granted = await _methodChannel.invokeMethod<bool>(
        'requestAudioPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 목적: 안드로이드에게 "지금부터 지정된 속도(Hz)로 센서 데이터 쏴줘!" 라고 명령을 내린다.
  ///       시작 전에 이전 측정 기록들을 모두 초기화한다.
  Future<void> startCapture() async {
    droppedMapCount = 0;
    lastCaptureError = null;
    lastRecordPath = null;
    try {
      await _methodChannel.invokeMethod('startCapture');
    } catch (error) {
      lastCaptureError = error;
    }
  }

  /// 목적: 안드로이드에게 "이제 그만 쏴도 돼. 지금까지 모은 거 파일로 저장해서 경로 알려줘!" 라고 명령을 내린다.
  Future<void> stopCapture() async {
    try {
      final String? path = await _methodChannel
          .invokeMethod<String>('stopCapture')
          .timeout(const Duration(milliseconds: 500));
      lastRecordPath = path;
    } catch (_) {
      lastRecordPath = null;
    }
    _parsedStream = null;
  }
}
