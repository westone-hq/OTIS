/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-28 17:16:58 · 박희정
/// 클래스: ReportLayout
/// 목적: TUNE 리포트 서식 위에 값을 얹을 자리를 모아 둔다. 리포트의
///       좌표 숫자는 전부 이 파일과 쪽별 좌표 파일
///       (`report_page1_layout.dart` · `report_chart_page_layout.dart`)에만
///       있고, 그리는 쪽은 여기서 꺼내 쓴다. 좌표가 틀어지면 이 세 파일만
///       고치면 된다.
///
///       옮겨온 곳
///         `docs/report_layout.json` (md5 38cde4c2b9730fa8ae66e84b902b175c,
///         2026-09-25 기준). 그 파일이 정본 기록이고 이 세 파일은 사람이
///         옮긴 사본이다. json 을 실행 중에 읽지 않는 이유는, 읽지 않으면
///         자산을 못 찾아 실패하는 경로가 하나 줄고, 좌표가 틀리면 빌드가
///         아니라 결과물을 눈으로 보고 잡게 되기 때문이다. 옮기다 숫자가
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

  /// 작성: 2026-09-25 09:30:00 · 박건준
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

  /// 작성: 2026-10-28 14:45:51 · 박희정
  /// 수정: 2026-10-28 23:30:00 · 박건준
  /// 변수: headerLogoAsset
  /// 목적: 모든 쪽의 머리말에 쓸 새 로고. 꼬리말도 같은 그림을 쓰고
  ///       크기 · 덮을 영역만 따로 정한다.
  /// 근거: 인용 — 2026-10-28 사용자 제공 `OTIS 최종로고.png`. 상단 교체 후
  ///       하단도 갈색 띠를 유지하면서 같은 로고로 교체하도록 요청했다.
  ///       측정 — 원본(2172 x 724, `design/report_logo/`)을 그대로 넣으면
  ///       PDF 가 1.16 → 1.84MB 로 커져 같은 비율 960 x 320 으로 줄였다.
  ///       리포트에 그리는 상자가 서식 기준 320 x 108 픽셀이라 세 배
  ///       해상도로 충분하다(2026-10-28)
  static const String headerLogoAsset = '${assetDirectory}otis_v_check.png';

  /// 작성: 2026-10-28 14:45:51 · 박희정
  /// 수정: 2026-10-28 15:10:01 · 박희정
  /// 변수: headerLogoMask
  /// 목적: 서식에 인쇄된 상단 로고와 옛 구분선을 덮을 자리 (픽셀). 확대
  ///       로고와 새 구분선을 이 안에 그리고 제번은 오른쪽에 따로 놓는다.
  /// 근거: 인용 — 2026-10-28 사용자 지시로 로고를 키우고 제번을 옮긴다.
  ///       기존 로고 · 구분선과 새 로고 자리를 함께 덮되 제번은 덮지 않는다
  static const LayoutPlotBox headerLogoMask = LayoutPlotBox(
    x: 50,
    y: 53,
    width: 315,
    height: 56,
  );

  /// 작성: 2026-10-28 14:45:51 · 박희정
  /// 수정: 2026-10-28 15:10:01 · 박희정
  /// 변수: headerLogoBox
  /// 목적: 원본의 흰 여백을 포함한 로고를 놓을 자리 (픽셀). 원본을 자르거나
  ///       늘리지 않고 맞추며, 바깥 여백은 `headerLogoMask` 로 가린다.
  /// 근거: 인용 — 2026-10-28 사용자 비교 이미지의 OTIS 글자 높이에 맞춰
  ///       이전 출력의 가로 · 세로를 두 배로 키운다. 원본 흰 여백을 포함해
  ///       가운데를 맞추면 실제 문양은 기존 로고와 같은 높이로 놓인다
  static const LayoutPlotBox headerLogoBox = LayoutPlotBox(
    x: 36,
    y: 26,
    width: 320,
    height: 108,
  );

  /// 작성: 2026-10-28 15:10:01 · 박희정
  /// 변수: headerLogoDivider
  /// 목적: 확대 로고와 제번 사이 금색 구분선 자리 (픽셀). 서식의 옛 선은
  ///       `headerLogoMask` 로 지우므로 새 위치에 그린다.
  /// 근거: 측정 — 기존 선의 높이 42픽셀과 제번까지의 간격을 유지하며
  ///       확대 로고 오른쪽으로 옮긴다
  static const LayoutPlotBox headerLogoDivider = LayoutPlotBox(
    x: 350,
    y: 60,
    width: 4,
    height: 42,
  );

  /// 작성: 2026-10-28 17:16:58 · 박희정
  /// 변수: footerLogoMask
  /// 목적: 꼬리말에서 옛 로고만 덮을 흰 영역 (픽셀). 사선이 가까워지는
  ///       오른쪽 아래끝까지 흰 영역 안에 두어 갈색 서식을 보호한다.
  /// 근거: 측정 — `tem_1.jpg` · `tem_2.jpg` 옛 로고는 x 59~175,
  ///       y 3107~3148 이다. 덮개 오른쪽 끝 x 225 는 사선 왼쪽 끝보다 작다
  static const LayoutPlotBox footerLogoMask = LayoutPlotBox(
    x: 12,
    y: 3097,
    width: 213,
    height: 60,
  );

  /// 작성: 2026-10-28 17:16:58 · 박희정
  /// 변수: footerLogoBox
  /// 목적: 여백을 포함한 하단 로고의 원본 상자 (픽셀). 원본 비율을 유지해
  ///       OTIS · 구분선 · V-check 가 흰 영역 안에 함께 들어가게 한다.
  /// 근거: 측정 — 원본의 문양 범위 x 160~2006, y 216~493 을 240 x 80
  ///       상자에 놓으면 문양 오른쪽 끝은 x 222, 아래끝은 y 3140 이다
  static const LayoutPlotBox footerLogoBox = LayoutPlotBox(
    x: 0,
    y: 3085,
    width: 240,
    height: 80,
  );

  /// 작성: 2026-09-25 09:30:00 · 박건준
  /// 수정: 2026-10-23 01:10:00 · 박건준
  /// 변수: textBaselineDropRatio
  /// 목적: 글자 크기 대비, 글자 덩이의 세로 한가운데에서 앉는 선까지
  ///       내려야 하는 몫. 서식의 세로 좌표가 글자의 수직 중심이라, 찍기
  ///       전에 이만큼 내려야 한다.
  /// 근거: 인용 — 파이썬 프로토타입(2026-10-23 저장소에서 지움, 커밋
  ///       6bd171a 의 `pdf_report_dev/tune_report/render.py` 92행)이 원본
  ///       리포트와 글자 자리를 맞춰 찾은 값이다. 1쪽과 차트 쪽이 모두
  ///       같은 몫을 써야 같은 자리에 찍히므로 이 값은 두 렌더러 사이의
  ///       약속이며, 바꾸면 원본 리포트와 글자 자리가 갈라진다
  static const double textBaselineDropRatio = 0.36;

  /// 작성: 2026-09-25 09:30:00 · 박건준
  /// 변수: datetimePattern
  /// 목적: 머리말 측정 일시의 표기 형식. 1쪽과 차트 쪽이 같은 자리에 같은
  ///       문구를 찍어야 해서 한 곳에 둔다.
  /// 근거: 인용 — 원본 리포트 머리말이 `14/01/2026 11:03:59 AM` 형태다
  static const String datetimePattern = 'dd/MM/yyyy hh:mm:ss a';

  /// 작성: 2026-09-15 20:13:49 · 박건준
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

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 변수: ptPerPxY
  /// 목적: 서식 이미지 픽셀 하나가 PDF 포인트로 세로 몇인지.
  /// 식: ky = pageHeightPt / pageHeightPx
  /// 근거: 인용 — `docs/report_layout.json` 의 `page.pt_per_px_y`.
  ///       `ptPerPxX` 와 다른 이유는 같은 설명을 본다
  static const double ptPerPxY = pageHeightPt / pageHeightPx;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 함수: xToPoints
  /// 목적: 서식 이미지의 가로 좌표를 PDF 가로 좌표로 바꾼다.
  /// 인자: xPx — 서식 이미지 가로 좌표 (픽셀, 왼쪽이 0)
  /// 반환: PDF 가로 좌표 (포인트)
  /// 식: x_pt = x_px x ptPerPxX
  static double xToPoints(num xPx) => xPx * ptPerPxX;

  /// 작성: 2026-09-15 19:43:50 · 박건준
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

  /// 작성: 2026-09-15 19:43:50 · 박건준
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

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 클래스: LayoutAlign
/// 목적: 글자를 기준 좌표의 어느 쪽에 붙일지.
enum LayoutAlign { left, center, right }

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 클래스: LayoutWeight
/// 목적: 글자 굵기. 서식에 쓰는 글꼴이 보통과 굵게 두 벌뿐이다.
enum LayoutWeight { regular, bold }

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-23 11:00:00 · 박건준
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

  /// 판정 주의 — 노란 신호등. 황색 기준을 넘고 적색 기준 이하일 때
  /// (`ReportThresholds`, 2026-10-15)
  static const int judgeYellow = 0xF5C324;

  /// 판정 초과 — 빨간 신호등
  static const int judgeRed = 0xD93025;

  /// 아직 재지 못해 판정할 수 없는 항목의 회색 신호등
  static const int judgeUnknown = 0xB9BFC7;

  /// 차트 선 색
  static const int chartLine = 0x0000CC;

  /// 차트 격자 선 색. 축 틀 · 눈금 · 라벨은 `text` 를 쓰고 격자만 이 색이다
  static const int chartGrid = 0x555555;

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-23 11:00:00 · 박건준
  /// 변수: chartMarker
  /// 목적: 차트에서 짚는 점과 그 옆 값 상자의 색. 진동 세 축의 최대 P2P
  ///       두 지점(2026-10-15, 수직은 Jptp 두 지점도)과 소음 최댓값에
  ///       붙는다.
  static const int chartMarker = 0xE03030;

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-23 11:00:00 · 박건준
  /// 변수: chartGuide
  /// 목적: 차트에 가로로 긋는 기준선의 색. 소음 차트의 평균선과 진동 세
  ///       축의 A95 점선(2026-10-20)에 쓴다.
  /// 근거: 측정 — 원본 리포트 소음 차트의 붉은 점선을 픽셀로 재니 한
  ///       줄이고 값이 45.73 dBA 로, 1쪽 표의 "소음, 평균"(45.80)과 같은
  ///       값이다. A95(52.82)와는 전혀 다르다
  static const int chartGuide = 0xE03030;

  /// 표 홀수 행 바탕색
  static const int stripeOdd = 0xE6E9EE;

  /// 표 짝수 행 바탕색
  static const int stripeEven = 0xFAF6ED;
}

