
/// 클래스: SiteInfo
/// 목적: 측정 현장 정보 (홈 화면에서 입력)
class SiteInfo {
  final String jobNo;
  final String siteName;
  final String bottomFloor;
  final String topFloor;
  final String direction;
  final String model;

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 함수: SiteInfo
  /// 목적: 입력받은 현장 정보 값을 그대로 담는 생성자.
  /// 인자: jobNo — 제번
  ///       siteName — 현장명
  ///       bottomFloor — 최하층
  ///       topFloor — 최상층
  ///       direction — 방향
  ///       model — 엘리베이터 모델명
  const SiteInfo({
    required this.jobNo,
    required this.siteName,
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    required this.model,
  });

  /// 작성: 2026-07-05 08:42:31 · 박건준
  /// 함수: toMap
  /// 목적: 현장 정보를 저장 가능한 Map 형태로 변환한다.
  /// 반환: 필드 이름을 키로 하는 Map
  Map<String, dynamic> toMap() => {
        'jobNo': jobNo,
        'siteName': siteName,
        'bottomFloor': bottomFloor,
        'topFloor': topFloor,
        'direction': direction,
        'model': model,
      };

  /// 작성: 2026-07-05 08:42:31 · 박건준
  /// 함수: fromMap
  /// 목적: Map 데이터로부터 현장 정보 인스턴스를 생성한다.
  /// 인자: map — 저장돼 있던 Map 데이터
  /// 반환: 복원된 SiteInfo 객체. 값이 없으면 기본값으로 채운다
  factory SiteInfo.fromMap(Map<String, dynamic> map) => SiteInfo(
        jobNo: map['jobNo']?.toString() ?? '',
        siteName: map['siteName']?.toString() ?? '',
        bottomFloor: map['bottomFloor']?.toString() ?? '1',
        topFloor: map['topFloor']?.toString() ?? '8',
        direction: map['direction']?.toString() ?? '하부 → 상부',
        model: map['model']?.toString() ?? 'Gen2',
      );
}

/// 클래스: MeasurementSession
/// 목적: 전역 측정 세션 싱글턴. 화면 간 실데이터 전송 E2E 플로우를 위한
///       상태 보관소.
class MeasurementSession {
  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 세션 인스턴스.
  static final MeasurementSession instance = MeasurementSession._();

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 함수: MeasurementSession._
  /// 목적: 외부에서 직접 생성하지 못하게 막는 전용 생성자. `instance`
  ///       하나만 쓰도록 강제한다.
  MeasurementSession._();

  SiteInfo? currentSite;
  int delaySec = 0;
}
