import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/chart_series.dart';
import 'package:vibration_checker/domain/report/report_chart_page_layout.dart';

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
/// 수정: 2026-10-22 23:40:00 · 박건준
/// 함수: main
/// 목적: 차트 표본 줄이기를 시험한다(렌더러 시험에서 옮겼다). 최댓값과
///       최솟값이 살아남는지, 소음 0 구간에서 선을 끊는지 본다.
void main() {
  group('reduceSeriesSegments — 0 구간 끊기', () {
    test('끊지 않으면 reduceSeries 와 같은 한 덩어리다', () {
      final values = _wave(5000, spikeIndex: 1200, spikeValue: 9.0);
      final whole = reduceSeries(values, columns: 300);
      final segments = reduceSeriesSegments(
        values,
        columns: 300,
        skipZeros: false,
      );

      expect(segments, hasLength(1));
      expect(
        segments.single.map((s) => s.index).toList(),
        whole.map((s) => s.index).toList(),
      );
    });

    test('0 구간에서 선을 끊고 0 은 그리지 않는다', () {
      final values = <double>[
        ...List<double>.filled(1000, 0.0), // 마이크 창이 차기 전
        ...List<double>.filled(2000, 50.0),
        ...List<double>.filled(500, 0.0), // 중간에 끊긴 구간
        ...List<double>.filled(1500, 60.0),
      ]; // 0 과 실측이 섞인 소음
      final segments = reduceSeriesSegments(
        values,
        columns: 300,
        skipZeros: true,
      );

      expect(segments, hasLength(2));
      for (final segment in segments) {
        expect(segment.map((s) => s.value), everyElement(isNot(0.0)));
      }
      expect(segments.first.first.index, 1000);
      expect(segments.last.first.index, 3500);
      // 값이 고른 칸은 칸 첫 자리 하나만 남으므로, 마지막 표본은 마지막
      // 칸(한 칸 = 16 표본) 안에 있으면 된다
      expect(
        segments.last.last.index,
        greaterThanOrEqualTo(values.length - values.length ~/ 300 - 1),
      );
    });

    test('한 칸에 0 과 실측이 섞이면 실측만으로 최소 · 최대를 낸다', () {
      // 5000 표본을 10칸으로 나누면 한 칸이 500 표본이다. 둘째 칸
      // (500 ~ 999) 앞 절반이 0 이고 뒤 절반이 실측이다
      final values = <double>[
        ...List<double>.filled(750, 0.0),
        for (var i = 0; i < 4250; i++) 40.0 + (i % 7),
      ];
      final segments = reduceSeriesSegments(
        values,
        columns: 10,
        skipZeros: true,
      );

      expect(segments, hasLength(1));
      final first = segments.single.take(2).map((s) => s.value); // 둘째 칸
      expect(first, everyElement(greaterThanOrEqualTo(40.0)));
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
        columns: ReportChartPageLayout.slotWidth,
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
        columns: ReportChartPageLayout.slotWidth,
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
        columns: ReportChartPageLayout.slotWidth,
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
        columns: ReportChartPageLayout.slotWidth,
      ); // 줄인 결과

      for (final sample in reduced) {
        expect(sample.value, values[sample.index]);
      }
    });
  });
}
