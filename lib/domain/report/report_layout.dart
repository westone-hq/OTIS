/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: ReportLayout
/// 목적: TUNE 리포트 서식 위에 값을 얹을 자리를 모아 둔다. 리포트의
///       좌표 숫자는 전부 이 파일에만 있고, 그리는 쪽은 여기서 꺼내 쓴다.
///       좌표가 틀어지면 이 파일 한 곳만 고치면 된다.
///
///       옮겨온 곳
///         `docs/report_layout.json` (md5 38cde4c2b9730fa8ae66e84b902b175c,
///         2026-09-25 기준). 그 파일이 정본 기록이고 이 파일은 사람이 옮긴
///         사본이다. json 을 실행 중에 읽지 않는 이유는, 읽지 않으면 자산을
///         못 찾아 실패하는 경로가 하나 줄고, 좌표가 틀리면 빌드가 아니라
///         결과물을 눈으로 보고 잡게 되기 때문이다. 옮기다 숫자가
///         틀어지는 것은 `report_layout_test.dart` 가 json 과 대조해 잡는다.
///
///       좌표계는 서식 이미지 픽셀이다. 2256 x 3190, 원점은 좌상단이다.
///       원본 리포트 페이지(924 x 1316)에서 잰 값에 K = 2.44156 을 곱해
///       옮긴 것이다.
class ReportLayout {
  /// 서식 이미지 가로 (픽셀)
  static const int pageWidthPx = 2256;

  /// 서식 이미지 세로 (픽셀)
  static const int pageHeightPx = 3190;

  /// A4 가로 (PDF 포인트)
  static const double pageWidthPt = 595.276;

  /// A4 세로 (PDF 포인트)
  static const double pageHeightPt = 841.89;

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 변수: assetDirectory
  /// 목적: 서식 배경 이미지가 놓인 자산 디렉터리. 정본은 파일 이름만 갖고,
  ///       디렉터리는 쓰는 쪽이 앞에 붙인다.
  /// 근거: 인용 — `docs/report_layout.json` 의 `_background_note`. 같은
  ///       서식 파일을 파이썬 프로토타입은 `assets/` 에, Flutter 는 이
  ///       경로에 두기 때문에 디렉터리를 정본에서 뺐다
  static const String assetDirectory = 'assets/report/';

  /// 본문용 한글 글꼴 자산 경로
  static const String regularFontAsset =
      '${assetDirectory}NanumGothic-Regular.ttf';

