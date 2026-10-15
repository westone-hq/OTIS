import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-15 21:14:33 · nada
/// 함수: _result
/// 목적: 지표 산출만 보려고 만드는 측정 결과. 산출에 쓰이지 않는 값은
///       비워 둔다.
/// 인자: noiseSeries — 소음 시계열 (dBA). 안 주면 빈 목록
///       noiseMax — 센서가 본 소음 최대 (dBA). 안 주면 null
///       xPtp, yPtp, zPtp — 축별 진동 P2P (mg). 안 주면 null
///       maxSpeed — 최대 속도 (m/s). 안 주면 null
///       distance — 운행 거리 (m). 안 주면 null
/// 반환: 지표 산출에 넣을 측정 결과
MeasurementResult _result({
  List<double> noiseSeries = const <double>[],
  double? noiseMax,
  double? xPtp,
  double? yPtp,
  double? zPtp,
  double? maxSpeed,
  double? distance,
}) {
  return MeasurementResult(
    id: 'id',
    jobNo: 'T-1001',
    siteName: '서울 본사',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부 → 상부',
    dateTime: DateTime(2026, 9, 15),
    xPtp: xPtp,
    yPtp: yPtp,
    zPtp: zPtp,
    maxSpeed: maxSpeed,
    distance: distance,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: noiseSeries,
    noiseMax: noiseMax,
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-09-25 11:20:00 · nada
/// 변수: _fixturePath
/// 목적: 기준 측정 기록의 경로. 원본 TUNE 리포트를 만든 실제 현장
///       기록이며, 소음 회귀는 이 파일로 고정한다.
const _fixturePath = 'test/fixtures/ride_reference.txt';

/// 작성: 2026-09-26 14:10:00 · nada
/// 변수: _warmupFixturePath
/// 목적: 수집 주기를 44100Hz · 1초 창으로 고정한 뒤 뽑은 측정 기록의 경로.
///       앞쪽에 0 구간이 있어, 0 을 거르는 규칙을 시험하는 데 쓴다.
///       이 기록은 수집 계층이 덜 찬 창을 내보내지 않게 고치기 전에 뽑은
///       것이다. 0 이 43개로 끝나고 그 뒤 약 1.2초가 0 에서 실제 크기로
///       올라오는 경사인데, 고친 뒤에는 그 경사가 0 구간에 흡수된다.
///       지금 동작의 근거로 쓰면 안 되고, 고치기 전 모습으로만 본다.
const _warmupFixturePath = 'test/fixtures/noise_warmup.txt';

/// 작성: 2026-09-25 11:20:00 · nada
/// 함수: _fixtureNoise
/// 목적: 측정 기록에서 소음 열만 뽑는다. EVIMP1 포맷이라 머리말이 두
///       줄이고 그 뒤로 X Y Z 소음 네 열이 공백으로 구분돼 있다.
/// 인자: path — 읽을 기록 파일 경로. 안 주면 회귀 기준 기록
/// 반환: 소음 값 목록 (dBA)
List<double> _fixtureNoise([String path = _fixturePath]) {
  return const LineSplitter()
      .convert(File(path).readAsStringSync())
      .where((line) => line.trim().isNotEmpty)
      .skip(2)
      .map((line) => double.parse(line.trim().split(RegExp(r'\s+'))[3]))
      .toList();
}

/// 작성: 2026-09-15 21:14:33 · nada
/// 수정: 2026-10-15 15:53:26 · nada
/// 함수: main
/// 목적: 측정 결과에서 리포트 표 여덟 행을 만드는 산출 계층을 시험한다.
///       - 지금 낼 수 있는 두 값이 나오는지
///       - 아직 못 내는 값이 0 이 아니라 비어 있는지, 그 표시가 `—` 인지
///       - 소음이 격자를 타고 들어오면 이 계층이 값을 내는지
///       - 진동 필터가 정해지면 마찬가지로 채워지는지
///       - 수평 행이 큰 쪽 값을 싣고 두 축을 함께 적는지
///       - 판정이 `ReportThresholds` 를 따르는지
void main() {
  group('지금 낼 수 있는 값', () {
    test('최대 속도와 운행 거리가 나온다', () {
      final metrics = ReportMetrics.from(
        _result(maxSpeed: 1.743390961, distance: 57.093948064),
      ); // 산출된 지표

      expect(metrics.maxSpeed.value, closeTo(1.743390961, 1e-9));
      expect(metrics.travelDistance.value, closeTo(57.093948064, 1e-9));
      expect(metrics.maxSpeed.display, '1.7m/s');
      expect(metrics.travelDistance.display, '57.1m');
    });

    test('최대 속도 · 운행 거리는 판정없음이고 기준 칸에는 0 을 찍는다', () {
      // 원본 리포트도 이 두 행에는 신호등 원을 그리지 않고 두 칸에 0 을
      // 찍는다(2026-10-15 사용자 지시 "0,0")
      final metrics = ReportMetrics.from(
        _result(maxSpeed: 1.7, distance: 57.1),
      ); // 산출된 지표

      for (final metric in [metrics.maxSpeed, metrics.travelDistance]) {
        expect(metric.verdict, ReportVerdict.none, reason: metric.key);
        expect(metric.yellowDisplay, '0', reason: metric.key);
        expect(metric.redDisplay, '0', reason: metric.key);
      }
    });

    test('100 이상은 소수점을 떼고 찍는다', () {
      final metrics = ReportMetrics.from(_result(distance: 123.456));

      expect(metrics.travelDistance.display, '123m');
    });
  });

  group('아직 못 내는 값', () {
    test('여섯 행이 0 이 아니라 비어 있다', () {
      final metrics = ReportMetrics.from(_result()); // 아무것도 못 잰 결과

      for (final metric in [
        metrics.noiseAvg,
        metrics.noiseMax,
        metrics.vertAvg,
        metrics.vertMax,
        metrics.horizAvg,
        metrics.horizMax,
      ]) {
        expect(metric.value, isNull, reason: metric.key);
        expect(metric.display, '—', reason: metric.key);
      }
    });

    test('판정하는 여섯 행은 값이 없으면 미확정이다', () {
      final metrics = ReportMetrics.from(_result()); // 아무것도 못 잰 결과

      for (final metric in metrics.rows.take(6)) {
        expect(metric.verdict, ReportVerdict.unknown, reason: metric.key);
      }
    });

    test('평균 진동 두 행에 A95 꼬리표가 붙어 있다', () {
      final metrics = ReportMetrics.from(_result());

      expect(metrics.vertAvg.suffix, 'A95');
      expect(metrics.horizAvg.suffix, 'A95');
    });
  });

  group('소음 통로가 뚫려 있는지', () {
    test('소음이 채워지면 이 계층을 고치지 않고 값이 나온다', () {
      // 수집 계층이 격자에 실어 준 소음이 어셈블러를 거쳐 온 모양으로,
      // noiseSeries 와 noiseMax 를 채워 넣는다. 산출 계층을 건드리지
      // 않았는데도 평균과 최대가 나와야 통로가 실제로 열려 있는 것이다
      final metrics = ReportMetrics.from(
        _result(noiseSeries: const <double>[44.0, 46.0, 48.0], noiseMax: 48.0),
      ); // 산출된 지표

      expect(metrics.noiseAvg.value, closeTo(46.0, 1e-9));
      expect(metrics.noiseMax.value, closeTo(48.0, 1e-9));
      expect(metrics.noiseAvg.display, '46.0dBA');
      expect(metrics.noiseMax.display, '48.0dBA');
    });

    test('최대는 시계열이 아니라 noiseMax 를 읽는다', () {
      // 최대의 정본은 noiseMax 다. 여기서 시계열로 다시 세면 0 인 표본을
      // 빼는 규칙이 어셈블러와 갈라져 두 값이 어긋난다
      final metrics = ReportMetrics.from(
        _result(noiseSeries: const <double>[44.0, 46.0, 48.0], noiseMax: 65.6),
      ); // 산출된 지표

      expect(metrics.noiseMax.value, closeTo(65.6, 1e-9));
      expect(metrics.noiseAvg.value, closeTo(46.0, 1e-9));
    });

    test('시계열만 있고 noiseMax 가 없으면 최대는 비어 있다', () {
      // 최대를 시계열에서 몰래 다시 세지 않는다는 것을 못박는다.
      // 시계열 최대로 채우는 일은 어셈블러가 맡는다
      final metrics = ReportMetrics.from(
        _result(noiseSeries: const <double>[44.0, 46.0, 48.0]),
      ); // 산출된 지표

      expect(metrics.noiseMax.value, isNull);
      expect(metrics.noiseAvg.value, closeTo(46.0, 1e-9));
    });

    test('시작 직후 0 구간을 빼고 평균을 낸다', () {
      // 첫 창이 찰 때까지 수집 계층이 0 을 내보낸다. 그대로 평균에
      // 넣으면 값이 실제보다 낮게 끌려 내려간다
      final withZeros = <double>[
        ...List<double>.filled(38, 0.0),
        44.0,
        46.0,
        48.0,
      ]; // 0 구간이 앞에 붙은 소음 시계열

      final metrics = ReportMetrics.from(
        _result(noiseSeries: withZeros),
      ); // 산출된 지표

      expect(metrics.noiseAvg.value, closeTo(46.0, 1e-9));
    });

    test('0 만 들어오면 평균이 값 없음이다', () {
      final metrics = ReportMetrics.from(
        _result(noiseSeries: List<double>.filled(38, 0.0)),
      ); // 쓸 표본이 하나도 없는 결과

      expect(metrics.noiseAvg.value, isNull);
      expect(metrics.noiseAvg.display, '—');
    });

    test('소음 최대는 72 를 넘으면 황색, 75 를 넘으면 적색이다', () {
      expect(
        ReportMetrics.from(_result(noiseMax: 65.6)).noiseMax.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(_result(noiseMax: 73.0)).noiseMax.verdict,
        ReportVerdict.yellow,
      );
      final loud = ReportMetrics.from(_result(noiseMax: 76.0)); // 적색 결과
      expect(loud.noiseMax.verdict, ReportVerdict.red);
      expect(loud.noiseMax.yellowDisplay, '72');
      expect(loud.noiseMax.redDisplay, '75');
    });

    test('소음 평균은 57 을 넘으면 황색, 60 을 넘으면 적색이다', () {
      // 고른 소음 시계열
      List<double> noise(double level) => List<double>.filled(10, level);
      expect(
        ReportMetrics.from(_result(noiseSeries: noise(45.8))).noiseAvg.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(_result(noiseSeries: noise(58.0))).noiseAvg.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(_result(noiseSeries: noise(61.0))).noiseAvg.verdict,
        ReportVerdict.red,
      );
    });
  });

  group('실측 소음 회귀', () {
    test('평균과 최대가 원본 리포트에 인쇄된 값 그대로 찍힌다', () {
      // 원본 TUNE 리포트 1쪽은 평균 45.8dBA · 최대 65.6dBA 로 적고 있다.
      // 기준 측정 기록의 소음 열에서 그대로 나오는 값이라 표기 문자열까지
      // 고정한다
      final noise = _fixtureNoise(); // 기준 기록의 소음 열 (dBA)
      final metrics = ReportMetrics.from(
        _result(noiseSeries: noise, noiseMax: 65.6),
      ); // 산출된 지표

      expect(noise.length, 11388);
      expect(metrics.noiseAvg.value!, closeTo(45.804380, 1e-6));
      expect(metrics.noiseAvg.display, '45.8dBA');
      expect(metrics.noiseMax.display, '65.6dBA');
    });
  });

  group('워밍업 0 구간', () {
    test('고치기 전 기록에서 0 은 앞쪽 43개였다', () {
      // 수집 계층을 고치기 전 모습이다. 지금은 창이 찰 때까지 0 이 나오므로
      // 0 구간이 이보다 길다. 거르는 쪽 코드는 개수를 모르고 돌아야 하므로,
      // 개수가 달라져도 이 함수가 그대로 동작한다는 것을 여기서 본다
      final noise = _fixtureNoise(_warmupFixturePath); // 워밍업이 있는 소음 열
      final leading = noise.takeWhile((v) => v == 0).length; // 앞쪽 연속 0 개수

      expect(noise.length, 14530);
      expect(leading, 43);
      expect(
        noise.where((v) => v == 0).length,
        leading,
        reason: '0 은 앞쪽에만 몰려 있어야 한다',
      );
    });

    test('0 을 거르면 평균이 0 쪽으로 끌려 내려가지 않는다', () {
      final noise = _fixtureNoise(_warmupFixturePath); // 워밍업이 있는 소음 열
      final metrics = ReportMetrics.from(_result(noiseSeries: noise)); // 산출 지표
      final rawAverage =
          noise.reduce((a, b) => a + b) / noise.length; // 0 을 포함한 평균

      expect(metrics.noiseAvg.value!, greaterThan(rawAverage));
    });
  });

  group('진동 통로가 뚫려 있는지', () {
    test('필터가 정해져 P2P 가 채워지면 값이 나온다', () {
      // 진동 필터가 확정돼 MeasurementResult 의 P2P 세 값이 채워졌다고
      // 가정한다. 산출 계층을 건드리지 않아도 세 행이 나와야 한다
      final metrics = ReportMetrics.from(
        _result(xPtp: 8.2, yPtp: 12.9, zPtp: 11.0),
      ); // 산출된 지표

      expect(metrics.vertMax.value, closeTo(11.0, 1e-9));
      expect(metrics.horizMax.value, closeTo(12.9, 1e-9));
      expect(metrics.vertMax.display, '11.0milli-G');
    });

    test('평균 행은 A95 를 싣고 수평은 큰 쪽만 적는다', () {
      final metrics = ReportMetrics.from(
        _result().copyWith(xA95: 10.4, yA95: 12.4, zA95: 4.9),
      ); // 산출된 지표

      expect(metrics.vertAvg.value, closeTo(4.9, 1e-9));
      expect(metrics.vertAvg.display, '4.9milli-G A95');
      expect(metrics.horizAvg.value, closeTo(12.4, 1e-9));
      expect(metrics.horizAvg.display, '12.4milli-G A95');
      expect(metrics.vertAvg.yellowDisplay, '14');
      expect(metrics.vertAvg.redDisplay, '21');
      expect(metrics.horizAvg.yellowDisplay, '9');
      expect(metrics.horizAvg.redDisplay, '13.5');
    });

    test('수평 최대 행에 X · Y 내역을 붙이지 않는다', () {
      // 2026-10-15 사용자 지시. 원본 리포트도 큰 쪽 값 하나만 적는다
      final metrics = ReportMetrics.from(
        _result(xPtp: 8.2, yPtp: 12.9),
      ); // 산출된 지표

      expect(metrics.horizMax.value, closeTo(12.9, 1e-9));
      expect(metrics.horizMax.display, '12.9milli-G');
    });

    test('한 축만 재면 그 축 값을 싣는다', () {
      final metrics = ReportMetrics.from(_result(xPtp: 8.2));

      expect(metrics.horizMax.value, closeTo(8.2, 1e-9));
      expect(metrics.horizMax.display, '8.2milli-G');
    });

    test('수평은 두 축 중 더 나쁜 쪽을 따른다', () {
      expect(
        ReportMetrics.from(_result(xPtp: 18.0, yPtp: 3.0)).horizMax.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(_result(xPtp: 3.0, yPtp: 26.0)).horizMax.verdict,
        ReportVerdict.red,
      );
    });

    test('수평 평균은 X · Y A95 각각을 9 · 13.5 로 본다', () {
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 4.0, yA95: 8.9),
        ).horizAvg.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 9.5, yA95: 3.0),
        ).horizAvg.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 3.0, yA95: 14.0),
        ).horizAvg.verdict,
        ReportVerdict.red,
      );
    });

    test('못 잰 축이 있고 넘은 축이 없으면 미확정이다', () {
      // 한 축만 보고 "정상"이라고 할 수 없다
      final metrics = ReportMetrics.from(_result(xPtp: 3.0));

      expect(metrics.horizMax.verdict, ReportVerdict.unknown);
    });

    test('수직 최대는 20 을 넘으면 황색, 30 을 넘으면 적색이다', () {
      final inside = ReportMetrics.from(_result(zPtp: 12.0)); // 황색 기준 안
      final yellow = ReportMetrics.from(_result(zPtp: 21.0)); // 황색
      final red = ReportMetrics.from(_result(zPtp: 31.0)); // 적색

      expect(inside.vertMax.verdict, ReportVerdict.green);
      expect(yellow.vertMax.verdict, ReportVerdict.yellow);
      expect(red.vertMax.verdict, ReportVerdict.red);
      expect(inside.vertMax.yellowDisplay, '20');
      expect(inside.vertMax.redDisplay, '30');
    });

    test('수직 평균은 14 를 넘으면 황색, 21 을 넘으면 적색이다', () {
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 14.0)).vertAvg.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 15.0)).vertAvg.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 22.0)).vertAvg.verdict,
        ReportVerdict.red,
      );
    });
  });

  group('표 짜임새', () {
    test('여덟 행이 서식 순서대로 나온다', () {
      final metrics = ReportMetrics.from(_result()); // 산출된 지표

      expect(metrics.rows.map((metric) => metric.key).toList(), [
        'noise_avg',
        'noise_max',
        'vert_avg',
        'vert_max',
        'horiz_avg',
        'horiz_max',
        'max_speed',
        'travel_distance',
      ]);
    });

    test('이름으로 행을 찾을 수 있다', () {
      final metrics = ReportMetrics.from(_result(distance: 57.1));

      expect(metrics.byKey('travel_distance')?.value, closeTo(57.1, 1e-9));
      expect(metrics.byKey('없는_행'), isNull);
    });

    test('임계값을 스스로 들고 있지 않고 테이블을 쓴다', () {
      final metrics = ReportMetrics.from(_result()); // 산출된 지표

      expect(metrics.noiseAvg.yellowLimit, ReportThresholds.noiseAvgYellowDba);
      expect(metrics.noiseAvg.redLimit, ReportThresholds.noiseAvgRedDba);
      expect(metrics.noiseMax.yellowLimit, ReportThresholds.noiseMaxYellowDba);
      expect(metrics.noiseMax.redLimit, ReportThresholds.noiseMaxRedDba);
      expect(metrics.vertAvg.yellowLimit, ReportThresholds.zA95YellowMg);
      expect(metrics.vertAvg.redLimit, ReportThresholds.zA95RedMg);
      expect(metrics.vertMax.yellowLimit, ReportThresholds.zPtpYellowMg);
      expect(metrics.vertMax.redLimit, ReportThresholds.zPtpRedMg);
      expect(metrics.horizAvg.yellowLimit, ReportThresholds.horizA95YellowMg);
      expect(metrics.horizAvg.redLimit, ReportThresholds.horizA95RedMg);
      expect(metrics.horizMax.yellowLimit, ReportThresholds.horizPtpYellowMg);
      expect(metrics.horizMax.redLimit, ReportThresholds.xPtpRedMg);
    });
  });
}
