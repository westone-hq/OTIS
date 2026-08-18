// 작성: 2026-08-17 15:35:02
// 작성자: 박건준

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:vibration_checker/domain/capture/native_event.dart';

export 'package:vibration_checker/model/sensor_sample.dart';

/// 클래스: SensorChannelManager
/// 목적: Flutter(UI)와 안드로이드(하드웨어) 사이에서 센서 데이터를
///       주고받는 다리 역할을 한다.
///       - `MethodChannel`(Flutter와 네이티브(안드로이드 쪽 코틀린 코드)가
///         요청 하나 · 응답 하나를 주고받는 통로)로 센서 확인 · 측정
///         시작 · 종료 같은 명령을 보낸다
///       - `EventChannel`(네이티브가 데이터를 계속 흘려보내는 통로)로
///         가속도 · 중력 센서 원본 데이터를 배치(batch, 여러 개를
///         묶은 덩어리)로 받는다
class SensorChannelManager {
  /// Flutter ↔ 안드로이드가 요청 하나 · 응답 하나를 주고받는 통로.
  /// 양쪽은 이 문자열 하나만으로 서로를 찾는다 — Dart 코드와 코틀린 코드
  /// 사이에는 컴파일러가 대신 검사해주는 연결이 없어서, 한쪽 문자열만
  /// 바뀌면 컴파일은 그대로 되지만 실행할 때 요청이 반대편에 닿지 않고
  /// 조용히 실패한다(예외 없이 응답만 안 옴). 이름을 바꿀 일이 생기면
  /// `MainActivity.kt`에 등록된 문자열도 반드시 같이 바꿔야 한다
  static const MethodChannel _methodChannel = MethodChannel(
    'com.otis.vibration_checker/sensors_method',
  );

  /// 안드로이드 → Flutter로 센서 원본 데이터가 계속 흘러오는 통로.
  /// 문자열 하나로 식별되고, 양쪽을 같이 바꿔야 하는 이유는
  /// `_methodChannel`과 같다
  static const EventChannel _eventChannel = EventChannel(
    'com.otis.vibration_checker/sensors_stream',
  );

  /// 테스트 · 개발용 가짜 모드 여부. true면 안드로이드에 실제로 묻지
  /// 않고 정해둔 값만 돌려준다
  final bool useMock;

  SensorChannelManager({this.useMock = false});

  Stream<NativeEvent>? _parsedStream;

  /// 안드로이드가 보낸 데이터 중 형태가 깨졌거나 이상해서 버린 개수
  int droppedMapCount = 0;

  /// 방금 시도한 측정 관련 요청이 실패했을 때 화면에 보여줄 한국어 요약
  /// 문구. 원본 예외는 `developer.log`로만 남긴다. 성공했으면 null
  String? lastCaptureError;

  /// 측정을 끝냈을 때 안드로이드가 저장해준 원본 텍스트 파일의 위치(경로).
  /// 아직 측정한 적 없거나 실패했으면 null
  String? lastRecordPath;

