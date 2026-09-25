import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart_page.dart';
import 'package:vibration_checker/adapter/report/report_page1.dart'
    show renderReportPage1;
import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-26 09:30:00 · nada
/// 변수: _outputPath
/// 목적: 만들어 낸 리포트 한 부를 남겨 둘 자리. 세 쪽이 제대로 이어졌는지는
///       눈으로 열어 봐야 알 수 있어 시험이 끝나도 지우지 않는다.
const _outputPath = 'build/tune_report_test.pdf';

/// 작성: 2026-09-26 09:30:00 · nada
/// 변수: _sampleCount
/// 목적: 시험에 쓰는 표본 개수.
/// 근거: 인용 — 회귀 기준 측정 기록의 행 수와 같다
const _sampleCount = 11388;

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: _series
/// 목적: 시험용 시계열 하나를 만든다.
/// 인자: amplitude — 파형의 진폭. 단위는 쓰는 쪽을 따른다
///       cycles — 전체 구간에 담을 파동 수
/// 반환: 시험용 시계열
List<double> _series(double amplitude, double cycles) {
  return List<double>.generate(
    _sampleCount,
    (i) => math.sin(2 * math.pi * cycles * i / _sampleCount) * amplitude,
  );
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: _result
/// 목적: 리포트 한 부를 그려 보려고 꾸미는 측정 결과. 소음까지 채워 실제
///       측정에 가장 가까운 모양으로 둔다.
/// 반환: 리포트에 넣을 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260114-110359',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    noiseMax: 65.6,
    xSeries: _series(6.0, 120),
    ySeries: _series(9.0, 90),
    zSeries: _series(14.0, 150),
    noiseSeries: _series(8.0, 60).map((v) => v + 50.0).toList(),
    positionSeries: List<double>.generate(
      _sampleCount,
      (i) => 57.093948064 * i / _sampleCount,
    ),
    speedSeries: _series(1.743390961, 0.5).map((v) => v.abs()).toList(),
    accelSeries: _series(0.9, 1),
    jerkSeries: _series(1.2, 2),
  );
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: _pageCount
/// 목적: PDF 안에 쪽이 몇 장 들어 있는지 센다. 쪽 하나가 `/Type/Page` 로
///       적히는데, 쪽 목록을 담는 객체도 `/Type/Pages` 라 앞부분이 겹친다.
///       그래서 목록 객체 수를 빼야 쪽 수가 나온다.
/// 인자: bytes — 살펴볼 PDF 내용
/// 반환: 쪽 수
int _pageCount(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true); // 객체 머리말을 읽을 문자열
  final all = '/Type/Page'.allMatches(text).length; // 쪽과 쪽 목록을 합한 수
  final lists = '/Type/Pages'.allMatches(text).length; // 쪽 목록 객체 수
  return all - lists;
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: main
/// 목적: 리포트 한 부 만들기를 시험한다. 1쪽과 차트 두 쪽이 한 문서에
///       차례대로 담기는지, 그리고 자산을 한 번만 읽는 것이 실제로 파일을
///       가볍게 하는지를 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TuneReportBuilder', () {
    test('세 쪽이 한 부로 담긴다', () async {
      final builder = await TuneReportBuilder.load(); // 자산을 읽은 빌더

      final bytes = await builder.build(_result()); // 만들어 낸 리포트

      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'PDF 머리말이 있어야 한다',
      );
      expect(
        _pageCount(bytes),
        1 + ReportChartPageRenderer.pages.length,
        reason: '1쪽 + 차트 쪽 수',
      );

      final file = File(_outputPath); // 눈으로 열어 볼 파일
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });

    test('글꼴을 한 번만 심어 따로 만드는 것보다 가볍다', () async {
      // 쪽별로 만들면 같은 글꼴이 문서마다 따로 심긴다. 한 문서에 모아
      // 그리는 편이 실제로 가벼운지 확인한다
      final result = _result(); // 시험용 측정 결과
      final combined = await (await TuneReportBuilder.load()).build(
        result,
      ); // 한 부로 만든 것
      final page1 = await renderReportPage1(result: result); // 1쪽만 만든 것
      final charts = await renderReportChartPages(result: result); // 차트 쪽만 만든 것

      expect(combined.length, lessThan(page1.length + charts.length));
    });

    test('파일로 떨구면 그 자리에 실제로 생긴다', () async {
      final path = '${Directory.systemTemp.path}/tune_report_write_test.pdf';
      final file = File(path); // 떨굴 파일
      if (await file.exists()) await file.delete();

      final written = await writeTuneReport(
        result: _result(),
        path: path,
      ); // 써 넣은 파일

      expect(await written.exists(), isTrue);
      expect(await written.length(), greaterThan(1000));
      expect(_pageCount(await written.readAsBytes()), 3);
      await written.delete();
    });
  });
}
