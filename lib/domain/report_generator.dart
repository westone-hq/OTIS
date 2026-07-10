import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models/measurement_result.dart';

/// P12 · TUNE 리포트 생성기 (PDF 및 텍스트 요약 문서 생성)
/// - pdf 패키지 연동 및 한글 폰트(Pretendard) 주입 (Phase 4-B)
/// - 현장정보 헤더, 6지표 표(초과 셀 붉은 배경/글자, D3), 차트 8종(D6) 포함
class ReportGenerator {
  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;

  static Future<void> _loadFonts() async {
    if (_fontRegular != null && _fontBold != null) return;
    try {
      final regData = await rootBundle.load('assets/fonts/Pretendard-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Pretendard-Bold.ttf');
      _fontRegular = pw.Font.ttf(regData);
      _fontBold = pw.Font.ttf(boldData);
    } catch (e) {
      // 유닛 테스트 등 rootBundle 사용 불가능 환경 폴백 (로컬 파일 직접 로드)
      try {
        final regFile = File('assets/fonts/Pretendard-Regular.ttf');
        final boldFile = File('assets/fonts/Pretendard-Bold.ttf');
        if (await regFile.exists() && await boldFile.exists()) {
          _fontRegular = pw.Font.ttf(await regFile.readAsBytes().then((b) => b.buffer.asByteData()));
          _fontBold = pw.Font.ttf(await boldFile.readAsBytes().then((b) => b.buffer.asByteData()));
        }
      } catch (_) {}
    }
  }

