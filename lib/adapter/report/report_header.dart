import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-10-28 14:45:51 · Codex
/// 함수: drawReportHeaderLogo
/// 목적: 서식의 상단 로고만 새 로고로 덮는다. 모든 쪽이 같은 좌표와 원본을
///       써야 머리말이 일치하므로 쪽별 렌더러에서 나눠 그리지 않는다.
///       그릴 범위를 제한해 구분선 · 제번 · 꼬리말은 덮지 않는다.
/// 인자: canvas — 서식을 이미 그린 PDF 그리기 도구
///       logo — 원본 비율과 흰 여백을 유지한 상단 로고
void drawReportHeaderLogo(PdfGraphics canvas, PdfImage logo) {
  const mask = ReportLayout.headerLogoMask; // 덮을 서식 영역 (픽셀)
  const box = ReportLayout.headerLogoBox; // 로고 원본을 놓을 영역 (픽셀)
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
