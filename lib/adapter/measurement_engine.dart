import 'package:vibration_checker/model/sensor_sample.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// [연결] 측정 엔진 어댑터. UI 계약 시그니처만 유지한다.
/// 샘플 버퍼만 보관하고, 결과 산출은 신호 처리 계층 리빌딩에서 구현한다.
/// 기존 구현: main 브랜치 git 이력 참조.
class MeasurementEngine {
  final List<SensorSample> _buffer = [];

  /// 목적: 지금까지 받은 샘플 수. 측정 화면의 유효성 확인에 쓰인다.
  int get sampleCount => _buffer.length;

  /// 목적: 수집 샘플을 버퍼에 보관한다.
  void addSamples(List<SensorSample> samples) {
    _buffer.addAll(samples);
  }

  /// 목적: 측정 결과를 산출한다 — 신호 처리 계층 리빌딩에서 구현.
  MeasurementResult analyze({
    String? id,
    String jobNo = 'MOCK-JOB',
    String siteName = 'MOCK-SITE',
    int bottomFloor = 1,
    int topFloor = 10,
    String direction = '하부 → 상부',
    DateTime? dateTime,
  }) {
    throw UnimplementedError('신호 처리 계층 리빌딩에서 구현');
  }
}
