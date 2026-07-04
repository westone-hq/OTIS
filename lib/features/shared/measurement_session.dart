import '../../domain/models/measurement_result.dart';

/// 측정 현장 정보 (홈 화면에서 입력)
class SiteInfo {
  final String jobNo;
  final String siteName;
  final String bottomFloor;
  final String topFloor;
  final String direction;
  final String model;

  const SiteInfo({
    required this.jobNo,
    required this.siteName,
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    required this.model,
  });

  Map<String, dynamic> toMap() => {
        'jobNo': jobNo,
        'siteName': siteName,
        'bottomFloor': bottomFloor,
        'topFloor': topFloor,
        'direction': direction,
        'model': model,
      };

  factory SiteInfo.fromMap(Map<String, dynamic> map) => SiteInfo(
        jobNo: map['jobNo']?.toString() ?? '',
        siteName: map['siteName']?.toString() ?? '',
        bottomFloor: map['bottomFloor']?.toString() ?? '1',
        topFloor: map['topFloor']?.toString() ?? '8',
        direction: map['direction']?.toString() ?? '하부 → 상부',
        model: map['model']?.toString() ?? 'Gen2',
      );
}

/// 전역 측정 세션 싱글턴
/// - 화면 간 실데이터 전송 E2E 플로우를 위한 상태 보관소
class MeasurementSession {
  static final MeasurementSession instance = MeasurementSession._();
  MeasurementSession._();

  SiteInfo? currentSite;
  int delaySec = 0;
  String? lastResultId;
  MeasurementResult? lastResult;

  void clear() {
    currentSite = null;
    delaySec = 0;
    lastResultId = null;
    lastResult = null;
  }
}
