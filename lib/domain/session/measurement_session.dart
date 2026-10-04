import 'package:vibration_checker/model/measurement_result.dart';

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
/// 수정: 2026-10-04 18:15:24 · nada
/// 클래스: SiteInfo
/// 목적: 측정 현장 정보. 홈 화면에서 입력받아 `MeasurementSession` 에
///       싣고, 저장할 때 `MeasurementAssembler` 가 측정 결과로 옮긴다.
class SiteInfo {
  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: directionUp
  /// 목적: 운전 방향 선택지 — 상승. 기본값이다.
  ///       측정 결과에 이 문구 그대로 저장되고 리포트에 찍힌다.
  static const String directionUp = '상승';

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 변수: directionDown
  /// 목적: 운전 방향 선택지 — 하강.
  static const String directionDown = '하강';

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 변수: modelOptions
  /// 목적: 기종 드롭다운에 보여줄 선택지와 그 차례. 측정 결과에 이 문구
  ///       그대로 저장되고 리포트에 찍힌다.
  /// 근거: 인용 — 2026-10-04 사용자 지정 목록
  static const List<String> modelOptions = <String>[
    '줄-로우프, 2:1',
    '줄-로우프, 1:1',
    'Gen2',
    '유압',
    '기타',
  ];

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 변수: defaultModel
  /// 목적: 처음 입력할 때 미리 골라 둘 기종.
  static const String defaultModel = 'Gen2';

  /// 제번
  final String jobNo;

  /// 현장명
  final String siteName;

  /// 현장 주소. 입력하지 않았으면 빈 문자열
  final String address;

  /// 최하층. 숫자 문자열 (예: "1", "-1")
  final String bottomFloor;

  /// 최상층. 숫자 문자열 (예: "8")
  final String topFloor;

  /// 운전 방향. `directionUp` 또는 `directionDown`
  final String direction;

  /// 엘리베이터 기종. `modelOptions` 가운데 하나
  final String model;

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: SiteInfo
  /// 목적: 입력받은 현장 정보 값을 그대로 담는 생성자.
  /// 인자: jobNo — 제번
  ///       siteName — 현장명
  ///       address — 현장 주소. 안 주면 빈 문자열
  ///       bottomFloor — 최하층
  ///       topFloor — 최상층
  ///       direction — 방향
  ///       model — 엘리베이터 모델명
  const SiteInfo({
    required this.jobNo,
    required this.siteName,
    this.address = '',
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    required this.model,
  });

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: SiteInfo.fromMap
  /// 목적: 기기에 저장해 둔 표에서 현장 정보를 되살린다. 홈 화면이 지난번
  ///       입력을 다시 채울 때 쓴다. 빠진 항목은 빈 값으로 두고, 운전
  ///       방향 · 기종은 `_knownDirection()` · `_knownModel()` 로 지금
  ///       선택지에 맞춘다.
  /// 인자: map — `toMap()` 이 만든 표
  /// 반환: 되살린 현장 정보
  factory SiteInfo.fromMap(Map<String, String?> map) {
    return SiteInfo(
      jobNo: map['jobNo'] ?? '',
      siteName: map['siteName'] ?? '',
      address: map['address'] ?? '',
      bottomFloor: map['bottomFloor'] ?? '',
      topFloor: map['topFloor'] ?? '',
      // → 로직 이동: _knownDirection()
      direction: _knownDirection(map['direction']),
      model: _knownModel(map['model']), // → 로직 이동: _knownModel()
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: SiteInfo.fromResult
  /// 목적: 저장된 측정 결과에서 그 측정의 현장 정보를 되살린다. 결과
  ///       화면의 "테스트 재실행" 이 같은 현장 정보로 다시 재는 데 쓴다.
  /// 인자: result — 저장된 측정 결과
  /// 반환: 되살린 현장 정보
  factory SiteInfo.fromResult(MeasurementResult result) {
    return SiteInfo(
      jobNo: result.jobNo,
      siteName: result.siteName,
      address: result.address,
      bottomFloor: '${result.bottomFloor}',
      topFloor: '${result.topFloor}',
      // → 로직 이동: _knownDirection()
      direction: _knownDirection(result.direction),
      model: _knownModel(result.model), // → 로직 이동: _knownModel()
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _knownDirection
  /// 목적: 저장돼 있던 운전 방향을 지금 선택지로 맞춘다. 예전 표기
  ///       "상부 → 하부" 는 하강으로, 그 밖에 알 수 없는 값은 상승으로 읽는다.
  /// 인자: saved — 저장돼 있던 운전 방향. 없으면 null
  /// 반환: `directionUp` 또는 `directionDown`
  static String _knownDirection(String? saved) =>
      saved == directionDown || saved == '상부 → 하부'
      ? directionDown
      : directionUp;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _knownModel
  /// 목적: 저장돼 있던 기종을 지금 선택지로 맞춘다. 선택지에 없으면
  ///       기본값으로 읽는다 — 그대로 두면 기종 드롭다운이 그릴 항목을 찾지
  ///       못한다.
  /// 인자: saved — 저장돼 있던 기종. 없으면 null
  /// 반환: `modelOptions` 가운데 하나
  static String _knownModel(String? saved) =>
      modelOptions.contains(saved) ? saved! : defaultModel;

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: toMap
  /// 목적: 기기에 저장할 표로 바꾼다. `SiteInfo.fromMap` 이 되읽는다.
  /// 반환: 항목 이름을 열쇠로 하는 표
  Map<String, String> toMap() => <String, String>{
    'jobNo': jobNo,
    'siteName': siteName,
    'address': address,
    'bottomFloor': bottomFloor,
    'topFloor': topFloor,
    'direction': direction,
    'model': model,
  };

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
/// 수정: 2026-10-04 18:15:24 · nada
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

  /// 측정 시작 전 카운트다운 대기 시간 (초). 0이면 카운트다운 없이 곧바로
  /// 시작. 시작 화면이 고른 값을 싣는다. 시작 화면을 거치지 않고 결과
  /// 화면의 "테스트 재실행" 으로 바로 잴 때도 휴대폰을 놓을 틈이 있도록
  /// 시작 화면의 기본값(5초)과 같게 둔다
  int delaySec = 5;
}
