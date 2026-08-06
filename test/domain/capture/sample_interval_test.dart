import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/sample_interval.dart';

NativeEvent _event(NativeEventType type, int tsUs, {int dtUs = 0}) {
  return NativeEvent(
    type: type,
    tsUs: tsUs,
    xMg: 0,
    yMg: 0,
    zMg: 0,
    dtUs: dtUs,
  );
}

void main() {
  group('SampleInterval.intervalsUs', () {
    test('같은 종류끼리만 간격을 계산한다', () {
      final events = [
        _event(NativeEventType.accel, 1000),
        _event(NativeEventType.gravity, 2000),
        _event(NativeEventType.accel, 5000),
        _event(NativeEventType.gravity, 6100),
        _event(NativeEventType.accel, 9100),
      ];
      expect(
        SampleInterval.intervalsUs(events, NativeEventType.accel),
        [4000, 4100],
      );
      expect(
        SampleInterval.intervalsUs(events, NativeEventType.gravity),
        [4100],
      );
    });

    test('해당 종류가 2개 미만이면 빈 목록', () {
      final events = [_event(NativeEventType.accel, 1000)];
      expect(SampleInterval.intervalsUs(events, NativeEventType.accel), []);
      expect(SampleInterval.intervalsUs(events, NativeEventType.gravity), []);
    });

    test('타임스탬프 역행은 음수 간격으로 그대로 담는다', () {
      final events = [
        _event(NativeEventType.accel, 5000),
        _event(NativeEventType.accel, 3000),
      ];
      expect(
        SampleInterval.intervalsUs(events, NativeEventType.accel),
        [-2000],
      );
    });
  });

  group('SampleInterval.recordedDtMismatchCount', () {
    test('기록 dtUs 와 재계산이 일치하면 0', () {
      final events = [
        _event(NativeEventType.accel, 1000, dtUs: 0),
        _event(NativeEventType.accel, 4900, dtUs: 3900),
        _event(NativeEventType.accel, 8850, dtUs: 3950),
      ];
      expect(
        SampleInterval.recordedDtMismatchCount(
          events,
          NativeEventType.accel,
        ),
        0,
      );
    });

    test('불일치 건수를 센다', () {
      final events = [
        _event(NativeEventType.accel, 1000, dtUs: 0),
        _event(NativeEventType.accel, 4900, dtUs: 9999),
      ];
      expect(
        SampleInterval.recordedDtMismatchCount(
          events,
          NativeEventType.accel,
        ),
        1,
      );
    });
  });

  group('IntervalStats.from', () {
    const config = CaptureConfig();

    test('알려진 간격에서 통계가 손계산과 일치한다', () {
      // 간격: 3000, 4000, 5000 → 평균 4000, 중앙값 4000
      // 표본 표준편차 = sqrt(((−1000)² + 0² + 1000²) / 2) = 1000
      final stats = IntervalStats.from([3000, 4000, 5000], config: config);
      expect(stats.count, 3);
      expect(stats.minUs, 3000);
      expect(stats.maxUs, 5000);
      expect(stats.meanUs, 4000);
      expect(stats.medianUs, 4000);
      expect(stats.stdDevUs, closeTo(1000, 0.001));
    });

    test('짝수 개수의 중앙값은 가운데 두 값의 평균', () {
      final stats = IntervalStats.from([3000, 4000, 5000, 6000],
          config: config);
      expect(stats.medianUs, 4500);
    });

    test('중앙값 기반 실측 주기 — 손계산 대조', () {
      // 중앙값 3906us → 1,000,000 / 3906 = 256.02...Hz
      final stats = IntervalStats.from([3906, 3906, 3906], config: config);
      expect(stats.estimatedRateHz, closeTo(256.02, 0.01));
    });

    test('큰 지연 몇 건이 있어도 중앙값 주기는 흔들리지 않는다', () {
      final intervals = [...List<int>.filled(98, 3906), 50000, 60000];
      final stats = IntervalStats.from(intervals, config: config);
      expect(stats.estimatedRateHz, closeTo(256.02, 0.01));
      expect(stats.aboveNormalCount, 2);
    });

    test('정상 범위 경계값 판정 — 기본 1950 / 7900 기준', () {
      final stats = IntervalStats.from(
        [1000, 1950, 3906, 7900, 8000, -50],
        config: config,
      );
      // 하한(1950) 미만: 1000, -50 → 2건 (1950 자체는 정상)
      // 상한(7900) 초과: 8000 → 1건 (7900 자체는 정상)
      expect(stats.belowNormalCount, 2);
      expect(stats.aboveNormalCount, 1);
    });

    test('빈 목록이면 전부 0', () {
      final stats = IntervalStats.from([], config: config);
      expect(stats.count, 0);
      expect(stats.estimatedRateHz, 0);
    });
  });
}
