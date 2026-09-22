import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-16 09:12:40 · nada
/// 클래스: ReportPage1Renderer
/// 목적: TUNE 리포트 1쪽을 PDF 로 그린다. 서식 이미지를 A4 전면에 깔고 그
///       위에 값을 얹는다. 자리는 `ReportLayout` 이, 값과 판정은
///       `ReportMetrics` 가 정해 둔 것을 받아 적기만 한다 — 여기서
///       계산하거나 판단하지 않는다.
///
///       서식을 덮어야 하는 자리
///         서식 이미지에는 예전 리포트의 값이 일부 인쇄된 채로 남아 있다.
///         그 위에 새 값을 쓰면 두 글자가 겹쳐 보이므로, 쓰기 전에 그 행의
///         줄무늬 색으로 덮는다.
///         - 적색 기준 칸 전체와 마지막 두 행의 황색 `0`
///         - 1행 신호등 자리에 지워지다 만 원
///
///       황색 칸은 덮기만 하고 비운다. 요구사항에 황색 단계가 없다.
class ReportPage1Renderer {
  /// 그림을 얹을 PDF 문서
  final PdfDocument document;

  /// 본문용 한글 글꼴
  final PdfFont regular;

  /// 굵게 쓸 자리용 한글 글꼴
  final PdfFont bold;

