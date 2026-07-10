import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/vibration_metrics.dart';

void main() {
  group('P10 · A95 산출 및 임계 판정 모듈 유닛 테스트', () {
    test('calculateP2P - 최대값과 최소값 차이(P2P) 정확도 검증', () {
      final series = [1.5, -2.0, 5.0, 0.0, -3.5];
      // max: 5.0, min: -3.5 => 5.0 - (-3.5) = 8.5
      expect(VibrationMetrics.calculateP2P(series), 8.5);
      expect(VibrationMetrics.calculateP2P([]), 0.0);
    });

    test('calculateA95 - 95백분위수 최대치(A95) 도출 검증', () {
      // 1.0부터 100.0까지 100개의 값 배열
      final series = List.generate(100, (i) => (i + 1).toDouble());
      // 95번째 위치(0-indexed 95% = index 95 => 96.0 또는 95.0 근방 정확한 인덱스 계산 확인)
      // absList.length * 0.95 = 95 => index 95는 값 96.0
      expect(VibrationMetrics.calculateA95(series), 96.0);
    });

    test('calculateMax - 최대 소음치 도출 검증', () {
      final series = [45.2, 52.1, 48.9, 50.0];
      expect(VibrationMetrics.calculateMax(series), 52.1);
    });

    test('ThresholdEvaluation - TUNE 규격 임계 판정 정확도 검증 (X·Y>10, Z>15, 소음>50)', () {
      // 1. X축만 초과
      final evalX = ThresholdEvaluation.evaluate(
        xPtp: 12.5,
        yPtp: 8.0,
        zPtp: 14.0,
        noiseMax: 48.0,
      );
      expect(evalX.xExceeded, isTrue);
      expect(evalX.yExceeded, isFalse);
      expect(evalX.zExceeded, isFalse);
      expect(evalX.noiseExceeded, isFalse);
      expect(evalX.isExceeded, isTrue);

      // 2. 전 지표 정상
      final evalNormal = ThresholdEvaluation.evaluate(
        xPtp: 5.0,
        yPtp: 6.0,
        zPtp: 12.0,
        noiseMax: 45.0,
      );
      expect(evalNormal.isExceeded, isFalse);
    });

    test('수치 연산 - 저크, 속도, 거리 시계열 변환 배열 길이 및 0 이상 검증', () {
      final accel = [0.0, 10.0, 20.0, 10.0, 0.0];
      final speed = VibrationMetrics.calculateSpeedSeries(accel, sampleRate: 10.0);
      final pos = VibrationMetrics.calculatePositionSeries(speed, sampleRate: 10.0);
      final jerk = VibrationMetrics.calculateJerkSeries(accel, sampleRate: 10.0);

      expect(speed.length, accel.length);
      expect(pos.length, accel.length);
      expect(jerk.length, accel.length);
      expect(pos.last, greaterThan(0.0));
    });
  });
}
