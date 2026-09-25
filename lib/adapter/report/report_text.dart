import 'package:pdf/pdf.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-09-25 09:30:00 · nada
/// 함수: reportPdfColor
/// 목적: `ReportColors` 의 0xRRGGBB 값을 PDF 색으로 바꾼다. 색을 정해 둔
///       `report_layout.dart` 는 바깥 패키지를 쓰지 않기로 되어 있어,
///       PDF 자료형으로 바꾸는 일은 그리는 쪽인 여기서 한다.
/// 인자: rgb — 색 값 (0xRRGGBB)
/// 반환: 불투명한 PDF 색
PdfColor reportPdfColor(int rgb) => PdfColor.fromInt(0xFF000000 | rgb);

/// 작성: 2026-09-25 09:30:00 · nada
/// 클래스: ReportTextWriter
/// 목적: 서식 좌표에 글자를 찍는다. 1쪽과 차트 쪽이 같은 방식으로 찍어야
///       두 쪽의 머리말이 같은 자리에 놓이므로, 찍는 코드를 한 곳에 둔다.
///
///       서식의 세로 좌표는 글자의 수직 중심이라 찍기 전에 글자가 앉는
///       선으로 내려야 한다. 내리는 몫은 `ReportLayout` 이 갖는다 — 그
///       값이 참조 PDF 와의 약속이라 구현마다 따로 두면 안 된다.
class ReportTextWriter {
  /// 보통 굵기 한글 글꼴
  final PdfFont regular;

  /// 굵게 쓸 자리용 한글 글꼴
  final PdfFont bold;

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 함수: ReportTextWriter
  /// 목적: 글꼴 두 벌을 그대로 담는 생성자.
  /// 인자: regular, bold — 한글 글꼴 두 벌
  const ReportTextWriter({required this.regular, required this.bold});

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 함수: fontOf
  /// 목적: 굵기에 맞는 글꼴을 고른다.
  /// 인자: weight — 글자 굵기
  /// 반환: 그 굵기의 글꼴
  PdfFont fontOf(LayoutWeight weight) =>
      weight == LayoutWeight.bold ? bold : regular;

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 함수: drawField
  /// 목적: 서식의 한 칸에 글자를 찍는다. 칸이 가진 자리 · 크기 · 굵기 ·
  ///       색을 그대로 따른다.
  /// 인자: canvas — 그리기 도구
  ///       field — 찍을 칸의 자리와 모양
  ///       text — 찍을 문구. 비어 있으면 아무것도 하지 않는다
  void drawField(
    PdfGraphics canvas, {
    required LayoutField field,
    required String text,
  }) {
    // → 로직 이동: ReportTextWriter.drawAt()
    drawAt(
      canvas,
      xPx: field.x,
      yPx: field.y,
      text: text,
      sizePx: field.size,
      align: field.align,
      weight: field.weight,
      color: field.color,
    );
  }

  /// 작성: 2026-09-25 09:30:00 · nada
  /// 함수: drawAt
  /// 목적: 글자 한 덩이를 서식 좌표에 찍는다. 서식에 칸으로 잡혀 있지 않은
  ///       자리, 이를테면 표 안의 값처럼 좌표를 그때그때 셈해 넣는 곳에
  ///       쓴다.
  /// 인자: canvas — 그리기 도구
  ///       xPx, yPx — 서식 이미지 좌표 (픽셀). `yPx` 는 글자의 수직 중심
  ///       text — 찍을 문구. 비어 있으면 아무것도 하지 않는다
  ///       sizePx — 글자 크기 (픽셀)
  ///       align — 기준 좌표의 어느 쪽에 붙일지
  ///       weight — 글자 굵기
  ///       color — 글자색 (0xRRGGBB)
  /// 식: baseline = y_pt - size_pt x ReportLayout.textBaselineDropRatio
  void drawAt(
    PdfGraphics canvas, {
    required num xPx,
    required num yPx,
    required String text,
    required num sizePx,
    required LayoutAlign align,
    required LayoutWeight weight,
    required int color,
  }) {
    if (text.isEmpty) return;

    final font = fontOf(weight); // 쓸 글꼴
    final size = ReportLayout.lengthToPoints(sizePx); // 글자 크기 (포인트)
    final baseline =
        ReportLayout.yToPoints(yPx) -
        size * ReportLayout.textBaselineDropRatio; // 글자가 앉는 선 (포인트)
    final width =
        font.stringMetrics(text).advanceWidth * size; // 문구 전체 너비 (포인트)

    var x = ReportLayout.xToPoints(xPx); // 찍기 시작할 가로 자리 (포인트)
    if (align == LayoutAlign.right) {
      x -= width;
    } else if (align == LayoutAlign.center) {
      x -= width / 2;
    }

    canvas
      ..setFillColor(reportPdfColor(color))
      ..drawString(font, size, text, x, baseline);
  }
}
