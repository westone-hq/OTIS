import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-15 20:13:49 · nada
/// 함수: _result
/// 목적: 판정만 보려고 만드는 측정 결과. 판정에 쓰이지 않는 값은 비워 둔다.
/// 인자: xPtp, yPtp, zPtp — 축별 진동 p2p (mg). 안 주면 null
///       noiseMax — 최대 소음 (dBA). 안 주면 null
/// 반환: 판정 게터만 볼 수 있게 채운 측정 결과
MeasurementResult _result({
  double? xPtp,
  double? yPtp,
  double? zPtp,
  double? noiseMax,
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
    noiseMax: noiseMax,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-09-15 20:13:49 · nada
/// 함수: main
/// 목적: 리포트 판정 기준과 그 기준을 쓰는 측정 결과 게터를 시험한다.
///       - 경계값에서 "초과"의 뜻이 흔들리지 않는지
///       - 값이 없을 때 정상이 아니라 미확정으로 나오는지
///       - 기준이 없는 항목이 판정없음으로 나오는지
///       - 수평 행이 X·Y 를 각각 보고 합치는지
///       - 임계값 숫자가 저장소 안에 한 곳에만 있는지
void main() {
  group('ReportThresholds.exceeds 경계값', () {
    test('기준치와 정확히 같으면 초과가 아니다', () {
      expect(ReportThresholds.exceeds(10.0, 10.0), isFalse);
      expect(ReportThresholds.exceeds(15.0, 15.0), isFalse);
      expect(ReportThresholds.exceeds(50.0, 50.0), isFalse);
    });

    test('기준치를 아주 조금이라도 넘으면 초과다', () {
      expect(ReportThresholds.exceeds(10.000001, 10.0), isTrue);
      expect(ReportThresholds.exceeds(10.1, 10.0), isTrue);
    });

    test('기준치보다 작으면 초과가 아니다', () {
      expect(ReportThresholds.exceeds(9.999999, 10.0), isFalse);
      expect(ReportThresholds.exceeds(0.0, 10.0), isFalse);
    });

    test('값이 없으면 false 가 아니라 null 이다', () {
      expect(ReportThresholds.exceeds(null, 10.0), isNull);
    });
  });

  group('ReportThresholds.judge', () {
    test('기준 안이면 녹색, 넘으면 적색', () {
      expect(ReportThresholds.judge(9.9, 10.0), ReportVerdict.green);
      expect(ReportThresholds.judge(10.0, 10.0), ReportVerdict.green);
      expect(ReportThresholds.judge(10.1, 10.0), ReportVerdict.red);
    });

    test('값이 없으면 미확정이다', () {
      expect(ReportThresholds.judge(null, 10.0), ReportVerdict.unknown);
    });

    test('기준이 없으면 판정없음이다', () {
      // 운행 거리 · 최대 속도가 이 경우다. 원본 리포트도 그 행에는
      // 신호등 원을 그리지 않는다
      expect(ReportThresholds.judge(57.1, null), ReportVerdict.none);
      expect(ReportThresholds.judge(null, null), ReportVerdict.none);
    });
  });

  group('ReportThresholds.judgeHorizontal', () {
    test('두 축 다 기준 안이면 녹색이다', () {
      expect(ReportThresholds.judgeHorizontal(9.0, 9.0), ReportVerdict.green);
    });

    test('한 축만 넘어도 적색이다', () {
      expect(ReportThresholds.judgeHorizontal(11.0, 9.0), ReportVerdict.red);
      expect(ReportThresholds.judgeHorizontal(9.0, 11.0), ReportVerdict.red);
    });

    test('넘은 축이 있으면 다른 축을 못 재도 적색이다', () {
      expect(ReportThresholds.judgeHorizontal(11.0, null), ReportVerdict.red);
    });

    test('못 잰 축이 있고 넘은 축이 없으면 미확정이다', () {
      // 한 축만 보고 "정상"이라고 할 수 없다
      expect(
        ReportThresholds.judgeHorizontal(9.0, null),
        ReportVerdict.unknown,
      );
      expect(
        ReportThresholds.judgeHorizontal(null, null),
        ReportVerdict.unknown,
      );
    });

    test('경계값에서는 녹색이다', () {
      expect(ReportThresholds.judgeHorizontal(10.0, 10.0), ReportVerdict.green);
    });
  });

  group('MeasurementResult 판정 게터', () {
    test('축마다 제 기준을 쓴다', () {
      // Z축만 기준이 15mg 라, 세 축에 같은 12mg 를 넣으면 Z만 통과한다
      final model = _result(xPtp: 12.0, yPtp: 12.0, zPtp: 12.0); // 시험용 결과

      expect(model.xExceeded, isTrue);
      expect(model.yExceeded, isTrue);
      expect(model.zExceeded, isFalse);
    });

    test('경계값에서는 초과가 아니다', () {
      final model = _result(
        xPtp: 10.0,
        yPtp: 10.0,
        zPtp: 15.0,
        noiseMax: 50.0,
      ); // 시험용 결과

      expect(model.xExceeded, isFalse);
      expect(model.yExceeded, isFalse);
      expect(model.zExceeded, isFalse);
      expect(model.noiseExceeded, isFalse);
    });

    test('경계값을 조금만 넘겨도 초과다', () {
      final model = _result(
        xPtp: 10.01,
        yPtp: 10.01,
        zPtp: 15.01,
        noiseMax: 50.01,
      ); // 시험용 결과

      expect(model.xExceeded, isTrue);
      expect(model.yExceeded, isTrue);
      expect(model.zExceeded, isTrue);
      expect(model.noiseExceeded, isTrue);
    });

    test('값이 없으면 false 가 아니라 null 이다', () {
      final model = _result(); // 아무 값도 재지 못한 결과

      expect(model.xExceeded, isNull);
      expect(model.yExceeded, isNull);
      expect(model.zExceeded, isNull);
      expect(model.noiseExceeded, isNull);
    });

    test('게터가 기준 테이블과 같은 값을 본다', () {
      // 게터가 숫자를 따로 들고 있지 않고 테이블을 참조한다는 것을,
      // 테이블 값 바로 위아래에서 판정이 갈리는 것으로 확인한다
      final atLimit = _result(
        xPtp: ReportThresholds.xPtpRedMg,
        yPtp: ReportThresholds.yPtpRedMg,
        zPtp: ReportThresholds.zPtpRedMg,
        noiseMax: ReportThresholds.noiseMaxRedDba,
      ); // 기준치와 똑같은 결과
      final overLimit = _result(
        xPtp: ReportThresholds.xPtpRedMg + 0.001,
        yPtp: ReportThresholds.yPtpRedMg + 0.001,
        zPtp: ReportThresholds.zPtpRedMg + 0.001,
        noiseMax: ReportThresholds.noiseMaxRedDba + 0.001,
      ); // 기준치를 살짝 넘은 결과

      expect(atLimit.xExceeded, isFalse);
      expect(atLimit.yExceeded, isFalse);
      expect(atLimit.zExceeded, isFalse);
      expect(atLimit.noiseExceeded, isFalse);
      expect(overLimit.xExceeded, isTrue);
      expect(overLimit.yExceeded, isTrue);
      expect(overLimit.zExceeded, isTrue);
      expect(overLimit.noiseExceeded, isTrue);
    });
  });

  group('기준 테이블 값', () {
    test('요구사항서가 정한 값과 같다', () {
      expect(ReportThresholds.xPtpRedMg, 10.0);
      expect(ReportThresholds.yPtpRedMg, 10.0);
      expect(ReportThresholds.zPtpRedMg, 15.0);
      expect(ReportThresholds.noiseMaxRedDba, 50.0);
    });

    test('수직 기준이 수평보다 느슨하다', () {
      expect(
        ReportThresholds.zPtpRedMg,
        greaterThan(ReportThresholds.xPtpRedMg),
      );
      expect(
        ReportThresholds.zPtpRedMg,
        greaterThan(ReportThresholds.yPtpRedMg),
      );
    });
  });
}