  /// 함수: nativeEventStream
  /// 목적: 안드로이드에서 배치(batch, 여러 개를 묶은 덩어리)로 보내는
  ///       원본 데이터를 센서 이벤트 스트림(stream, 값이 시간차를 두고
  ///       하나씩 계속 흘러나오는 것)으로 풀어 그대로 내보낸다.
  ///       가공(보간 · 필터 · 보정)은 하지 않는다.
  /// 반환: `NativeEvent`(센서 원본 이벤트 하나를 담는 자료형) 스트림.
  ///       형태가 깨진 데이터는 걸러내고 `droppedMapCount`만 늘린다
  Stream<NativeEvent> get nativeEventStream {
    _parsedStream ??= _eventChannel
        .receiveBroadcastStream()
        .expand<NativeEvent>((batch) {
          final items = batch is List
              ? batch
              : <dynamic>[batch]; // 배치를 리스트 형태로 통일
          final parsed = <NativeEvent>[]; // 이번 배치에서 걸러낸 정상 이벤트
          for (final item in items) {
            if (item is! Map) {
              droppedMapCount++;
              continue;
            }
            final event = NativeEvent.fromChannelMap(item); // 변환 실패 시 null
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

  /// 함수: checkSensorsAvailable
  /// 목적: 이 기기에 가속도 · 중력 센서가 실제로 있는지 안드로이드에
  ///       물어봐서 확인한다.
  ///       - `useMock`이면 안드로이드에 묻지 않고 항상 false를 돌려준다
  ///       - 정상 응답이 오면 그 값을 그대로 돌려준다
  ///       - 안드로이드 쪽에서 예외가 나면 원인은 로그로만 남기고,
  ///         `lastCaptureError`에 화면에 보여줄 문구를 채운 뒤 false를
  ///         돌려준다
  /// 반환: 센서를 실제로 쓸 수 있으면 true. `useMock`이거나 확인 요청이
  ///       실패하면 false
  Future<bool> checkSensorsAvailable() async {
    if (useMock) return false;
    try {
      // → 로직 이동: MainActivity.kt의 checkAvailable
      final bool? available = await _methodChannel.invokeMethod<bool>(
        'checkAvailable',
      );
      // available: 안드로이드가 돌려준 값. 요청 자체가 실패하면 null
      return available ?? false;
    } catch (error, stack) {
      // 원인을 삼키지 않고 로그로 남긴다. 반환 동작(false)은 유지.
      developer.log(
        'checkSensorsAvailable 실패',
        name: 'SensorChannel',
        error: error,
        stackTrace: stack,
      );
      lastCaptureError = '센서 확인 요청이 실패했습니다.';
      return false;
    }
  }

  /// 함수: requestAudioPermission
  /// 목적: 소음 측정을 위해 폰의 마이크 사용 권한을 사용자에게 물어본다.
  ///       현재는 소음 캡처 기능 자체가 꺼져 있어, 실제 요청 없이 항상
  ///       성공(true)만 돌려준다.
  /// 반환: 항상 true
  Future<bool> requestAudioPermission() async {
    return true;
  }

  /// 함수: startCapture
  /// 목적: 안드로이드에게 지정된 속도(Hz)로 센서 데이터를 쏴 달라고
  ///       명령을 내린다. 시작 전에 이전 측정 기록(폐기 개수 · 오류
  ///       문구 · 저장 경로)을 모두 초기화한다.
  /// 반환: 없음. 요청이 실패하면 원인은 `debugPrint`로 남기고
  ///       `lastCaptureError`에 화면에 보여줄 문구를 채운다
  Future<void> startCapture() async {
    droppedMapCount = 0;
    lastCaptureError = null;
    lastRecordPath = null;
    try {
      await _methodChannel.invokeMethod('startCapture');
    } catch (error) {
      debugPrint('startCapture 실패: $error');
      lastCaptureError = '측정 시작 요청이 실패했습니다.';
    }
  }

  /// 함수: stopCapture
  /// 목적: 안드로이드에게 그만 보내고 지금까지 모은 걸 파일로 저장해
  ///       경로를 알려달라고 명령을 내린다. 0.5초 안에 응답이 없거나
  ///       실패하면 포기하고 넘어간다.
  /// 반환: 없음. 성공하면 `lastRecordPath`에 저장 경로를, 실패하거나
  ///       시간 초과되면 null을 담는다
  Future<void> stopCapture() async {
    try {
      final String? path = await _methodChannel
          .invokeMethod<String>('stopCapture')
          .timeout(const Duration(milliseconds: 500)); // 응답 대기 한도
      lastRecordPath = path;
    } catch (_) {
      lastRecordPath = null;
    }
    _parsedStream = null; // 다음 측정을 위해 이전 스트림 캐시를 비운다
  }
}
