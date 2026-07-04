import 'dart:math' as math;
import 'metrics_config.dart';
import 'sensor_sample.dart';

/// 승강기 진동·소음 분석 임계 판정 결과
class ThresholdEvaluation {
  final double xPtp;
  final double yPtp;
  final double zPtp;
  final double noiseMax;

  final bool xExceeded;
  final bool yExceeded;
  final bool zExceeded;
  final bool noiseExceeded;

  const ThresholdEvaluation({
    required this.xPtp,
    required this.yPtp,
    required this.zPtp,
    required this.noiseMax,
    required this.xExceeded,
    required this.yExceeded,
    required this.zExceeded,
    required this.noiseExceeded,
  });

  /// 임계 초과 기준: X·Y > 10mg, Z > 15mg, 소음 > 50dBA (metrics_config 단일 지점 참조)
  bool get isExceeded => xExceeded || yExceeded || zExceeded || noiseExceeded;

  factory ThresholdEvaluation.evaluate({
    required double xPtp,
    required double yPtp,
    required double zPtp,
    required double noiseMax,
    MetricsConfig config = MetricsConfig.defaultConfig,
  }) {
    return ThresholdEvaluation(
      xPtp: xPtp,
      yPtp: yPtp,
      zPtp: zPtp,
      noiseMax: noiseMax,
      xExceeded: xPtp > config.xyThresholdMg,
      yExceeded: yPtp > config.xyThresholdMg,
      zExceeded: zPtp > config.zThresholdMg,
      noiseExceeded: noiseMax > config.noiseThresholdDba,
    );
  }
}

/// 승강기 진동·소음 연산 및 지표 도출 모듈 (ISO 18738 / Otis TUNE 규격)
class VibrationMetrics {
  /// Aptp (A95 Peak-to-Peak) 산출
  /// - 정속 구간(또는 지정 구간)의 진동 성분을 [windowSec] (기본 1.0초) 슬라이딩 윈도우(stride <= 1/5)로 분할
  /// - 각 윈도우별 P2P(max - min)를 도출하고 그 중 95백분위수(ceil((n-1)*p)) 선택
  static double calculateAptp(
    List<double> vibrationSeries, {
    double sampleRate = 256.0,
    double windowSec = 1.0,
    double percentile = 0.95,
  }) {
    if (vibrationSeries.isEmpty) return 0.0;
    if (vibrationSeries.length < 2) return 0.0;

    final int windowSize = math.max(2, (windowSec * sampleRate).round());
    // 슬라이딩 윈도우 사용: 텀블링은 구간 경계 0.1초 이동에 Z Aptp가 22.6→16.8mg로 요동(위상 민감)해 폐기. 슬라이딩 1.0초는 위상 무관 안정.
    // 슬라이딩 윈도우 stride: 윈도우의 1/10 (예: 1.0초 윈도우 기준 0.1초)
    final int stride = math.max(1, (windowSize / 10).round());
    final List<double> windowP2pValues = [];

    if (vibrationSeries.length <= windowSize) {
      windowP2pValues.add(_calculateRawP2P(vibrationSeries));
    } else {
      for (int start = 0; start <= vibrationSeries.length - windowSize; start += stride) {
        final window = vibrationSeries.sublist(start, start + windowSize);
        windowP2pValues.add(_calculateRawP2P(window));
      }
      final int lastStart = vibrationSeries.length - windowSize;
      if (lastStart % stride != 0) {
        windowP2pValues.add(_calculateRawP2P(vibrationSeries.sublist(lastStart)));
      }
    }

    windowP2pValues.sort();
    final int idx = ((windowP2pValues.length - 1) * percentile).ceil();
    final int clampedIdx = idx.clamp(0, windowP2pValues.length - 1);
    return windowP2pValues[clampedIdx];
  }

  /// 소음 최대값 도출 (dBA)
  static double calculateNoiseMax(List<SensorSample> samples) {
    if (samples.isEmpty) return 0.0;
    double maxDba = samples.first.noiseDba;
    for (final s in samples) {
      if (s.noiseDba > maxDba) maxDba = s.noiseDba;
    }
    return maxDba;
  }

  /// 내부 연산용 단순 P2P (max - min)
  static double _calculateRawP2P(List<double> series) {
    if (series.isEmpty) return 0.0;
    double minVal = series[0];
    double maxVal = series[0];
    for (final val in series) {
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    return maxVal - minVal;
  }

  /// 기존 feature-ui 위젯 및 호환성 유지를 위한 P2P 도출 (반올림 포함)
  static double calculateP2P(List<double> series) {
    return double.parse(_calculateRawP2P(series).toStringAsFixed(2));
  }

  /// 기존 feature-ui A95 도출 호환
  static double calculateA95(List<double> series) {
    if (series.isEmpty) return 0.0;
    final absList = series.map((v) => v.abs()).toList()..sort();
    final idx = (absList.length * 0.95).floor();
    final clampedIdx = idx.clamp(0, absList.length - 1);
    return double.parse(absList[clampedIdx].toStringAsFixed(2));
  }

  /// 최대값 도출 (최대 소음 dBA 등)
  static double calculateMax(List<double> series) {
    if (series.isEmpty) return 0.0;
    double maxVal = series[0];
    for (final val in series) {
      if (val > maxVal) maxVal = val;
    }
    return double.parse(maxVal.toStringAsFixed(2));
  }

  /// 가속도 미분 연산을 통한 저크(Jerk, da/dt) 시계열 배열 산출
  static List<double> calculateJerkSeries(
    List<double> accelSeries, {
    double sampleRate = 256.0,
  }) {
    if (accelSeries.isEmpty) return [];
    final List<double> jerk = [0.0];
    final double dt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 256.0;
    for (int i = 1; i < accelSeries.length; i++) {
      final double da = accelSeries[i] - accelSeries[i - 1];
      jerk.add(double.parse((da / dt).toStringAsFixed(2)));
    }
    return jerk;
  }

  /// 가속도 수치 적분을 통한 속도 시계열 배열 산출 (클램프 제거)
  static List<double> calculateSpeedSeries(
    List<double> accelSeries, {
    double sampleRate = 256.0,
  }) {
    if (accelSeries.isEmpty) return [];
    final List<double> speed = [];
    double currentSpeed = 0.0;
    final double dt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 256.0;
    const double mgToMs2 = 0.00980665;

    for (int i = 0; i < accelSeries.length; i++) {
      currentSpeed += accelSeries[i] * mgToMs2 * dt;
      speed.add(double.parse(currentSpeed.abs().toStringAsFixed(2)));
    }
    return speed;
  }

  /// 속도 수치 적분을 통한 이동 거리 시계열 배열 산출 (m)
  static List<double> calculatePositionSeries(
    List<double> speedSeries, {
    double sampleRate = 256.0,
  }) {
    if (speedSeries.isEmpty) return [];
    final List<double> pos = [];
    double currentPos = 0.0;
    final double dt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 256.0;

    for (int i = 0; i < speedSeries.length; i++) {
      currentPos += speedSeries[i] * dt;
      pos.add(double.parse(currentPos.abs().toStringAsFixed(2)));
    }
    return pos;
  }
}
