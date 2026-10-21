import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_chart.dart';
import 'package:vibration_checker/model/measurement_result.dart';

import '../../support/otis_1021_records.dart';

/// 작성: 2026-10-21 15:20:00 · nada
/// 함수: _firstAccelSign
/// 목적: 차트 가속도에서 첫 가속의 부호를 본다. 크기가 최대의 절반을 처음
///       넘는 표본의 부호다.
/// 인자: accel — 가속도 시계열 (m/s²)
/// 반환: 첫 가속이 양수면 1, 음수면 −1
int _firstAccelSign(List<double> accel) {
  final peak = accel.map((a) => a.abs()).reduce(math.max); // 가속도 크기 최대
  final first = accel.firstWhere((a) => a.abs() > peak / 2); // 첫 가속
  return first > 0 ? 1 : -1;
}

/// 작성: 2026-10-21 15:20:00 · nada
/// 함수: _restMean
/// 목적: 시계열 앞 · 뒤 1초의 평균을 낸다.
/// 인자: series — 시계열
///       rate — 표본 속도 (Hz)
/// 반환: (앞 1초 평균, 뒤 1초 평균)
(double, double) _restMean(List<double> series, double rate) {
  final n = rate.round(); // 1초 표본 수
  double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  return (mean(series.take(n)), mean(series.skip(series.length - n)));
}

/// 작성: 2026-10-21 15:20:00 · nada
/// 함수: _expectDescent
/// 목적: 하강 운행 결과가 물리 부호 · 하부층 기준으로 나왔는지 본다.
///       - 첫 가속이 음수(아래로 출발)
///       - 속도가 음수이고 그 크기의 최대가 표의 최대 속도
///       - 위치가 운행 거리에서 0 으로 내려온다
///       - 표의 최대 속도 · 운행 거리는 양수
/// 인자: result — 하강 측정 결과
void _expectDescent(MeasurementResult result) {
  expect(_firstAccelSign(result.accelSeries), -1, reason: '첫 가속');
  final slowest = result.speedSeries.reduce(math.min); // 가장 빠른 하강 속도
  expect(slowest, lessThan(-1.0));
  expect(-slowest, closeTo(result.maxSpeed!, 1e-12));
  expect(result.speedSeries.reduce(math.max), lessThan(0.05));
  expect(result.positionSeries.first, closeTo(result.distance!, 0.05));
  expect(result.positionSeries.last, closeTo(0, 0.01));
  expect(result.positionSeries.reduce(math.min), 0.0);
  expect(result.maxSpeed, greaterThan(0));
  expect(result.distance, greaterThan(20));
}

/// 작성: 2026-10-21 15:20:00 · nada
/// 함수: main
/// 목적: 하강 운행(2026-10-21 서일대 11 → 4층)이 OTIS 리포트처럼 물리
///       부호로 나오는지 시험한다.
///       - otis_down3: 오티스폰 원시데이터(화면 아래, 부호 바름)를 그대로
///       - dev_down3: 화면을 위로 놓고 예전 식으로 기록돼 Z 가 뒤집힌 개발폰
///         기록을 지금 식이 냈을 값(Z 반전)으로 읽어서(`faceUpRecords`)
///       - 상승은 예전과 같이 위치 0 → 운행 거리, 속도 양수
///       raw 정지 Z 오프셋(dev_down3 −13.6 mg)은 가속도계 영점 · 배율
///       오차라 raw 에서는 남고 신호 처리 기준선(첫 1초 평균 빼기)에서
///       없어진다. 이 시험은 기준선 뒤 값이 |평균| < 2 mg 인지 본다.
void main() {
  test('otis_down3: 첫 가속 음수 · 속도 음수 · 위치 운행 거리 → 0', () {
    final result = assembleRecord(otis1021Records['otis_down3']!).result!;
    _expectDescent(result);
  });

  test('dev_down3(Z 반전): 하강 부호와 OTIS 저크 봉우리 +0.58/−0.68', () {
    expect(faceUpRecords, contains('dev_down3'));
    final result = assembleRecord(
      otis1021Records['dev_down3']!,
      flipVertical: true,
    ).result!;
    _expectDescent(result);
    expect(result.jerkSeries.reduce(math.max), closeTo(0.58, 0.08));
    expect(result.jerkSeries.reduce(math.min), closeTo(-0.68, 0.08));
  });

  test('dev_down3: 기준선을 뺀 뒤 정지 구간 Z 는 처음 · 마지막 1초 모두 |평균| < 2 mg', () {
    final grid = readEvimpGrid(
      otis1021Records['dev_down3']!,
      flipVertical: true,
    ); // 256Hz 격자
    final raw = <double>[for (final s in grid.samples) s.zMg]; // raw Z (mg)
    final (rawHead, rawTail) = _restMean(raw, 256);
    // raw 는 처리 전이라 가속도계 오프셋이 그대로 남는다(보고만)
    expect(rawHead, closeTo(13.6, 0.5));
    expect(rawTail, closeTo(13.9, 0.5));

    final result = assembleRecord(
      otis1021Records['dev_down3']!,
      flipVertical: true,
    ).result!;
    // 차트 가속도는 움직인 구간 평균을 뺀 값이라 정지 구간이 0 근처다
    final (head, tail) = _restMean(<double>[
      for (final a in result.accelSeries) a / 9.80665e-3,
    ], result.sampleRate); // 정지 구간 평균 (mg)
    expect(head.abs(), lessThan(2));
    expect(tail.abs(), lessThan(2));
  });

  test('상승은 위치 0 → 운행 거리, 속도 양수로 예전과 같다', () {
    final result = assembleRecord(otis1021Records['dev_up1']!).result!;
    expect(_firstAccelSign(result.accelSeries), 1);
    expect(result.positionSeries.first, closeTo(0, 0.01));
    expect(result.positionSeries.last, closeTo(result.distance!, 0.05));
    expect(
      result.speedSeries.reduce(math.max),
      closeTo(result.maxSpeed!, 1e-12),
    );
  });

  test('하강 속도 · 위치 차트에 축 밖 표본이 없다', () {
    final result = assembleRecord(otis1021Records['otis_down3']!).result!;
    for (final spec in <ChartAxisSpec>[
      ReportChartAxes.position,
      ReportChartAxes.speed,
      ReportChartAxes.accel,
      ReportChartAxes.jerk,
    ]) {
      final values = ReportChartAxes.seriesOf(spec, result); // 그릴 값
      final range = spec.rangeFor(values); // 고른 세로축
      expect(
        values.where((v) => !range.contains(v, v)),
        isEmpty,
        reason: spec.key,
      );
    }
  });
}