  /// 굵게 쓸 자리용 한글 글꼴 자산 경로
  static const String boldFontAsset = '${assetDirectory}NanumGothic-Bold.ttf';

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 변수: textBaselineDropRatio
  /// 목적: 글자 크기 대비, 글자 덩이의 세로 한가운데에서 앉는 선까지
  ///       내려야 하는 몫. 서식의 세로 좌표가 글자의 수직 중심이라, 찍기
  ///       전에 이만큼 내려야 한다.
  /// 근거: 인용 — 파이썬 프로토타입
  ///       `pdf_report_dev/tune_report/render.py` 의 92행이 원본 리포트와
  ///       글자 자리를 맞춰 찾은 값이다. 1쪽과 차트 쪽, 프로토타입이 모두
  ///       같은 몫을 써야 같은 자리에 찍히므로 이 값은 구현들 사이의
  ///       약속이며, 바꾸면 참조 PDF
  ///       (`docs/reference/sample_evimp.pdf`)와 글자 자리가 갈라진다
  static const double textBaselineDropRatio = 0.36;

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 변수: datetimePattern
  /// 목적: 머리말 측정 일시의 표기 형식. 1쪽과 차트 쪽이 같은 자리에 같은
  ///       문구를 찍어야 해서 한 곳에 둔다.
  /// 근거: 인용 — 원본 리포트 머리말이 `14/01/2026 11:03:59 AM` 형태다
  static const String datetimePattern = 'dd/MM/yyyy hh:mm:ss a';

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: ptPerPxX
  /// 목적: 서식 이미지 픽셀 하나가 PDF 포인트로 가로 몇인지.
  /// 근거: 인용 — `docs/report_layout.json` 의 `page.pt_per_px_x`. 가로와
  ///       세로 계수가 다른 이유는 서식 이미지 비율(1.414007)이 A4
  ///       비율(1.414285)과 미세하게 달라서다. 배경을 A4 전면에 늘려
  ///       깔기 때문에 좌표도 같은 배율로 늘어나야 배경 위 자리와
  ///       맞는다. 하나의 계수로 두 축을 다 쓰면 페이지 아래쪽에서
  ///       0.16pt 어긋난다
  /// 식: kx = pageWidthPt / pageWidthPx
  ///     json 에는 소수로 끊은 사본이 적혀 있고, 여기서는 페이지 크기에서
  ///     직접 나눈다. 그래야 서식 오른쪽 끝이 A4 폭에 정확히 떨어진다
  static const double ptPerPxX = pageWidthPt / pageWidthPx;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: ptPerPxY
  /// 목적: 서식 이미지 픽셀 하나가 PDF 포인트로 세로 몇인지.
  /// 근거: 인용 — `docs/report_layout.json` 의 `page.pt_per_px_y`.
  ///       `ptPerPxX` 와 다른 이유는 같은 설명을 본다
  /// 식: ky = pageHeightPt / pageHeightPx
  static const double ptPerPxY = pageHeightPt / pageHeightPx;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: xToPoints
  /// 목적: 서식 이미지의 가로 좌표를 PDF 가로 좌표로 바꾼다.
  /// 인자: xPx — 서식 이미지 가로 좌표 (픽셀, 왼쪽이 0)
  /// 반환: PDF 가로 좌표 (포인트)
  /// 식: x_pt = x_px x ptPerPxX
  static double xToPoints(num xPx) => xPx * ptPerPxX;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: yToPoints
  /// 목적: 서식 이미지의 세로 좌표를 PDF 세로 좌표로 바꾼다. 위아래가
  ///       뒤집히므로 곱하기만 해서는 안 된다.
  /// 인자: yPx — 서식 이미지 세로 좌표 (픽셀, 위쪽이 0)
  /// 반환: PDF 세로 좌표 (포인트, 아래쪽이 0)
  /// 식: y_pt = pageHeightPt - y_px x ptPerPxY
  ///     이미지는 세로를 위에서 아래로 세고 PDF 는 아래에서 위로 센다.
  ///     그래서 같은 자리라도 두 좌표계의 값이 반대 방향으로 커진다.
  ///     페이지 높이에서 빼면 기준점이 위에서 아래로 옮겨 가며 방향도
  ///     함께 뒤집힌다.
  static double yToPoints(num yPx) => pageHeightPt - yPx * ptPerPxY;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: lengthToPoints
  /// 목적: 길이(글자 크기 · 너비 · 지름)를 PDF 포인트로 바꾼다. 위치가
  ///       아니라 길이라 위아래 뒤집기가 끼지 않는다.
  /// 인자: lengthPx — 서식 이미지 기준 길이 (픽셀)
  /// 반환: PDF 기준 길이 (포인트)
  /// 식: length_pt = length_px x ptPerPxX
  ///     쓰이는 곳이 글자 크기와 가로 너비라 가로 계수를 따른다. 두 계수
  ///     차이가 0.02% 라 지름 30픽셀에서 0.0016pt 밖에 안 벌어진다
  static double lengthToPoints(num lengthPx) => lengthPx * ptPerPxX;
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: LayoutAlign
/// 목적: 글자를 기준 좌표의 어느 쪽에 붙일지.
enum LayoutAlign { left, center, right }

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: LayoutWeight
/// 목적: 글자 굵기. 서식에 쓰는 글꼴이 보통과 굵게 두 벌뿐이다.
enum LayoutWeight { regular, bold }

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: ReportColors
/// 목적: 리포트에 쓰는 색을 모아 둔다. 값은 0xRRGGBB 이며, PDF 색 자료형으로
///       바꾸는 일은 그리는 쪽이 한다 — 이 파일은 바깥 패키지를 쓰지 않는다.
class ReportColors {
  /// 머리말 · 식별자에 쓰는 남색
  static const int navy = 0x0D2B52;

  /// 차트 쪽 제목에 쓰는 금색
  static const int gold = 0xC09B54;

  /// 본문 글자색
  static const int text = 0x231F20;

  /// 남색 띠 위에 얹는 흰 글자색
  static const int white = 0xFFFFFF;

  /// 판정 통과 — 초록 신호등
  static const int judgeGreen = 0x4CAF3E;

  /// 판정 주의 — 노란 신호등. 요구사항에 황색 단계가 없어 지금은 쓰지 않는다
  static const int judgeYellow = 0xF5C324;

  /// 판정 초과 — 빨간 신호등
  static const int judgeRed = 0xD93025;

