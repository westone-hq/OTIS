import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
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
/// 목적: 차트를 그려 보려고 만드는 측정 결과. 소음만 비워 둔다 — 실제
///       측정이 지금 그 상태라, 빈 시계열에서도 축 틀이 그려지는지 같이
///       확인하려는 것이다.
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
/// 함수: main
/// 목적: 차트 계층을 시험한다. 크게 셋을 본다.
///       1. 축 단계 고르기 — 경계값과 적분 잔차를 포함해 어떤 단계를
///          고르는지
///       2. 눈금 만들기 — 마지막 눈금이 축 위끝에 정확히 떨어지는지
///       3. 표본 줄이기 — 최댓값과 최솟값이 살아남는지
///       마지막으로 실제 PDF 를 한 장 그려 그리기 과정이 끝까지 도는지
///       확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChartAxisSpec.rangeFor — 축 단계 고르기', () {
    test('데이터가 비면 가장 좁은 단계를 쓴다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[]);

      expect(range.max, ReportChartAxes.position.steps.first.max);
    });

    test('고정 축은 데이터와 상관없이 같은 범위를 쓴다', () {
      final narrow = ReportChartAxes.x.rangeFor(const <double>[0.1]);
      final wide = ReportChartAxes.x.rangeFor(const <double>[-999.0, 999.0]);

      expect(narrow.min, wide.min);
      expect(narrow.max, wide.max);
    });

    test('데이터가 들어가는 가장 좁은 단계를 고른다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[0.0, 9.5]);

      expect(range.max, 10.0);
    });

    test('축 위끝과 똑같은 값은 그 단계 안이다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[
        0.0,
        10.0,
      ]);

      expect(range.max, 10.0);
    });

    test('여유 폭 끝에 걸친 값도 그 단계 안이다', () {
      // 여유는 축 길이에 비례한다. 코드와 같은 식으로 끝값을 만들어
      // 부동소수점 오차 때문에 갈라지지 않게 한다
      final edge = 10.0 + 10.0 * ChartAxisRange.toleranceRatio; // 여유의 끝
      final range = ReportChartAxes.position.rangeFor(<double>[0.0, edge]);

      expect(range.max, 10.0);
    });

    test('여유 폭을 넘으면 다음 단계로 올라간다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[
        0.0,
        10.25,
      ]);

      expect(range.max, 25.0);
    });

    test('적분 잔차로 0 아래로 살짝 내려간 값은 단계를 올리지 않는다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[
        -0.15,
        9.0,
      ]);

      expect(range.max, 10.0);
    });

    test('아래로 여유를 넘게 내려가면 다음 단계로 올라간다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[
        -0.25,
        9.0,
      ]);

      expect(range.max, 25.0);
    });

    test('어느 단계에도 안 들어가면 가장 넓은 단계를 쓴다', () {
      final range = ReportChartAxes.position.rangeFor(const <double>[0.0, 400]);

      expect(range.max, ReportChartAxes.position.steps.last.max);
    });

    test('실측 최대 속도는 두 번째 단계에 들어간다', () {
      final range = ReportChartAxes.speed.rangeFor(const <double>[
        0.0,
        1.743390961,
      ]);

      expect(range.max, 2.0);
    });

    test('조용한 운행은 소음 축 첫 단계에 그대로 머문다', () {
      // 첫 단계는 원본 리포트와 같은 범위다. 원본과 똑같이 보여야 한다
      final range = ReportChartAxes.noise.rangeFor(const <double>[41.0, 53.5]);

      expect(range.min, 40.0);
      expect(range.max, 54.0);
    });

    test('앱 실측 소음 범위는 두 번째 단계에 들어간다', () {
      // `test/fixtures/app_measurement.xlsx` 의 `noiseDba` 열 양 끝값
      final range = ReportChartAxes.noise.rangeFor(const <double>[44.8, 63.0]);

      expect(range.min, 35.0);
      expect(range.max, 70.0);
    });

    test('가속도는 아래쪽 경계도 여유를 두고 견준다', () {
      final inside = ReportChartAxes.accel.rangeFor(const <double>[
        -0.61,
        0.5,
      ]); // 여유 안쪽
      final outside = ReportChartAxes.accel.rangeFor(const <double>[
        -0.63,
        0.5,
      ]); // 여유 바깥쪽

      expect(inside.max, 0.6);
      expect(outside.max, 1.0);
    });
  });

  group('ChartAxisRange.ticks — 눈금 만들기', () {
    test('소음 축은 40 부터 54 까지 2 씩 놓인다', () {
      final ticks = ReportChartAxes.noise.steps.first.ticks();

      expect(ticks, const <double>[40, 42, 44, 46, 48, 50, 52, 54]);
    });

    test('마지막 눈금은 어느 단계에서도 축 위끝에 정확히 떨어진다', () {
      final specs = <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
        ReportChartAxes.noise,
        ReportChartAxes.position,
        ReportChartAxes.speed,
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ]; // 축 여덟 개 전부

      for (final spec in specs) {
        for (final step in spec.steps) {
          final ticks = step.ticks(); // 이 단계의 눈금

          expect(
            ticks.first,
            step.min,
            reason: '${spec.key} 단계 ${step.min}~${step.max} 의 첫 눈금',
          );
          expect(
            ticks.last,
            step.max,
            reason: '${spec.key} 단계 ${step.min}~${step.max} 의 마지막 눈금',
          );
        }
      }
    });

    test('소음 축은 어느 단계에서나 눈금이 여덟 개다', () {
      for (final step in ReportChartAxes.noise.steps) {
        expect(step.ticks().length, 8, reason: '${step.min}~${step.max} 단계');
      }
    });

    test('이진수로 안 떨어지는 간격에서도 오차가 쌓이지 않는다', () {
      // 0.2 씩 다섯 번은 거듭 더하면 1.0 에서 벗어난다
      final ticks = ReportChartAxes.speed.steps.first.ticks();

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
        steps: <ChartAxisRange>[ChartAxisRange(min: 0, max: 1, tickStep: 1)],
      ); // 사양에 없는 축

      expect(
        () => ReportChartAxes.seriesOf(unknown, _result()),
        throwsArgumentError,
      );
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
