import 'dart:async';

import 'measure/sensor_sample.dart';
export 'measure/sensor_sample.dart';

/// [골격] 본문 미구현. 시그니처는 docs/ui_contract.md §2.5 기준.
/// 구현 예정: P6
class SensorChannelManager {
  final bool useMock;

  SensorChannelManager({this.useMock = false});

  Stream<SensorSample> get sensorStream {
    throw UnimplementedError('P6 구현 예정');
  }

  Future<bool> checkSensorsAvailable() async {
    throw UnimplementedError('P6 구현 예정');
  }

  Future<bool> requestAudioPermission() async {
    throw UnimplementedError('P6 구현 예정');
  }

  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {
    throw UnimplementedError('P6 구현 예정');
  }

  Future<void> stopCapture() async {
    throw UnimplementedError('P6 구현 예정');
  }
}