  /// 아직 재지 못해 판정할 수 없는 항목의 회색 신호등
  static const int judgeUnknown = 0xB9BFC7;

  /// 차트 선 색
  static const int chartLine = 0x0000CC;

  /// 차트 격자 선 색. 축 틀 · 눈금 · 라벨은 `text` 를 쓰고 격자만 이 색이다
  static const int chartGrid = 0x555555;

  /// 작성: 2026-09-23 09:40:00 · nada
  /// 변수: chartMarker
  /// 목적: 차트에서 최댓값 자리를 짚는 점과 그 옆에 적는 값의 색. 지금은
  ///       소음 차트에만 붙는다 — 진동 차트의 최댓값은 저역통과
  ///       필터(빠르게 흔들리는 성분을 깎아 내는 계산)를 거친 파형에서
  ///       나오는 값이라, 필터가 정해지기 전에는 찍을 값이 없다.
  static const int chartMarker = 0xE03030;

  /// 작성: 2026-09-23 09:40:00 · nada
  /// 변수: chartGuide
  /// 목적: 차트에 가로로 긋는 기준선의 색. 지금은 소음 차트의 평균선에
  ///       쓴다.
  /// 근거: 측정 — 원본 리포트 소음 차트의 붉은 점선을 픽셀로 재니 한
  ///       줄이고 값이 45.73 dBA 로, 1쪽 표의 "소음, 평균"(45.80)과 같은
  ///       값이다. A95(52.82)와는 전혀 다르다
  /// 미구현: 진동 차트의 A95 밴드는 아직 없다. 그 값은 저역통과 필터를
  ///       거친 파형에서 나오므로 필터가 정해져야 그을 수 있다.
  static const int chartGuide = 0xE03030;

  /// 표 홀수 행 바탕색
  static const int stripeOdd = 0xE6E9EE;

  /// 표 짝수 행 바탕색
  static const int stripeEven = 0xFAF6ED;
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: LayoutField
/// 목적: 글자 하나를 찍을 자리와 모양을 담는다. 서식 머리말의 각 칸처럼
///       값 하나가 한 자리에 들어가는 곳에 쓴다.
class LayoutField {
  /// 서식에서 이 칸을 부르는 이름. json 의 `key` 와 같다
  final String key;

  /// 가로 좌표 (서식 이미지 픽셀)
  final int x;

  /// 세로 좌표 (서식 이미지 픽셀, 글자 수직 중심)
  final int y;

  /// 글자 크기 (서식 이미지 픽셀)
  final int size;

  /// 기준 좌표의 어느 쪽에 붙일지
  final LayoutAlign align;

  /// 글자 굵기
  final LayoutWeight weight;

  /// 글자색 (0xRRGGBB). `ReportColors` 의 값 중 하나
  final int color;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: LayoutField
  /// 목적: 글자 한 칸의 자리와 모양을 그대로 담는 생성자.
  /// 인자: key — 칸 이름
  ///       x, y — 서식 이미지 좌표 (픽셀)
  ///       size — 글자 크기 (픽셀)
  ///       align — 붙이는 쪽
  ///       weight — 글자 굵기
  ///       color — 글자색 (0xRRGGBB)
  const LayoutField({
    required this.key,
    required this.x,
    required this.y,
    required this.size,
    required this.align,
    required this.weight,
    required this.color,
  });
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: LayoutMetricRow
/// 목적: Performance Metrics 표의 한 행이 어디에 놓이고 어떤 성질인지 담는다.
class LayoutMetricRow {
  /// 이 행이 담는 지표 이름. json 의 `key` 와 같다
  final String key;

  /// 행의 세로 좌표 (서식 이미지 픽셀, 글자 수직 중심)
  final int y;

  /// 기준치가 있어 신호등으로 판정하는 행인지. 속도 · 거리는 기준이 없다
  final bool judge;

  /// 설명 라벨이 서식에 박혀 있는 행인지. 없으면 값을 라벨 자리부터 쓴다
  final bool hasLabel;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: LayoutMetricRow
  /// 목적: 표 한 행의 자리와 성질을 그대로 담는 생성자.
  /// 인자: key — 지표 이름
  ///       y — 행의 세로 좌표 (픽셀)
  ///       judge — 신호등 판정 대상인지
  ///       hasLabel — 설명 라벨이 서식에 박혀 있는지
  const LayoutMetricRow({
    required this.key,
    required this.y,
    required this.judge,
    required this.hasLabel,
  });
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: LayoutPlotBox
/// 목적: 차트 하나가 놓일 네모난 자리. 축 눈금과 라벨을 뺀, 실제 축 틀이
///       들어갈 영역이다.
class LayoutPlotBox {
  /// 왼쪽 가로 좌표 (서식 이미지 픽셀)
  final int x;

