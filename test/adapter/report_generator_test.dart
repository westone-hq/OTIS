import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report_generator.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: _result
/// 목적: 메일 요약을 만들어 보려고 꾸미는 측정 결과. 진동 P2P 는 비워 둔다
///       — 진동 필터가 확정되기 전의 실제 측정이 그 상태다.
/// 인자: noiseMax — 소음 최대 (dBA). 안 주면 null
///       noiseSeries — 소음 시계열 (dBA). 안 주면 빈 목록
///       model — 엘리베이터 기종. 안 주면 null
/// 반환: 요약에 넣을 측정 결과
MeasurementResult _result({
  double? noiseMax,
  List<double> noiseSeries = const <double>[],
  String? model,
}) {
  return MeasurementResult(
    id: '20260114-110359',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    model: model,
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    noiseMax: noiseMax,
    noiseSeries: noiseSeries,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: main
/// 목적: 메일 본문 요약을 시험한다. 받는 사람이 PDF 를 열지 않고도 결과를
///       알 수 있어야 하므로, 값이 있는 지표와 없는 지표가 각각 어떻게
///       적히는지를 본다.
void main() {
  group('ReportGenerator.generateSummaryText', () {
    test('머리말에 제번 · 현장 · 일시 · 운행 구간이 들어간다', () {
      final text = ReportGenerator.generateSummaryText(_result()); // 만든 요약

      expect(text, contains('2025F 1234R01'));
      expect(text, contains('럭키종합건설/송정동근생'));
      expect(text, contains('14/01/2026 11:03:59 AM'));
      expect(text, contains('하부에서 상부로 (1층 → 8층)'));
    });

    test('기종은 입력됐을 때만 적는다', () {
      expect(
        ReportGenerator.generateSummaryText(_result()),
        isNot(contains('기종')),
      );
      expect(
        ReportGenerator.generateSummaryText(_result(model: 'Gen2')),
        contains('기종: Gen2'),
      );
    });

    test('여덟 지표를 표와 같은 차례로 적는다', () {
      final text = ReportGenerator.generateSummaryText(_result()); // 만든 요약
      var cursor = -1; // 앞 항목이 나온 자리

      for (final label in ReportGenerator.rowLabels.values) {
        final at = text.indexOf('- $label:'); // 이 항목이 나온 자리
        expect(at, greaterThan(cursor), reason: '$label 차례');
        cursor = at;
      }
    });

    test('값이 나오는 지표는 표와 같은 문자열로 적는다', () {
      final text = ReportGenerator.generateSummaryText(_result()); // 만든 요약

      expect(text, contains('- 최대 속도: 1.7m/s'));
      expect(text, contains('- 운행 거리: 57.1m'));
    });

    test('기준을 넘긴 지표는 그 사실을 옆에 적는다', () {
      final text = ReportGenerator.generateSummaryText(
        _result(noiseMax: 65.6, noiseSeries: const <double>[45.8]),
      ); // 만든 요약

      expect(text, contains('- 소음, 최대: 65.6dBA ← 기준 50dBA 초과'));
    });

    test('빠진 값은 까닭을 나눠 적는다', () {
      // `—` 만 적으면 못 잰 것인지 기준이 없는 것인지 읽는 사람이 모른다
      final text = ReportGenerator.generateSummaryText(_result()); // 만든 요약

      expect(text, contains('- 수직진동, 평균: —(필터 확정 대기)'));
      expect(text, contains('- 수평진동, 최대: —(필터 확정 대기)'));
      expect(text, contains('- 소음, 평균: —(소음 미측정)'));
    });

    test('빠진 값이 있으면 끝에 까닭을 한 번씩만 덧붙인다', () {
      final text = ReportGenerator.generateSummaryText(_result()); // 만든 요약

      expect('※ 진동 네 항목'.allMatches(text).length, 1);
      expect('※ 소음은 측정된 값이'.allMatches(text).length, 1);
    });

    test('소음을 쟀으면 소음 안내는 붙지 않는다', () {
      final text = ReportGenerator.generateSummaryText(
        _result(noiseMax: 48.0, noiseSeries: const <double>[45.0, 48.0]),
      ); // 만든 요약

      expect(text, isNot(contains('※ 소음은 측정된 값이')));
      expect(text, contains('※ 진동 네 항목'), reason: '진동은 여전히 빠져 있다');
    });
  });
}
