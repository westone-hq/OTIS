import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-10-04 13:31:53 · nada
/// 수정: 2026-10-11 17:26:58 · nada
/// 클래스: SiteFieldError
/// 목적: 현장 정보 입력 검사에서 걸린 항목의 종류. 화면이 종류마다 안내
///       문구와 옮겨 갈 입력칸을 고른다. 층수 오류 셋, 하중 오류 둘,
///       우편번호 오류 둘은 각각 한 번에 하나만 나온다.
///       - `jobNoMissing` — 제번이 비었다
///       - `siteNameMissing` — 현장명이 비었다
///       - `addressMissing` — 주소가 비었다
///       - `postalCodeMissing` — 우편번호가 비었다
///       - `postalCodeInvalid` — 우편번호가 숫자 5자리가 아니다
///       - `loadMissing` — 하중이 비었다
///       - `loadNotNumber` — 하중이 0 보다 큰 유한한 숫자가 아니다
///       - `floorMissing` — 최하층이나 최상층이 비었다
///       - `floorNotNumber` — 층수가 정수가 아니다
///       - `floorNotAscending` — 최상층이 최하층보다 크지 않다
enum SiteFieldError {
  jobNoMissing,
  siteNameMissing,
  addressMissing,
  postalCodeMissing,
  postalCodeInvalid,
  loadMissing,
  loadNotNumber,
  floorMissing,
  floorNotNumber,
  floorNotAscending,
}

