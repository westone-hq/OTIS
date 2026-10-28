import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_header.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_page1_layout.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';

/// 작성: 2026-09-16 09:12:40 · 박건준
/// 수정: 2026-10-28 17:39:01 · 박희정
/// 클래스: ReportPage1Renderer
/// 목적: TUNE 리포트 1쪽을 PDF 로 그린다. 서식 이미지를 A4 전면에 깔고 그
///       위에 값을 얹는다. 자리는 `ReportLayout` 이, 값과 판정은
///       `ReportMetrics` 가 정해 둔 것을 받아 적기만 한다 — 여기서
///       계산하거나 판단하지 않는다.
///
///       서식 이미지에는 옛 지표 이름 · 분석 자료 · 주소 제목 · 로고가 남아
///       있다. 해당 영역만 덮어 글자가 겹치지 않게 하고, 지표 본문은 이름 ·
///       값 · 설명 · 기준 · 줄무늬를 다시 그린다. 하단 갈색 띠와 문구는
///       덮개 밖에 두어 원래 모양을 유지한다.
class ReportPage1Renderer {
  /// 그림을 얹을 PDF 문서
  final PdfDocument document;

  /// A4 전면에 깔 서식 이미지
  final PdfImage background;

  /// 상단 · 하단에서 크기를 달리해 함께 쓰는 새 로고
  final PdfImage headerLogo;

  /// 서식 좌표에 글자를 찍는 도구
  final ReportTextWriter textWriter;

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-28 14:45:51 · 박희정
  /// 함수: ReportPage1Renderer
  /// 목적: 문서와 미리 읽어 둔 자산을 그대로 담는 생성자. 직접 부르지 말고
  ///       `load()` 를 쓴다.
  /// 인자: document — 그림을 얹을 PDF 문서
  ///       background — 서식 이미지
  ///       headerLogo — 머리말에 그릴 로고 원본
  ///       textWriter — 서식 좌표에 글자를 찍는 도구. 글꼴 두 벌을 갖고
  ///       있어 이 클래스가 따로 들고 있지 않는다
  const ReportPage1Renderer({
    required this.document,
    required this.background,
    required this.headerLogo,
    required this.textWriter,
  });

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-28 14:45:51 · 박희정
  /// 함수: load
  /// 목적: 글꼴 두 벌과 서식 이미지 · 상단 로고를 자산에서 읽어 만든다.
  ///       자산 읽기는 느리고 한 번이면 되므로 그리기와 떼어 둔다.
  /// 인자: document — 그림을 얹을 PDF 문서
  /// 반환: 바로 그릴 수 있는 렌더러
  static Future<ReportPage1Renderer> load(PdfDocument document) async {
    final regularBytes = await rootBundle.load(
      ReportLayout.regularFontAsset,
    ); // 본문 글꼴 원본
    final boldBytes = await rootBundle.load(
      ReportLayout.boldFontAsset,
    ); // 굵은 글꼴 원본
    final backgroundBytes = await rootBundle.load(
      ReportPage1Layout.background,
    ); // 서식 이미지 원본
    final logoBytes = await rootBundle.load(
      ReportLayout.headerLogoAsset,
    ); // 상단 로고 원본

    final regular = PdfTtfFont(document, regularBytes); // 본문 글꼴
    final bold = PdfTtfFont(document, boldBytes); // 굵은 글꼴
    return ReportPage1Renderer(
      document: document,
      headerLogo: PdfImage.file(
        document,
        bytes: logoBytes.buffer.asUint8List(),
      ),
      background: PdfImage.file(
        document,
        bytes: backgroundBytes.buffer.asUint8List(),
      ),
      textWriter: ReportTextWriter(regular: regular, bold: bold),
    );
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-28 17:16:58 · 박희정
  /// 함수: draw
  /// 목적: 1쪽을 문서에 더한다. 순서대로 그린다.
  ///       1. 서식 이미지를 깔고 주소 제목을 지운 뒤 상단 · 하단 로고를 그린다
  ///       2. 머리말 11칸을 찍는다
  ///       3. 옛 지표 본문과 폐지한 분석 자료를 지운다
  ///       4. Performance Metrics 10행의 이름 · 값 · 기준 · 신호등을 찍는다
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

    const addressLabel = ReportPage1Layout.addressLabelEraseBox; // 주소 제목 자리
    _erase(
      canvas,
      xPx: addressLabel.x,
      yPx: addressLabel.y,
      widthPx: addressLabel.width,
      heightPx: addressLabel.height,
      color: ReportColors.white,
    );

    // → 로직 이동: drawReportHeaderLogo()
    drawReportHeaderLogo(canvas, headerLogo);
    // → 로직 이동: drawReportFooterLogo()
    drawReportFooterLogo(canvas, headerLogo);

    // → 로직 이동: ReportMetrics.from()
    final metrics = ReportMetrics.from(result); // 표에 올릴 지표 열 개
    // → 로직 이동: headerValues()
    final header = headerValues(result); // 머리말 칸마다 채울 문구

    for (final field in ReportPage1Layout.fields) {
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
        // → 로직 이동: ReportPage1Layout.maxWidthOf()
        maxWidthPx: ReportPage1Layout.maxWidthOf(field),
      );
    }

