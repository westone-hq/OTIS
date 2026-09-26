import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_page1.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-16 09:12:40 · nada
/// 변수: _outputPath
/// 목적: 만들어 낸 1쪽을 남겨 둘 자리. 표와 신호등이 서식 위에 제대로
///       얹혔는지는 숫자로 재기 어려워 눈으로 열어 봐야 한다. 시험이
///       끝나도 지우지 않는 이유가 그것이다.
const _outputPath = 'build/report_page1_test.pdf';

/// 작성: 2026-09-16 09:12:40 · nada
/// 함수: _result
/// 목적: 1쪽을 그려 보려고 만드는 측정 결과. 지금 값을 낼 수 있는 두
///       지표만 채우고 나머지는 비운다 — 실제 측정이 지금 그렇다.
/// 반환: 1쪽 렌더링에 넣을 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260915-130837',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-09-16 09:12:40 · nada
/// 함수: main
/// 목적: 1쪽 렌더링을 시험한다. 자리가 맞는지는 `ReportLayout` 과 대조하는
///       `report_layout_test.dart` 가 맡으므로, 여기서는 PDF 가 실제로
///       만들어지는지와 디버그 모드가 제품 흐름에 섞이지 않는지를 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPage1Renderer', () {
    test('1쪽 PDF 를 만들어 낸다', () async {
      final bytes = await renderReportPage1(result: _result()); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'PDF 머리말이 있어야 한다',
      );

      final file = File(_outputPath); // 대조 스크립트가 읽을 파일
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });

    test('디버그 모드는 기본으로 꺼져 있다', () async {
      // 표식을 그리면 그만큼 내용이 늘어난다. 기본값으로 부른 결과가 더
      // 작아야 제품 흐름에 표식이 섞이지 않는다는 뜻이다
      final plain = await renderReportPage1(result: _result()); // 기본값
      final marked = await renderReportPage1(
        result: _result(),
        debug: true,
      ); // 표식을 켠 것

      expect(marked.length, greaterThan(plain.length));
    });
  });
}
