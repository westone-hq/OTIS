import 'dart:convert';
import 'dart:typed_data';

import 'models/measurement_result.dart';

/// P12 · TUNE 리포트 생성기 (PDF 및 텍스트 요약 문서 생성 구조 및 인터페이스)
/// - 나중에 UI(S5 ResultScreen, P7 이메일 발송) 및 pdf 패키지 연동을 위한 자리 마련 구조
///
/// [기술적 대비 및 주의사항 - PDF 한글 깨짐 방지]
/// 1. 기본 폰트 한계:
///    - fl_chart 또는 pdf 패키지의 기본 폰트(Helvetica 등)는 한글을 지원하지 않아
///      '제번', '현장명', '상향' 등 한글 텍스트가 깨지거나 물음표(?)로 출력됨.
/// 2. 해결책 (TTF 폰트 주입 구조):
///    - 실제 PDF 문서 드로잉 구현 시 rootBundle.load('assets/fonts/Pretendard-Regular.ttf') 등을 통해
///      Font.ttf() 인스턴스를 생성하고 pw.Document(theme: pw.ThemeData.withFont(base: koreanFont))로 주입 예정.
class ReportGenerator {
  /// 기존 TUNE 리포트 레이아웃 기준의 PDF 바이너리(Uint8List) 생성 인터페이스
  /// - 추후 pdf 패키지(pw.Document, pw.Table 등)와 연동하여 실제 문서 바이트 반환 예정
  static Future<Uint8List> generateTuneReportPdf(MeasurementResult result) async {
    // 현재는 인터페이스 자리 마련 및 모듈 통합 테스트용 임시 PDF 바이너리 헤더 반환
    const String placeholderHeader = '%PDF-1.4\n%OTIS_TUNE_REPORT_PLACEHOLDER\n';
    return Uint8List.fromList(utf8.encode(placeholderHeader));
  }

  /// 이메일 본문이나 간단 리포트로 공유 가능한 TUNE 요약 텍스트 생성
  /// - P7 이메일 발송 바텀 시트의 '지표 요약(메일 본문)' 선택 시 실제로 사용될 포맷
  static String generateSummaryText(MeasurementResult result) {
    final buffer = StringBuffer();
    buffer.writeln('[OTIS 승강기 진동·소음 TUNE 측정 리포트]');
    buffer.writeln('----------------------------------------');
    buffer.writeln('• 측정 제번: ${result.jobNo}');
    buffer.writeln('• 현 장 명 : ${result.siteName}');
    buffer.writeln('• 운행 구간: ${result.bottomFloor}층 → ${result.topFloor}층 (${result.direction})');
    buffer.writeln('• 측정 일시: ${_formatDate(result.dateTime)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('[측정 지표 요약 및 임계 판정]');
    buffer.writeln('1. X축 진동 (P2P): ${result.xPtp.toStringAsFixed(2)} mg ${_checkBadge(result.xPtp > 10.0)}');
    buffer.writeln('2. Y축 진동 (P2P): ${result.yPtp.toStringAsFixed(2)} mg ${_checkBadge(result.yPtp > 10.0)}');
    buffer.writeln('3. Z축 진동 (P2P): ${result.zPtp.toStringAsFixed(2)} mg ${_checkBadge(result.zPtp > 15.0)}');
    buffer.writeln('4. 최대 소음      : ${result.noiseMax.toStringAsFixed(1)} dBA ${_checkBadge(result.noiseMax > 50.0)}');
    buffer.writeln('5. 운행 거리      : ${result.distance.toStringAsFixed(1)} m');
    buffer.writeln('6. 최대 속도      : ${result.maxSpeed.toStringAsFixed(2)} m/s');
    buffer.writeln('----------------------------------------');
    buffer.writeln('* 임계 기준: X·Y축 > 10mg, Z축 > 15mg, 소음 > 50dBA 초과 시 [기준 초과]');
    return buffer.toString();
  }

  static String _checkBadge(bool isExceeded) {
    return isExceeded ? '[기준 초과 ▲]' : '[정상 ✔]';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
