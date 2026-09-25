import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/adapter/report/report_chart_page.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-23 09:40:00 · nada
/// 변수: _outputPath
/// 목적: 만들어 낸 차트 두 쪽을 남겨 둘 자리. 축 틀 자리를 참조 PDF 와
///       대조하는 파이썬 스크립트가 이 파일을 읽는다. 시험이 끝나도 지우지
///       않는 이유는, 어긋났을 때 눈으로 열어 볼 수 있어야 해서다.
const _outputPath = 'build/report_chart_page_test.pdf';

/// 작성: 2026-09-23 09:40:00 · nada
/// 변수: _sampleRate
/// 목적: 시험에 쓰는 표본 주기 (Hz).
/// 근거: 인용 — 회귀 기준 측정 기록(`test/fixtures/ride_reference.txt`)이
///       이 주기로 기록돼 있다
const _sampleRate = 256.0;

/// 작성: 2026-09-23 09:40:00 · nada
/// 변수: _sampleCount
/// 목적: 시험에 쓰는 표본 개수.
/// 근거: 인용 — 회귀 기준 측정 기록의 행 수와 같다
const _sampleCount = 11388;

/// 작성: 2026-09-23 09:40:00 · nada
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

/// 작성: 2026-09-23 09:40:00 · nada
/// 함수: _result
/// 목적: 차트 쪽을 그려 보려고 만드는 측정 결과. 소음만 비워 둔다 — 실제
///       측정이 지금 그 상태다.
/// 반환: 차트 쪽 렌더링에 넣을 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260923-094000',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    sampleRate: _sampleRate,
    xSeries: _series(6.0, 120),
    ySeries: _series(9.0, 90),
    zSeries: _series(14.0, 150),
    noiseSeries: const <double>[],
    positionSeries: List<double>.generate(
      _sampleCount,
      (i) => 57.093948064 * i / _sampleCount,
    ),
    speedSeries: _series(1.743390961, 0.5).map((v) => v.abs()).toList(),
    accelSeries: _series(0.9, 1),
    jerkSeries: _series(1.2, 2),
  );
}

/// 작성: 2026-09-23 09:40:00 · nada
/// 함수: main
/// 목적: 차트 쪽 렌더링을 시험한다. 축 틀 자리가 참조 PDF 와 맞는지는
///       파이썬 스크립트가 두 파일을 읽어 대조하므로, 여기서는 쪽 구성이
///       원본 차례와 같은지와 PDF 가 실제로 만들어지는지를 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportChartPageRenderer 쪽 구성', () {
    test('차트 쪽은 두 장이고 번호가 2 · 3 이다', () {
      final numbers = ReportChartPageRenderer.pages
          .map((plan) => plan.pageNumber)
          .toList(); // 쪽 번호

      expect(numbers, <int>[2, 3]);
    });

    test('쪽마다 축이 넷이고 차트 자리 수와 같다', () {
      for (final plan in ReportChartPageRenderer.pages) {
        expect(
          plan.axes.length,
          ReportChartPage.slots.length,
          reason: '${plan.pageNumber}쪽',
        );
      }
    });

    test('2쪽은 진동 세 축과 소음을 이 차례로 놓는다', () {
      final keys = ReportChartPageRenderer.pages.first.axes
          .map((spec) => spec.key)
          .toList(); // 2쪽 축 차례

      expect(keys, <String>['x', 'y', 'z', 'noise']);
    });

    test('3쪽은 위치 · 속도 · 가속도 · 저크를 이 차례로 놓는다', () {
      final keys = ReportChartPageRenderer.pages.last.axes
          .map((spec) => spec.key)
          .toList(); // 3쪽 축 차례

      expect(keys, <String>['pos', 'vel', 'acc', 'jerk']);
    });

    test('여덟 축을 두 쪽에 겹치지 않게 나눠 놓는다', () {
      final keys = ReportChartPageRenderer.pages
          .expand((plan) => plan.axes)
          .map((spec) => spec.key)
          .toList(); // 두 쪽에 놓인 모든 축

      expect(keys.toSet().length, keys.length, reason: '같은 축이 두 번 놓였다');
      expect(keys.length, 8);
    });
  });

  group('ReportChartPageRenderer 축 틀 자리', () {
    test('축 틀 네 자리가 서식 좌표를 그대로 옮긴 값이다', () {
      // 참조 PDF 와 대조할 때 쓰는 기준값이다. 그리는 쪽이 자리를 스스로
      // 계산하지 않고 `ReportLayout` 이 옮겨 둔 값만 쓴다는 것을 못 박는다
      for (final slot in ReportChartPage.slots) {
        final left = ReportLayout.xToPoints(slot.x); // 축 틀 왼쪽 끝
        final bottom = ReportLayout.yToPoints(
          slot.y + slot.height,
        ); // 축 틀 아래쪽 끝

        expect(left, closeTo(74.67336, 1e-4), reason: '왼쪽 끝은 네 자리가 같다');
        expect(bottom, greaterThan(0));
        expect(
          ReportLayout.xToPoints(slot.x + slot.width),
          lessThan(ReportLayout.pageWidthPt),
          reason: '축 틀이 쪽 오른쪽 밖으로 나가면 안 된다',
        );
      }
    });
  });

  group('ReportChartPageRenderer 그리기', () {
    test('차트 두 쪽을 담은 PDF 를 만들어 낸다', () async {
      final bytes = await renderReportChartPages(result: _result()); // 만든 PDF

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

    test('소음 시계열이 비어도 2쪽은 그려진다', () async {
      // 2쪽 넷째 자리가 소음이고 지금 값이 없다. 빈 축 하나 때문에 쪽
      // 전체가 실패하면 안 된다
      final result = _result(); // 소음만 빈 측정 결과

      expect(ReportChartAxes.seriesOf(ReportChartAxes.noise, result), isEmpty);
      await expectLater(renderReportChartPages(result: result), completes);
    });
  });
}
