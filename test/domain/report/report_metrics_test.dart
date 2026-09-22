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

/// 작성: 2026-09-15 21:14:33 · nada
/// 함수: main
/// 목적: 측정 결과에서 리포트 표 여덟 행을 만드는 산출 계층을 시험한다.
///       - 지금 낼 수 있는 두 값이 나오는지
///       - 아직 못 내는 값이 0 이 아니라 비어 있는지, 그 표시가 `—` 인지
///       - 소음 수집이 붙으면 이 파일을 고치지 않고 값이 채워지는지
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

    test('기준이 없는 두 행은 판정없음이다', () {
      // 원본 리포트도 이 두 행에는 신호등 원을 그리지 않는다
      final metrics = ReportMetrics.from(
        _result(maxSpeed: 1.7, distance: 57.1),
      ); // 산출된 지표

      expect(metrics.maxSpeed.verdict, ReportVerdict.none);
      expect(metrics.travelDistance.verdict, ReportVerdict.none);
      expect(metrics.maxSpeed.redDisplay, '');
      expect(metrics.travelDistance.redDisplay, '');
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

    test('기준이 있는 행은 미확정, 없는 행은 판정없음이다', () {
      final metrics = ReportMetrics.from(_result()); // 아무것도 못 잰 결과

      expect(metrics.noiseMax.verdict, ReportVerdict.unknown);
      expect(metrics.vertMax.verdict, ReportVerdict.unknown);
      expect(metrics.horizMax.verdict, ReportVerdict.unknown);
      expect(metrics.noiseAvg.verdict, ReportVerdict.none);
      expect(metrics.vertAvg.verdict, ReportVerdict.none);
      expect(metrics.horizAvg.verdict, ReportVerdict.none);
    });

    test('평균 진동 두 행에 A95 꼬리표가 붙어 있다', () {
      final metrics = ReportMetrics.from(_result());

      expect(metrics.vertAvg.suffix, 'A95');
      expect(metrics.horizAvg.suffix, 'A95');
    });
  });

  group('소음 통로가 뚫려 있는지', () {
    test('소음이 채워지면 이 계층을 고치지 않고 값이 나온다', () {
      // 소음 수집을 다른 엔지니어가 붙였다고 가정하고, 그 결과물인
      // noiseSeries 와 noiseMax 를 채워 넣는다. 산출 계층을 건드리지
      // 않았는데도 평균과 최대가 나와야 통로가 실제로 열려 있는 것이다
      final metrics = ReportMetrics.from(
        _result(
          noiseSeries: const <double>[44.0, 46.0, 48.0],
          noiseMax: 48.0,
        ),
      ); // 산출된 지표

      expect(metrics.noiseAvg.value, closeTo(46.0, 1e-9));
      expect(metrics.noiseMax.value, closeTo(48.0, 1e-9));
      expect(metrics.noiseAvg.display, '46.0dBA');
      expect(metrics.noiseMax.display, '48.0dBA');
    });

    test('최대는 시계열이 아니라 noiseMax 를 읽는다', () {
      // 소음은 약 8Hz 라 격자 시계열이 표본 사이 봉우리를 잃는다. 센서가
      // 본 최대가 시계열 최대보다 클 수 있고, 그때 정본은 noiseMax 다
      final metrics = ReportMetrics.from(
        _result(
          noiseSeries: const <double>[44.0, 46.0, 48.0],
          noiseMax: 65.6,
        ),
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
      // 실제 측정에서 앞 38개 표본이 0 으로 들어온다. 그대로 평균에
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

    test('소음 최대가 기준을 넘으면 적색이다', () {
      final metrics = ReportMetrics.from(
        _result(noiseMax: 65.6),
      ); // 산출된 지표

      expect(metrics.noiseMax.verdict, ReportVerdict.red);
      expect(metrics.noiseMax.redDisplay, '50');
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
      expect(metrics.vertMax.display, '11.0mg');
    });

    test('수평 행은 큰 쪽을 싣고 두 축을 함께 적는다', () {
      final metrics = ReportMetrics.from(
        _result(xPtp: 8.2, yPtp: 12.9),
      ); // 산출된 지표

      expect(metrics.horizMax.value, closeTo(12.9, 1e-9));
      expect(metrics.horizMax.detail, 'X 8.2 / Y 12.9');
      expect(metrics.horizMax.display, '12.9mg  (X 8.2 / Y 12.9)');
    });

    test('한 축만 재면 그 축 값을 싣고 다른 축은 내역에 —', () {
      final metrics = ReportMetrics.from(_result(xPtp: 8.2));

      expect(metrics.horizMax.value, closeTo(8.2, 1e-9));
      expect(metrics.horizMax.detail, 'X 8.2 / Y —');
    });

    test('수평은 한 축만 넘어도 적색이다', () {
      final metrics = ReportMetrics.from(
        _result(xPtp: 11.0, yPtp: 3.0),
      ); // X만 기준을 넘은 결과

      expect(metrics.horizMax.verdict, ReportVerdict.red);
    });

    test('못 잰 축이 있고 넘은 축이 없으면 미확정이다', () {
      // 한 축만 보고 "정상"이라고 할 수 없다
      final metrics = ReportMetrics.from(_result(xPtp: 3.0));

      expect(metrics.horizMax.verdict, ReportVerdict.unknown);
    });

    test('수직은 제 기준(15mg)으로 판정한다', () {
      final inside = ReportMetrics.from(_result(zPtp: 12.0)); // 기준 안
      final outside = ReportMetrics.from(_result(zPtp: 16.0)); // 기준 밖

      expect(inside.vertMax.verdict, ReportVerdict.green);
      expect(outside.vertMax.verdict, ReportVerdict.red);
      expect(inside.vertMax.redDisplay, '15');
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

      expect(metrics.noiseMax.redLimit, ReportThresholds.noiseMaxRedDba);
      expect(metrics.vertMax.redLimit, ReportThresholds.zPtpRedMg);
      expect(metrics.horizMax.redLimit, ReportThresholds.xPtpRedMg);
    });
  });
}
