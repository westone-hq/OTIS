import 'dart:math';

import '../models/sensor_sample.dart';
import '../models/vibration_result.dart';

class VibrationAnalyzer {
  static const double gravity = 9.81;
  static const double suspectedImpactThreshold = 0.1 * gravity;
  static const double constantSpeedCandidateThreshold = 0.02 * gravity;
  static const double rideActivityThreshold = 0.02 * gravity;
  static const Duration baselineDuration = Duration(seconds: 1);
  static const int movingAverageWindowSize = 3;
  static const Duration rideActivityPadding = Duration(milliseconds: 800);
  static const Duration minimumDetectedRideDuration = Duration(seconds: 3);
  static const Duration reportWindowDuration = Duration(seconds: 1);

  VibrationResult analyze(List<SensorSample> samples) {
    if (samples.length < 2) {
      throw ArgumentError('계산하려면 최소 2개 이상의 센서 샘플이 필요합니다.');
    }

    final correctedSamples = _applyBaselineCorrection(samples);
    final filteredSamples = _movingAverage(correctedSamples);
    final reportSegment = _detectRideSegment(filteredSamples);
    final reportSamples = reportSegment.samples;
    final xValues = filteredSamples.map((sample) => sample.x).toList();
    final yValues = filteredSamples.map((sample) => sample.y).toList();
    final zValues = filteredSamples.map((sample) => sample.z).toList();
    final vibrationValues = filteredSamples.map(_vibrationValue).toList();

    final sortedVibrationValues = [...vibrationValues]..sort();
    final sumOfSquares = vibrationValues.fold<double>(
      0,
      (sum, value) => sum + (value * value),
    );

    return VibrationResult(
      sampleCount: samples.length,
      reportSampleCount: reportSamples.length,
      usedDetectedRideSegment: reportSegment.usedDetectedRideSegment,
      reportDurationSeconds: reportSegment.duration.inMilliseconds / 1000,
      xRide: _axisRideResult(reportSamples.map((sample) => sample.x).toList()),
      yRide: _axisRideResult(reportSamples.map((sample) => sample.y).toList()),
      zRide: _axisRideResult(reportSamples.map((sample) => sample.z).toList()),
      xPeakToPeak: _peakToPeak(xValues),
      yPeakToPeak: _peakToPeak(yValues),
      zPeakToPeak: _peakToPeak(zValues),
      totalVibrationPeakToPeak: _peakToPeak(vibrationValues),
      rms: sqrt(sumOfSquares / vibrationValues.length),
      a95: _percentile(sortedVibrationValues, 0.95),
      maxVibration: vibrationValues.reduce(max),
      suspectedImpactSampleCount: vibrationValues
          .where((value) => value > suspectedImpactThreshold)
          .length,
      constantSpeedCandidateSampleCount: vibrationValues
          .where((value) => value < constantSpeedCandidateThreshold)
          .length,
    );
  }

  List<SensorSample> _applyBaselineCorrection(List<SensorSample> samples) {
    final baselineEndedAt = samples.first.timestamp.add(baselineDuration);
    final baselineSamples = samples
        .where((sample) => !sample.timestamp.isAfter(baselineEndedAt))
        .toList();

    final effectiveBaselineSamples = baselineSamples.isNotEmpty
        ? baselineSamples
        : samples.take(1).toList();
    final baselineX = _average(
      effectiveBaselineSamples.map((sample) => sample.x).toList(),
    );
    final baselineY = _average(
      effectiveBaselineSamples.map((sample) => sample.y).toList(),
    );
    final baselineZ = _average(
      effectiveBaselineSamples.map((sample) => sample.z).toList(),
    );

    return samples
        .map(
          (sample) => SensorSample(
            timestamp: sample.timestamp,
            x: sample.x - baselineX,
            y: sample.y - baselineY,
            z: sample.z - baselineZ,
          ),
        )
        .toList();
  }

  List<SensorSample> _movingAverage(List<SensorSample> samples) {
    if (samples.length <= 2 || movingAverageWindowSize <= 1) {
      return samples;
    }

    final halfWindow = movingAverageWindowSize ~/ 2;
    return List.generate(samples.length, (index) {
      final start = max(0, index - halfWindow);
      final end = min(samples.length, index + halfWindow + 1);
      final window = samples.sublist(start, end);

      return SensorSample(
        timestamp: samples[index].timestamp,
        x: _average(window.map((sample) => sample.x).toList()),
        y: _average(window.map((sample) => sample.y).toList()),
        z: _average(window.map((sample) => sample.z).toList()),
      );
    });
  }

