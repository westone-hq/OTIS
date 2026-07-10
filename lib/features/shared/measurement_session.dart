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
  /// 현장 정보를 직렬화 가능한 Map 형태로 변환합니다.
  Map<String, dynamic> toMap() => {
        'jobNo': jobNo,
        'siteName': siteName,
        'bottomFloor': bottomFloor,
        'topFloor': topFloor,
        'direction': direction,
        'model': model,
      };
  /// Map 데이터로부터 현장 정보 인스턴스를 생성합니다.
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
  /// 세션에 보관된 현재 현장 정보 및 마지막 측정 결과를 초기화합니다.
  void clear() {
    currentSite = null;
    delaySec = 0;
    lastResultId = null;
    lastResult = null;
  }
}
