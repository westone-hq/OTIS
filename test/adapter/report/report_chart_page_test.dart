import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/adapter/report/report_chart_page.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/model/measurement_result.dart';

import 'pdf_probe.dart';

/// 작성: 2026-09-23 09:40:00 · nada
/// 변수: _outputPath
/// 목적: 만들어 낸 차트 두 쪽을 남겨 둘 자리. 자리는 아래 시험이 값으로
///       대조하므로, 이 파일은 눈금과 라벨이 겹치지 않는지처럼 숫자로 재기
///       어려운 것을 눈으로 열어 볼 때 쓴다.
const _outputPath = 'build/report_chart_page_test.pdf';

/// 작성: 2026-09-27 09:30:00 · nada
/// 변수: _framePrecision
/// 목적: 축 틀 자리를 대조할 때 봐주는 오차 (PDF 포인트).
/// 근거: 측정 — 렌더러와 기대값이 같은 계수로 같은 곱셈을 하므로 실제
///       차이는 5e-6pt 안쪽이다. 여기에 두 자리 여유를 두었다. 옛 참조
///       PDF 대조가 허용하던 0.1pt 보다 백 배 촘촘하다
const _framePrecision = 0.001;

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
/// 목적: 차트 쪽을 그려 보려고 만드는 측정 결과.
/// 인자: noiseSeries — 소음 시계열 (dBA). 안 주면 빈 목록이며, 마이크
///       권한이 없는 측정을 흉내 낸 것이다
/// 반환: 차트 쪽 렌더링에 넣을 측정 결과
MeasurementResult _result({List<double> noiseSeries = const <double>[]}) {
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
    noiseSeries: noiseSeries,
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
/// 목적: 차트 쪽 렌더링을 시험한다. 쪽 구성이 원본 차례와 같은지, 만들어진
///       PDF 의 축 틀이 서식 좌표에서 계산한 자리와 맞는지를 본다.
///
///       참조 PDF 와 대조하지 않는 까닭
///         `docs/reference/sample_evimp.pdf` 는 축별 계수를 나누기 전 단일
///         계수로 그려진 옛 산출물이라 아래쪽으로 갈수록 최대 0.1035pt 씩
///         벌어진다. 새로 받을 수도 없다. 남는 잔차(가로 -0.0004 · 폭
///         -0.0022 · 높이 +0.0100pt)도 렌더러가 아니라 그 PDF 를 만든
///         파이썬 쪽 반올림에서 오는 것이라, 새 참조를 받아도 0 이 되지
///         않는다. 참조가 알려 줄 수 있는 것은 이미 다 확인했다.
///         지금은 `ReportLayout` 이 옮겨 둔 서식 좌표와 쪽 크기에서 곧바로
///         계산해 0.001pt 로 대조한다. 참조보다 백 배 촘촘하고, 좌표가
///         바뀌면 기대값도 따라 바뀐다. `sample_evimp.pdf` 는 눈으로 볼
///         때만 쓰는 참고물로 남긴다.
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
    test('두 쪽 모두 축 틀이 계산한 자리에 그려진다', () async {
      final bytes = await renderReportChartPages(result: _result()); // 만든 PDF
      final pages = pdfChartStreams(bytes); // 차트가 그려진 쪽들

      expect(pages.length, ReportChartPageRenderer.pages.length);
      for (var p = 0; p < pages.length; p++) {
        final drawn = axisFrames(
          pages[p],
          pageWidthPt: ReportLayout.pageWidthPt,
        ); // 실제로 찍힌 축 틀
        expect(
          drawn.length,
          ReportChartPage.slots.length,
          reason: '${p + 2}쪽 축 틀 수',
        );

        for (var i = 0; i < drawn.length; i++) {
          final slot = ReportChartPage.slots[i]; // 서식이 정한 그 자리
          final where = '${p + 2}쪽 ${i + 1}번째 자리'; // 어긋난 자리를 알릴 문구

          expect(
            drawn[i][0],
            closeTo(ReportLayout.xToPoints(slot.x), _framePrecision),
            reason: '$where 왼쪽 끝',
          );
          expect(
            drawn[i][1],
            closeTo(
              ReportLayout.yToPoints(slot.y + slot.height),
              _framePrecision,
            ),
            reason: '$where 아래쪽 끝',
          );
          expect(
            drawn[i][2],
            closeTo(ReportLayout.lengthToPoints(slot.width), _framePrecision),
            reason: '$where 가로',
          );
          expect(
            drawn[i][3],
            closeTo(slot.height * ReportLayout.ptPerPxY, _framePrecision),
            reason: '$where 세로',
          );
        }
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

    test('소음이 들어오면 2쪽 넷째 차트에 파형이 얹힌다', () async {
      // 소음이 붙기 전에는 축 틀만 그려진다. 값이 들어오면 그 자리에
      // 꺾은선이 더해지므로 내용이 늘어난다
      final quiet = await renderReportChartPages(result: _result()); // 소음 없음
      final withNoise = await renderReportChartPages(
        result: _result(
          noiseSeries: _series(8.0, 60).map((v) => v + 50.0).toList(),
        ),
      ); // 42~58 dBA 사이를 오르내리는 소음

      expect(withNoise.length, greaterThan(quiet.length));
    });

    test('소음이 비어도 눈금이 다른 차트와 같은 자리에 온다', () async {
      // 축마다 제 시계열 길이로 폭을 잡으면 빈 소음만 0~1초가 된다.
      // 그리는 세로 자리를 빼고 눈금 자리가 네 차트 모두 같아야 한다
      final result = _result(); // 소음만 빈 측정 결과
      final bytes = await renderReportChartPages(result: result); // 만든 PDF
      final page2 = verticalGridLines(
        pdfChartStreams(bytes).first,
      ); // 2쪽 차트별 세로 격자선 자리

      expect(page2.length, 4, reason: '차트 넷');
      for (var i = 1; i < page2.length; i++) {
        expect(
          page2[i],
          page2.first,
          reason: '${i + 1}번째 차트의 눈금 자리가 첫 차트와 다르다',
        );
      }
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
