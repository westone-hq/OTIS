import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-23 00:40:00 · 박건준
/// 클래스: ReportPage1Layout
/// 목적: 리포트 1쪽의 자리들을 담는다. 머리말 11칸, Performance Metrics
///       표 8행, 분석 자료 표 7행이 있다.
///
///       Performance Metrics 행 여덟 개의 세로 좌표는 계산하지 않고 값을
///       그대로 박아 둔다. 행 간격이 106 109 110 109 109 110 95 로 고르지
///       않고, 특히 마지막 한 칸이 뚜렷하게 좁다. 첫 행에서 일정 간격을
///       더해 가면 마지막 행이 12픽셀 넘게 어긋난다.
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

  /// 측정 식별자 (제번)
  static const LayoutField measurementId = LayoutField(
    key: 'measurement_id',
    x: 222,
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
  /// 수정: 2026-10-12 02:13:59 · 박건준
  /// 변수: address
  /// 목적: 주소. "주소, 우편번호" 다. 둘 다 없는 예전 결과는
  ///       `placeholder`. "주소:" 라벨과 같은 줄, 라벨 바로 뒤에서
  ///       시작한다.
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

  /// 작성: 2026-10-11 19:15:25 · 박건준
  /// 변수: placeholder
  /// 목적: 값이 없는 머리말 칸(엔지니어 · 하중 · 주소)에 찍는 자리 표시
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

  /// 신호등 원의 중심 가로 좌표 (픽셀)
  static const int dotCenterX = 243;

  /// 신호등 원의 지름 (픽셀)
  static const int dotDiameter = 30;

  /// 구분 이름이 시작하는 가로 좌표 (픽셀)
  static const int colCategoryX = 313;

  /// 서식에 박힌 설명 라벨이 시작하는 가로 좌표 (픽셀)
  static const int colDescLabelStartX = 741;

  /// 서식에 박힌 설명 라벨이 끝나는 가로 좌표 (픽셀)
  static const int colDescLabelEndX = 1004;

  /// 값을 쓰기 시작하는 가로 좌표 (픽셀). 라벨이 있는 1~6행에서 쓴다
  static const int colValueX = 1016;

  /// 라벨이 없는 7~8행에서 값을 쓰기 시작하는 가로 좌표 (픽셀)
  static const int colValueNoLabelX = 742;

  /// 황색 기준치 칸의 가로 좌표 (픽셀)
  static const int colYellowX = 1531;

  /// 적색 기준치 칸의 가로 좌표 (픽셀)
  static const int colRedX = 1855;

  /// 구분 이름을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colCategoryAlign = LayoutAlign.left;

  /// 값을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colValueAlign = LayoutAlign.left;

  /// 라벨 없는 7~8행의 값을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colValueNoLabelAlign = LayoutAlign.left;

  /// 황색 기준치를 칸의 어느 쪽에 붙일지
  static const LayoutAlign colYellowAlign = LayoutAlign.center;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 변수: colRedAlign
  /// 목적: 적색 기준치를 칸의 어느 쪽에 붙일지. 이 칸만 가운데로 모은다.
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
  /// 변수: remarkX
  /// 목적: 황색 · 적색 행의 OTIS 문구(`ReportMetric.remarkLines`)를 쓰기
  ///       시작하는 가로 좌표 (픽셀). 서식 설명 라벨 자리(`colValueNoLabelX`
  ///       와 같은 열)다.
  /// 근거: 인용 — 2026-10-21 점검 지시. OTIS 리포트는 황색 · 적색 행의
  ///       설명 칸에 라벨 · 값 대신 문장을 적는다
  static const int remarkX = 742;

  /// 문구를 쓰기 전에 서식 설명 라벨 · 값 자리를 덮을 네모의 왼쪽 끝 (픽셀)
  static const int remarkEraseX = 735;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 변수: remarkEraseWidth
  /// 목적: 문구 자리를 덮을 네모의 가로 길이 (픽셀). 오른쪽 끝(1447)이 황색
  ///       칸 덮개 왼쪽 끝(`colYellowX` − `eraseRedWidth` / 2 = 1456)에 닿지
  ///       않는다. 문구가 이 폭을 넘으면 글자를 줄인다.
  static const int remarkEraseWidth = 712;

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
  static const int noiseAvgY = 995;

  /// 최대 소음 행의 세로 좌표 (픽셀)
  static const int noiseMaxY = 1101;

  /// 평균 수직 진동 행의 세로 좌표 (픽셀)
  static const int vertAvgY = 1210;

  /// 최대 수직 진동 행의 세로 좌표 (픽셀)
  static const int vertMaxY = 1320;

  /// 평균 수평 진동 행의 세로 좌표 (픽셀)
  static const int horizAvgY = 1429;

  /// 최대 수평 진동 행의 세로 좌표 (픽셀)
  static const int horizMaxY = 1538;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: maxSpeedY
  /// 목적: 최대 속도 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 원본 리포트에서 잰 값이다. 앞 행과의 간격은 110으로
  ///       위 여섯 행과 비슷하지만, 표 전체 간격이 고르지 않아 계산으로
  ///       구하지 않는다. 이 값을 그대로 쓴다
  static const int maxSpeedY = 1648;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: travelDistanceY
  /// 목적: 운행 거리 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 원본 리포트에서 잰 값이다. 앞 행과의 간격이 95로 표에서
  ///       가장 좁다. 위 여섯 행의 평균 간격(108.6)으로 넘겨짚으면 1755가
  ///       나와 12픽셀 넘게 어긋난다. 계산하지 말고 이 값을 그대로 쓴다
  static const int travelDistanceY = 1743;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: metricRows
  /// 목적: Performance Metrics 표 여덟 행을 서식에 놓인 차례대로 모아
  ///       둔 것. 세로 좌표는 위 낱개 상수와 같은 값이다.
  static const List<LayoutMetricRow> metricRows = <LayoutMetricRow>[
    LayoutMetricRow(
      key: 'noise_avg',
      y: noiseAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'noise_max',
      y: noiseMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(key: 'vert_avg', y: vertAvgY, judge: true, hasLabel: true),
    LayoutMetricRow(key: 'vert_max', y: vertMaxY, judge: true, hasLabel: true),
    LayoutMetricRow(
      key: 'horiz_avg',
      y: horizAvgY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'horiz_max',
      y: horizMaxY,
      judge: true,
      hasLabel: true,
    ),
    LayoutMetricRow(
      key: 'max_speed',
      y: maxSpeedY,
      judge: false,
      hasLabel: false,
    ),
    LayoutMetricRow(
      key: 'travel_distance',
      y: travelDistanceY,
      judge: false,
      hasLabel: false,
    ),
  ];

  /// 분석 자료 표의 구분 이름을 칸의 어느 쪽에 붙일지
  static const LayoutAlign analysisCategoryAlign = LayoutAlign.left;

  /// 분석 자료 표의 구분 이름이 시작하는 가로 좌표 (픽셀)
  static const int analysisCategoryX = 313;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: analysisCategorySize
  /// 목적: 분석 자료 표의 구분 이름을 새로 찍을 때 글자 크기 (픽셀).
  /// 근거: 측정 — 서식 tem_1.jpg 에서 "Machine으로 부터 진동" 글자 높이가
  ///       y 2185~2212(27 픽셀)다. 1쪽 표의 값 글자 크기(28)와 같게 둔다
  static const int analysisCategorySize = 28;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: analysisCategoryWeight
  /// 목적: 분석 자료 표의 구분 이름을 새로 찍을 때 글자 굵기.
  /// 근거: 측정 — 서식 tem_1.jpg 의 구분 이름은 본문 글자보다 굵다. 보통
  ///       굵기로 찍으면 이웃 행 이름보다 가늘고 흐리게 보였다(2026-10-15
  ///       270dpi 비교)
  static const LayoutWeight analysisCategoryWeight = LayoutWeight.bold;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: eraseAnalysisLabelX
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 왼쪽 끝 가로 좌표 (픽셀).
  ///       신호등 원(오른쪽 끝 x 258)에 닿지 않는다.
  /// 근거: 측정 — 서식 tem_1.jpg 에서 구분 이름 글자가 x 311 에서
  ///       시작한다
  static const int eraseAnalysisLabelX = 300;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: eraseAnalysisLabelWidth
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 가로 길이 (픽셀).
  /// 근거: 측정 — 가장 긴 "Machine으로 부터 진동" 이 x 620 에서 끝난다.
  ///       설명 칸(x 1172)보다 한참 앞에서 멈춘다
  static const int eraseAnalysisLabelWidth = 360;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: eraseAnalysisLabelHeight
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 세로 길이 (픽셀). 행
  ///       세로 좌표를 가운데로 둔다.
  /// 근거: 측정 — 글자 높이 27 픽셀에 위아래 여유를 둔 값. 행 간격(약
  ///       101)의 절반을 넘지 않아 이웃 행을 덮지 않는다
  static const int eraseAnalysisLabelHeight = 52;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: analysisRelabels
  /// 목적: 서식에 박힌 분석 자료 구분 이름 가운데 바꿔 찍을 행과 새 이름.
  ///       열쇠는 `analysisRowKeys` 의 행 이름이다. 서식 글자를 덮고 이
  ///       이름을 찍는다.
  /// 근거: 인용 — 2026-10-15 사용자 지시 "Machine 대신 권상기 머신,
  ///       Belts 대신 로우프"
  static const Map<String, String> analysisRelabels = <String, String>{
    'machine': '권상기 머신으로 부터 진동',
    'belts': '로우프',
  };

  /// 분석 자료 표의 설명이 시작하는 가로 좌표 (픽셀)
  static const int analysisDescriptionX = 1172;

  /// 분석 자료 표의 설명을 칸의 어느 쪽에 붙일지
  static const LayoutAlign analysisDescriptionAlign = LayoutAlign.left;

  /// 분석 자료 표의 설명 글자 크기 (픽셀)
  static const int analysisDescriptionSize = 28;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: analysisRowYs
  /// 목적: 분석 자료 표 일곱 행의 세로 좌표 (픽셀)를 서식에 놓인
  ///       차례대로 모아 둔 것. 행 이름은 `analysisRowKeys` 와 짝이다.
  /// 근거: 인용 — 원본 리포트에서 잰 값이다
  static const List<int> analysisRowYs = <int>[
    2098,
    2199,
    2300,
    2401,
    2504,
    2606,
    2707,
  ];

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: analysisRowKeys
  /// 목적: 분석 자료 표 일곱 행의 이름. `analysisRowYs` 와 같은 차례다.
  ///       일곱 항목 모두 판정 근거가 없어 지금은 회색으로 비워 둔다.
  static const List<String> analysisRowKeys = <String>[
    'car_noise',
    'machine',
    'belts',
    'guide_rail',
    'transient_noise',
    'idler_sheave',
    'guide',
  ];
}
