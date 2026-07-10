import 'dart:math' as math;
import 'sensor_sample.dart';

/// 이동 성분(Motion)과 진동 성분(Vibration) 분리 결과
class MotionAndVibration {
  final List<SensorSample> motion;
  final List<SensorSample> vibration;

  const MotionAndVibration({
    required this.motion,
    required this.vibration,
  });
}

/// 측정 신호 전처리 및 필터링 (기준선 보정, 샘플레이트 도출, 성분 분리)
class SignalFilters {
  /// 1. 기준선 보정 (Baseline Correction)
  /// - 측정 시작 후 처음 [baselineSec]초 동안의 평균 가속도를 정지 상태 0점으로 가정하고 3축에서 차감
  static List<SensorSample> applyBaselineCorrection(
    List<SensorSample> samples, {
    double baselineSec = 1.0,
  }) {
    if (samples.isEmpty) return [];
    if (samples.length == 1) {
      return [
        SensorSample(
          tsUs: samples.first.tsUs,
          x: 0.0,
          y: 0.0,
          z: 0.0,
          noiseDba: samples.first.noiseDba,
        ),
      ];
    }

    final int startTsUs = samples.first.tsUs;
    final int baselineDurationUs = (baselineSec * 1000000.0).round();
    final int endTsUs = startTsUs + baselineDurationUs;

    final baselineSamples = samples
        .where((s) => s.tsUs <= endTsUs)
        .toList();

    final effectiveSamples = baselineSamples.isNotEmpty
        ? baselineSamples
        : [samples.first];

    double sumX = 0.0;
    double sumY = 0.0;
    double sumZ = 0.0;
    for (final s in effectiveSamples) {
      sumX += s.x;
      sumY += s.y;
      sumZ += s.z;
    }
    final double avgX = sumX / effectiveSamples.length;
    final double avgY = sumY / effectiveSamples.length;
    final double avgZ = sumZ / effectiveSamples.length;

    return samples
        .map(
          (s) => SensorSample(
            tsUs: s.tsUs,
            x: s.x - avgX,
            y: s.y - avgY,
            z: s.z - avgZ,
            noiseDba: s.noiseDba,
          ),
        )
        .toList();
  }

  /// 2. 실측 샘플레이트 도출 (Estimate Sample Rate)
  /// - 타임스탬프 간격(dt)의 중앙값(Median)을 이용해 정확한 샘플링 주파수(Hz) 산출
  static double estimateSampleRate(List<SensorSample> samples) {
    if (samples.length < 2) return 256.0; // 기본 폴백

    final List<double> dtSeconds = [];
    for (int i = 1; i < samples.length; i++) {
      final int dtUs = samples[i].tsUs - samples[i - 1].tsUs;
      if (dtUs > 0) {
        dtSeconds.add(dtUs / 1000000.0);
      }
    }

    if (dtSeconds.isEmpty) return 256.0;

    dtSeconds.sort();
    final double medianDt = dtSeconds[dtSeconds.length ~/ 2];
    if (medianDt <= 0.0) return 256.0;

    final double rate = 1.0 / medianDt;
    // 비정상적인 값 클램핑 (10Hz ~ 2000Hz 범위)
    return rate.clamp(10.0, 2000.0);
  }

  /// 3. 성분 분리 (Motion vs Vibration Separation)
  /// - 저역통과필터(LPF): 샘플레이트와 컷오프 주파수(기본 0.8Hz)에 기반한 중심 이동평균
  /// - motion = lowpass(signal), vibration = signal - motion
  static MotionAndVibration separateMotionAndVibration(
    List<SensorSample> samples, {
    double sampleRate = 256.0,
    double cutoffHz = 0.8,
  }) {
    if (samples.isEmpty) {
      return const MotionAndVibration(motion: [], vibration: []);
    }
    if (samples.length <= 2 || cutoffHz <= 0.0) {
      return MotionAndVibration(
        motion: List.from(samples),
        vibration: samples
            .map((s) => SensorSample(tsUs: s.tsUs, x: 0, y: 0, z: 0, noiseDba: 0))
            .toList(),
      );
    }

    // 컷오프 0.1Hz: Z축 저주파 진동 보존. 0.8Hz는 진동까지 모션으로 흡수해 Z를 과소산출(16.97 vs 목표 22.2).
    // 이동평균 윈도우 크기 산출: N = round(sampleRate / cutoffHz)
    // 예: 256Hz / 0.8Hz = 320 샘플
    int windowSize = (sampleRate / cutoffHz).round();
    if (windowSize < 3) windowSize = 3;
    if (windowSize % 2 == 0) windowSize += 1; // 중심 맞춤을 위해 홀수로 조정
    final int halfWindow = windowSize ~/ 2;

    final List<SensorSample> motion = [];
    final List<SensorSample> vibration = [];

    // 누적 합 방식(Sliding Window Sum)으로 O(N) 최적화 연산
    double currentSumX = 0.0;
    double currentSumY = 0.0;
    double currentSumZ = 0.0;
    int currentStart = 0;
    int currentEnd = -1;

    for (int i = 0; i < samples.length; i++) {
      final int targetStart = math.max(0, i - halfWindow);
      final int targetEnd = math.min(samples.length - 1, i + halfWindow);

      while (currentEnd < targetEnd) {
        currentEnd++;
        currentSumX += samples[currentEnd].x;
        currentSumY += samples[currentEnd].y;
        currentSumZ += samples[currentEnd].z;
      }
      while (currentStart < targetStart) {
        currentSumX -= samples[currentStart].x;
        currentSumY -= samples[currentStart].y;
        currentSumZ -= samples[currentStart].z;
        currentStart++;
      }

      final int count = targetEnd - targetStart + 1;
      final double motX = currentSumX / count;
      final double motY = currentSumY / count;
      final double motZ = currentSumZ / count;

      final s = samples[i];
      motion.add(
        SensorSample(
          tsUs: s.tsUs,
          x: motX,
          y: motY,
          z: motZ,
          noiseDba: s.noiseDba,
        ),
      );
      vibration.add(
        SensorSample(
          tsUs: s.tsUs,
          x: s.x - motX,
          y: s.y - motY,
          z: s.z - motZ,
          noiseDba: s.noiseDba,
        ),
      );
    }

    return MotionAndVibration(motion: motion, vibration: vibration);
  }
}
