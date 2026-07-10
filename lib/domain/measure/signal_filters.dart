import 'dart:math' as math;
import 'sensor_sample.dart';

/// 이동 성분(Motion)과 진동 성분(Vibration) 분리 결과
class MotionAndVibration {
  final List<SensorSample> motion;
  final List<SensorSample> vibration;

  const MotionAndVibration({required this.motion, required this.vibration});
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

    final baselineSamples = samples.where((s) => s.tsUs <= endTsUs).toList();

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
    double? cutoffHzX,
    double? cutoffHzY,
    double? cutoffHzZ,
    double? lowpassCutoffHz,
    double? lowpassCutoffHzX,
    double? lowpassCutoffHzY,
    double? lowpassCutoffHzZ,
  }) {
    if (samples.isEmpty) {
      return const MotionAndVibration(motion: [], vibration: []);
    }
    if (samples.length <= 2 || cutoffHz <= 0.0) {
      return MotionAndVibration(
        motion: List.from(samples),
        vibration: samples
            .map(
              (s) => SensorSample(tsUs: s.tsUs, x: 0, y: 0, z: 0, noiseDba: 0),
            )
            .toList(),
      );
    }

    final effectiveCutoffX = cutoffHzX ?? cutoffHz;
    final effectiveCutoffY = cutoffHzY ?? cutoffHz;
    final effectiveCutoffZ = cutoffHzZ ?? cutoffHz;
    final lowpassX = _centeredMovingAverage(
      samples.map((s) => s.x).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffX,
    );
    final lowpassY = _centeredMovingAverage(
      samples.map((s) => s.y).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffY,
    );
    final lowpassZ = _centeredMovingAverage(
      samples.map((s) => s.z).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffZ,
    );

    final highpassX = <double>[];
    final highpassY = <double>[];
    final highpassZ = <double>[];
    for (int i = 0; i < samples.length; i++) {
      highpassX.add(samples[i].x - lowpassX[i]);
      highpassY.add(samples[i].y - lowpassY[i]);
      highpassZ.add(samples[i].z - lowpassZ[i]);
    }

    final effectiveLowpassX = lowpassCutoffHzX ?? lowpassCutoffHz;
    final effectiveLowpassY = lowpassCutoffHzY ?? lowpassCutoffHz;
    final effectiveLowpassZ = lowpassCutoffHzZ ?? lowpassCutoffHz;
    final vibrationX = effectiveLowpassX != null && effectiveLowpassX > 0.0
        ? _centeredMovingAverage(
            highpassX,
            sampleRate: sampleRate,
            cutoffHz: effectiveLowpassX,
          )
        : highpassX;
    final vibrationY = effectiveLowpassY != null && effectiveLowpassY > 0.0
        ? _centeredMovingAverage(
            highpassY,
            sampleRate: sampleRate,
            cutoffHz: effectiveLowpassY,
          )
        : highpassY;
    final vibrationZ = effectiveLowpassZ != null && effectiveLowpassZ > 0.0
        ? _centeredMovingAverage(
            highpassZ,
            sampleRate: sampleRate,
            cutoffHz: effectiveLowpassZ,
          )
        : highpassZ;

    final List<SensorSample> motion = [];
    final List<SensorSample> vibration = [];
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final double motX = lowpassX[i];
      final double motY = lowpassY[i];
      final double motZ = lowpassZ[i];
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
          x: vibrationX[i],
          y: vibrationY[i],
          z: vibrationZ[i],
          noiseDba: s.noiseDba,
        ),
      );
    }

    return MotionAndVibration(motion: motion, vibration: vibration);
  }

  static List<double> _centeredMovingAverage(
    List<double> values, {
    required double sampleRate,
    required double cutoffHz,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || cutoffHz <= 0.0) return List.from(values);

    int windowSize = (sampleRate / cutoffHz).round();
    if (windowSize < 3) windowSize = 3;
    if (windowSize % 2 == 0) windowSize += 1;
    final int halfWindow = windowSize ~/ 2;

    final List<double> result = [];
    double currentSum = 0.0;
    int currentStart = 0;
    int currentEnd = -1;

    for (int i = 0; i < values.length; i++) {
      final int targetStart = math.max(0, i - halfWindow);
      final int targetEnd = math.min(values.length - 1, i + halfWindow);

      while (currentEnd < targetEnd) {
        currentEnd++;
        currentSum += values[currentEnd];
      }
      while (currentStart < targetStart) {
        currentSum -= values[currentStart];
        currentStart++;
      }

      final int count = targetEnd - targetStart + 1;
      result.add(currentSum / count);
    }

    return result;
  }
}
