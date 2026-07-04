import 'dart:math' as math;
import 'sensor_sample.dart';

/// 주행 구간 검출 결과
class RideSegmentResult {
  final List<SensorSample> samples;
  final List<double> speedSeries;
  final bool usedDetectedRideSegment;
  final int startIndex;
  final int endIndex;

  const RideSegmentResult({
    required this.samples,
    required this.speedSeries,
    required this.usedDetectedRideSegment,
    required this.startIndex,
    required this.endIndex,
  });

  double get durationSeconds {
    if (samples.length < 2) return 0.0;
    return (samples.last.tsUs - samples.first.tsUs) / 1000000.0;
  }
}

/// 정속 구간 검출 결과
class ConstantSpeedResult {
  final List<SensorSample> samples;
  final bool isDetected;
  final String rangeSummary; // 예: "1.2초 ~ 18.5초"

  const ConstantSpeedResult({
    required this.samples,
    required this.isDetected,
    required this.rangeSummary,
  });
}

/// 승강기 주행 구간(Ride) 및 정속 운행 구간(Constant Speed) 자동 검출기
class RideDetector {
  /// 1. 주행 구간 감지 (Detect Ride Segment)
  /// - 속도 |v(t)| > [speedThreshold] (기본 0.05 m/s) 인 첫 지점부터 마지막 지점까지 추출
  /// - 전후 [paddingSec] (기본 0.8초) 패딩 추가
  /// - 유효 주행 시간이 [minDurationSec] (기본 3.0초) 미만이면 전 구간 폴백 및 false 반환
  static RideSegmentResult detectRideSegment(
    List<SensorSample> samples,
    List<double> speedSeries, {
    double speedThreshold = 0.05,
    double paddingSec = 0.8,
    double minDurationSec = 3.0,
  }) {
    if (samples.length < 2 || speedSeries.length != samples.length) {
      return RideSegmentResult(
        samples: List.from(samples),
        speedSeries: List.from(speedSeries),
        usedDetectedRideSegment: false,
        startIndex: 0,
        endIndex: math.max(0, samples.length - 1),
      );
    }

    final List<int> activeIndices = [];
    for (int i = 0; i < speedSeries.length; i++) {
      if (speedSeries[i] > speedThreshold) {
        activeIndices.add(i);
      }
    }

    if (activeIndices.length < 2) {
      return RideSegmentResult(
        samples: List.from(samples),
        speedSeries: List.from(speedSeries),
        usedDetectedRideSegment: false,
        startIndex: 0,
        endIndex: samples.length - 1,
      );
    }

    final int firstActive = activeIndices.first;
    final int lastActive = activeIndices.last;
    final double durationSec =
        (samples[lastActive].tsUs - samples[firstActive].tsUs) / 1000000.0;

    if (durationSec < minDurationSec) {
      return RideSegmentResult(
        samples: List.from(samples),
        speedSeries: List.from(speedSeries),
        usedDetectedRideSegment: false,
        startIndex: 0,
        endIndex: samples.length - 1,
      );
    }

    // 패딩 적용: timestamp 기준으로 앞뒤 paddingSec 추가
    final int startTsUs = samples[firstActive].tsUs - (paddingSec * 1000000.0).round();
    final int endTsUs = samples[lastActive].tsUs + (paddingSec * 1000000.0).round();

    int paddedStart = 0;
    int paddedEnd = samples.length - 1;

    for (int i = 0; i < samples.length; i++) {
      if (samples[i].tsUs >= startTsUs) {
        paddedStart = i;
        break;
      }
    }
    for (int i = samples.length - 1; i >= 0; i--) {
      if (samples[i].tsUs <= endTsUs) {
        paddedEnd = i;
        break;
      }
    }

    if (paddedEnd - paddedStart < 1) {
      return RideSegmentResult(
        samples: List.from(samples),
        speedSeries: List.from(speedSeries),
        usedDetectedRideSegment: false,
        startIndex: 0,
        endIndex: samples.length - 1,
      );
    }

    return RideSegmentResult(
      samples: samples.sublist(paddedStart, paddedEnd + 1),
      speedSeries: speedSeries.sublist(paddedStart, paddedEnd + 1),
      usedDetectedRideSegment: true,
      startIndex: paddedStart,
      endIndex: paddedEnd,
    );
  }

  /// 2. 정속 구간 감지 (Detect Constant Speed Range)
  /// - 주행 구간 속도 중 |v(t)| >= [constantRatio] * maxSpeed (기본 0.9) 를 만족하는 연속 구간
  /// - 여러 연속 구간이 존재할 경우 가장 긴 연속 구간을 선택
  /// - 미검출 시 주행 구간 전체로 폴백
  static ConstantSpeedResult detectConstantSpeedRange(
    List<SensorSample> rideSamples,
    List<double> rideSpeedSeries, {
    double constantRatio = 0.9,
  }) {
    if (rideSamples.length < 2 || rideSpeedSeries.isEmpty) {
      return ConstantSpeedResult(
        samples: List.from(rideSamples),
        isDetected: false,
        rangeSummary: '전체 구간',
      );
    }

    double maxSpeed = 0.0;
    for (final v in rideSpeedSeries) {
      if (v > maxSpeed) maxSpeed = v;
    }

    if (maxSpeed <= 0.0) {
      return ConstantSpeedResult(
        samples: List.from(rideSamples),
        isDetected: false,
        rangeSummary: '전체 구간',
      );
    }

    final double threshold = maxSpeed * constantRatio;
    int bestStart = -1;
    int bestLen = 0;
    int currentStart = -1;
    int currentLen = 0;

    for (int i = 0; i < rideSpeedSeries.length; i++) {
      if (rideSpeedSeries[i] >= threshold) {
        if (currentStart == -1) currentStart = i;
        currentLen++;
        if (currentLen > bestLen) {
          bestLen = currentLen;
          bestStart = currentStart;
        }
      } else {
        currentStart = -1;
        currentLen = 0;
      }
    }

    // 유효 정속 구간이 최소 1초 이상(또는 10샘플 이상) 되지 않으면 주행 전체 구간 폴백
    final double durationSec = bestStart != -1 && bestLen >= 2
        ? (rideSamples[bestStart + bestLen - 1].tsUs - rideSamples[bestStart].tsUs) / 1000000.0
        : 0.0;
    if (bestStart == -1 || bestLen < 10 || durationSec < 1.0) {
      final double startSec = rideSamples.first.tsUs / 1000000.0;
      final double endSec = rideSamples.last.tsUs / 1000000.0;
      return ConstantSpeedResult(
        samples: List.from(rideSamples),
        isDetected: false,
        rangeSummary: '${startSec.toStringAsFixed(1)}초 ~ ${endSec.toStringAsFixed(1)}초 (전체)',
      );
    }

    final int bestEnd = bestStart + bestLen - 1;
    final subSamples = rideSamples.sublist(bestStart, bestEnd + 1);
    final double startSec = subSamples.first.tsUs / 1000000.0;
    final double endSec = subSamples.last.tsUs / 1000000.0;

    return ConstantSpeedResult(
      samples: subSamples,
      isDetected: true,
      rangeSummary: '${startSec.toStringAsFixed(1)}초 ~ ${endSec.toStringAsFixed(1)}초',
    );
  }
}
