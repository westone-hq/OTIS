import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart_renderer.dart';
import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/analysis/measurement_assembler.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';
import 'package:vibration_checker/domain/report/chart_series.dart';
import 'package:vibration_checker/domain/report/report_chart_page_layout.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/session/site_info.dart';

import '../../support/pdf_probe.dart';

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 변수: _outputPath
/// 목적: 그려 본 차트 쪽을 남겨 둘 자리. 축 눈금과 라벨이 겹치지 않는지는
///       숫자로 재기 어려워 눈으로 열어 봐야 한다. 시험이 끝나도 지우지
///       않는 이유가 그것이다.
const _outputPath = 'build/report_chart_test.pdf';

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 변수: _sampleRate
/// 목적: 시험에 쓰는 표본 주기 (Hz).
/// 근거: 인용 — 회귀 기준 측정 기록(`test/fixtures/records/ride_reference.txt`)이
///       이 주기로 기록돼 있다
const _sampleRate = 256.0;

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 변수: _rideSampleCount
/// 목적: 시험에 쓰는 표본 개수.
/// 근거: 인용 — 회귀 기준 측정 기록의 행 수와 같다. 줄이기가 실제 측정
///       크기에서 어떻게 도는지 보려고 같은 수를 쓴다
const _rideSampleCount = 11388;

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 함수: _wave
/// 목적: 시험용 파형을 만든다. 사인파에 뾰족한 봉우리 하나를 섞어, 줄이기가
///       봉우리를 지우지 않는지 볼 수 있게 한다.
/// 인자: count — 만들 표본 개수
///       spikeIndex — 봉우리를 꽂을 자리
///       spikeValue — 봉우리 값
/// 반환: 시험용 시계열
List<double> _wave(
  int count, {
  required int spikeIndex,
  required double spikeValue,
}) {
  final values = List<double>.generate(
    count,
    (i) => math.sin(i / 40.0) * 3.0,
  ); // 바탕이 되는 사인파
  values[spikeIndex] = spikeValue;
  return values;
}

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 함수: _result
/// 목적: 차트를 그려 보려고 만드는 측정 결과. 소음만 비워 둔다 — 마이크
///       권한이 없는 측정을 흉내 내, 빈 시계열에서도 축 틀이 그려지는지
///       같이 확인하려는 것이다.
/// 반환: 차트 렌더링에 넣을 측정 결과
MeasurementResult _result() {
  final zWave = _wave(
    _rideSampleCount,
    spikeIndex: 5000,
    spikeValue: 18.0,
  ); // 수직 진동 파형
  return MeasurementResult(
    id: '20260917-100500',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    sampleRate: _sampleRate,
    xSeries: _wave(_rideSampleCount, spikeIndex: 100, spikeValue: 8.0),
    ySeries: _wave(_rideSampleCount, spikeIndex: 200, spikeValue: -12.0),
    zSeries: zWave,
    noiseSeries: const <double>[],
    positionSeries: List<double>.generate(
      _rideSampleCount,
      (i) => 57.09 * i / _rideSampleCount,
    ),
    speedSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(math.pi * i / _rideSampleCount) * 1.743390961,
    ),
    accelSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(2 * math.pi * i / _rideSampleCount) * 0.9,
    ),
    jerkSeries: List<double>.generate(
      _rideSampleCount,
      (i) => math.sin(4 * math.pi * i / _rideSampleCount) * 1.2,
    ),
  );
}