  /// A4 전면에 깔 서식 이미지
  final PdfImage background;

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: ReportPage1Renderer
  /// 목적: 문서와 미리 읽어 둔 자산을 그대로 담는 생성자. 직접 부르지 말고
  ///       `load()` 를 쓴다.
  /// 인자: document — 그림을 얹을 PDF 문서
  ///       regular, bold — 한글 글꼴 두 벌
  ///       background — 서식 이미지
  const ReportPage1Renderer({
    required this.document,
    required this.regular,
    required this.bold,
    required this.background,
  });

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: load
  /// 목적: 글꼴 두 벌과 서식 이미지를 자산에서 읽어 렌더러를 만든다.
  ///       자산 읽기는 느리고 한 번이면 되므로 그리기와 떼어 둔다.
  /// 인자: document — 그림을 얹을 PDF 문서
  /// 반환: 바로 그릴 수 있는 렌더러
  static Future<ReportPage1Renderer> load(PdfDocument document) async {
    final regularBytes = await rootBundle.load(
      'assets/report/NanumGothic-Regular.ttf',
    ); // 본문 글꼴 원본
    final boldBytes = await rootBundle.load(
      'assets/report/NanumGothic-Bold.ttf',
    ); // 굵은 글꼴 원본
    final backgroundBytes = await rootBundle.load(
      ReportPage1.background,
    ); // 서식 이미지 원본

    return ReportPage1Renderer(
      document: document,
      regular: PdfTtfFont(document, regularBytes),
      bold: PdfTtfFont(document, boldBytes),
      background: PdfImage.file(
        document,
        bytes: backgroundBytes.buffer.asUint8List(),
      ),
    );
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: draw
  /// 목적: 1쪽을 문서에 더한다. 순서대로 그린다.
  ///       1. 서식 이미지를 A4 전면에 깐다
  ///       2. 머리말 11칸을 찍는다
  ///       3. Performance Metrics 8행을 찍는다. 행마다 서식에 남은 자국을
  ///          덮고, 신호등 · 값 · 적색 기준을 올린다
  ///       4. 분석 자료 7행의 신호등을 회색으로 찍는다
  /// 인자: result — 값을 가져올 측정 결과
  ///       debug — true 면 모든 자리에 십자 표식과 키 이름을 함께 찍는다.
  ///       좌표가 틀어졌는지 눈으로 확인할 때만 켠다. 제품 흐름은 기본값인
  ///       꺼짐으로 돈다
  /// 반환: 문서에 더해진 1쪽
  PdfPage draw({required MeasurementResult result, bool debug = false}) {
    final page = PdfPage(
      document,
      pageFormat: PdfPageFormat(
        ReportLayout.pageWidthPt,
        ReportLayout.pageHeightPt,
      ),
    ); // 이번에 그릴 쪽
    final canvas = page.getGraphics(); // 그리기 도구

    canvas.drawImage(
      background,
      0,
      0,
      ReportLayout.pageWidthPt,
      ReportLayout.pageHeightPt,
    );

    // → 로직 이동: ReportMetrics.from()
    final metrics = ReportMetrics.from(result); // 표에 올릴 지표 여덟 개
    final header = _headerValues(result); // 머리말 칸마다 채울 문구

    for (final field in ReportPage1.fields) {
      _text(
        canvas,
        xPx: field.x,
        yPx: field.y,
        text: header[field.key] ?? '',
        sizePx: field.size,
        align: field.align,
        weight: field.weight,
        color: field.color,
        key: field.key,
        debug: debug,
      );
    }

    _drawMetricsTable(canvas, metrics, debug: debug);
    _drawAnalysisTable(canvas, debug: debug);
    return page;
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _drawMetricsTable
  /// 목적: Performance Metrics 여덟 행을 찍는다. 행마다 이렇게 한다.
  ///       1. 신호등 자리를 그 행의 줄무늬 색으로 덮는다. 서식 1행에
  ///          지워지다 만 원이 흐리게 남아 있어서다
  ///       2. 판정이 "판정없음" 이 아니면 신호등 원을 그린다. "미확정" 은
  ///          회색 원이다 — 지금은 소음 2행과 진동 4행이 여기 해당한다
  ///       3. 값을 찍는다. 설명 라벨이 서식에 박힌 행은 라벨이 끝나는
  ///          자리 뒤에서, 라벨이 없는 마지막 두 행은 더 왼쪽에서 시작한다
  ///       4. 황색 칸과 적색 칸을 덮은 뒤, 기준이 있는 행만 적색을 다시
  ///          찍는다. 황색은 비운다
  /// 인자: canvas — 그리기 도구
  ///       metrics — 표에 올릴 지표 여덟 개
  ///       debug — 표식을 함께 찍을지
  void _drawMetricsTable(
    PdfGraphics canvas,
    ReportMetrics metrics, {
    required bool debug,
  }) {
    final rows = ReportPage1.metricRows; // 서식에 놓인 행 자리
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index]; // 이번에 그릴 행의 자리
      final metric = metrics.rows[index]; // 그 행에 올릴 지표
      final stripe = index.isEven
          ? ReportColors.stripeOdd
          : ReportColors.stripeEven; // 이 행의 줄무늬 색

      const diameter = ReportPage1.dotDiameter; // 신호등 지름 (픽셀)
      _erase(
        canvas,
        xPx: ReportPage1.dotCenterX - diameter,
        yPx: row.y - diameter,
        widthPx: diameter * 2,
        heightPx: diameter * 2,
        color: stripe,
      );
      final dotColor = _verdictColor(metric.verdict); // 신호등 색, 없으면 null
      if (dotColor != null) {
        _dot(
          canvas,
          centerXPx: ReportPage1.dotCenterX,
          centerYPx: row.y,
          diameterPx: diameter,
          color: dotColor,
        );
      }

      _text(
        canvas,
        xPx: row.hasLabel
            ? ReportPage1.colValueX
            : ReportPage1.colValueNoLabelX,
        yPx: row.y,
        text: metric.display,
        sizePx: ReportPage1.valueSize,
        align: ReportPage1.colValueAlign,
        weight: LayoutWeight.regular,
        color: ReportColors.text,
        key: row.key,
        debug: debug,
      );

      for (final columnX in [ReportPage1.colYellowX, ReportPage1.colRedX]) {
        _erase(
          canvas,
          xPx: columnX - ReportPage1.eraseRedWidth / 2,
          yPx: row.y - ReportPage1.eraseRedHeight / 2,
          widthPx: ReportPage1.eraseRedWidth,
          heightPx: ReportPage1.eraseRedHeight,
          color: stripe,
        );
      }
      _text(
        canvas,
        xPx: ReportPage1.colRedX,
        yPx: row.y,
        text: metric.redDisplay,
        sizePx: ReportPage1.thresholdSize,
        align: ReportPage1.colRedAlign,
        weight: LayoutWeight.regular,
        color: ReportColors.text,
        key: '${row.key}.red',
        debug: debug,
      );
    }
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _drawAnalysisTable
  /// 목적: 분석 자료 일곱 행의 신호등을 찍는다. 일곱 개 모두 회색이다.
  ///       설명 칸은 비운다.
  /// 인자: canvas — 그리기 도구
  ///       debug — 표식을 함께 찍을지
  /// 근거: 인용 — `pdf_report_dev/README.md` 가 이 일곱 항목을 회색으로
  ///       두기로 확정했다. 요구사항에 없고 앱이 판정할 근거도 없다.
  ///       녹색으로 찍으면 "이상 없음을 확인했다" 로 읽히는데 확인한 적이
  ///       없다
  void _drawAnalysisTable(PdfGraphics canvas, {required bool debug}) {
    final keys = ReportPage1.analysisRowKeys; // 행 이름
    final ys = ReportPage1.analysisRowYs; // 행 세로 자리
    for (var index = 0; index < ys.length; index++) {
      final stripe = index.isEven
          ? ReportColors.stripeOdd
          : ReportColors.stripeEven; // 이 행의 줄무늬 색

      const diameter = ReportPage1.dotDiameter; // 신호등 지름 (픽셀)
      _erase(
        canvas,
        xPx: ReportPage1.dotCenterX - diameter,
        yPx: ys[index] - diameter,
        widthPx: diameter * 2,
        heightPx: diameter * 2,
        color: stripe,
      );
      _dot(
        canvas,
        centerXPx: ReportPage1.dotCenterX,
        centerYPx: ys[index],
        diameterPx: diameter,
        color: ReportColors.judgeUnknown,
      );
      if (debug) {
        _debugMark(
          canvas,
          xPx: ReportPage1.analysisDescriptionX,
          yPx: ys[index],
          label: keys[index],
        );
      }
    }
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _headerValues
  /// 목적: 머리말 열한 칸에 채울 문구를 만든다. 앱이 들고 있지 않은 칸은
  ///       고정값으로 채우거나 비운다.
  ///       - 제번 → 측정 ID, 현장명 → 건물명, 최하층·최상층 → 층 정보
  ///       - 제품 · 품질성능기준 · 측정 종류는 고정 문구
  ///       - 하중과 주소는 앱이 입력받지 않아 비운다
  ///       - 엔지니어명은 비운다. 로그인 아이디를 끌어오지 않기로 했다
  /// 인자: result — 값을 가져올 측정 결과
  /// 반환: 서식 칸 이름을 열쇠로 하는 문구 표
  /// 근거: 인용 — `pdf_report_dev/README.md` 의 헤더 대응표. 그 표는
  ///       요구사항서 "현장 정보" 를 우선 배치하도록 정하고 있다
  Map<String, String> _headerValues(MeasurementResult result) {
    final stamp = DateFormat(
      'dd/MM/yyyy hh:mm:ss a',
    ).format(result.dateTime); // 머리말에 쓸 측정 일시
    return <String, String>{
      'measurement_id': result.jobNo,
      'engineer_name': '',
      'datetime': stamp,
      'product': '엘리베이터',
      'load': '',
      'standard': 'Standard',
      'test_type': '층간 시험',
      'direction': result.direction,
      'floors': '시작층 : ${result.bottomFloor}, 도착층 : ${result.topFloor}',
      'building_name': result.siteName,
      'address': '',
    };
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _verdictColor
  /// 목적: 판정 결과를 신호등 색으로 바꾼다.
  /// 인자: verdict — 판정 결과
  /// 반환: 신호등 색 (0xRRGGBB). 기준이 없는 항목이면 null — 원을 그리지
  ///       않는다. 원본 리포트도 그 행에는 원이 없다
  int? _verdictColor(ReportVerdict verdict) {
    switch (verdict) {
      case ReportVerdict.green:
        return ReportColors.judgeGreen;
      case ReportVerdict.red:
        return ReportColors.judgeRed;
      case ReportVerdict.unknown:
        return ReportColors.judgeUnknown;
      case ReportVerdict.none:
        return null;
    }
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _text
  /// 목적: 글자 한 덩이를 서식 좌표에 찍는다. 세로 좌표는 글자의 수직
  ///       중심이라 글자가 앉는 선(baseline)으로 내려 준다.
  /// 인자: canvas — 그리기 도구
  ///       xPx, yPx — 서식 이미지 좌표 (픽셀)
  ///       text — 찍을 문구. 비어 있으면 아무것도 하지 않는다
  ///       sizePx — 글자 크기 (픽셀)
  ///       align — 기준 좌표의 어느 쪽에 붙일지
  ///       weight — 글자 굵기
  ///       color — 글자색 (0xRRGGBB)
  ///       key — 디버그 표식에 쓸 이름
  ///       debug — 표식을 함께 찍을지
  /// 식: baseline = y_pt - size_pt x 0.36
  ///     0.36 은 글자 크기 대비 중심에서 내려야 하는 몫이다. 파이썬
  ///     프로토타입이 원본 리포트와 맞춰 찾은 값을 그대로 쓴다
  void _text(
    PdfGraphics canvas, {
    required num xPx,
    required num yPx,
    required String text,
    required num sizePx,
    required LayoutAlign align,
    required LayoutWeight weight,
    required int color,
    required String key,
    required bool debug,
  }) {
    if (debug) {
      _debugMark(canvas, xPx: xPx, yPx: yPx, label: key);
    }
    if (text.isEmpty) return;

    final font = weight == LayoutWeight.bold ? bold : regular; // 쓸 글꼴
    final size = ReportLayout.lengthToPoints(sizePx); // 글자 크기 (포인트)
    final baseline =
        ReportLayout.yToPoints(yPx) - size * 0.36; // 글자가 앉는 선 (포인트)
    final width =
        font.stringMetrics(text).advanceWidth * size; // 문구 전체 너비 (포인트)

    var x = ReportLayout.xToPoints(xPx); // 찍기 시작할 가로 자리 (포인트)
    if (align == LayoutAlign.right) {
      x -= width;
    } else if (align == LayoutAlign.center) {
      x -= width / 2;
    }

    canvas
      ..setFillColor(_color(color))
      ..drawString(font, size, text, x, baseline);
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _dot
  /// 목적: 신호등 원 하나를 채워 그린다.
  /// 인자: canvas — 그리기 도구
  ///       centerXPx, centerYPx — 원 중심의 서식 좌표 (픽셀)
  ///       diameterPx — 지름 (픽셀)
  ///       color — 채울 색 (0xRRGGBB)
  void _dot(
    PdfGraphics canvas, {
    required num centerXPx,
    required num centerYPx,
    required num diameterPx,
    required int color,
  }) {
    final radius = ReportLayout.lengthToPoints(diameterPx) / 2; // 반지름 (포인트)
    canvas
      ..setFillColor(_color(color))
      ..drawEllipse(
        ReportLayout.xToPoints(centerXPx),
        ReportLayout.yToPoints(centerYPx),
        radius,
        radius,
      )
      ..fillPath();
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _erase
  /// 목적: 서식에 인쇄된 채로 남아 있는 값을 네모로 덮는다. 흰색이 아니라
  ///       그 행의 줄무늬 색으로 칠해야 덮은 자국이 드러나지 않는다.
  /// 인자: canvas — 그리기 도구
  ///       xPx, yPx — 덮을 네모의 왼쪽 위 모서리 (픽셀)
  ///       widthPx, heightPx — 네모의 가로 · 세로 (픽셀)
  ///       color — 칠할 줄무늬 색 (0xRRGGBB)
  void _erase(
    PdfGraphics canvas, {
    required num xPx,
    required num yPx,
    required num widthPx,
    required num heightPx,
    required int color,
  }) {
    canvas
      ..setFillColor(_color(color))
      ..drawRect(
        ReportLayout.xToPoints(xPx),
        ReportLayout.yToPoints(yPx + heightPx),
        ReportLayout.lengthToPoints(widthPx),
        ReportLayout.lengthToPoints(heightPx),
      )
      ..fillPath();
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _debugMark
  /// 목적: 자리 하나에 자홍색 십자와 이름을 찍는다. 좌표가 틀어졌는지
  ///       눈으로 바로 확인하려고 두는 것이라 제품 흐름에서는 그리지
  ///       않는다.
  /// 인자: canvas — 그리기 도구
  ///       xPx, yPx — 표식을 찍을 서식 좌표 (픽셀)
  ///       label — 십자 옆에 적을 이름
  void _debugMark(
    PdfGraphics canvas, {
    required num xPx,
    required num yPx,
    required String label,
  }) {
    final x = ReportLayout.xToPoints(xPx); // 표식 가로 자리 (포인트)
    final y = ReportLayout.yToPoints(yPx); // 표식 세로 자리 (포인트)
    canvas
      ..setStrokeColor(_debugColor)
      ..setLineWidth(0.3)
      ..drawLine(x - 4, y, x + 4, y)
      ..drawLine(x, y - 4, x, y + 4)
      ..strokePath()
      ..setFillColor(_debugColor)
      ..drawString(regular, 3.6, label, x + 5, y + 1.5);
  }

  /// 작성: 2026-09-16 09:12:40 · nada
  /// 함수: _color
  /// 목적: `ReportColors` 의 0xRRGGBB 값을 PDF 색으로 바꾼다.
  /// 인자: rgb — 색 값 (0xRRGGBB)
  /// 반환: 불투명한 PDF 색
  PdfColor _color(int rgb) => PdfColor.fromInt(0xFF000000 | rgb);

  /// 디버그 표식에 쓰는 자홍색. 서식에 없는 색이라 눈에 바로 띈다
  static final PdfColor _debugColor = PdfColor.fromInt(0xFFFF00AA);
}

/// 작성: 2026-09-16 09:12:40 · nada
/// 함수: renderReportPage1
/// 목적: 1쪽만 담은 PDF 한 부를 만든다. 아직 뒤 쪽들이 없어서 1쪽을 따로
///       확인할 때 쓴다.
/// 인자: result — 값을 가져올 측정 결과
///       debug — 자리마다 표식을 찍을지. 기본은 꺼짐
/// 반환: PDF 파일 내용
Future<Uint8List> renderReportPage1({
  required MeasurementResult result,
  bool debug = false,
}) async {
  final document = PdfDocument(); // 만들어 낼 PDF 문서
  // → 로직 이동: ReportPage1Renderer.load()
  final renderer = await ReportPage1Renderer.load(document); // 자산을 읽은 렌더러
  // → 로직 이동: ReportPage1Renderer.draw()
  renderer.draw(result: result, debug: debug);
  return document.save();
}
