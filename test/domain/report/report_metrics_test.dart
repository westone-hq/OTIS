import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';

/// 작성: 2026-09-15 21:14:33 · 박건준
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

/// 작성: 2026-09-25 11:20:00 · 박건준
/// 변수: _fixturePath
/// 목적: 기준 측정 기록의 경로. 원본 TUNE 리포트를 만든 실제 현장
///       기록이며, 소음 회귀는 이 파일로 고정한다.
const _fixturePath = 'test/fixtures/records/ride_reference.txt';

/// 작성: 2026-09-26 14:10:00 · 박건준
/// 변수: _warmupFixturePath
/// 목적: 수집 주기를 44100Hz · 1초 창으로 고정한 뒤 뽑은 측정 기록의 경로.
///       앞쪽에 0 구간이 있어, 0 을 거르는 규칙을 시험하는 데 쓴다.
///       이 기록은 수집 계층이 덜 찬 창을 내보내지 않게 고치기 전에 뽑은
///       것이다. 0 이 43개로 끝나고 그 뒤 약 1.2초가 0 에서 실제 크기로
///       올라오는 경사인데, 고친 뒤에는 그 경사가 0 구간에 흡수된다.
///       지금 동작의 근거로 쓰면 안 되고, 고치기 전 모습으로만 본다.
const _warmupFixturePath = 'test/fixtures/records/noise_warmup.txt';

/// 작성: 2026-09-25 11:20:00 · 박건준
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

