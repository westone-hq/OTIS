import 'package:vibration_checker/model/sensor_sample.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 목적: 스마트폰 센서에서 수집된 진동 데이터(샘플)들을 모아두었다가,
///       나중에 한 번에 수학적 계산(필터링, 분석)을 돌려 최종 결과(성적표)를 뽑아내는 엔진 역할을 한다.
class MeasurementEngine {
  final List<SensorSample> _buffer = [];

  /// 목적: 엔진이 현재까지 수집해 보관 중인 전체 진동 데이터 개수를 반환한다.
  int get sampleCount => _buffer.length;

  /// 목적: 센서에서 방금 측정한 진동 데이터 뭉치를 엔진 내부에 누적 저장한다.
  void addSamples(List<SensorSample> samples) {
    _buffer.addAll(samples);
  }

  /// 목적: 그동안 모아둔 수만 개의 진동 데이터를 분석(필터링, P2P 계산)하여 최종 리포트 결과를 만든다.
  ///       (현재는 뼈대만 있고, 실제 복잡한 수학 공식은 나중에 추가될 예정이다)
  /// 인자: id — 저장 아이디
  ///       jobNo — 엘리베이터 호기 번호 (제번)
  ///       siteName — 설치 현장명
  ///       bottomFloor — 시작 층수
  ///       topFloor — 도착 층수
  ///       direction — 운행 방향 (상/하)
  ///       dateTime — 측정 시각
  /// 반환: 모든 계산이 끝난 최종 MeasurementResult 객체
  /// 근거: 미정 — 신호 처리 엔진 개발 완료 시 구현됨
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