  _RideSegment _detectRideSegment(List<SensorSample> samples) {
    final activeIndexes = <int>[];

    for (var i = 0; i < samples.length; i++) {
      if (_vibrationValue(samples[i]) >= rideActivityThreshold) {
        activeIndexes.add(i);
      }
    }

    if (activeIndexes.length < 2) {
      return _RideSegment.fromSamples(
        samples: samples,
        usedDetectedRideSegment: false,
      );
    }

    final startIndex = activeIndexes.first;
    final endIndex = activeIndexes.last;
    final detectedDuration = samples[endIndex].timestamp.difference(
      samples[startIndex].timestamp,
    );

    if (detectedDuration < minimumDetectedRideDuration) {
      return _RideSegment.fromSamples(
        samples: samples,
        usedDetectedRideSegment: false,
      );
    }

    final reportStartedAt = samples[startIndex].timestamp.subtract(
      rideActivityPadding,
    );
    final reportEndedAt = samples[endIndex].timestamp.add(rideActivityPadding);
    final detectedSamples = samples
        .where(
          (sample) =>
              !sample.timestamp.isBefore(reportStartedAt) &&
              !sample.timestamp.isAfter(reportEndedAt),
        )
        .toList();

    if (detectedSamples.length < 2) {
      return _RideSegment.fromSamples(
        samples: samples,
        usedDetectedRideSegment: false,
      );
    }

    return _RideSegment.fromSamples(
      samples: detectedSamples,
      usedDetectedRideSegment: true,
    );
  }

  AxisRideResult _axisRideResult(List<double> values) {
    if (values.length < 2) {
      throw ArgumentError('축별 리포트 계산을 위한 값이 부족합니다.');
    }

    final windowSize = _estimatedWindowSize(values.length);
    final windowPeakToPeakValues = <double>[];

    for (var start = 0; start < values.length; start += windowSize) {
      final end = min(start + windowSize, values.length);
      final window = values.sublist(start, end);
      if (window.length >= 2) {
        windowPeakToPeakValues.add(_peakToPeak(window));
      }
    }

    if (windowPeakToPeakValues.isEmpty) {
      windowPeakToPeakValues.add(_peakToPeak(values));
    }

    final sortedWindowPeakToPeakValues = [...windowPeakToPeakValues]..sort();

    return AxisRideResult(
      maxPeakToPeak: windowPeakToPeakValues.reduce(max),
      a95PeakToPeak: _percentile(sortedWindowPeakToPeakValues, 0.95),
    );
  }

  int _estimatedWindowSize(int sampleCount) {
    // The stream uses gameInterval on S22-class devices, commonly near 50Hz.
    const estimatedSamplesPerSecond = 50;
    return min(
      sampleCount,
      max(2, reportWindowDuration.inSeconds * estimatedSamplesPerSecond),
    );
  }

  double _vibrationValue(SensorSample sample) {
    return sqrt(
      (sample.x * sample.x) + (sample.y * sample.y) + (sample.z * sample.z),
    );
  }

  double _peakToPeak(List<double> values) {
    if (values.isEmpty) {
      throw ArgumentError('Peak-to-Peak 계산을 위한 값이 없습니다.');
    }

    return values.reduce(max) - values.reduce(min);
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      throw ArgumentError('평균 계산을 위한 값이 없습니다.');
    }

    return values.reduce((a, b) => a + b) / values.length;
  }

  double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) {
      throw ArgumentError('A95 계산을 위한 값이 없습니다.');
    }

    final index = ((sortedValues.length - 1) * percentile).ceil();
    return sortedValues[index.clamp(0, sortedValues.length - 1)];
  }
}

class _RideSegment {
  const _RideSegment({
    required this.samples,
    required this.usedDetectedRideSegment,
    required this.duration,
  });

  factory _RideSegment.fromSamples({
    required List<SensorSample> samples,
    required bool usedDetectedRideSegment,
  }) {
    return _RideSegment(
      samples: samples,
      usedDetectedRideSegment: usedDetectedRideSegment,
      duration: samples.last.timestamp.difference(samples.first.timestamp),
    );
  }

  final List<SensorSample> samples;
  final bool usedDetectedRideSegment;
  final Duration duration;
}