  /// TUNE 리포트 PDF 바이너리(Uint8List) 생성
  static Future<Uint8List> generateTuneReportPdf(MeasurementResult result) async {
    await _loadFonts();

    final doc = pw.Document(
      theme: (_fontRegular != null && _fontBold != null)
          ? pw.ThemeData.withFont(base: _fontRegular, bold: _fontBold)
          : pw.ThemeData.base(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. 헤더 (타이틀 및 현장 정보)
            _buildHeader(result),
            pw.SizedBox(height: 16),

            // 2. 6지표 표 (초과 셀 붉은 표시 D3)
            _buildMetricsTable(result),
            pw.SizedBox(height: 24),

            // 3. 차트 8종 섹션 헤더 (D6 순서)
            pw.Text(
              '[데이터 차트 (8종)]',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),

            // 4. 차트 8종 목록
            ..._buildChartsList(result),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(MeasurementResult result) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'OTIS 승강기 진동·소음 TUNE 측정 리포트',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              _infoRow('측정 제번', result.jobNo, '현 장 명', result.siteName),
              pw.SizedBox(height: 6),
              _infoRow('운행 층수', '${result.bottomFloor}층 → ${result.topFloor}층', '운행 방향', result.direction),
              pw.SizedBox(height: 6),
              _infoRow('측정 일시', _formatDate(result.dateTime), '샘플레이트', '${result.sampleRate.toStringAsFixed(1)} Hz'),
            ],
          ),
        ),
        if (!result.usedDetectedRideSegment) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '참고: 주행 구간 자동검출 실패 — 전체 구간 기준 산출',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _infoRow(String label1, String val1, String label2, String val2) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Text('$label1 : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(val1),
        ),
        pw.Expanded(
          flex: 1,
          child: pw.Text('$label2 : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(val2),
        ),
      ],
    );
  }

  static pw.Widget _buildMetricsTable(MeasurementResult result) {
    pw.Widget cell(String text, {bool isHeader = false, bool isExceeded = false, pw.Alignment align = pw.Alignment.centerLeft}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: align,
        color: isHeader
            ? PdfColors.grey200
            : (isExceeded ? PdfColor.fromHex('#FFEBEE') : null),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: isHeader || isExceeded ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isExceeded ? PdfColors.red800 : PdfColors.black,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          children: [
            cell('번호', isHeader: true, align: pw.Alignment.center),
            cell('측정 항목', isHeader: true),
            cell('측정 결과', isHeader: true, align: pw.Alignment.centerRight),
            cell('임계 기준', isHeader: true, align: pw.Alignment.centerRight),
            cell('판정 상태', isHeader: true, align: pw.Alignment.center),
          ],
        ),
        pw.TableRow(
          children: [
            cell('1', align: pw.Alignment.center),
            cell('X축 진동 (P2P)', isExceeded: result.xExceeded),
            cell('${result.xPtp.toStringAsFixed(2)} mg', isExceeded: result.xExceeded, align: pw.Alignment.centerRight),
            cell('10.0 mg', align: pw.Alignment.centerRight),
            cell(_pdfCheckBadge(result.xExceeded), isExceeded: result.xExceeded, align: pw.Alignment.center),
          ],
        ),
        pw.TableRow(
          children: [
            cell('2', align: pw.Alignment.center),
            cell('Y축 진동 (P2P)', isExceeded: result.yExceeded),
            cell('${result.yPtp.toStringAsFixed(2)} mg', isExceeded: result.yExceeded, align: pw.Alignment.centerRight),
            cell('10.0 mg', align: pw.Alignment.centerRight),
            cell(_pdfCheckBadge(result.yExceeded), isExceeded: result.yExceeded, align: pw.Alignment.center),
          ],
        ),
        pw.TableRow(
          children: [
            cell('3', align: pw.Alignment.center),
            cell('Z축 진동 (P2P)', isExceeded: result.zExceeded),
            cell('${result.zPtp.toStringAsFixed(2)} mg', isExceeded: result.zExceeded, align: pw.Alignment.centerRight),
            cell('15.0 mg', align: pw.Alignment.centerRight),
            cell(_pdfCheckBadge(result.zExceeded), isExceeded: result.zExceeded, align: pw.Alignment.center),
          ],
        ),
        pw.TableRow(
          children: [
            cell('4', align: pw.Alignment.center),
            cell('최대 소음', isExceeded: result.noiseExceeded),
            cell(
              result.noiseMax <= 0.0 ? 'N/A' : '${result.noiseMax.toStringAsFixed(1)} dBA',
              isExceeded: result.noiseExceeded,
              align: pw.Alignment.centerRight,
            ),
            cell('50.0 dBA', align: pw.Alignment.centerRight),
            cell(
              result.noiseMax <= 0.0 ? '[제외]' : _pdfCheckBadge(result.noiseExceeded),
              isExceeded: result.noiseExceeded,
              align: pw.Alignment.center,
            ),
          ],
        ),
        pw.TableRow(
          children: [
            cell('5', align: pw.Alignment.center),
            cell('운행 거리'),
            cell('${result.distance.toStringAsFixed(1)} m', align: pw.Alignment.centerRight),
            cell('-', align: pw.Alignment.centerRight),
            cell('[정상]', align: pw.Alignment.center),
          ],
        ),
        pw.TableRow(
          children: [
            cell('6', align: pw.Alignment.center),
            cell('최대 속도'),
            cell('${result.maxSpeed.toStringAsFixed(2)} m/s', align: pw.Alignment.centerRight),
            cell('-', align: pw.Alignment.centerRight),
            cell('[정상]', align: pw.Alignment.center),
          ],
        ),
      ],
    );
  }

  static List<pw.Widget> _buildChartsList(MeasurementResult result) {
    return [
      _buildChartBox('1. X축 진동 (P2P)', 'mg', result.xSeries, PdfColors.blue600, threshold: 10.0),
      _buildChartBox('2. Y축 진동 (P2P)', 'mg', result.ySeries, PdfColors.blue600, threshold: 10.0),
      _buildChartBox('3. Z축 진동 (P2P)', 'mg', result.zSeries, PdfColors.blue600, threshold: 15.0),
      if (result.noiseMax > 0.0)
        _buildChartBox('4. 소음 (Noise)', 'dBA', result.noiseSeries, PdfColors.amber700, threshold: 50.0)
      else
        _buildEmptyChartBox('4. 소음 (Noise)', 'dBA (제외됨)'),
      _buildChartBox('5. 운행 위치 (Position)', 'm', result.positionSeries, PdfColors.green600),
      _buildChartBox('6. 운행 속도 (Velocity)', 'm/s', result.speedSeries, PdfColors.purple600),
      _buildChartBox('7. 가속도 (Acceleration)', 'm/s²', result.accelSeries, PdfColors.teal600),
      _buildChartBox('8. 저크 (Jerk)', 'm/s³', result.jerkSeries, PdfColors.brown600),
    ];
  }

  static pw.Widget _buildEmptyChartBox(String title, String subtitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 60,
            alignment: pw.Alignment.center,
            child: pw.Text('데이터 없음 / $subtitle', style: pw.TextStyle(color: PdfColors.grey500)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildChartBox(String title, String unit, List<double> series, PdfColor color, {double? threshold}) {
    if (series.isEmpty) {
      return _buildEmptyChartBox(title, unit);
    }

    // 다운샘플링 (≤400pt)
    List<double> data = series;
    if (data.length > 400) {
      final step = data.length / 400;
      data = List.generate(400, (i) => series[(i * step).floor()]);
    }

    double minVal = data.reduce(math.min);
    double maxVal = data.reduce(math.max);
    if (threshold != null && threshold > maxVal) maxVal = threshold * 1.1;
    if (minVal == maxVal) {
      minVal -= 1.0;
      maxVal += 1.0;
    }
    final range = maxVal - minVal;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$title ($unit)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.Text('최소: ${minVal.toStringAsFixed(1)} ~ 최대: ${maxVal.toStringAsFixed(1)} $unit', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.SizedBox(
            height: 70,
            width: double.infinity,
            child: pw.CustomPaint(
              painter: (PdfGraphics canvas, PdfPoint size) {
                // 배경 격자선
                canvas.setStrokeColor(PdfColors.grey200);
                canvas.setLineWidth(0.5);
                for (int i = 1; i <= 3; i++) {
                  final y = size.y * (i / 4);
                  canvas.drawLine(0, y, size.x, y);
                }
                canvas.strokePath();

                // 임계선 (붉은색)
                if (threshold != null && threshold >= minVal && threshold <= maxVal) {
                  final ty = (threshold - minVal) / range * size.y;
                  canvas.setStrokeColor(PdfColors.red400);
                  canvas.setLineWidth(0.8);
                  canvas.drawLine(0, ty, size.x, ty);
                  canvas.strokePath();
                }

                // 데이터 곡선/선
                canvas.setStrokeColor(color);
                canvas.setLineWidth(1.2);
                for (int i = 0; i < data.length; i++) {
                  final x = (i / (data.length - 1)) * size.x;
                  final y = ((data[i] - minVal) / range) * size.y;
                  if (i == 0) {
                    canvas.moveTo(x, y);
                  } else {
                    canvas.lineTo(x, y);
                  }
                }
                canvas.strokePath();
              },
            ),
          ),
        ],
      ),
    );
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
    final noiseStr = result.noiseMax <= 0.0
        ? 'N/A (소음 제외 측정)'
        : '${result.noiseMax.toStringAsFixed(1)} dBA ${_checkBadge(result.noiseMax > 50.0)}';
    buffer.writeln('4. 최대 소음      : $noiseStr');
    buffer.writeln('5. 운행 거리      : ${result.distance.toStringAsFixed(1)} m');
    buffer.writeln('6. 최대 속도      : ${result.maxSpeed.toStringAsFixed(2)} m/s');
    buffer.writeln('----------------------------------------');
    buffer.writeln('* 임계 기준: X·Y축 > 10mg, Z축 > 15mg, 소음 > 50dBA 초과 시 [기준 초과]');
    return buffer.toString();
  }

  static String _pdfCheckBadge(bool isExceeded) {
    return isExceeded ? '[기준 초과]' : '[정상]';
  }

  static String _checkBadge(bool isExceeded) {
    return isExceeded ? '[기준 초과 ▲]' : '[정상 ✔]';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
