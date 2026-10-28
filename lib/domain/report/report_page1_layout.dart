import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-28 16:41:21 · Codex
/// 클래스: ReportPage1Layout
/// 목적: 리포트 1쪽의 자리들을 담는다. 머리말 11칸, Performance Metrics
///       표 10행이 있다. 좌표 단위는 서식 이미지 픽셀이고 원점은
///       좌상단이다. 폐지한 분석 자료의 제목 · 표는 본문과 함께 덮고
///       지표 표 아래는 여백으로 남긴다.
class ReportPage1Layout {
  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-22 11:10:00 · 박건준
  /// 변수: background
  /// 목적: 서식 배경 이미지 자산 경로. 정본이 가진 파일 이름 앞에 자산
  ///       디렉터리를 붙인 것이다. 2026-10-22 이미지에서 예전 값을 붓으로
  ///       지운 자국(흰 바탕 위 밝기 246 ~ 254 덩어리 — 머리말 제번 자리,
  ///       주소 칸 등)을 흰색(255)으로 바꿨다. 흰 바탕과 이어진 밝은 점만
  ///       바꿔(연결 성분) 표 줄무늬(E6E9EE · FAF6ED)와 그 안의 얼룩은 그대로다
  ///       — 줄무늬 안 얼룩을 흰색으로 바꾸면 오히려 흰 점이 생긴다.
  static const String background = '${ReportLayout.assetDirectory}tem_1.jpg';