  /// 위쪽 세로 좌표 (서식 이미지 픽셀)
  final int y;

  /// 가로 길이 (픽셀)
  final int width;

  /// 세로 길이 (픽셀)
  final int height;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 함수: LayoutPlotBox
  /// 목적: 차트 자리의 좌표와 크기를 그대로 담는 생성자.
  /// 인자: x, y — 왼쪽 위 모서리 (픽셀)
  ///       width, height — 가로 · 세로 길이 (픽셀)
  const LayoutPlotBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: ReportPage1
/// 목적: 리포트 1쪽의 자리들을 담는다. 머리말 11칸, Performance Metrics
///       표 8행, 분석 자료 표 7행이 있다.
///
///       Performance Metrics 행 여덟 개의 세로 좌표는 계산하지 않고 값을
///       그대로 박아 둔다. 행 간격이 106 109 110 109 109 110 95 로 고르지
///       않고, 특히 마지막 한 칸이 뚜렷하게 좁다. 첫 행에서 일정 간격을
///       더해 가면 마지막 행이 12픽셀 넘게 어긋난다.
class ReportPage1 {
  /// 서식 배경 이미지 자산 경로. 정본이 가진 파일 이름 앞에 자산
  /// 디렉터리를 붙인 것이다
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

  /// 엔지니어명. 지금은 비워 둔다 — 로그인 아이디를 끌어오지 않는다
  static const LayoutField engineerName = LayoutField(
    key: 'engineer_name',
    x: 1023,
    y: 100,
    size: 21,
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

  /// 제품. "엘리베이터" 고정
  static const LayoutField product = LayoutField(
    key: 'product',
    x: 1340,
    y: 219,
    size: 26,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.white,
  );

  /// 하중. 앱에 값이 없어 비워 둔다
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

  /// 측정 종류. "층간 시험" 고정
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

  /// 건물명 (현장명)
  static const LayoutField buildingName = LayoutField(
    key: 'building_name',
    x: 78,
    y: 655,
    size: 24,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.text,
  );

  /// 주소. 앱에 값이 없어 비워 둔다
  static const LayoutField address = LayoutField(
    key: 'address',
    x: 1062,
    y: 655,
    size: 24,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.text,
  );

  /// 작성: 2026-09-15 19:43:50 · nada
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

  /// 황색 단계 칸의 가로 좌표 (픽셀). 요구사항에 황색 기준이 없어 비운다
  static const int colYellowX = 1531;

  /// 적색 기준치 칸의 가로 좌표 (픽셀)
  static const int colRedX = 1855;

  /// 구분 이름을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colCategoryAlign = LayoutAlign.left;

  /// 값을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colValueAlign = LayoutAlign.left;

  /// 라벨 없는 7~8행의 값을 칸의 어느 쪽에 붙일지
  static const LayoutAlign colValueNoLabelAlign = LayoutAlign.left;

  /// 황색 단계 값을 칸의 어느 쪽에 붙일지. 지금은 비워 두는 칸이다
  static const LayoutAlign colYellowAlign = LayoutAlign.center;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: colRedAlign
  /// 목적: 적색 기준치를 칸의 어느 쪽에 붙일지. 이 칸만 가운데로 모은다.
  /// 근거: 인용 — `docs/report_layout.json` 의
  ///       `page1.metrics_table.col_align.red`
  static const LayoutAlign colRedAlign = LayoutAlign.center;

  /// 값 글자 크기 (픽셀)
  static const int valueSize = 28;

  /// 기준치 글자 크기 (픽셀)
  static const int thresholdSize = 28;

  /// 서식에 남아 있는 적색 칸을 덮을 네모의 가로 길이 (픽셀)
  static const int eraseRedWidth = 150;

  /// 서식에 남아 있는 적색 칸을 덮을 네모의 세로 길이 (픽셀)
  static const int eraseRedHeight = 46;

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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 변수: maxSpeedY
  /// 목적: 최대 속도 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 원본 리포트에서 잰 값이다. 앞 행과의 간격은 110으로
  ///       위 여섯 행과 비슷하지만, 표 전체 간격이 고르지 않아 계산으로
  ///       구하지 않는다. 이 값을 그대로 쓴다
  static const int maxSpeedY = 1648;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 변수: travelDistanceY
  /// 목적: 운행 거리 행의 세로 좌표 (픽셀).
  /// 근거: 인용 — 원본 리포트에서 잰 값이다. 앞 행과의 간격이 95로 표에서
  ///       가장 좁다. 위 여섯 행의 평균 간격(108.6)으로 넘겨짚으면 1755가
  ///       나와 12픽셀 넘게 어긋난다. 계산하지 말고 이 값을 그대로 쓴다
  static const int travelDistanceY = 1743;

  /// 작성: 2026-09-15 19:43:50 · nada
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

  /// 분석 자료 표의 설명이 시작하는 가로 좌표 (픽셀)
  static const int analysisDescriptionX = 1172;

  /// 분석 자료 표의 설명을 칸의 어느 쪽에 붙일지
  static const LayoutAlign analysisDescriptionAlign = LayoutAlign.left;

  /// 분석 자료 표의 설명 글자 크기 (픽셀)
  static const int analysisDescriptionSize = 28;

  /// 작성: 2026-09-15 19:43:50 · nada
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

  /// 작성: 2026-09-15 19:43:50 · nada
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

/// 작성: 2026-09-15 19:43:50 · nada
/// 클래스: ReportChartPage
/// 목적: 차트 쪽의 자리들을 담는다. 머리말 네 칸과 차트 네 자리가 있다.
///       1쪽과 달리 쪽 번호 칸이 있고, 쪽 제목이 금색으로 들어간다.
class ReportChartPage {
  /// 서식 배경 이미지 자산 경로. 정본이 가진 파일 이름 앞에 자산
  /// 디렉터리를 붙인 것이다
  static const String background = '${ReportLayout.assetDirectory}tem_2.jpg';

  /// 쪽 제목
  static const LayoutField title = LayoutField(
    key: 'title',
    x: 317,
    y: 315,
    size: 70,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.gold,
  );

  /// 측정 식별자 (제번). 1쪽과 같은 자리다
  static const LayoutField measurementId = LayoutField(
    key: 'measurement_id',
    x: 222,
    y: 79,
    size: 30,
    align: LayoutAlign.left,
    weight: LayoutWeight.bold,
    color: ReportColors.navy,
  );

  /// 엔지니어명. 1쪽과 같은 자리다
  static const LayoutField engineerName = LayoutField(
    key: 'engineer_name',
    x: 1023,
    y: 100,
    size: 21,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.navy,
  );

  /// 측정 일시. 1쪽과 같은 자리다
  static const LayoutField datetime = LayoutField(
    key: 'datetime',
    x: 2192,
    y: 80,
    size: 24,
    align: LayoutAlign.right,
    weight: LayoutWeight.bold,
    color: ReportColors.navy,
  );

  /// 쪽 번호
  static const LayoutField pageNumber = LayoutField(
    key: 'page_number',
    x: 2180,
    y: 3128,
    size: 22,
    align: LayoutAlign.right,
    weight: LayoutWeight.regular,
    color: ReportColors.navy,
  );

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 변수: fields
  /// 목적: 차트 쪽 머리말 네 칸을 모아 둔 것. 낱개 상수와 같은 값이며,
  ///       전부 훑어야 할 때 쓴다. 쪽 제목은 머리말이 아니라 따로 둔다.
  static const List<LayoutField> fields = <LayoutField>[
    measurementId,
    engineerName,
    datetime,
    pageNumber,
  ];

  /// 차트 자리의 왼쪽 가로 좌표 (픽셀). 네 자리가 모두 같다
  static const int slotX = 283;

  /// 차트 자리의 가로 길이 (픽셀). 네 자리가 모두 같다
  static const int slotWidth = 1458;

  /// 차트 자리의 세로 길이 (픽셀). 네 자리가 모두 같다
  static const int slotHeight = 198;

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 변수: slots
  /// 목적: 차트 네 자리를 위에서 아래 차례대로 모아 둔 것. 세로 좌표만
  ///       다르고 가로 좌표와 크기는 같다.
  /// 근거: 인용 — 원본 리포트에서 잰 축 틀 위치다
  static const List<LayoutPlotBox> slots = <LayoutPlotBox>[
    LayoutPlotBox(x: slotX, y: 415, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 896, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 1377, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 1858, width: slotWidth, height: slotHeight),
  ];
}