/// 작성: 2026-09-15 19:43:50 · 박건준
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

  /// 작성: 2026-09-15 19:43:50 · 박건준
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

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-28 15:25:15 · 박희정
/// 클래스: LayoutMetricRow
/// 목적: Performance Metrics 표의 한 행이 어디에 놓이고 어떤 성질인지 담는다.
class LayoutMetricRow {
  /// 이 행이 담는 지표 이름. json 의 `key` 와 같다
  final String key;

  /// 카테고리 칸에 찍을 이름. 배경 이미지의 옛 수직 · 수평 이름을 대신한다
  final String label;

  /// 측정값 오른쪽 설명 열의 문구. 속도 · 거리처럼 설명을 쓰지 않으면 빈 문자열
  final String description;

  /// 행의 세로 좌표 (서식 이미지 픽셀, 글자 수직 중심)
  final int y;

  /// 기준치가 있어 신호등으로 판정하는 행인지. 속도 · 거리는 기준이 없다
  final bool judge;

  /// 설명 열에 기본 문구를 그릴 행인지. 측정값 위치는 모든 행이 같다
  final bool hasLabel;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-28 16:29:35 · 박희정
  /// 함수: LayoutMetricRow
  /// 목적: 표 한 행의 자리와 성질을 그대로 담는 생성자.
  /// 인자: key — 지표 이름
  ///       label — 카테고리 이름
  ///       description — 측정값 오른쪽 열의 설명. 없으면 빈 문자열
  ///       y — 행의 세로 좌표 (픽셀)
  ///       judge — 신호등 판정 대상인지
  ///       hasLabel — 설명 열에 기본 문구를 그릴지
  const LayoutMetricRow({
    required this.key,
    required this.label,
    required this.description,
    required this.y,
    required this.judge,
    required this.hasLabel,
  });
}

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-28 17:39:01 · 박희정
/// 클래스: LayoutPlotBox
/// 목적: 차트 · 로고 · 서식 덮개에 쓰는 네모 영역을 담는다. 같은 서식
///       이미지 픽셀 좌표계를 써야 배경과 덧그린 내용의 위치가 일치한다.
class LayoutPlotBox {
  /// 왼쪽 가로 좌표 (서식 이미지 픽셀)
  final int x;

  /// 위쪽 세로 좌표 (서식 이미지 픽셀)
  final int y;

  /// 가로 길이 (픽셀)
  final int width;

  /// 세로 길이 (픽셀)
  final int height;

  /// 작성: 2026-09-15 19:43:50 · 박건준
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