/// 작성: 2026-07-04 15:04:38 · 박건준
/// 수정: 2026-10-11 16:58:59 · nada
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

  /// 작성: 2026-10-13 13:17:56 · nada
  /// 변수: loadUnit
  /// 목적: 하중 단위. 고를 수 없고 늘 이 단위로 받아 측정 결과에 이 문구
  ///       그대로 저장한다. 홈 화면 하중 입력칸 오른쪽에 고정 글자로 보인다.
  /// 근거: 인용 — 2026-10-13 사용자 결정 "하중 단위는 kg 하나로 고정한다.
  ///       lb 선택은 없앤다"
  static const String loadUnit = 'kg';

  /// 작성: 2026-10-11 16:58:59 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 변수: loadUnitReportLabels
  /// 목적: 저장된 하중 단위의 리포트 표기. 하중은 환산하지 않고 입력 숫자
  ///       뒤에 이 말을 붙여 찍는다("2000 킬로그램").
  ///       - `kg` — 지금 받는 단위(`loadUnit`)
  ///       - `lb` — 단위를 고를 수 있던 빌드(2026-10-11 ~ 10-13)로 저장한
  ///         예전 결과. 저장된 값을 바꾸지 않고 그 단위로 찍는다
  /// 근거: 인용 — "킬로그램" 은 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제 현장
  ///       리포트) 1쪽 머리말 "2000 킬로그램" 표기.
  ///       "파운드" 는 2026-10-08 사용자 지정("4400 파운드").
  ///       lb 를 남긴 것은 그 빌드(5a517e5)를 2026-10-13 테스트 폰에
  ///       설치했기 때문이다
  ///       미확인: 그 폰에 lb 로 저장한 결과가 실제로 있는지 — 없으면 `lb`
  ///       를 지운다(docs/pending_checks.md)
  static const Map<String, String> loadUnitReportLabels = <String, String>{
    'kg': '킬로그램',
    'lb': '파운드',
  };

  /// 작성: 2026-10-11 16:58:59 · nada
  /// 변수: analysisTypeOptions
  /// 목적: 해석 종류(분석 내용) 드롭다운에 보여줄 선택지와 그 차례. 측정
  ///       결과에 이 문구 그대로 저장되고 리포트 머리말 측정 칸에 찍힌다.
  ///       기록 · 표시만 하고 측정 · 지표 계산을 종류마다 달리하지 않는다.
  /// 근거: 인용 — 2026-10-08 사용자 지정 목록
  static const List<String> analysisTypeOptions = <String>[
    '일반',
    '층간 시험',
    '문 열림 사이클',
    '브레이크 기능',
    '사이클 저크(가속도증가율) 테스트',
  ];

  /// 작성: 2026-10-11 17:26:58 · nada
  /// 변수: postalCodeLength
  /// 목적: 우편번호 자릿수. 검사(`validate()`)와 홈 화면 입력 길이 제한이
  ///       함께 쓴다.
  /// 근거: 표준 — 2015-08-01 시행 국가기초구역 우편번호(숫자 5자리).
  ///       원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제 현장 리포트)
  ///       1쪽 머리말 주소 끝 "10575" 도 5자리다
  static const int postalCodeLength = 5;

  /// 작성: 2026-10-11 16:58:59 · nada
  /// 변수: defaultAnalysisType
  /// 목적: 처음 입력할 때 미리 골라 둘 해석 종류.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제 현장
  ///       리포트) 1쪽 머리말 측정 칸 "층간 시험"
  static const String defaultAnalysisType = '층간 시험';

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

  /// 하중. 입력한 문자열 그대로 (예: "2000", "1.5"). 숫자로 바꾸는 일은
  /// 저장할 때 한다. 입력하지 않았으면 빈 문자열
  final String load;

  /// 해석 종류. `analysisTypeOptions` 가운데 하나
  final String analysisType;

  /// 우편번호. 입력한 문자열 그대로. 입력하지 않았으면 빈 문자열
  final String postalCode;

  /// 추가 참고사항. 메일 본문에 들어간다. 비워 둘 수 있다
  final String notes;

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: SiteInfo
  /// 목적: 입력받은 현장 정보 값을 그대로 담는 생성자.
  /// 인자: jobNo — 제번
  ///       siteName — 현장명
  ///       address — 현장 주소. 안 주면 빈 문자열
  ///       bottomFloor — 최하층
  ///       topFloor — 최상층
  ///       direction — 방향
  ///       model — 엘리베이터 모델명
  ///       load — 하중 입력 문자열 (`loadUnit` 단위). 안 주면 빈 문자열
  ///       analysisType — 해석 종류. 안 주면 `defaultAnalysisType`
  ///       postalCode — 우편번호 입력 문자열. 안 주면 빈 문자열
  ///       notes — 추가 참고사항. 안 주면 빈 문자열
  const SiteInfo({
    required this.jobNo,
    required this.siteName,
    this.address = '',
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    required this.model,
    this.load = '',
    this.analysisType = defaultAnalysisType,
    this.postalCode = '',
    this.notes = '',
  });

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: SiteInfo.fromMap
  /// 목적: 기기에 저장해 둔 표에서 현장 정보를 되살린다. 홈 화면이 지난번
  ///       입력을 다시 채울 때 쓴다. 빠진 항목은 빈 값으로 두고, 운전
  ///       방향 · 기종 · 해석 종류는 `_known*()` 으로 지금 선택지에
  ///       맞춘다. 참고사항은 표에 없으므로 빈 칸으로 시작한다
  ///       (`toMap()` 참고). 단위를 고를 수 있던 빌드가 표에 남긴
  ///       "loadUnit" 항목(예: "lb")은 읽지 않는다 — 단위는 상수
  ///       `loadUnit` 하나다.
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
      load: map['load'] ?? '',
      // → 로직 이동: _knownOption()
      analysisType: _knownOption(
        map['analysisType'],
        analysisTypeOptions,
        defaultAnalysisType,
      ),
      postalCode: map['postalCode'] ?? '',
    );
  }

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: SiteInfo.fromResult
  /// 목적: 저장된 측정 결과에서 그 측정의 현장 정보를 되살린다. 결과
  ///       화면의 "테스트 재실행" 이 같은 현장 정보로 다시 재는 데 쓴다.
  ///       하중 · 우편번호가 없는 예전 결과는 빈 칸으로 되살린다 — 재실행
  ///       화면이 `validate()` 로 걸러 홈에서 채우게 한다. 하중 단위가
  ///       `loadUnit` 이 아닌 예전 결과(lb)도 하중을 빈 칸으로 되살린다 —
  ///       그 숫자를 그대로 쓰면 새 결과에 kg 로 잘못 저장된다. 참고사항은
  ///       측정마다 새로 적으므로 되살리지 않는다.
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
      load: result.load == null || result.loadUnit != loadUnit
          ? ''
          : loadText(result.load!), // → 로직 이동: loadText()
      // → 로직 이동: _knownOption()
      analysisType: _knownOption(
        result.analysisType,
        analysisTypeOptions,
        defaultAnalysisType,
      ),
      postalCode: result.postalCode ?? '',
    );
  }

  /// 작성: 2026-10-11 19:09:59 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: copyWith
  /// 목적: 일부 값만 바꾼 사본을 만든다. 넘기지 않은 값은 이 현장 정보의
  ///       값을 그대로 쓴다. 결과 화면 재실행이 운전 방향만 바꿔 다시 잴 때
  ///       쓴다 — 항목을 하나씩 옮겨 적으면 새 항목이 생길 때 빠뜨린다.
  /// 인자: 생성자 `SiteInfo` 와 같다. 모두 생략할 수 있다
  /// 반환: 새 현장 정보
  SiteInfo copyWith({
    String? jobNo,
    String? siteName,
    String? address,
    String? bottomFloor,
    String? topFloor,
    String? direction,
    String? model,
    String? load,
    String? analysisType,
    String? postalCode,
    String? notes,
  }) {
    return SiteInfo(
      jobNo: jobNo ?? this.jobNo,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      bottomFloor: bottomFloor ?? this.bottomFloor,
      topFloor: topFloor ?? this.topFloor,
      direction: direction ?? this.direction,
      model: model ?? this.model,
      load: load ?? this.load,
      analysisType: analysisType ?? this.analysisType,
      postalCode: postalCode ?? this.postalCode,
      notes: notes ?? this.notes,
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

  /// 작성: 2026-10-11 16:58:59 · nada
  /// 함수: _knownOption
  /// 목적: 저장돼 있던 값을 선택지로 맞춘다. 선택지에 없으면 기본값으로
  ///       읽는다 — 그대로 두면 선택 버튼 · 드롭다운이 그릴 항목을 찾지
  ///       못한다. `_knownModel()` 과 같은 규칙이다.
  /// 인자: saved — 저장돼 있던 값. 없으면 null
  ///       options — 지금 선택지
  ///       fallback — 선택지에 없을 때 쓸 기본값
  /// 반환: `options` 가운데 하나
  static String _knownOption(
    String? saved,
    List<String> options,
    String fallback,
  ) => options.contains(saved) ? saved! : fallback;

  /// 작성: 2026-10-11 17:26:58 · nada
  /// 함수: parseLoad
  /// 목적: 하중 입력 문자열을 숫자로 바꾼다. 하중을 받아들이는 기준을 한
  ///       곳에 둔다 — 홈 화면 검사(`validate()`)와 저장할 때 변환
  ///       (`MeasurementAssembler.assemble()`)이 둘 다 이 함수를 쓴다. 두
  ///       곳이 따로 판정하면 홈은 통과했는데 측정 뒤 저장이 거절될 수 있다.
  ///       `double.tryParse` 는 "Infinity" · "NaN" 도 숫자로 읽으므로
  ///       유한한지까지 본다.
  /// 인자: text — 하중 입력 문자열. 앞뒤 공백은 지우고 본다
  /// 반환: 0 보다 큰 유한한 하중. 비었거나 그런 수가 아니면 null
  static double? parseLoad(String text) {
    final value = double.tryParse(text.trim()); // 숫자로 읽은 값, 못 읽으면 null
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  /// 작성: 2026-10-11 16:58:59 · nada
  /// 함수: loadText
  /// 목적: 하중 숫자를 화면 입력칸 · 리포트에 쓸 문자열로 바꾼다. 정수면
  ///       소수점 없이("2000"), 아니면 입력한 자리까지("1.5") 쓴다.
  /// 인자: load — 하중 숫자
  /// 반환: 하중 문자열
  static String loadText(double load) =>
      load == load.truncateToDouble() ? load.toStringAsFixed(0) : '$load';

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 수정: 2026-10-13 13:17:56 · nada
  /// 함수: toMap
  /// 목적: 기기에 저장할 표로 바꾼다. `SiteInfo.fromMap` 이 되읽는다.
  ///       참고사항은 넣지 않는다 — 현장마다 달라, 남겨 두면 다음 현장
  ///       메일에 섞인다(2026-10-10 사용자 결정). 하중 단위도 넣지
  ///       않는다 — 고를 수 없는 상수(`loadUnit`)다.
  /// 반환: 항목 이름을 열쇠로 하는 표
  Map<String, String> toMap() => <String, String>{
    'jobNo': jobNo,
    'siteName': siteName,
    'address': address,
    'bottomFloor': bottomFloor,
    'topFloor': topFloor,
    'direction': direction,
    'model': model,
    'load': load,
    'analysisType': analysisType,
    'postalCode': postalCode,
  };

  /// 작성: 2026-10-04 13:31:53 · nada
  /// 수정: 2026-10-11 17:26:58 · nada
  /// 함수: validate
  /// 목적: 측정을 시작해도 되는 현장 정보인지 검사한다. 홈 화면이 측정
  ///       시작 전에, `MeasurementRecorder` 가 저장 전에, 결과 화면이
  ///       재실행 전에 같은 기준으로 부른다 — 기준이 갈라지면 화면은
  ///       통과시켰는데 저장이 거절하는 일이 생긴다.
  ///       필수: 제번 · 현장명 · 주소 · 우편번호 · 하중 · 층수. 참고사항만
  ///       선택이다(2026-10-10 사용자 결정).
  /// 반환: 걸린 항목 목록. 문제가 없으면 빈 목록
  List<SiteFieldError> validate() {
    final errors = <SiteFieldError>[]; // 걸린 항목을 모을 목록
    if (jobNo.trim().isEmpty) errors.add(SiteFieldError.jobNoMissing);
    if (siteName.trim().isEmpty) errors.add(SiteFieldError.siteNameMissing);
    if (address.trim().isEmpty) errors.add(SiteFieldError.addressMissing);

    final postalText = postalCode.trim(); // 앞뒤 공백을 지운 우편번호
    if (postalText.isEmpty) {
      errors.add(SiteFieldError.postalCodeMissing);
    } else if (!RegExp('^[0-9]{$postalCodeLength}\$').hasMatch(postalText)) {
      errors.add(SiteFieldError.postalCodeInvalid);
    }

    // → 로직 이동: parseLoad()
    final loadValue = parseLoad(load); // 0 보다 큰 유한한 하중, 아니면 null
    if (load.trim().isEmpty) {
      errors.add(SiteFieldError.loadMissing);
    } else if (loadValue == null) {
      errors.add(SiteFieldError.loadNotNumber);
    }

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