/// 작성: 2026-09-17 10:05:00 · 박건준
/// 수정: 2026-10-28 15:25:15 · Codex
/// 함수: main
/// 목적: 차트 렌더러를 시험한다. 실제 PDF 를 그려 그리기 과정이 끝까지
///       도는지, 표시점 · 점선 · 글자 상자가 제자리에 놓이는지 본다. 축
///       범위 · 시계열 줄이기는 `chart_axes_test` · `chart_series_test` 가
///       본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportChartRenderer — 가로축 · 눈금 숫자', () {
    test('가로축은 2 · 3쪽 모두 양쪽 4% 여백이고 눈금은 30 · 45초 → 5초, 60초 넘으면 10초', () {
      ({double start, double span, double step}) of(double seconds) =>
          ReportChartRenderer.timeWindow((seconds * 100).round() + 1, 100);
      final t31 = of(31.4); // OTIS 예 31.4초
      expect(t31.start, closeTo(-1.256, 1e-6));
      expect(t31.start + t31.span, closeTo(32.656, 1e-6));
      expect(t31.step, 5);
      expect(of(44.5).step, 5);
      expect(of(60).step, 5);
      expect(of(61).step, 10);
      expect(of(10).step, 1);
      expect(ReportChartRenderer.timePaddingRatio, 0.04);
    });

    test('눈금 숫자는 한 축 안에서 소수 자리를 맞춘다', () {
      String f(double v, double step) =>
          ReportChartRenderer.formatTick(v, step);
      expect(
        <String>[
          for (final v in <double>[0, 0.5, 1, 1.5]) f(v, 0.5),
        ],
        <String>['0.0', '0.5', '1.0', '1.5'],
      );
      expect(
        <String>[
          for (final v in <double>[0.6, 0.4, 0, -0.2]) f(v, 0.2),
        ],
        <String>['0.6', '0.4', '0.0', '-0.2'],
      );
      expect(f(25, 5), '25');
      expect(f(40, 10), '40');
      expect(f(0.25, 0.25), '0.25');
      expect(f(-1e-17, 0.2), '0.0', reason: '−0 을 찍지 않는다');
      expect(ReportChartRenderer.tickDecimals(5), 0);
      expect(ReportChartRenderer.tickDecimals(0.5), 1);
      expect(ReportChartRenderer.tickDecimals(0.25), 2);
    });
  });

  group('차트 주석 — 소음 평균선과 최댓값 표시점', () {
    test('소음 축만 평균선과 표시점을 갖는다', () {
      expect(ReportChartAxes.noise.meanKey, 'noise_avg');
      expect(ReportChartAxes.noise.peakKey, 'noise_max');

      for (final spec in ReportChartAxes.all) {
        if (spec.key == 'noise') continue;
        expect(spec.meanKey, isNull, reason: '${spec.key} 는 평균선이 없다');
        expect(spec.peakKey, isNull, reason: '${spec.key} 는 표시점이 없다');
      }
    });

    test('가리키는 지표가 실제로 표에 있는 이름이다', () {
      // 이름이 어긋나면 조용히 아무것도 안 그린다. 표가 가진 이름과
      // 맞는지 못박아 둔다
      final metrics = ReportMetrics.from(_result()); // 표에 올리는 지표

      expect(metrics.byKey(ReportChartAxes.noise.meanKey!), isNotNull);
      expect(metrics.byKey(ReportChartAxes.noise.peakKey!), isNotNull);
    });

    test('주석이 붙으면 그만큼 내용이 늘어난다', () async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final noisy = _result().copyWith(
        noiseSeries: List<double>.generate(
          _rideSampleCount,
          (i) => 45.0 + (i == 3000 ? 12.0 : 0.0),
        ),
        noiseMax: 57.0,
      ); // 3000번째에 봉우리가 있는 소음

      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.noise,
        box: ReportChartPageLayout.slots.first,
        result: noisy,
      );
      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });
  });

  group('ReportChartRenderer — 그리기', () {
    test('차트 네 개를 그린 PDF 가 만들어진다', () async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        'assets/report/NanumGothic-Regular.ttf',
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      final canvas = page.getGraphics(); // 그리기 도구
      final result = _result(); // 시험용 측정 결과
      final specs = <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
        ReportChartAxes.noise,
      ]; // 차트 쪽 첫 장에 놓이는 축 넷

      for (var i = 0; i < specs.length; i++) {
        renderer.draw(
          canvas,
          spec: specs[i],
          box: ReportChartPageLayout.slots[i],
          result: result,
        );
      }

      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'PDF 머리말이 있어야 한다',
      );

      final file = File(_outputPath); // 눈으로 열어 볼 파일
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });

    test('시계열이 비어도 축 틀은 그린다', () async {
      // 소음처럼 아직 수집하지 않은 차트도 자리를 차지해야 한다. 아무것도
      // 그리지 않았다면 내용 길이가 거의 늘지 않는다
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        'assets/report/NanumGothic-Regular.ttf',
      ); // 눈금·라벨에 쓸 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽

      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.noise,
        box: ReportChartPageLayout.slots.first,
        result: _result(),
      );
      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });
  });

  group('진동 P2P 표시', () {
    test('P2P 는 진동 세 축에서만 1쪽 표와 같은 지표를 꺼낸다', () {
      final result = _result().copyWith(xPtp: 14.2, yPtp: 10.6, zPtp: 108.4);

      expect(ReportChartAxes.ptpOf(ReportChartAxes.x, result), 14.2);
      expect(ReportChartAxes.ptpOf(ReportChartAxes.y, result), 10.6);
      expect(ReportChartAxes.ptpOf(ReportChartAxes.z, result), 108.4);
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.noise,
        ReportChartAxes.position,
        ReportChartAxes.speed,
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]) {
        expect(ReportChartAxes.ptpOf(spec, result), isNull, reason: spec.key);
      }
    });

    test('적는 숫자는 1쪽 표와 같은 규칙으로 다듬는다', () {
      final result = _result().copyWith(xPtp: 14.2125, zPtp: 108.3677);
      final metrics = ReportMetrics.from(result); // 1쪽 표 지표

      expect(ReportChartRenderer.ptpLabel(14.2125), 'ptp 14.2milli-G');
      expect(ReportChartRenderer.ptpLabel(108.3677), 'ptp 108milli-G');
      expect(
        metrics.zMax.display,
        ReportChartRenderer.ptpLabel(108.3677).substring(4),
      );
    });

    test('P2P 가 있으면 빨간 표시점과 글자가 붙고, 없으면 붙지 않는다', () async {
      Future<String> drawX(MeasurementResult result) async {
        final document = PdfDocument(); // 만들어 낼 PDF 문서
        final fontBytes = await rootBundle.load(
          ReportLayout.regularFontAsset,
        ); // 글꼴 원본
        final renderer = ReportChartRenderer(
          font: PdfTtfFont(document, fontBytes),
        ); // 차트를 그릴 렌더러
        final page = PdfPage(
          document,
          pageFormat: PdfPageFormat(
            ReportLayout.pageWidthPt,
            ReportLayout.pageHeightPt,
          ),
        ); // 차트를 얹을 쪽
        renderer.draw(
          page.getGraphics(),
          spec: ReportChartAxes.x,
          box: ReportChartPageLayout.slots.first,
          result: result,
        );
        final bytes = await document.save(); // 만든 PDF
        return pdfChartStreams(bytes).join();
      }

      final withPtp = await drawX(_result().copyWith(xPtp: 15.0)); // 새 결과
      final legacy = await drawX(_result()); // P2P 를 계산하지 않은 예전 결과

      expect(withPtp, contains(markerColorOperand));
      expect(legacy, isNot(contains(markerColorOperand)));
    });

    test('표시점 자리는 줄이기 전 원래 시계열의 최댓값 · 최솟값 자리다', () {
      final values = _wave(_rideSampleCount, spikeIndex: 4321, spikeValue: 9.0);
      values[777] = -9.5; // 줄이면 다른 칸 값과 섞일 수 있는 골
      final at = extremeIndices(values)!; // 표시점 자리

      expect(at.maxIndex, 4321);
      expect(at.minIndex, 777);
      final reduced = reduceSeries(values, columns: 300); // 그리는 표본
      expect(reduced.map((s) => s.index), containsAll(<int>[4321, 777]));
    });
  });

  group('운행 구간 점선 (2026-10-20)', () {
    const window = TravelWindow(
      startIndex: 2000,
      endIndex: 9000,
      startSec: 2000 / _sampleRate,
      endSec: 9000 / _sampleRate,
      startM: 0.5,
      endM: 56.5,
    ); // 시험용 운행 구간
    final box = ReportChartPageLayout.slots.first; // 차트 자리
    final frameLeft = ReportLayout.xToPoints(box.x); // 축 틀 왼쪽 (포인트)
    final frameRight = ReportLayout.xToPoints(
      box.x + box.width,
    ); // 축 틀 오른쪽 (포인트)
    // 행 첨자가 축 틀 안 어느 가로 자리인지 렌더러와 같은 식으로 구한다
    double xOfIndex(int index) {
      const length = (_rideSampleCount - 1) / _sampleRate; // 측정 길이 (초)
      const start = -length * 0.04; // 가로축 왼쪽 끝 (초)
      const span = length * 1.08; // 가로축 폭 (초)
      return frameLeft +
          (frameRight - frameLeft) * (index / _sampleRate - start) / span;
    }

    // 차트 하나를 그려 그 쪽의 운행 구간 점선을 돌려준다
    Future<List<({double left, double y, double right})>> drawGuides(
      ChartAxisSpec spec,
      MeasurementResult result,
    ) async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(page.getGraphics(), spec: spec, box: box, result: result);
      final bytes = await document.save(); // 만든 PDF
      return guideLines(pdfChartStreams(bytes).join());
    }

    test('진동 차트는 A95 두 줄을 운행 구간에만 0 을 가운데 두고 긋는다', () async {
      final result = _result().copyWith(
        xA95: 4.0,
        travelWindow: window,
      ); // 구간 · A95 가 있는 결과
      final lines = await drawGuides(ReportChartAxes.x, result); // 그은 점선

      expect(lines.length, 2);
      for (final line in lines) {
        expect(line.left, closeTo(xOfIndex(2000), 0.01));
        expect(line.right, closeTo(xOfIndex(9000), 0.01));
      }
      final range = ReportChartAxes.x.rangeFor(result.xSeries); // 세로축
      final top = ReportLayout.yToPoints(box.y); // 축 틀 위 (포인트)
      final bottom = ReportLayout.yToPoints(box.y + box.height); // 아래
      double yOf(double value) =>
          bottom + (top - bottom) * (value - range.min) / range.span;
      expect(
        lines.map((l) => l.y),
        unorderedEquals(<Matcher>[
          closeTo(yOf(2.0), 0.01),
          closeTo(yOf(-2.0), 0.01),
        ]),
      );
    });

    test('A95 나 운행 구간이 없으면 진동 점선을 긋지 않는다', () async {
      final noA95 = _result().copyWith(travelWindow: window); // A95 없음
      final noWindow = _result().copyWith(xA95: 4.0); // 예전 결과

      expect(await drawGuides(ReportChartAxes.x, noA95), isEmpty);
      expect(await drawGuides(ReportChartAxes.x, noWindow), isEmpty);
    });

    test('소음 평균선은 운행 구간에만, 구간 없는 예전 결과는 폭 전체에 긋는다', () async {
      final noise = List<double>.filled(_rideSampleCount, 45.0); // 소음 (dBA)
      final windowed = _result().copyWith(
        noiseSeries: noise,
        travelWindow: window,
      ); // 구간이 있는 결과
      final legacy = _result().copyWith(noiseSeries: noise); // 예전 결과

      final inWindow = await drawGuides(ReportChartAxes.noise, windowed);
      expect(inWindow.length, 1);
      expect(inWindow.single.left, closeTo(xOfIndex(2000), 0.01));
      expect(inWindow.single.right, closeTo(xOfIndex(9000), 0.01));

      final full = await drawGuides(ReportChartAxes.noise, legacy);
      expect(full.single.left, closeTo(frameLeft, 0.01));
      expect(full.single.right, closeTo(frameRight, 0.01));
    });
  });

  group('수직 ptp · Jptp 표시 (2026-10-21)', () {
    const zones = MotionZones(
      runStartIndex: 1000,
      runEndIndex: 9000,
      steadyStartIndex: 3000,
      steadyEndIndex: 7000,
      sampleRate: _sampleRate,
    ); // 시험용 정속 · 가감속 구간
    const window = TravelWindow(
      startIndex: 1200,
      endIndex: 8800,
      startSec: 1200 / _sampleRate,
      endSec: 8800 / _sampleRate,
      startM: 0.5,
      endM: 56.5,
    ); // 시험용 운행 구간

    // 수직 차트 하나를 그려 그 쪽 내용 스트림을 돌려준다
    Future<String> drawZ(MeasurementResult result) async {
      final document = PdfDocument(); // 만들어 낼 PDF 문서
      final fontBytes = await rootBundle.load(
        ReportLayout.regularFontAsset,
      ); // 글꼴 원본
      final renderer = ReportChartRenderer(
        font: PdfTtfFont(document, fontBytes),
      ); // 차트를 그릴 렌더러
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat(
          ReportLayout.pageWidthPt,
          ReportLayout.pageHeightPt,
        ),
      ); // 차트를 얹을 쪽
      renderer.draw(
        page.getGraphics(),
        spec: ReportChartAxes.z,
        box: ReportChartPageLayout.slots[2],
        result: result,
      );
      return pdfChartStreams(await document.save()).join();
    }

    // 정속 · 가감속 구간에 봉우리를 하나씩 둔 수직 시계열
    List<double> zWith({required int steadyAt, required int transientAt}) {
      final values = List<double>.generate(
        _rideSampleCount,
        (i) => i.isEven ? 1.0 : -1.0,
      ); // 잔잔한 진동 (mg)
      values[steadyAt] = 9.0;
      values[transientAt] = 12.0;
      return values;
    }

    test('Jptp 라벨 문구는 ptp 와 같은 숫자 규칙이다', () {
      expect(ReportChartRenderer.jptpLabel(17.14), 'Jptp 17.1milli-G');
      expect(ReportChartRenderer.jptpLabel(123.4), 'Jptp 123milli-G');
    });

    test('정속 쌍은 정속 구간, Jptp 쌍은 가감속 구간에서 찾는다', () {
      final values = zWith(steadyAt: 5000, transientAt: 2000);
      final result = _result().copyWith(motionZones: zones);
      final pairs = ReportChartAxes.verticalPairs(values, result)!;
      expect(pairs.steady!.high, 5000);
      expect(pairs.transient!.high, 2000);
      expect(ReportChartAxes.verticalPairs(values, _result()), isNull);
    });

    test('Jptp 가 있으면 글자 상자가 둘이고 서로 겹치지 않는다', () async {
      // 두 봉우리를 정속 경계 양쪽 바로 옆에 두어 글자가 같은 자리로 간다
      final values = zWith(steadyAt: 3002, transientAt: 2998);
      values[2998] = 9.0;
      final base = _result().copyWith(
        zSeries: values,
        travelWindow: window,
        motionZones: zones,
        zPtp: 10.0,
      ); // Jptp 없는 결과
      final one = labelBoxes(await drawZ(base)); // ptp 상자만
      final two = labelBoxes(
        await drawZ(base.copyWith(zJptp: 10.0)),
      ); // ptp · Jptp 상자

      expect(one.length, 1);
      expect(two.length, 2);
      final a = two[0];
      final b = two[1];
      final overlaps =
          a.left < b.left + b.width &&
          b.left < a.left + a.width &&
          a.bottom < b.bottom + b.height &&
          b.bottom < a.bottom + a.height; // 두 상자가 겹치는지
      expect(overlaps, isFalse, reason: '$a / $b');
    });
  });

  group('A95 글자 자리 (2026-10-22, 점선 오른쪽 끝)', () {
    const frame = (left: 50.0, bottom: 100.0, right: 250.0, top: 200.0);
    const width = 9.0; // 글자 폭 (포인트)
    const height = ReportChartRenderer.tickLabelSize; // 글자 세로
    const gap = ReportChartRenderer.labelGap; // 점선과 띄움
    ChartRect place({
      double spanRight = 200,
      List<ChartRect> avoid = const [],
    }) => ReportChartRenderer.placeA95Label(
      frame: frame,
      spanRight: spanRight,
      upperY: 160,
      lowerY: 140,
      width: width,
      avoid: avoid,
    );

    test('빈자리면 점선 오른쪽 끝 바깥, 아래 점선 바로 밑이다', () {
      final rect = place(); // 고른 자리
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 140 - gap - height);
    });

    test('ptp 상자가 그 자리를 차지하면 위 점선 위로 비킨다', () {
      final rect = place(
        avoid: [(left: 195, bottom: 125, width: 40, height: 15)],
      ); // 고른 자리
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 160 + gap);
    });

    test('바깥 두 자리가 막히면 점선 끝 안쪽으로 들어간다', () {
      final rect = place(
        avoid: [(left: 201, bottom: 100, width: 40, height: 100)],
      ); // 고른 자리
      expect(rect.left + width, 200, reason: '글자 끝 = 점선 끝');
      expect(rect.bottom, 140 - gap - height);
    });

    test('빨간 점도 피한다', () {
      const ring =
          ReportChartRenderer.markerRadius +
          ReportChartRenderer.markerRingWidth; // 점 반지름
      final rect = place(
        avoid: [
          (
            left: 205 - ring,
            bottom: 133 - ring,
            width: ring * 2,
            height: ring * 2,
          ),
        ],
      ); // 아래 바깥 자리에 점이 있음
      expect(rect.bottom, 160 + gap);
    });

    test('운행 구간이 기록 끝까지면 틀 안으로 밀어 넣는다', () {
      final rect = place(spanRight: 250); // 점선 끝 = 틀 오른쪽
      expect(
        rect.left + width,
        lessThanOrEqualTo(frame.right - ReportChartRenderer.labelInset),
      );
    });

    test('모두 막히면 첫 자리를 쓴다', () {
      final rect = place(
        avoid: [(left: 0, bottom: 0, width: 400, height: 400)],
      ); // 틀 전체를 덮음
      expect(rect.left, 200 + gap);
      expect(rect.bottom, 140 - gap - height);
    });
  });

  group('운행 구간 · 반주기 표시점 (2026-10-15)', () {
    const window = TravelWindow(
      startIndex: 100,
      endIndex: 199,
      startSec: 1.0,
      endSec: 1.99,
      startM: 0.5,
      endM: 9.5,
    ); // 시험용 운행 구간

    test('표시점은 구간 안 최대 반주기 P2P 의 이웃 봉우리 · 골이다', () {
      final values = List<double>.filled(300, 0.0); // 진동 (mg)
      values[20] = 50.0; // 구간 밖 큰 봉우리 — 고르면 안 된다
      values[21] = -50.0;
      for (var i = 100; i < 200; i++) {
        values[i] = i.isEven ? 1.0 : -1.0;
      }
      values[150] = 6.0; // 구간 안 가장 큰 쌍: 6 + 1
      final result = _result().copyWith(
        sampleRate: 100,
        travelWindow: window,
      ); // 구간이 있는 결과
      final pair = ReportChartAxes.peakToPeakPair(values, result)!; // 두 지점

      expect(pair.high, 150);
      expect((pair.low - 150).abs(), 1, reason: '이웃한 골');
      final best = HalfCycle.maximum(values, start: 100, end: 199)!;
      expect(values[pair.high] + values[pair.low].abs(), best.value);
    });

    test('구간이 없는 예전 결과는 전체 최댓값 · 최솟값 자리다', () {
      final values = _wave(_rideSampleCount, spikeIndex: 4321, spikeValue: 9.0);
      values[777] = -9.5; // 가장 깊은 골
      final pair = ReportChartAxes.peakToPeakPair(values, _result())!;

      expect(pair.high, 4321);
      expect(pair.low, 777);
    });

    test('소음 최댓값 자리는 구간 안에서 찾는다', () {
      final values = List<double>.filled(300, 45.0); // 소음 (dBA)
      values[30] = 52.0; // 구간 밖 같은 값
      values[160] = 52.0; // 구간 안
      final windowed = _result().copyWith(travelWindow: window);

      expect(ReportChartAxes.indexInTravel(values, 52.0, windowed), 160);
      expect(ReportChartAxes.indexInTravel(values, 52.0, _result()), 30);
      expect(ReportChartAxes.indexInTravel(values, 99.0, windowed), -1);
    });

    test('가중 · 구간을 거친 기준 데이터도 8개 차트 모두 축 밖 표본이 없다', () {
      final lines = const LineSplitter()
          .convert(
            File('test/fixtures/records/ride_reference.txt').readAsStringSync(),
          )
          .where((line) => line.trim().isNotEmpty)
          .toList(); // 파일 줄
      final rows = <GridSample>[
        for (final line in lines.sublist(2))
          () {
            final f = line.trim().split(RegExp(r'\s+')); // 열 값
            return GridSample(
              xMg: double.parse(f[0]),
              yMg: double.parse(f[1]),
              zMg: double.parse(f[2]),
              noiseDba: double.parse(f[3]),
            );
          }(),
      ]; // 기준 데이터 격자 행
      final grid = GridResampleResult(
        samples: rows,
        t0Ns: 0,
        gridIntervalNs: 3906250,
        rawUsedCount: rows.length,
        gravityUsedCount: rows.length,
        droppedZeroCount: 0,
        droppedBackwardCount: 0,
        droppedLinearCount: 0,
        headTrimmedRows: 0,
        tailTrimmedRows: 0,
        rawMaxSpanNs: 0,
        gravityMaxSpanNs: 0,
        degenerateSpanCount: 0,
      ); // 256Hz 격자
      final result = MeasurementAssembler.assemble(
        grid: const SignalConditioner(
          config: CaptureConfig(),
        ).condition(grid).grid,
        site: const SiteInfo(
          jobNo: 'J',
          siteName: 'S',
          bottomFloor: '1',
          topFloor: '8',
          direction: SiteInfo.directionUp,
          model: SiteInfo.defaultModel,
        ),
        id: 'id',
        measuredAt: DateTime(2026, 1, 14),
      ).result!; // 앱과 같은 길로 만든 결과

      for (final spec in ReportChartAxes.all) {
        final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
        final range = spec.rangeFor(values); // 고른 세로축
        final outside = values
            .where((v) => !spec.scale.ignoreZeros || v != 0)
            .where((v) => !range.contains(v, v))
            .length; // 축 밖 표본 수
        expect(outside, 0, reason: spec.key);
      }
    });
  });
}
