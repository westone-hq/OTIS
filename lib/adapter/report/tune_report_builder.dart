import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/adapter/report/report_chart_page.dart';
import 'package:vibration_checker/adapter/report/report_page1.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-26 09:30:00 · nada
/// 클래스: TuneReportBuilder
/// 목적: TUNE 리포트 한 부를 통째로 만든다. 1쪽(요약표)과 2·3쪽(차트)을
///       각각 그리던 것을 한 문서에 이어 붙인다.
///
///       자산을 한 번만 읽는 이유
///         글꼴과 서식 이미지를 쪽마다 따로 읽으면 같은 글꼴이 PDF 안에
///         두 벌 심긴다. 여기서 한 번 읽어 두 렌더러에 나눠 주면 파일이
///         그만큼 가벼워진다. 그래서 쪽별 `load()` 를 쓰지 않고 렌더러를
///         직접 만든다.
class TuneReportBuilder {
  /// 1쪽을 그릴 렌더러
  final ReportPage1Renderer page1;

  /// 차트 쪽을 그릴 렌더러
  final ReportChartPageRenderer chartPages;

  /// 두 렌더러가 함께 쓰는 PDF 문서
  final PdfDocument document;

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: TuneReportBuilder
  /// 목적: 한 문서를 함께 쓰는 렌더러 둘을 그대로 담는 생성자. 직접
  ///       부르지 말고 `load()` 를 쓴다.
  /// 인자: document — 두 렌더러가 함께 쓰는 PDF 문서
  ///       page1 — 1쪽 렌더러
  ///       chartPages — 차트 쪽 렌더러
  const TuneReportBuilder({
    required this.document,
    required this.page1,
    required this.chartPages,
  });

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: load
  /// 목적: 글꼴 두 벌과 서식 이미지 두 장을 자산에서 한 번에 읽어, 한
  ///       문서를 함께 쓰는 렌더러 둘을 만든다.
  /// 반환: 바로 그릴 수 있는 빌더
  static Future<TuneReportBuilder> load() async {
    final regularBytes = await rootBundle.load(
      ReportLayout.regularFontAsset,
    ); // 본문 글꼴 원본
    final boldBytes = await rootBundle.load(
      ReportLayout.boldFontAsset,
    ); // 굵은 글꼴 원본
    final page1Bytes = await rootBundle.load(
      ReportPage1.background,
    ); // 1쪽 서식 이미지 원본
    final chartBytes = await rootBundle.load(
      ReportChartPage.background,
    ); // 차트 쪽 서식 이미지 원본

    final document = PdfDocument(); // 두 렌더러가 함께 쓸 문서
    final regular = PdfTtfFont(document, regularBytes); // 본문 글꼴
    final writer = ReportTextWriter(
      regular: regular,
      bold: PdfTtfFont(document, boldBytes),
    ); // 두 렌더러가 함께 쓸 글자 찍기 도구

    return TuneReportBuilder(
      document: document,
      page1: ReportPage1Renderer(
        document: document,
        background: PdfImage.file(
          document,
          bytes: page1Bytes.buffer.asUint8List(),
        ),
        textWriter: writer,
      ),
      chartPages: ReportChartPageRenderer(
        document: document,
        background: PdfImage.file(
          document,
          bytes: chartBytes.buffer.asUint8List(),
        ),
        textWriter: writer,
        chartRenderer: ReportChartRenderer(font: regular),
      ),
    );
  }

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: build
  /// 목적: 리포트 세 쪽을 차례로 그려 PDF 한 부를 만든다. 1쪽을 먼저
  ///       그리고 차트 쪽을 이어 붙인다 — 붙인 차례가 곧 쪽 차례다.
  /// 인자: result — 값을 가져올 측정 결과
  /// 반환: PDF 파일 내용
  Future<Uint8List> build(MeasurementResult result) async {
    // → 로직 이동: ReportPage1Renderer.draw()
    page1.draw(result: result);
    for (final plan in ReportChartPageRenderer.pages) {
      // → 로직 이동: ReportChartPageRenderer.draw()
      chartPages.draw(result: result, plan: plan);
    }
    return document.save();
  }
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: writeTuneReport
/// 목적: TUNE 리포트 한 부를 만들어 파일로 떨군다. 부르는 쪽이 자산
///       읽기와 쪽 조립을 몰라도 되게 한 줄로 감싼 것이다.
/// 인자: result — 값을 가져올 측정 결과
///       path — 떨굴 파일 경로
/// 반환: 써 넣은 파일
Future<File> writeTuneReport({
  required MeasurementResult result,
  required String path,
}) async {
  // → 로직 이동: TuneReportBuilder.load()
  final builder = await TuneReportBuilder.load(); // 자산을 읽은 빌더
  // → 로직 이동: TuneReportBuilder.build()
  final bytes = await builder.build(result); // 만들어 낸 PDF 내용

  final file = File(path); // 떨굴 파일
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}
