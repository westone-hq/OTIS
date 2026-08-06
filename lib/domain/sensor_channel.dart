import 'dart:async';

import 'package:flutter/services.dart';

import 'package:vibration_checker/domain/capture/motion_synthesizer.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

import 'measure/sensor_sample.dart';
export 'measure/sensor_sample.dart';

/// 안드로이드 네이티브 수집 채널 관리자.
///
/// 네이티브는 보간 전 원본 이벤트(raw·gravity)를 배치로 보낸다 (RD-1, RD-6).
/// 원본 이벤트 스트림이 1차 산출물이며, UI·측정 엔진 호환용 SensorSample 스트림은
/// raw − gravity 합성으로 파생한다. 원본 기록 파일은 네이티브가 저장하고
/// stopCapture 응답으로 경로를 돌려준다.
/// 채널 계약: docs/capture_channel_contract.md
class SensorChannelManager {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.otis.vibration_checker/sensors_method',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.otis.vibration_checker/sensors_stream',
  );

  final bool useMock;

  SensorChannelManager({this.useMock = false});

  final MotionSynthesizer _synthesizer = MotionSynthesizer();
  Stream<(NativeEvent, double)>? _parsedStream;

  /// 판독 실패로 폐기한 채널 항목 수 (RD-4). startCapture 시 0으로 초기화
  int droppedMapCount = 0;

  /// 마지막 startCapture 실패 원인. 정상 시작이면 null (RD-9)
  Object? lastCaptureError;

  /// 마지막 stopCapture 가 돌려준 원본 기록 파일 경로. 못 받았으면 null
  String? lastRecordPath;

  /// 목적: 채널 배치를 (이벤트, 소음값) 쌍의 스트림으로 만든다.
  ///       판독 실패 항목은 폐기하고 집계한다 (RD-4)
  Stream<(NativeEvent, double)> get _events {
    _parsedStream ??= _eventChannel
        .receiveBroadcastStream()
        .expand<(NativeEvent, double)>((batch) {
          final items = batch is List ? batch : <dynamic>[batch];
          final parsed = <(NativeEvent, double)>[];
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
            final noise = item['noiseDba'];
            parsed.add((event, noise is num ? noise.toDouble() : 0.0));
          }
          return parsed;
        })
        .asBroadcastStream();
    return _parsedStream!;
  }

  /// 목적: 보간 전 원본 이벤트 스트림. 1차 산출물 (RD-1)
  Stream<NativeEvent> get nativeEventStream {
    return _events.map((pair) => pair.$1);
  }

  /// 목적: UI·측정 엔진 호환 샘플 스트림.
  ///       raw 이벤트마다 최근 gravity 를 붙여 motion = raw − gravity 로 합성한다.
  ///       샘플의 tsUs 는 raw 이벤트의 실제 센서 시각이다 (보간 격자 아님, RD-1)
  Stream<SensorSample> get sensorStream {
    return _events
        .map((pair) => _synthesizer.onEvent(pair.$1, noiseDba: pair.$2))
        .where((sample) => sample != null)
        .cast<SensorSample>();
  }

  /// 목적: 하드웨어 센서 사용 가능 여부를 확인한다.
  Future<bool> checkSensorsAvailable() async {
    if (useMock) return false;
    try {
      final bool? available = await _methodChannel.invokeMethod<bool>(
        'checkAvailable',
      );
      return available ?? false;
    } catch (_) {
      // 네이티브 확인 불가 시 불가용으로 간주 (테스트 환경 포함)
      return false;
    }
  }

  /// 목적: 마이크 권한을 요청한다.
  Future<bool> requestAudioPermission() async {
    if (useMock) return true;
    try {
      final bool? granted = await _methodChannel.invokeMethod<bool>(
        'requestAudioPermission',
      );
      return granted ?? false;
    } catch (_) {
      return true; // 테스트 환경 대비 기본 허용
    }
  }

  /// 목적: 주기를 정해 수집을 시작한다. 이전 측정 상태를 비운다.
  ///       실패 시 예외를 화면으로 던지지 않고 lastCaptureError 에 보존한다 —
  ///       화면 쪽 3초 미수신 타임아웃이 사용자 안내를 담당한다 (RD-9)
  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {
    _synthesizer.reset();
    droppedMapCount = 0;
    lastCaptureError = null;
    lastRecordPath = null;
    try {
      await _methodChannel.invokeMethod('startCapture', {
        'sampleRate': targetSampleRate,
        'calibrationOffset': calibrationOffsetDba,
        'micDbfsToDbaOffset': micDbfsToDbaOffset,
      });
    } catch (error) {
      lastCaptureError = error;
    }
  }

  /// 목적: 수집을 정지하고 원본 기록 파일 경로를 받아 보존한다.
  ///       스트림 캐시를 비워 다음 시작 시 새로 만든다 (판독서 C7)
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
