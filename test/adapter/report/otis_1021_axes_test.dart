import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/adapter/report/report_chart_page.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';

import '../../support/pdf_probe.dart';
import '../../support/reference_records.dart';

/// 작성: 2026-10-22 10:30:00 · nada
/// 함수: main
/// 목적: 2026-10-22 축 규칙(가속도 · 저크 0 대칭 여백, 2 · 3쪽 시간축 여백 ·
///       눈금)으로 실측 7건을 그렸을 때
///       - 여덟 차트 모두 축 밖 표본이 없는지
///       - ptp · Jptp · 소음 최대 글자 상자가 축 틀 안에 있는지
///       - 30 · 45초 기록의 시간 눈금이 5초인지
///       본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final paths = <String, String>{
    ...otis1021Records,
    'ride_reference': rideReferencePath,
  }; // 기록 이름 → 경로

  for (final entry in paths.entries) {
    test(entry.key, () async {
      final result = assembleRecord(
        entry.value,
        flipVertical: faceUpRecords.contains(entry.key),
      ).result!;
      for (final spec in ReportChartAxes.all) {
        final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
        final range = spec.rangeFor(values); // 고른 세로축
        expect(
          values.where(
            (v) => !(spec.scale.ignoreZeros && v == 0) && !range.contains(v, v),
          ),
          isEmpty,
          reason: spec.key,
        );
      }

      final time = ReportChartRenderer.timeWindow(
        ReportChartAxes.longestSeriesLength(result),
        result.sampleRate,
      ); // 가로축
      expect(time.step, 5, reason: '30 · 45초 기록은 5초 눈금');

      final bytes = await renderReportChartPages(result: result); // 2 · 3쪽
      for (final stream in pdfChartStreams(bytes)) {
        final frames = axisFrames(
          stream,
          pageWidthPt: ReportLayout.pageWidthPt,
        ); // 축 틀 [왼쪽, 아래, 가로, 세로]
        for (final box in labelBoxes(stream)) {
          final inside = frames.any(
            (f) =>
                box.left >= f[0] - 0.01 &&
                box.left + box.width <= f[0] + f[2] + 0.01 &&
                box.bottom >= f[1] - 0.01 &&
                box.bottom + box.height <= f[1] + f[3] + 0.01,
          ); // 어느 축 틀 안에 드는지
          expect(inside, isTrue, reason: '$box');
        }
      }
    });
  }

  test('2 · 3쪽 차트 페이지 계획이 여덟 축을 모두 그린다', () {
    expect(
      ReportChartPageRenderer.pages.expand((p) => p.axes).length,
      ReportChartAxes.all.length,
    );
  });
}
