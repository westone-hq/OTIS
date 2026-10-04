/// 작성: 2026-10-04 13:31:53 · nada
/// 클래스: SiteFieldError
/// 목적: 현장 정보 입력 검사에서 걸린 항목의 종류. 화면이 종류마다 안내
///       문구와 옮겨 갈 입력칸을 고른다. 층수 오류 셋은 한 번에 하나만
///       나온다.
///       - `jobNoMissing` — 제번이 비었다
///       - `siteNameMissing` — 현장명이 비었다
///       - `floorMissing` — 최하층이나 최상층이 비었다
///       - `floorNotNumber` — 층수가 정수가 아니다
///       - `floorNotAscending` — 최상층이 최하층보다 크지 않다
enum SiteFieldError {
  jobNoMissing,
  siteNameMissing,
  floorMissing,
  floorNotNumber,
  floorNotAscending,
}

/// 작성: 2026-07-04 15:04:38 · 박건준
/// 수정: 2026-10-04 13:31:53 · nada
/// 클래스: SiteInfo
/// 목적: 측정 현장 정보. 홈 화면에서 입력받아 `MeasurementSession` 에
///       싣고, 저장할 때 `MeasurementAssembler` 가 측정 결과로 옮긴다.
class SiteInfo {
  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: directionUp
  /// 목적: 운전 방향 선택지 — 아래층에서 위층으로. 기본값이다.
  ///       측정 결과에 이 문구 그대로 저장되고 리포트에 찍힌다.
  static const String directionUp = '하부 → 상부';

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: directionDown
  /// 목적: 운전 방향 선택지 — 위층에서 아래층으로.
  static const String directionDown = '상부 → 하부';

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: modelGen2
  /// 목적: 기종 선택지 — Gen2. 기본값이다.
  ///       측정 결과에 이 문구 그대로 저장되고 리포트에 찍힌다.
  static const String modelGen2 = 'Gen2';

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: modelOther
  /// 목적: 기종 선택지 — Gen2 가 아닌 나머지 전부.
  static const String modelOther = '기타';

  /// 제번
  final String jobNo;

  /// 현장명
  final String siteName;

  /// 최하층. 숫자 문자열 (예: "1", "-1")
  final String bottomFloor;

  /// 최상층. 숫자 문자열 (예: "8")
  final String topFloor;

  /// 운전 방향. `directionUp` 또는 `directionDown`
  final String direction;

  /// 엘리베이터 기종. `modelGen2` 또는 `modelOther`
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

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 함수: validate
  /// 목적: 측정을 시작해도 되는 현장 정보인지 검사한다. 홈 화면이 측정
  ///       시작 전에, `MeasurementRecorder` 가 저장 전에 같은 기준으로
  ///       부른다 — 두 곳의 기준이 갈라지면 화면은 통과시켰는데 저장이
  ///       거절하는 일이 생긴다.
  /// 반환: 걸린 항목 목록. 문제가 없으면 빈 목록
  List<SiteFieldError> validate() {
    final errors = <SiteFieldError>[]; // 걸린 항목을 모을 목록
    if (jobNo.trim().isEmpty) errors.add(SiteFieldError.jobNoMissing);
    if (siteName.trim().isEmpty) errors.add(SiteFieldError.siteNameMissing);

    final bottomText = bottomFloor.trim(); // 앞뒤 공백을 지운 최하층
    final topText = topFloor.trim(); // 앞뒤 공백을 지운 최상층
    if (bottomText.isEmpty || topText.isEmpty) {
      errors.add(SiteFieldError.floorMissing);
      return errors;
    }
    final bottom = int.tryParse(bottomText); // 최하층 숫자, 정수가 아니면 null
    final top = int.tryParse(topText); // 최상층 숫자, 정수가 아니면 null
    if (bottom == null || top == null) {
      errors.add(SiteFieldError.floorNotNumber);
    } else if (bottom >= top) {
      errors.add(SiteFieldError.floorNotAscending);
    }
    return errors;
  }
}

/// 작성: 2026-07-04 15:04:38 · 박건준
/// 수정: 2026-10-04 13:31:53 · nada
/// 클래스: MeasurementSession
/// 목적: 화면 사이에 넘기는 이번 측정의 상태 보관소. 홈 화면 → 시작
///       화면 → 측정 화면이 차례로 채우고 읽는다. 앱 전체에 하나만 둔다.
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

  /// 홈 화면에서 입력한 이번 측정의 현장 정보. 아직 입력 전이면 null
  SiteInfo? currentSite;

  /// 측정 시작 전 카운트다운 대기 시간 (초). 0이면 카운트다운 없이 곧바로 시작
  int delaySec = 0;

  /// true 면 측정 중 볼륨키(올림 · 내림)를 측정 완료 입력으로 쓴다.
  /// 일반 측정 시작에서는 false 로 둬 볼륨키 본래 동작을 그대로 둔다
  bool useVolumeKeyStop = false;
}
