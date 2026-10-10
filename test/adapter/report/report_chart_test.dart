import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/domain/report/chart_scale.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _outputPath
/// 목적: 그려 본 차트 쪽을 남겨 둘 자리. 축 눈금과 라벨이 겹치지 않는지는
///       숫자로 재기 어려워 눈으로 열어 봐야 한다. 시험이 끝나도 지우지
///       않는 이유가 그것이다.
const _outputPath = 'build/report_chart_test.pdf';

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _sampleRate
/// 목적: 시험에 쓰는 표본 주기 (Hz).
/// 근거: 인용 — 회귀 기준 측정 기록(`test/fixtures/ride_reference.txt`)이
///       이 주기로 기록돼 있다
const _sampleRate = 256.0;

/// 작성: 2026-09-17 10:05:00 · nada
/// 변수: _rideSampleCount
/// 목적: 시험에 쓰는 표본 개수.
/// 근거: 인용 — 회귀 기준 측정 기록의 행 수와 같다. 줄이기가 실제 측정
///       크기에서 어떻게 도는지 보려고 같은 수를 쓴다
const _rideSampleCount = 11388;

/// 작성: 2026-09-17 10:05:00 · nada
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

/// 작성: 2026-09-17 10:05:00 · nada
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

/// 작성: 2026-09-17 10:05:00 · nada
/// 수정: 2026-10-10 11:48:41 · nada
/// 함수: main
/// 목적: 차트 계층을 시험한다. 크게 셋을 본다.
///       1. 축마다 세로축 범위 — 최소 범위를 지키는지, 넘치면 넓어지는지,
///          축마다 넓히는 모양이 맞는지
///       2. 눈금 만들기 — 마지막 눈금이 축 위끝에 정확히 떨어지는지
///       3. 표본 줄이기 — 최댓값과 최솟값이 살아남는지
///       마지막으로 실제 PDF 를 한 장 그려 그리기 과정이 끝까지 도는지
///       확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChartAxisSpec.rangeFor — 축마다 세로축 범위', () {
    test('데이터가 비면 최소 범위를 쓴다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[]);

      expect(range.min, 0.0);
      expect(range.max, 10.0);
    });

    test('최소 범위 안의 값은 원본 리포트 범위 그대로 보인다', () {
      final x = ReportChartAxes.x.rangeFor(const <double>[0.1]);
      final noise = ReportChartAxes.noise.rangeFor(const <double>[41.0, 53.5]);

      expect(<double>[x.min, x.max], const <double>[-4.0, 4.0]);
      expect(<double>[noise.min, noise.max], const <double>[40.0, 54.0]);
    });

    test('최소 범위를 넘는 진동은 축이 넓어져 잘리지 않는다', () {
      final range = ReportChartAxes.x.rangeFor(const <double>[-999.0, 999.0]);

      expect(range.min, lessThanOrEqualTo(-999.0));
      expect(range.max, greaterThanOrEqualTo(999.0));
    });

    test('여유 폭 끝에 걸친 값은 최소 범위 안이다', () {
      // 여유는 축 길이에 비례한다. 코드와 같은 식으로 끝값을 만들어
      // 부동소수점 오차 때문에 갈라지지 않게 한다
      final edge = 10.0 + 10.0 * ChartAxisRange.toleranceRatio; // 여유의 끝
      final range = ReportChartAxes.position.rangeFor(<double>[0.0, edge]);

      expect(range.max, 10.0);
    });

    test('적분 잔차로 0 아래로 살짝 내려간 위치는 축을 넓히지 않는다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[
        -0.15,
        9.0,
      ]);

      expect(range.min, 0.0);
      expect(range.max, 10.0);
    });

    test('실측 최대 속도는 0 ~ 2 m/s 에 담긴다', () {
      final range = ReportChartAxes.speed.rangeFor(const <double>[
        0.0,
        1.743390961,
      ]);

      expect(range.min, 0.0);
      expect(range.max, closeTo(2.0, 1e-9));
    });

    test('음수 쪽으로 나온 속도는 0 이 위끝이 된다', () {
      final range = ReportChartAxes.speed.rangeFor(const <double>[
        -1.743390961,
        0.0,
      ]);

      expect(range.min, closeTo(-2.0, 1e-9));
      expect(range.max, 0.0);
    });

    test('앱 실측 소음은 0 을 빼고 40 ~ 65 dBA 로 넓어진다', () {
      // `test/fixtures/app_measurement.xlsx` 의 `noiseDba` 열 양 끝값.
      // 앞쪽 0 은 마이크 창이 차기 전 미측정 구간이다
      final range = ReportChartAxes.noise.rangeFor(const <double>[
        0.0,
        44.8,
        63.0,
      ]);

      expect(range.min, 40.0);
      expect(range.max, closeTo(65.0, 1e-9));
    });

    test('축마다 넓히는 모양이 정해져 있다', () {
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]) {
        expect(spec.scale.kind, ChartScaleKind.symmetric, reason: spec.key);
      }
      for (final spec in <ChartAxisSpec>[
        ReportChartAxes.position,
        ReportChartAxes.speed,
      ]) {
        expect(spec.scale.kind, ChartScaleKind.zeroAnchored, reason: spec.key);
      }
      expect(ReportChartAxes.noise.scale.kind, ChartScaleKind.free);
      expect(ReportChartAxes.noise.scale.ignoreZeros, isTrue);
    });
  });

  group('ChartAxisRange.ticks — 눈금 만들기', () {
    test('소음 최소 범위는 40 부터 54 까지 2 씩 놓인다', () {
      final ticks = ReportChartAxes.noise.scale.minimum.ticks();

      expect(ticks, const <double>[40, 42, 44, 46, 48, 50, 52, 54]);
    });

    test('마지막 눈금은 어느 축의 최소 범위에서도 위끝에 정확히 떨어진다', () {
      for (final spec in ReportChartAxes.all) {
        final minimum = spec.scale.minimum; // 이 축의 최소 범위
        final ticks = minimum.ticks(); // 그 눈금

        expect(ticks.first, minimum.min, reason: '${spec.key} 첫 눈금');
        expect(ticks.last, minimum.max, reason: '${spec.key} 마지막 눈금');
      }
    });

    test('이진수로 안 떨어지는 간격에서도 오차가 쌓이지 않는다', () {
      // 0.2 씩 다섯 번은 거듭 더하면 1.0 에서 벗어난다
      final ticks = ReportChartAxes.speed.scale.minimum.ticks();

      expect(ticks.length, 6);
      expect(ticks.last, 1.0);
    });
  });

  group('reduceSeries — 표본 줄이기', () {
    test('빈 시계열은 빈 목록이 된다', () {
      expect(reduceSeries(const <double>[], columns: 100), isEmpty);
    });

    test('칸 수의 두 배 이하면 줄이지 않고 그대로 옮긴다', () {
      final values = List<double>.generate(20, (i) => i.toDouble());

      final reduced = reduceSeries(values, columns: 10); // 줄인 결과

      expect(reduced.length, values.length);
      expect(reduced.map((s) => s.value).toList(), values);
    });

    test('최댓값과 최솟값이 살아남는다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 봉우리를 섞은 파형
      values[7000] = -17.0;
      final before = (
        min: values.reduce(math.min),
        max: values.reduce(math.max),
      ); // 줄이기 전 끝값

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과
      final after = (
        min: reduced.map((s) => s.value).reduce(math.min),
        max: reduced.map((s) => s.value).reduce(math.max),
      ); // 줄인 뒤 끝값

      expect(after.min, before.min);
      expect(after.max, before.max);
      expect(reduced.length, lessThan(values.length));
    });

    test('한 표본짜리 뾰족한 봉우리도 지워지지 않는다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 99.0,
      ); // 봉우리 하나만 아주 높은 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      expect(
        reduced.any((s) => s.index == 5000 && s.value == 99.0),
        isTrue,
        reason: '봉우리는 그 칸의 최댓값이라 반드시 남아야 한다',
      );
    });

    test('자리 번호가 커지는 차례를 지킨다', () {
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 시험용 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      for (var i = 1; i < reduced.length; i++) {
        expect(
          reduced[i].index,
          greaterThan(reduced[i - 1].index),
          reason: '$i 번째 표본이 앞 표본보다 앞쪽 자리로 돌아갔다',
        );
      }
    });

    test('남은 값은 모두 원래 시계열에 있던 값이다', () {
      // 평균을 냈다면 원래 없던 값이 섞여 나온다
      final values = _wave(
        _rideSampleCount,
        spikeIndex: 5000,
        spikeValue: 18.0,
      ); // 시험용 파형

      final reduced = reduceSeries(
        values,
        columns: ReportChartPage.slotWidth,
      ); // 줄인 결과

      for (final sample in reduced) {
        expect(sample.value, values[sample.index]);
      }
    });
  });

  group('ReportChartAxes.seriesOf — 시계열 고르기', () {
    test('축마다 짝이 되는 시계열을 꺼낸다', () {
      final result = _result(); // 시험용 측정 결과

      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.z, result),
        result.zSeries,
      );
      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.speed, result),
        result.speedSeries,
      );
    });

    test('아직 수집하지 않은 소음은 빈 목록이 나온다', () {
      expect(
        ReportChartAxes.seriesOf(ReportChartAxes.noise, _result()),
        isEmpty,
      );
    });

    test('모르는 축 이름은 조용히 넘어가지 않고 실패한다', () {
      const unknown = ChartAxisSpec(
        key: '없는축',
        label: '없는 축',
        scale: ChartScale(
          minimum: ChartAxisRange(min: 0, max: 1, tickStep: 1),
          kind: ChartScaleKind.free,
        ),
      ); // 사양에 없는 축

      expect(
        () => ReportChartAxes.seriesOf(unknown, _result()),
        throwsArgumentError,
      );
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
        box: ReportChartPage.slots.first,
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
          box: ReportChartPage.slots[i],
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
        box: ReportChartPage.slots.first,
        result: _result(),
      );
      final bytes = await document.save(); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });
  });
}
