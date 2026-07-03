import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/models/measurement_result.dart';
import 'package:vibration_checker/domain/report_generator.dart';
import 'package:vibration_checker/domain/sensor_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P11 · 안드로이드 센서 채널 관리자 구조 및 인터페이스 검증', () {
    test('SensorSample.fromMap - 이벤트 맵 정상 변환 검증', () {
      final sample = SensorSample.fromMap({
        'timestamp': 12345.0,
        'x': 5.2,
        'y': -3.1,
        'z': 16.8,
        'noiseDba': 55.4,
      });

      expect(sample.timestamp, 12345.0);
      expect(sample.x, 5.2);
      expect(sample.y, -3.1);
      expect(sample.z, 16.8);
      expect(sample.noiseDba, 55.4);
    });

    test('SensorChannelManager - 플랫폼 예외 발생 시 안전한 fallback 처리 검증', () async {
      final manager = SensorChannelManager();
      final available = await manager.checkSensorsAvailable();
      expect(available, isTrue);

      // 예외 없이 완료되는지 확인
      await expectLater(manager.startCapture(targetSampleRate: 256), completes);
      await expectLater(manager.stopCapture(), completes);
    });
  });

  group('P12 · TUNE 리포트 생성기 인터페이스 및 텍스트 요약 문서 검증', () {
    test('generateTuneReportPdf - PDF 바이너리 헤더 정상 생성 검증', () async {
      final pdfBytes = await ReportGenerator.generateTuneReportPdf(MeasurementResult.mock);
      expect(pdfBytes.isNotEmpty, isTrue);
      
      final headerStr = utf8.decode(pdfBytes.sublist(0, 8));
      expect(headerStr, '%PDF-1.4');
    });

    test('generateSummaryText - TUNE 측정 지표 요약 및 임계 초과 뱃지 표출 검증', () {
      final summary = ReportGenerator.generateSummaryText(MeasurementResult.mock);

      expect(summary.contains('2024F 1447R01'), isTrue);
      expect(summary.contains('럭키종합건설/송정동근생'), isTrue);
      expect(summary.contains('[기준 초과 ▲]'), isTrue);
      expect(summary.contains('12.90 mg'), isTrue);
      expect(summary.contains('71.7 dBA'), isTrue);
    });
  });
}
