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
  /// 목적: 서식 이미지 픽셀 하나가 PDF 포인트로 가로 몇인지. json 에는
  ///       소수로 끊은 사본이 적혀 있고, 여기서는 페이지 크기에서 직접
  ///       나눈다. 그래야 서식 오른쪽 끝이 A4 폭에 정확히 떨어진다.
  /// 식: kx = pageWidthPt / pageWidthPx
  /// 근거: 인용 — `docs/report_layout.json` 의 `page.pt_per_px_x`. 가로와
  ///       세로 계수가 다른 이유는 서식 이미지 비율(1.414007)이 A4
  ///       비율(1.414285)과 미세하게 달라서다. 배경을 A4 전면에 늘려
  ///       깔기 때문에 좌표도 같은 배율로 늘어나야 배경 위 자리와
  ///       맞는다. 하나의 계수로 두 축을 다 쓰면 페이지 아래쪽에서
  ///       0.16pt 어긋난다
  static const double ptPerPxX = pageWidthPt / pageWidthPx;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: ptPerPxY
  /// 목적: 서식 이미지 픽셀 하나가 PDF 포인트로 세로 몇인지.
  /// 식: ky = pageHeightPt / pageHeightPx
  /// 근거: 인용 — `docs/report_layout.json` 의 `page.pt_per_px_y`.
  ///       `ptPerPxX` 와 다른 이유는 같은 설명을 본다
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-12 02:13:59 · nada
  /// 변수: engineerName
  /// 목적: 엔지니어명. 측정을 저장할 때 설정에 있던 이름이다. 없으면
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-11 19:15:25 · nada
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-11 19:15:25 · nada
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-11 19:15:25 · nada
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-12 02:13:59 · nada
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

  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-12 02:13:59 · nada
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

  /// 작성: 2026-10-11 19:15:25 · nada
  /// 변수: placeholder
  /// 목적: 값이 없는 머리말 칸(엔지니어 · 하중 · 주소)에 찍는 자리 표시
  ///       문구. 칸을 비우면 빠뜨린 것처럼 보인다. 0 이나 지어낸 값은 찍지
  ///       않는다(관통 원칙 1).
  /// 근거: 인용 — 2026-10-11 사용자 결정
  static const String placeholder = '미입력';

  /// 작성: 2026-10-11 19:15:25 · nada
  /// 변수: headerRightLimitX
  /// 목적: 머리말 글자가 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 측정 일시
  ///       칸의 오른쪽 맞춤 자리와 같은 여백이다.
  /// 근거: 인용 — `datetime` 칸의 x 와 같다
  static const int headerRightLimitX = 2192;

  /// 작성: 2026-10-12 02:13:59 · nada
  /// 변수: engineerRightLimitX
  /// 목적: 엔지니어명이 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 같은 금색
  ///       띠 오른쪽의 측정 일시 문구와 겹치지 않게 그 앞에서 멈춘다.
  /// 근거: 측정 — 원본 리포트 1쪽에서 측정 일시 문구가 x 약 1832 에서
  ///       시작한다. 그 앞으로 여백을 둔다
  static const int engineerRightLimitX = 1800;

  /// 작성: 2026-10-12 02:13:59 · nada
  /// 변수: buildingNameRightLimitX
  /// 목적: 건물명이 넘지 않을 오른쪽 끝의 가로 좌표 (픽셀). 금색 띠의 사선
  ///       줄무늬가 시작하기 전에 멈춘다.
  /// 근거: 측정 — 원본 리포트 1쪽 건물명 줄 높이에서 사선 줄무늬가 x 약
  ///       709 에서 시작한다
  static const int buildingNameRightLimitX = 700;

  /// 작성: 2026-10-11 19:15:25 · nada
  /// 수정: 2026-10-12 02:13:59 · nada
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

  /// 작성: 2026-10-11 19:15:25 · nada
  /// 수정: 2026-10-12 02:13:59 · nada
  /// 함수: maxWidthOf
  /// 목적: 칸 하나가 쓸 수 있는 가장 큰 폭을 정한다. 차트 쪽 머리말도 같은
  ///       이름 · 같은 자리의 칸(엔지니어명)이라 함께 쓴다.
  /// 인자: field — 머리말 칸
  /// 반환: 쓸 수 있는 폭 (픽셀). 폭을 재지 않는 칸이면 null
  static int? maxWidthOf(LayoutField field) {
    final limit = fitRightLimitX[field.key]; // 그 칸의 오른쪽 한계, 없으면 null
    return limit == null ? null : limit - field.x;
  }

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

  /// 서식에 남아 있는 황색 · 적색 칸을 덮을 네모의 가로 길이 (픽셀)
  static const int eraseRedWidth = 150;

  /// 서식에 남아 있는 황색 · 적색 칸을 덮을 네모의 세로 길이 (픽셀)
  static const int eraseRedHeight = 46;

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 변수: remarkX
  /// 목적: 황색 · 적색 행의 OTIS 문구(`ReportMetric.remarkLines`)를 쓰기
  ///       시작하는 가로 좌표 (픽셀). 서식 설명 라벨 자리(`colValueNoLabelX`
  ///       와 같은 열)다.
  /// 근거: 인용 — 2026-10-21 점검 지시. OTIS 리포트는 황색 · 적색 행의
  ///       설명 칸에 라벨 · 값 대신 문장을 적는다
  static const int remarkX = 742;

  /// 문구를 쓰기 전에 서식 설명 라벨 · 값 자리를 덮을 네모의 왼쪽 끝 (픽셀)
  static const int remarkEraseX = 735;

  /// 작성: 2026-10-21 13:10:00 · nada
  /// 변수: remarkEraseWidth
  /// 목적: 문구 자리를 덮을 네모의 가로 길이 (픽셀). 오른쪽 끝(1447)이 황색
  ///       칸 덮개 왼쪽 끝(`colYellowX` − `eraseRedWidth` / 2 = 1456)에 닿지
  ///       않는다. 문구가 이 폭을 넘으면 글자를 줄인다.
  static const int remarkEraseWidth = 712;

  /// 문구 자리를 덮을 네모의 세로 길이 (픽셀). 행 줄무늬 안이다
  static const int remarkEraseHeight = 86;

  /// 문구 글자 크기 (픽셀). 두 줄이 한 행에 들어가게 값보다 조금 작다
  static const int remarkSize = 25;

  /// 문구 두 줄의 세로 간격 (픽셀). 행 가운데에서 위아래로 반씩 띄운다
  static const int remarkLineGap = 34;

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

  /// 분석 자료 표의 구분 이름이 시작하는 가로 좌표 (픽셀)
  static const int analysisCategoryX = 313;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: analysisCategorySize
  /// 목적: 분석 자료 표의 구분 이름을 새로 찍을 때 글자 크기 (픽셀).
  /// 근거: 측정 — 서식 tem_1.jpg 에서 "Machine으로 부터 진동" 글자 높이가
  ///       y 2185~2212(27 픽셀)다. 1쪽 표의 값 글자 크기(28)와 같게 둔다
  static const int analysisCategorySize = 28;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: analysisCategoryWeight
  /// 목적: 분석 자료 표의 구분 이름을 새로 찍을 때 글자 굵기.
  /// 근거: 측정 — 서식 tem_1.jpg 의 구분 이름은 본문 글자보다 굵다. 보통
  ///       굵기로 찍으면 이웃 행 이름보다 가늘고 흐리게 보였다(2026-10-15
  ///       270dpi 비교)
  static const LayoutWeight analysisCategoryWeight = LayoutWeight.bold;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: eraseAnalysisLabelX
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 왼쪽 끝 가로 좌표 (픽셀).
  ///       신호등 원(오른쪽 끝 x 258)에 닿지 않는다.
  /// 근거: 측정 — 서식 tem_1.jpg 에서 구분 이름 글자가 x 311 에서
  ///       시작한다
  static const int eraseAnalysisLabelX = 300;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: eraseAnalysisLabelWidth
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 가로 길이 (픽셀).
  /// 근거: 측정 — 가장 긴 "Machine으로 부터 진동" 이 x 620 에서 끝난다.
  ///       설명 칸(x 1172)보다 한참 앞에서 멈춘다
  static const int eraseAnalysisLabelWidth = 360;

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: eraseAnalysisLabelHeight
  /// 목적: 서식에 박힌 구분 이름을 덮을 네모의 세로 길이 (픽셀). 행
  ///       세로 좌표를 가운데로 둔다.
  /// 근거: 측정 — 글자 높이 27 픽셀에 위아래 여유를 둔 값. 행 간격(약
  ///       101)의 절반을 넘지 않아 이웃 행을 덮지 않는다
  static const int eraseAnalysisLabelHeight = 52;

  /// 작성: 2026-10-15 15:53:26 · nada
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
  /// 작성: 2026-09-15 19:43:50 · nada
  /// 수정: 2026-10-21 17:10:00 · nada
  /// 변수: background
  /// 목적: 서식 배경 이미지 자산 경로. 정본이 가진 파일 이름 앞에 자산
  ///       디렉터리를 붙인 것이다. 2026-10-21 이미지에서 예전 차트를 붓으로
  ///       지운 자국(밝기 252 ~ 254 의 옅은 회색 덩어리, PDF 에서 차트 둘레
  ///       그림자처럼 보임)을 흰색(255)으로 바꿨다 — 세 채널이 모두 246
  ///       이상인 점만 바꿔 머리말 · 꼬리말 띠와 로고는 그대로다.
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

  /// 엔지니어명. 1쪽과 같은 칸을 그대로 쓴다 — 자리를 두 곳에 적으면 한쪽만
  /// 고쳐져 어긋난다
  static const LayoutField engineerName = ReportPage1.engineerName;

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
