import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-10-28 14:45:51 · 박희정
/// 수정: 2026-10-28 17:16:58 · 박희정
/// 함수: drawReportHeaderLogo
/// 목적: 서식의 상단 로고만 새 로고로 덮는다. 모든 쪽이 같은 좌표와 원본을
///       써야 머리말이 일치하므로 쪽별 렌더러에서 나눠 그리지 않는다.
///       옛 구분선도 덮고 확대 로고 오른쪽에 다시 그린다. 그릴 범위를
///       제한해 제번 · 꼬리말은 덮지 않는다.
/// 인자: canvas — 서식을 이미 그린 PDF 그리기 도구
///       logo — 원본 비율과 흰 여백을 유지한 상단 로고
void drawReportHeaderLogo(PdfGraphics canvas, PdfImage logo) {
  // → 로직 이동: _drawClippedLogo()
  _drawClippedLogo(
    canvas,
    logo,
    ReportLayout.headerLogoMask,
    ReportLayout.headerLogoBox,
  );
  const divider = ReportLayout.headerLogoDivider; // 새 구분선 자리 (픽셀)
  canvas
    ..saveContext()
    ..setFillColor(reportPdfColor(ReportColors.gold))
    ..drawRect(
      ReportLayout.xToPoints(divider.x),
      ReportLayout.yToPoints(divider.y + divider.height),
      ReportLayout.lengthToPoints(divider.width),
      divider.height * ReportLayout.ptPerPxY,
    )
    ..fillPath()
    ..restoreContext();
}

/// 작성: 2026-10-28 17:16:58 · 박희정
/// 함수: drawReportFooterLogo
/// 목적: 꼬리말의 왼쪽 흰 영역에만 새 로고를 그린다. 갈색 띠 · 사선 ·
///       기밀 문구 · 쪽 번호는 서식 그대로 유지한다. 모든 쪽이 같은
///       영역과 원본을 써야 하므로 쪽별 렌더러에 좌표를 나누지 않는다.
/// 인자: canvas — 서식을 이미 그린 PDF 그리기 도구
///       logo — 상단과 함께 쓰는 로고 원본
void drawReportFooterLogo(PdfGraphics canvas, PdfImage logo) {
  // → 로직 이동: _drawClippedLogo()
  _drawClippedLogo(
    canvas,
    logo,
    ReportLayout.footerLogoMask,
    ReportLayout.footerLogoBox,
  );
}

/// 작성: 2026-10-28 17:16:58 · 박희정
/// 함수: _drawClippedLogo
/// 목적: 원본 비율을 유지한 로고를 지정한 흰 영역에만 그린다. 상단은
///       제번, 하단은 사선을 보호해야 하므로 그림 범위를 제한한다.
/// 인자: canvas — PDF 그리기 도구
///       logo — 여백을 포함한 로고 원본
///       mask — 덮을 영역 (서식 이미지 픽셀)
///       box — 로고를 놓을 영역 (서식 이미지 픽셀)
void _drawClippedLogo(
  PdfGraphics canvas,
  PdfImage logo,
  LayoutPlotBox mask,
  LayoutPlotBox box,
) {
  final left = ReportLayout.xToPoints(mask.x); // 덮을 영역 왼쪽 (포인트)
  final bottom = ReportLayout.yToPoints(mask.y + mask.height); // 아래 (포인트)
  final width = ReportLayout.lengthToPoints(mask.width); // 너비 (포인트)
  final height = mask.height * ReportLayout.ptPerPxY; // 높이 (포인트)
  final boxWidth = ReportLayout.lengthToPoints(box.width); // 로고 너비 한계
  final boxHeight = box.height * ReportLayout.ptPerPxY; // 로고 높이 한계
  final scale = math.min(
    boxWidth / logo.width,
    boxHeight / logo.height,
  ); // 원본 비율을 유지할 배율 (포인트 / 픽셀)
  final logoWidth = logo.width * scale; // 그릴 로고 너비 (포인트)
  final logoHeight = logo.height * scale; // 그릴 로고 높이 (포인트)

  canvas
    ..saveContext()
    ..setFillColor(PdfColors.white)
    ..drawRect(left, bottom, width, height)
    ..fillPath()
    ..drawRect(left, bottom, width, height)
    ..clipPath()
    ..drawImage(
      logo,
      ReportLayout.xToPoints(box.x) + (boxWidth - logoWidth) / 2,
      ReportLayout.yToPoints(box.y + box.height) + (boxHeight - logoHeight) / 2,
      logoWidth,
      logoHeight,
    )
    ..restoreContext();
}