    // → 로직 이동: _prepareTables()
    _prepareTables(canvas);
    _drawMetricsTable(canvas, metrics, debug: debug);
    return page;
  }

  /// 작성: 2026-10-28 15:25:15 · 박희정
  /// 수정: 2026-10-28 16:37:52 · 박희정
  /// 함수: _prepareTables
  /// 목적: 지표 본문에 남은 옛 이름과 폐지한 분석 자료 제목 · 표를 지운다.
  ///       서식 파일은 유지하고 필요한 영역만 흰색으로 덮어 머리말 · 지표
  ///       표의 머리 · 꼬리말에 영향이 없도록 한다.
  /// 인자: canvas — 서식과 머리말을 그린 PDF 그리기 도구
  void _prepareTables(PdfGraphics canvas) {
    const erase = ReportPage1Layout.tablesEraseBox; // 옛 본문과 분석 자료를 지울 영역
    _erase(
      canvas,
      xPx: erase.x,
      yPx: erase.y,
      widthPx: erase.width,
      heightPx: erase.height,
      color: ReportColors.white,
    );
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-28 22:54:57 · 박희정
  /// 함수: _drawMetricsTable
  /// 목적: Performance Metrics 열 행을 찍는다. 행마다 이렇게 한다.
  ///       1. 행 높이에 맞는 줄무늬와 카테고리 이름을 그린다
  ///       2. 판정이 "판정없음" 이 아니면 맨 왼쪽에 신호등 원(초록 · 노랑 ·
  ///          빨강, 값이 없으면 회색)을 그린다. 소음 2행과 진동 6행이
  ///          해당하고, 최대 속도 · 운행 거리는 원이 없다
  ///       3. 모든 측정값을 같은 열에 찍고 오른쪽 열에 설명을 적는다.
  ///          Z 평균 · 최대는 진동값 반복 없이 판정 · 위치 설명을 두 줄로
  ///          쓴다. 두 행 · 모든 줄은 같은 크기로 맞춘다. 값 · 판정은 유지한다
  ///       4. 서식에 인쇄된 황색 칸과 적색 칸을 덮은 뒤 지표의 황색 · 적색
  ///          기준을 다시 찍는다 — 서식 값과 판정 기준이 어긋나지 않게
  ///          `ReportThresholds` 의 값을 쓴다
  /// 인자: canvas — 그리기 도구
  ///       metrics — 표에 올릴 지표 열 개
  ///       debug — 표식을 함께 찍을지
  void _drawMetricsTable(
    PdfGraphics canvas,
    ReportMetrics metrics, {
    required bool debug,
  }) {
    const header = ReportPage1Layout.metricHeaderEraseBox; // 옛 설명 제목 자리
    _erase(
      canvas,
      xPx: header.x,
      yPx: header.y,
      widthPx: header.width,
      heightPx: header.height,
      color: ReportPage1Layout.metricHeaderBackground,
    );
    for (final (x, label) in [
      (ReportPage1Layout.colValueX, '측정값'),
      (ReportPage1Layout.colDescriptionX, '설명'),
    ]) {
      _text(
        canvas,
        xPx: x,
        yPx: ReportPage1Layout.metricHeaderY,
        text: label,
        sizePx: ReportPage1Layout.metricHeaderSize,
        align: LayoutAlign.left,
        weight: LayoutWeight.bold,
        color: ReportColors.white,
        key: 'metrics.header.$label',
        debug: debug,
      );
    }
    final rows = ReportPage1Layout.metricRows; // 서식에 놓인 행 자리
    final descriptionWidth =
        ReportPage1Layout.colDescriptionRightX -
        ReportPage1Layout.colDescriptionX; // 설명 열에서 쓸 수 있는 폭 (픽셀)
    var remarkSize = ReportPage1Layout.remarkSize.toDouble(); // Z 두 행 공통 크기
    for (final metric in [metrics.zAvg, metrics.zMax]) {
      for (final line in metric.remarkLines ?? const <String>[]) {
        final width = textWriter.regular.stringMetrics(line).advanceWidth;
        if (width * remarkSize > descriptionWidth) {
          remarkSize = descriptionWidth / width;
        }
      }
    }
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index]; // 이번에 그릴 행의 자리
      final metric = metrics.rows[index]; // 그 행에 올릴 지표
      final stripe = index.isEven
          ? ReportColors.stripeOdd
          : ReportColors.stripeEven; // 이 행의 줄무늬 색

      _erase(
        canvas,
        xPx: ReportPage1Layout.metricBodyX,
        yPx:
            ReportPage1Layout.metricBodyTop +
            index * ReportPage1Layout.metricRowHeight,
        widthPx: ReportPage1Layout.metricBodyWidth,
        heightPx: ReportPage1Layout.metricRowHeight,
        color: stripe,
      );
      _text(
        canvas,
        xPx: ReportPage1Layout.colCategoryX,
        yPx: row.y,
        text: row.label,
        sizePx: ReportPage1Layout.metricCategorySize,
        align: ReportPage1Layout.colCategoryAlign,
        weight: LayoutWeight.bold,
        color: ReportColors.text,
        key: '${row.key}.category',
        debug: debug,
      );

      const diameter = ReportPage1Layout.dotDiameter; // 신호등 지름 (픽셀)
      _erase(
        canvas,
        xPx: ReportPage1Layout.dotCenterX - diameter,
        yPx: row.y - diameter,
        widthPx: diameter * 2,
        heightPx: diameter * 2,
        color: stripe,
      );
      final dotColor = _verdictColor(metric.verdict); // 신호등 색, 없으면 null
      if (dotColor != null) {
        _dot(
          canvas,
          centerXPx: ReportPage1Layout.dotCenterX,
          centerYPx: row.y,
          diameterPx: diameter,
          color: dotColor,
        );
      }

      _text(
        canvas,
        xPx: ReportPage1Layout.colValueX,
        yPx: row.y,
        text: metric.display,
        sizePx: ReportPage1Layout.valueSize,
        align: ReportPage1Layout.colValueAlign,
        weight: LayoutWeight.regular,
        color: ReportColors.text,
        key: row.key,
        debug: debug,
        maxWidthPx:
            ReportPage1Layout.colValueRightX - ReportPage1Layout.colValueX,
      );
      final remarks = metric.remarkLines; // 값 없음이면 기본 설명을 쓴다
      if (remarks != null) {
        for (var line = 0; line < remarks.length; line++) {
          _text(
            canvas,
            xPx: ReportPage1Layout.colDescriptionX,
            yPx:
                row.y +
                (line - (remarks.length - 1) / 2) *
                    ReportPage1Layout.remarkLineGap,
            text: remarks[line],
            sizePx: remarkSize,
            align: ReportPage1Layout.colValueAlign,
            weight: LayoutWeight.regular,
            color: ReportColors.text,
            key: '${row.key}.remark.$line',
            debug: debug,
          );
        }
      } else if (row.hasLabel) {
        _text(
          canvas,
          xPx: ReportPage1Layout.colDescriptionX,
          yPx: row.y,
          text: row.description,
          sizePx: ReportPage1Layout.valueSize,
          align: ReportPage1Layout.colValueAlign,
          weight: LayoutWeight.regular,
          color: ReportColors.text,
          key: '${row.key}.description',
          debug: debug,
          maxWidthPx:
              ReportPage1Layout.colDescriptionRightX -
              ReportPage1Layout.colDescriptionX,
        );
      }

      for (final columnX in [
        ReportPage1Layout.colYellowX,
        ReportPage1Layout.colRedX,
      ]) {
        _erase(
          canvas,
          xPx: columnX - ReportPage1Layout.eraseRedWidth / 2,
          yPx: row.y - ReportPage1Layout.eraseRedHeight / 2,
          widthPx: ReportPage1Layout.eraseRedWidth,
          heightPx: ReportPage1Layout.eraseRedHeight,
          color: stripe,
        );
      }
      _text(
        canvas,
        xPx: ReportPage1Layout.colYellowX,
        yPx: row.y,
        text: metric.yellowDisplay,
        sizePx: ReportPage1Layout.thresholdSize,
        align: ReportPage1Layout.colYellowAlign,
        weight: LayoutWeight.regular,
        color: ReportColors.text,
        key: '${row.key}.yellow',
        debug: debug,
      );
      _text(
        canvas,
        xPx: ReportPage1Layout.colRedX,
        yPx: row.y,
        text: metric.redDisplay,
        sizePx: ReportPage1Layout.thresholdSize,
        align: ReportPage1Layout.colRedAlign,
        weight: LayoutWeight.regular,
        color: ReportColors.text,
        key: '${row.key}.red',
        debug: debug,
      );
    }
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-28 17:39:01 · 박희정
  /// 함수: headerValues
  /// 목적: 머리말 열한 칸에 채울 문구를 만든다. 값이 없는 칸은 비우지 않고
  ///       자리 표시 문구(`ReportPage1Layout.placeholder`, "미입력")를 찍는다.
  ///       주소 칸만 예외로 비운다 — 주소 · 우편번호를 받지 않는다
  ///       (2026-10-27). 서식의 주소 제목도 `draw()` 에서 지운다.
  ///       - 제번 → 측정 ID, 현장명 → 건물명, 최하층·최상층 → 층 정보
  ///       - 엔지니어 → 저장 시점 로그인 작업자 성명(2026-10-18)
  ///       - 제품 → "엘리베이터, 기종". 기종의 쉼표는 이 표기에서만
  ///         공백으로 바꾼다("엘리베이터, 줄-로우프 2:1") — 제품 칸의 쉼표가
  ///         제품과 기종을 가르는 자리라 기종 안 쉼표가 섞이면 읽기
  ///         어렵다. 저장 값과 화면 표기는 그대로다. 기종이 없으면
  ///         "엘리베이터"
  ///       - 하중 → "숫자 단위표기"("2000 킬로그램"). 환산하지 않는다.
  ///         단위표기는 결과에 저장된 단위를 따른다 — 새 결과는 늘
  ///         킬로그램, 단위를 고를 수 있던 빌드의 lb 결과는 파운드
  ///       - 측정 종류 → 해석 종류. 없으면 기본값 "층간 시험"
  ///       - 층 정보 → "Start Floor : 최하층, Stop Floor : 최상층". 지하층은
  ///         "B1" 꼴(`SiteInfo.floorLabel()`, 2026-10-27)
  ///         (2026-10-15 사용자 지시, 예전 "시작층 · 도착층"). 하강이면
  ///         "Start Floor : 최상층, Stop Floor : 최하층" 이다 — 홈 화면은
  ///         최하층 · 최상층을 받고(최상층 > 최하층 검사), 출발 · 도착은
  ///         운전 방향이 정한다(2026-10-21, OTIS 하강 리포트 "Start Floor :
  ///         11, Stop Floor : 4")
  ///       - 측정 일시 → 한국 시간(`KoreaTime.of()`). 기기 시간대 설정과
  ///         상관없이 같은 글자가 나온다
  ///       - 품질성능기준은 고정 문구
  ///       시험이 칸마다 문구를 확인할 수 있게 공개해 둔다.
  /// 인자: result — 값을 가져올 측정 결과
  /// 반환: 서식 칸 이름을 열쇠로 하는 문구 표
  /// 근거: 인용 — `docs/spec/report.md` 의 1쪽 머리말 대응과 주소 제거
  ///       규칙. 엔지니어명 · 측정 시각은 `MeasurementAssembler.assemble()`
  ///       이 결과에 저장한 값을 읽는다
  static Map<String, String> headerValues(MeasurementResult result) {
    final stamp = DateFormat(
      ReportLayout.datetimePattern,
    ).format(KoreaTime.of(result.dateTime)); // 머리말에 쓸 측정 일시 (한국 시간)
    final model = result.model; // 기종, 없으면 null
    final load = result.load; // 하중 숫자, 없으면 null
    final unit = result.loadUnit; // 하중 단위, 없으면 null
    final unitLabel = unit == null
        ? ''
        : SiteInfo.loadUnitReportLabels[unit] ?? unit; // 리포트 단위 표기
    const placeholder = ReportPage1Layout.placeholder; // 값이 없을 때 찍는 문구
    // → 로직 이동: SiteInfo.startStopFloors()
    final floors = SiteInfo.startStopFloors(
      result.direction,
      result.bottomFloor,
      result.topFloor,
    ); // (출발층, 도착층)

    return <String, String>{
      'measurement_id': result.jobNo,
      'engineer_name': result.engineerName ?? placeholder,
      'datetime': stamp,
      'product': model == null
          ? '엘리베이터'
          : '엘리베이터, ${model.replaceAll(RegExp(r'\s*,\s*'), ' ')}',
      'load': load == null
          ? placeholder
          : '${SiteInfo.loadText(load)} $unitLabel'.trim(),
      'standard': 'Standard',
      'test_type': result.analysisType ?? SiteInfo.defaultAnalysisType,
      'direction': result.direction,
      // → 로직 이동: SiteInfo.floorLabel()
      'floors':
          'Start Floor : ${SiteInfo.floorLabel(floors.$1)}, '
          'Stop Floor : ${SiteInfo.floorLabel(floors.$2)}',
      'building_name': result.siteName,
      // 주소 · 우편번호는 받지 않아(2026-10-27) 칸을 비운다. "미입력" 도
      // 찍지 않는다 — 넣지 않기로 한 칸이다. 예전 결과의 값도 찍지 않는다
      'address': '',
    };
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: _verdictColor
  /// 목적: 판정 결과를 신호등 색으로 바꾼다.
  /// 인자: verdict — 판정 결과
  /// 반환: 신호등 색 (0xRRGGBB). 기준이 없는 항목이면 null — 원을 그리지
  ///       않는다. 원본 리포트도 그 행에는 원이 없다
  int? _verdictColor(ReportVerdict verdict) {
    switch (verdict) {
      case ReportVerdict.green:
        return ReportColors.judgeGreen;
      case ReportVerdict.yellow:
        return ReportColors.judgeYellow;
      case ReportVerdict.red:
        return ReportColors.judgeRed;
      case ReportVerdict.unknown:
        return ReportColors.judgeUnknown;
      case ReportVerdict.none:
        return null;
    }
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
  /// 수정: 2026-10-11 19:15:25 · 박건준
  /// 함수: _text
  /// 목적: 글자 한 덩이를 서식 좌표에 찍는다. 찍는 일 자체는
  ///       `ReportTextWriter` 가 하고, 여기서는 디버그 표식을 얹을지만
  ///       가른다 — 표식은 1쪽에서만 쓴다.
  /// 인자: canvas — 그리기 도구
  ///       xPx, yPx — 서식 이미지 좌표 (픽셀)
  ///       text — 찍을 문구. 비어 있으면 아무것도 하지 않는다
  ///       sizePx — 글자 크기 (픽셀)
  ///       align — 기준 좌표의 어느 쪽에 붙일지
  ///       weight — 글자 굵기
  ///       color — 글자색 (0xRRGGBB)
  ///       key — 디버그 표식에 쓸 이름
  ///       debug — 표식을 함께 찍을지
  ///       maxWidthPx — 쓸 수 있는 폭 (픽셀). 넘으면 글자를 줄인다. null
  ///       이면 재지 않는다
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
    num? maxWidthPx,
  }) {
    if (debug) {
      _debugMark(canvas, xPx: xPx, yPx: yPx, label: key);
    }
    // → 로직 이동: ReportTextWriter.drawAt()
    textWriter.drawAt(
      canvas,
      xPx: xPx,
      yPx: yPx,
      text: text,
      sizePx: sizePx,
      align: align,
      weight: weight,
      color: color,
      maxWidthPx: maxWidthPx,
    );
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
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
      ..setFillColor(reportPdfColor(color))
      ..drawEllipse(
        ReportLayout.xToPoints(centerXPx),
        ReportLayout.yToPoints(centerYPx),
        radius,
        radius,
      )
      ..fillPath();
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
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
      ..setFillColor(reportPdfColor(color))
      ..drawRect(
        ReportLayout.xToPoints(xPx),
        ReportLayout.yToPoints(yPx + heightPx),
        ReportLayout.lengthToPoints(widthPx),
        ReportLayout.lengthToPoints(heightPx),
      )
      ..fillPath();
  }

  /// 작성: 2026-09-16 09:12:40 · 박건준
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
      ..drawString(textWriter.regular, 3.6, label, x + 5, y + 1.5);
  }

  /// 작성: 2026-09-22 20:18:06 · 박건준
  /// 변수: _debugColor
  /// 목적: 자리 확인용 표식(`debug: true` 일 때만 그린다)에 쓰는 자홍색.
  ///       서식에 없는 색이라 눈에 바로 띈다.
  static final PdfColor _debugColor = PdfColor.fromInt(0xFFFF00AA);
}

/// 작성: 2026-09-16 09:12:40 · 박건준
/// 수정: 2026-10-23 11:00:00 · 박건준
/// 함수: renderReportPage1
/// 목적: 1쪽만 담은 PDF 한 부를 만든다. 앱은 세 쪽을 이어 붙인
///       `TuneReportBuilder` 를 쓰고, 이 함수는 시험이 1쪽만 따로 확인할 때
///       쓴다.
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