  /// 측정 식별자 (제번). 확대 로고 오른쪽 구분선 뒤에 놓는다
  static const LayoutField measurementId = LayoutField(
    key: 'measurement_id',
    x: 378,
    y: 79,
    size: 30,
    align: LayoutAlign.left,
    weight: LayoutWeight.bold,
    color: ReportColors.navy,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-23 11:00:00 · 박건준
  /// 변수: engineerName
  /// 목적: 엔지니어명. 측정을 저장할 때 로그인한 작업자 성명이다. 없으면
  ///       `placeholder`. "엔지니어:" 라벨 바로 아래, 라벨과 같은 왼쪽
  ///       끝에서 시작한다.
  /// 근거: 측정 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말을 300dpi 로 잘라 잰 값. 이름 글자 왼쪽 끝 x 1026, 세로 가운데 y 103,
  ///       라틴 대문자 높이로 셈한 글자 크기 약 29. 예전 값(1023, 100,
  ///       21)은 원본보다 글자가 작았다
  static const LayoutField engineerName = LayoutField(
    key: 'engineer_name',
    x: 1026,
    y: 103,
    size: 29,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.navy,
  );

  /// 측정 일시
  static const LayoutField datetime = LayoutField(
    key: 'datetime',
    x: 2192,
    y: 80,
    size: 24,
    align: LayoutAlign.right,
    weight: LayoutWeight.bold,
    color: ReportColors.navy,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-11 19:15:25 · 박건준
  /// 변수: product
  /// 목적: 제품. "엘리베이터, 기종" 이다. 기종이 없는 예전 결과는
  ///       "엘리베이터".
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말 "엘리베이터, Gen2"
  static const LayoutField product = LayoutField(
    key: 'product',
    x: 1340,
    y: 219,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-11 19:15:25 · 박건준
  /// 변수: load
  /// 목적: 하중. 입력 숫자와 단위의 리포트 표기("2000 킬로그램")다. 값이
  ///       없는 예전 결과는 `placeholder`.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말 "2000 킬로그램"
  static const LayoutField load = LayoutField(
    key: 'load',
    x: 1340,
    y: 260,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 품질성능기준. "Standard" 고정
  static const LayoutField standard = LayoutField(
    key: 'standard',
    x: 1340,
    y: 300,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-11 19:15:25 · 박건준
  /// 변수: testType
  /// 목적: 측정 종류. 홈 화면에서 고른 해석 종류 문구 그대로다. 값이 없는
  ///       예전 결과는 기본값 "층간 시험".
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말 "층간 시험"
  static const LayoutField testType = LayoutField(
    key: 'test_type',
    x: 1340,
    y: 342,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 운전 방향
  static const LayoutField direction = LayoutField(
    key: 'direction',
    x: 1340,
    y: 382,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 층 정보 (최하층 · 최상층)
  static const LayoutField floors = LayoutField(
    key: 'floors',
    x: 1340,
    y: 424,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-12 02:13:59 · 박건준
  /// 변수: buildingName
  /// 목적: 건물명 (현장명). "건물명:" 라벨 바로 아래, 라벨과 같은 왼쪽
  ///       끝에서 시작한다.
  /// 근거: 측정 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말을 300dpi 로 잘라 잰 값. 글자 왼쪽 끝 x 53, 세로 가운데 y 661, 한글 높이로
  ///       셈한 글자 크기 약 32. 예전 값(78, 655, 24)은 라벨보다 오른쪽으로
  ///       들어가고 작았다
  static const LayoutField buildingName = LayoutField(
    key: 'building_name',
    x: 53,
    y: 661,
    size: 32,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.text,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-28 16:41:21 · Codex
  /// 변수: address
  /// 목적: 예전 주소 칸의 자리다. 저장 결과에 주소가 있어도 출력 값은
  ///       비우고 서식의 제목은 `addressLabelEraseBox` 로 지운다.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제
  ///       현장 리포트) 1쪽 머리말 "…, 경기도, 10575".
  ///       측정 — 같은 쪽을 300dpi 로 잘라 잰 자리: 글자 왼쪽 끝 x 1057,
  ///       세로 가운데 y 643(라벨과 같은 줄), 글자 크기 약 28. 예전 값
  ///       (1062, 655, 24)은 라벨보다 아래로 처졌다
  static const LayoutField address = LayoutField(
    key: 'address',
    x: 1057,
    y: 643,
    size: 28,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.text,
  );

  /// 작성: 2026-10-28 16:41:21 · Codex
  /// 변수: addressLabelEraseBox
  /// 목적: 1쪽 서식에 남은 주소 제목만 지울 영역 (픽셀). 금색 건물명 띠와
  ///       위쪽 사진 · 오른쪽 여백은 그대로 유지한다.
  /// 근거: 측정 — `tem_1.jpg` 제목 글자 범위 x 989~1044, y 631~654 에
  ///       가장자리 여유를 둔다. 주소 · 우편번호는 2026-10-27 부터 출력하지 않는다
  static const LayoutPlotBox addressLabelEraseBox = LayoutPlotBox(
    x: 980,
    y: 620,
    width: 80,
    height: 48,
  );

  /// 작성: 2026-10-11 19:15:25 · 박건준
  /// 수정: 2026-10-28 16:41:21 · Codex
  /// 변수: placeholder
  /// 목적: 값이 없는 머리말 칸(엔지니어 · 하중)에 찍는 자리 표시
  ///       문구. 칸을 비우면 빠뜨린 것처럼 보인다. 0 이나 지어낸 값은 찍지
  ///       않는다(관통 원칙 1).
  /// 근거: 인용 — 2026-10-11 사용자 결정
  static const String placeholder = '미입력';

  /// 작성: 2026-10-11 19:15:25 · 박건준
  /// 변수: headerRightLimitX
  /// 목적: 머리말 글자가 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 측정 일시
  ///       칸의 오른쪽 맞춤 자리와 같은 여백이다.
  /// 근거: 인용 — `datetime` 칸의 x 와 같다
  static const int headerRightLimitX = 2192;

  /// 작성: 2026-10-12 02:13:59 · 박건준
  /// 변수: engineerRightLimitX
  /// 목적: 엔지니어명이 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 같은 금색
  ///       띠 오른쪽의 측정 일시 문구와 겹치지 않게 그 앞에서 멈춘다.
  /// 근거: 측정 — 원본 리포트 1쪽에서 측정 일시 문구가 x 약 1832 에서
  ///       시작한다. 그 앞으로 여백을 둔다
  static const int engineerRightLimitX = 1800;

  /// 작성: 2026-10-12 02:13:59 · 박건준
  /// 변수: buildingNameRightLimitX
  /// 목적: 건물명이 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 금색 띠의 사선
  ///       줄무늬가 시작하기 전에 멈춘다.
  /// 근거: 측정 — 원본 리포트 1쪽 건물명 줄 높이에서 사선 줄무늬가 x 약
  ///       709 에서 시작한다
  static const int buildingNameRightLimitX = 700;

  /// 작성: 2026-10-11 19:15:25 · 박건준
  /// 수정: 2026-10-12 02:13:59 · 박건준
  /// 변수: fitRightLimitX
  /// 목적: 문구가 길어 서식 오른쪽 끝이나 이웃 문구에 닿을 수 있는 칸과 그
  ///       칸의 오른쪽 한계 (픽셀). 넘칠 때만 한 줄을 지키며 글자를 줄인다.
  ///       긴 주소 · 해석 종류 · 기종 · 엔지니어명 · 건물명이 들어오는
  ///       칸이다.
  /// 근거: 측정 — 주소 칸은 x 1057, 28 픽셀이라 한글 약 40자를 넘으면
  ///       오른쪽 여백에 닿는다
  static const Map<String, int> fitRightLimitX = <String, int>{
    'product': headerRightLimitX,
    'load': headerRightLimitX,
    'test_type': headerRightLimitX,
    'address': headerRightLimitX,
    'engineer_name': engineerRightLimitX,
    'building_name': buildingNameRightLimitX,
  };

  /// 작성: 2026-10-11 19:15:25 · 박건준
  /// 수정: 2026-10-12 02:13:59 · 박건준
  /// 함수: maxWidthOf
  /// 목적: 칸 하나가 쓸 수 있는 가장 큰 폭을 정한다. 차트 쪽 머리말도 같은
  ///       이름 · 같은 자리의 칸(엔지니어명)이라 함께 쓴다.
  /// 인자: field — 머리말 칸
  /// 반환: 쓸 수 있는 폭 (픽셀). 폭을 재지 않는 칸이면 null
  static int? maxWidthOf(LayoutField field) {
    final limit = fitRightLimitX[field.key]; // 그 칸의 오른쪽 한계, 없으면 null
    return limit == null ? null : limit - field.x;
  }

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: fields
  /// 목적: 머리말 11칸을 이름으로 찾아 쓸 수 있게 모아 둔 것. 낱개 상수와
  ///       같은 값이며, 전부 훑어야 할 때 쓴다.
  static const List<LayoutField> fields = <LayoutField>[
    measurementId,
    engineerName,
    datetime,
    product,
    load,
    standard,
    testType,
    direction,
    floors,
    buildingName,
    address,
  ];

  /// 작성: 2026-10-28 15:25:15 · Codex
  /// 수정: 2026-10-28 16:37:52 · Codex
  /// 변수: tablesEraseBox
  /// 목적: 옛 지표 본문과 분석 자료를 지울 영역 (픽셀). 머리말 · 지표 표의
  ///       제목과 열 이름 · 꼬리말은 지우지 않는다.
  /// 근거: 측정 — `tem_1.jpg` 지표 표 머리의 아래끝 y 945 부터
  ///       꼬리말 위 여백 y 3000 까지다. 분석 자료를 다시 그리지 않는다
  static const LayoutPlotBox tablesEraseBox = LayoutPlotBox(
    x: 0,
    y: 945,
    width: ReportLayout.pageWidthPx,
    height: 2055,
  );

  /// 지표 본문 왼쪽 · 너비 · 첫 행 위끝 · 행 높이 (픽셀). 기존 표 머리와 맞춘다
  static const int metricBodyX = 189;
  static const int metricBodyWidth = 1828;
  static const int metricBodyTop = 945;
  static const int metricRowHeight = 108;

  /// 카테고리 이름 글자 크기 (픽셀). 값과 같은 높이로 맞춘다
  static const int metricCategorySize = 28;

  /// 신호등 원의 중심 가로 좌표 (픽셀)
  static const int dotCenterX = 243;

  /// 신호등 원의 지름 (픽셀)
  static const int dotDiameter = 30;

  /// 구분 이름이 시작하는 가로 좌표 (픽셀)
  static const int colCategoryX = 313;

  /// 측정값 · 설명 열의 왼쪽과 오른쪽 경계 (픽셀). 열 행을 같은 위치에 맞춘다
  static const int colValueX = 741;
  static const int colValueRightX = 991;
  static const int colDescriptionX = 1016;
  static const int colDescriptionRightX = 1447;

  /// 작성: 2026-10-28 16:19:26 · Codex
  /// 변수: metricHeaderEraseBox
  /// 목적: 서식의 옛 설명 제목을 지울 영역 (픽셀). 카테고리 · 황색 · 적색
  ///       제목은 남기고 측정값 · 설명 제목만 본문 열에 맞춰 다시 쓴다.
  /// 근거: 측정 — `tem_1.jpg` 표 머리의 단색 안쪽이며 색은 RGB(4, 30, 65)다
  static const LayoutPlotBox metricHeaderEraseBox = LayoutPlotBox(
    x: 720,
    y: 860,
    width: 727,
    height: 70,
  );

  /// 표 머리 제목의 세로 중심 · 글자 크기 (픽셀)와 서식의 남색 (0xRRGGBB)
  static const int metricHeaderY = 890;
  static const int metricHeaderSize = 30;
  static const int metricHeaderBackground = 0x041E41;

  /// 황색 기준치 칸의 가로 좌표 (픽셀)
  static const int colYellowX = 1531;

  /// 적색 기준치 칸의 가로 좌표 (픽셀)
  static const int colRedX = 1855;

  /// 구분 이름을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colCategoryAlign = LayoutAlign.left;

  /// 값을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colValueAlign = LayoutAlign.left;

  /// 황색 기준치를 칸의 어느 쪽에 붙일지
  static const LayoutAlign colYellowAlign = LayoutAlign.center;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-28 17:39:01 · Codex
  /// 변수: colRedAlign
  /// 목적: 적색 기준치를 칸 가운데로 맞춘다. 황색 기준 열과 같은 정렬이다.
  /// 근거: 인용 — `docs/report_layout.json` 의
  ///       `page1.metrics_table.col_align.red`
  static const LayoutAlign colRedAlign = LayoutAlign.center;

  /// 값 글자 크기 (픽셀)
  static const int valueSize = 28;

  /// 기준치 글자 크기 (픽셀)
  static const int thresholdSize = 28;

  /// 서식에 남아 있는 황색 · 적색 칸을 덮을 네모의 가로 길이 (픽셀)
  static const int eraseRedWidth = 150;

  /// 서식에 남아 있는 황색 · 적색 칸을 덮을 네모의 세로 길이 (픽셀)
  static const int eraseRedHeight = 46;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-28 16:19:26 · Codex
  /// 변수: remarkX
  /// 목적: 황색 · 적색 행의 OTIS 문구(`ReportMetric.remarkLines`)를 쓰기
  ///       시작하는 가로 좌표 (픽셀). 측정값을 가리지 않도록 설명 열에 둔다.
  /// 근거: 인용 — 2026-10-28 사용자 지시로 측정값 뒤에 설명 열을 놓는다
  static const int remarkX = colDescriptionX;

  /// 문구를 쓸 설명 칸만 덮을 네모의 왼쪽 끝 (픽셀)
  static const int remarkEraseX = 1004;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-28 16:19:26 · Codex
  /// 변수: remarkEraseWidth
  /// 목적: 문구 자리를 덮을 네모의 가로 길이 (픽셀). 오른쪽 끝(1447)이 황색
  ///       칸 덮개 왼쪽 끝(`colYellowX` − `eraseRedWidth` / 2 = 1456)에 닿지
  ///       않는다. 문구가 이 폭을 넘으면 글자를 줄인다.
  static const int remarkEraseWidth = 443;

  /// 문구 자리를 덮을 네모의 세로 길이 (픽셀). 행 줄무늬 안이다
  static const int remarkEraseHeight = 86;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-22 11:10:00 · 박건준
  /// 변수: remarkSize
  /// 목적: 문구 글자 크기 (픽셀). 다른 행 설명 글자와 같은 크기로 두 줄을
  ///       쓴다. 덮은 폭(`remarkEraseWidth`)을 넘는 줄은 글자를 줄인다.
  /// 근거: 측정 — 서식 tem_1.jpg 의 설명 라벨("평균 진동 측정 수치") 글자
  ///       높이가 28 픽셀이고 값 글자(`valueSize`)도 28 이다. 2026-10-22 점검
  ///       지시 "다른 행 설명 글자와 같게"
  static const int remarkSize = 28;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-22 11:10:00 · 박건준
  /// 변수: remarkLineGap
  /// 목적: 문구 두 줄의 세로 간격 (픽셀). 행 가운데에서 위아래로 반씩
  ///       띄운다. 두 줄(±18 + 글자 반 높이 14)이 덮개 높이(±43) 안이다.
  static const int remarkLineGap = 36;

  /// 평균 소음 행의 세로 좌표 (픽셀)
  static const int noiseAvgY = 999;

  /// 최대 소음 행의 세로 좌표 (픽셀)
  static const int noiseMaxY = 1107;

  /// X 평균 · 최대 행의 세로 좌표 (픽셀)
  static const int xAvgY = 1215;
  static const int xMaxY = 1323;

  /// Y 평균 · 최대 행의 세로 좌표 (픽셀)
  static const int yAvgY = 1431;
  static const int yMaxY = 1539;

  /// Z 평균 · 최대 행의 세로 좌표 (픽셀)
  static const int zAvgY = 1647;
  static const int zMaxY = 1755;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-28 15:25:15 · Codex
  /// 변수: maxSpeedY
  /// 목적: 최대 속도 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 2026-10-28 사용자 지시로 축별 여섯 행 뒤에 놓는다
  static const int maxSpeedY = 1863;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-28 15:25:15 · Codex
  /// 변수: travelDistanceY
  /// 목적: 운행 거리 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 2026-10-28 사용자 지시로 열 번째 행에 놓고 행 높이를 맞춘다
  static const int travelDistanceY = 1971;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-28 15:25:15 · Codex
  /// 변수: metricRows
  /// 목적: Performance Metrics 표 열 행의 이름 · 설명 · 자리를 묶는다.
  ///       배경에 옛 수직 · 수평 이름이 남지 않게 본문을 코드로 다시 그린다.
  static const List<LayoutMetricRow> metricRows = <LayoutMetricRow>[
    LayoutMetricRow(
      key: 'noise_avg',
      label: '소음, 평균',
      description: '평균 소음 측정 수치',
      y: noiseAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'noise_max',
      label: '소음, 최대',
      description: '최대 소음 측정 수치',
      y: noiseMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'x_avg',
      label: 'X진동 평균',
      description: '평균 진동 측정 수치',
      y: xAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'x_max',
      label: 'X진동 최대',
      description: '최대 진동 측정 수치',
      y: xMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'y_avg',
      label: 'Y진동 평균',
      description: '평균 진동 측정 수치',
      y: yAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'y_max',
      label: 'Y진동 최대',
      description: '최대 진동 측정 수치',
      y: yMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'z_avg',
      label: 'Z진동 평균',
      description: '평균 진동 측정 수치',
      y: zAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'z_max',
      label: 'Z진동 최대',
      description: '최대 진동 측정 수치',
      y: zMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'max_speed',
      label: '최대 속도',
      description: '',
      y: maxSpeedY,
      judge: false,
      hasLabel: false,
    ),
    LayoutMetricRow(
      key: 'travel_distance',
      label: '운행 거리',
      description: '',
      y: travelDistanceY,
      judge: false,
      hasLabel: false,
    ),
  ];
}