/// 작성: 2026-09-15 21:14:33 · 박건준
/// 수정: 2026-10-28 15:25:15 · Codex
/// 함수: main
/// 목적: 측정 결과에서 리포트 표 열 행을 만드는 산출 계층을 시험한다.
///       - 지금 낼 수 있는 두 값이 나오는지
///       - 아직 못 내는 값이 0 이 아니라 비어 있는지, 그 표시가 `—` 인지
///       - 소음이 격자를 타고 들어오면 이 계층이 값을 내는지
///       - 진동 필터가 정해지면 마찬가지로 채워지는지
///       - X · Y · Z 가 각 축 값과 기준으로 독립적으로 나오는지
///       - 판정이 `ReportThresholds` 를 따르는지
void main() {
  group('지금 낼 수 있는 값', () {
    test('최대 속도와 운행 거리가 나온다', () {
      final metrics = ReportMetrics.from(
        _result(maxSpeed: 1.743390961, distance: 57.093948064),
      ); // 산출된 지표

      expect(metrics.maxSpeed.value, closeTo(1.743390961, 1e-9));
      expect(metrics.travelDistance.value, closeTo(57.093948064, 1e-9));
      // 최대 속도는 반올림 단위 없이 둘째 자리(2026-10-22 0.05 반올림 되돌림)
      expect(metrics.maxSpeed.display, '1.74m/s', reason: '속도는 둘째 자리');
      expect(metrics.travelDistance.display, '57.1m');
    });

    test('최대 속도는 0.05 단위로 반올림하지 않고 둘째 자리로 찍는다', () {
      String shown(double speed) =>
          ReportMetrics.from(_result(maxSpeed: speed)).maxSpeed.display;
      expect(shown(1.518), '1.52m/s');
      expect(shown(1.529), '1.53m/s');
      expect(shown(1.737), '1.74m/s');
      expect(ReportMetric.decimalsFor('m/s'), 2);
      expect(ReportMetric.decimalsFor('dBA'), 1);
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
    test('판정하는 여덟 행이 0 이 아니라 비어 있다', () {
      final metrics = ReportMetrics.from(_result()); // 아무것도 못 잰 결과

      for (final metric in [
        metrics.noiseAvg,
        metrics.noiseMax,
        metrics.zAvg,
        metrics.zMax,
        metrics.xAvg,
        metrics.xMax,
        metrics.yAvg,
        metrics.yMax,
      ]) {
        expect(metric.value, isNull, reason: metric.key);
        expect(metric.display, '—', reason: metric.key);
      }
    });

    test('판정하는 여덟 행은 값이 없으면 미확정이다', () {
      final metrics = ReportMetrics.from(_result()); // 아무것도 못 잰 결과

      for (final metric in metrics.rows.take(8)) {
        expect(metric.verdict, ReportVerdict.unknown, reason: metric.key);
      }
    });

    test('평균 진동 세 행에 A95 꼬리표가 붙어 있다', () {
      final metrics = ReportMetrics.from(_result());

      expect(metrics.zAvg.suffix, 'A95');
      expect(metrics.xAvg.suffix, 'A95');
      expect(metrics.yAvg.suffix, 'A95');
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

      expect(metrics.zMax.value, closeTo(11.0, 1e-9));
      expect(metrics.xMax.value, closeTo(8.2, 1e-9));
      expect(metrics.yMax.value, closeTo(12.9, 1e-9));
      expect(metrics.zMax.display, '11.0milli-G');
    });

    test('평균 행은 X · Y · Z 의 A95 를 각각 싣는다', () {
      final metrics = ReportMetrics.from(
        _result().copyWith(xA95: 10.4, yA95: 12.4, zA95: 4.9),
      ); // 산출된 지표

      expect(metrics.zAvg.value, closeTo(4.9, 1e-9));
      expect(metrics.zAvg.display, '4.9milli-G A95');
      expect(metrics.xAvg.value, closeTo(10.4, 1e-9));
      expect(metrics.xAvg.display, '10.4milli-G A95');
      expect(metrics.yAvg.value, closeTo(12.4, 1e-9));
      expect(metrics.yAvg.display, '12.4milli-G A95');
      expect(metrics.zAvg.yellowDisplay, '14');
      expect(metrics.zAvg.redDisplay, '21');
      expect(metrics.xAvg.yellowDisplay, '9');
      expect(metrics.xAvg.redDisplay, '13.5');
    });

    test('X · Y 최대를 합치지 않고 각 행에 적는다', () {
      final metrics = ReportMetrics.from(
        _result(xPtp: 8.2, yPtp: 12.9),
      ); // 산출된 지표

      expect(metrics.xMax.value, closeTo(8.2, 1e-9));
      expect(metrics.xMax.display, '8.2milli-G');
      expect(metrics.yMax.display, '12.9milli-G');
    });

    test('한 축만 재면 다른 축을 채우지 않는다', () {
      final metrics = ReportMetrics.from(_result(xPtp: 8.2));

      expect(metrics.xMax.value, closeTo(8.2, 1e-9));
      expect(metrics.xMax.display, '8.2milli-G');
      expect(metrics.yMax.value, isNull);
      expect(metrics.yMax.verdict, ReportVerdict.unknown);
    });

    test('X · Y 최대는 각 축을 수평 기준으로 판정한다', () {
      expect(
        ReportMetrics.from(_result(xPtp: 18.0, yPtp: 3.0)).xMax.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(_result(xPtp: 3.0, yPtp: 26.0)).yMax.verdict,
        ReportVerdict.red,
      );
    });

    test('수평 평균은 X · Y A95 각각을 9 · 13.5 로 본다', () {
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 4.0, yA95: 8.9),
        ).xAvg.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 9.5, yA95: 3.0),
        ).xAvg.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(
          _result().copyWith(xA95: 3.0, yA95: 14.0),
        ).yAvg.verdict,
        ReportVerdict.red,
      );
    });

    test('Y 가 비어 있어도 측정된 X 는 독립적으로 판정한다', () {
      final metrics = ReportMetrics.from(_result(xPtp: 3.0));

      expect(metrics.xMax.verdict, ReportVerdict.green);
      expect(metrics.yMax.verdict, ReportVerdict.unknown);
    });

    test('수직 최대는 20 을 넘으면 황색, 30 을 넘으면 적색이다', () {
      final inside = ReportMetrics.from(_result(zPtp: 12.0)); // 황색 기준 안
      final yellow = ReportMetrics.from(_result(zPtp: 21.0)); // 황색
      final red = ReportMetrics.from(_result(zPtp: 31.0)); // 적색

      expect(inside.zMax.verdict, ReportVerdict.green);
      expect(yellow.zMax.verdict, ReportVerdict.yellow);
      expect(red.zMax.verdict, ReportVerdict.red);
      expect(inside.zMax.yellowDisplay, '20');
      expect(inside.zMax.redDisplay, '30');
    });

    test('수직 평균은 14 를 넘으면 황색, 21 을 넘으면 적색이다', () {
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 14.0)).zAvg.verdict,
        ReportVerdict.green,
      );
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 15.0)).zAvg.verdict,
        ReportVerdict.yellow,
      );
      expect(
        ReportMetrics.from(_result().copyWith(zA95: 22.0)).zAvg.verdict,
        ReportVerdict.red,
      );
    });
  });

  group('수직 행 황색 · 적색 문구 (2026-10-21 OTIS)', () {
    test('초록 · 값 없음은 문구가 없다', () {
      final metrics = ReportMetrics.from(
        _result(zPtp: 12.0).copyWith(zA95: 5.0),
      ); // 초록
      expect(metrics.zMax.remarkLines, isNull);
      expect(metrics.zAvg.remarkLines, isNull);
      expect(ReportMetrics.from(_result()).zMax.remarkLines, isNull);
    });

    test('평균 행은 A95 값을 넣은 두 줄이다', () {
      final metrics = ReportMetrics.from(_result().copyWith(zA95: 15.4));
      expect(metrics.zAvg.remarkLines, <String>[
        '진동측정결과가 15.4milli-G A95 로',
        '일관되게 높게 측정되었습니다',
      ]);
    });

    test('최대 행은 하부층 기준 위치를 소수 첫째 자리로 적는다', () {
      final metrics = ReportMetrics.from(
        _result(zPtp: 22.04).copyWith(zPtpPositionM: 5.46),
      ); // 황색
      expect(metrics.zMax.remarkLines, <String>[
        '최대의 진동 22.0milli-G 가 하부층 정지레벨로부터',
        '5.5m 에서 측정되었습니다.',
      ]);
      final red = ReportMetrics.from(
        _result(zPtp: 31.0).copyWith(zPtpPositionM: 12.0),
      ); // 적색
      expect(red.zMax.verdict, ReportVerdict.red);
      expect(red.zMax.remarkLines, isNotNull);
    });

    test('위치가 없는 예전 결과는 위치 없이 적는다', () {
      final metrics = ReportMetrics.from(_result(zPtp: 22.0));
      expect(metrics.zMax.remarkLines, <String>[
        '최대의 진동 22.0milli-G 가',
        '측정되었습니다.',
      ]);
    });

    test('수평 · 소음 행은 황색이어도 문구가 없다', () {
      final metrics = ReportMetrics.from(
        _result(xPtp: 20.0, yPtp: 5.0, noiseMax: 73.0),
      ); // 수평 · 소음 황색
      expect(metrics.xMax.verdict, ReportVerdict.yellow);
      expect(metrics.xMax.remarkLines, isNull);
      expect(metrics.noiseMax.remarkLines, isNull);
    });
  });

  group('표 짜임새', () {
    test('열 행이 소음 · X · Y · Z · 속도 · 거리 순서다', () {
      final metrics = ReportMetrics.from(_result()); // 산출된 지표

      expect(metrics.rows.map((metric) => metric.key).toList(), [
        'noise_avg',
        'noise_max',
        'x_avg',
        'x_max',
        'y_avg',
        'y_max',
        'z_avg',
        'z_max',
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
      expect(metrics.zAvg.yellowLimit, ReportThresholds.zA95YellowMg);
      expect(metrics.zAvg.redLimit, ReportThresholds.zA95RedMg);
      expect(metrics.zMax.yellowLimit, ReportThresholds.zPtpYellowMg);
      expect(metrics.zMax.redLimit, ReportThresholds.zPtpRedMg);
      expect(metrics.xAvg.yellowLimit, ReportThresholds.horizA95YellowMg);
      expect(metrics.xAvg.redLimit, ReportThresholds.horizA95RedMg);
      expect(metrics.xMax.yellowLimit, ReportThresholds.horizPtpYellowMg);
      expect(metrics.xMax.redLimit, ReportThresholds.xPtpRedMg);
      expect(metrics.yAvg.yellowLimit, ReportThresholds.horizA95YellowMg);
      expect(metrics.yAvg.redLimit, ReportThresholds.horizA95RedMg);
      expect(metrics.yMax.yellowLimit, ReportThresholds.horizPtpYellowMg);
      expect(metrics.yMax.redLimit, ReportThresholds.yPtpRedMg);
    });
  });

  group('소음 평균의 범위 (2026-10-15 운행 구간)', () {
    final noise = <double>[
      ...List<double>.filled(10, 80.0), // 출발 전 문 소음 — 구간 밖
      ...List<double>.filled(10, 45.0), // 운행 중
      ...List<double>.filled(10, 80.0), // 도착 뒤 — 구간 밖
    ]; // 소음 시계열 (dBA)
    const window = TravelWindow(
      startIndex: 10,
      endIndex: 19,
      startSec: 0.1,
      endSec: 0.19,
      startM: 0.5,
      endM: 9.5,
    ); // 운행 구간

    test('운행 구간이 있으면 그 안에서만 평균을 낸다', () {
      final metrics = ReportMetrics.from(
        _result(noiseSeries: noise).copyWith(travelWindow: window),
      ); // 산출된 지표
      expect(metrics.noiseAvg.value, closeTo(45.0, 1e-9));
    });

    test('구간을 정하지 못한 결과는 평균도 비운다', () {
      final metrics = ReportMetrics.from(
        _result(
          noiseSeries: noise,
        ).copyWith(travelWindowFailure: '운행 거리가 1.0m 이하다'),
      ); // 산출된 지표
      expect(metrics.noiseAvg.value, isNull);
      expect(metrics.noiseAvg.verdict, ReportVerdict.unknown);
    });

    test('구간이 들어가기 전 예전 결과는 예전처럼 전체에서 낸다', () {
      final metrics = ReportMetrics.from(_result(noiseSeries: noise)); // 산출된 지표
      expect(
        metrics.noiseAvg.value,
        closeTo((80.0 * 20 + 45.0 * 10) / 30, 1e-9),
      );
    });
  });
}
