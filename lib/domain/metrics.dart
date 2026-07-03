import 'dart:math' as math;

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

  /// 임계 초과 기준: X·Y > 10mg, Z > 15mg, 소음 > 50dBA
  bool get isExceeded => xExceeded || yExceeded || zExceeded || noiseExceeded;

  factory ThresholdEvaluation.evaluate({
    required double xPtp,
    required double yPtp,
    required double zPtp,
    required double noiseMax,
  }) {
    return ThresholdEvaluation(
      xPtp: xPtp,
      yPtp: yPtp,
      zPtp: zPtp,
      noiseMax: noiseMax,
      xExceeded: xPtp > 10.0,
      yExceeded: yPtp > 10.0,
      zExceeded: zPtp > 15.0,
      noiseExceeded: noiseMax > 50.0,
    );
  }
}

/// 승강기 진동·소음 연산 및 임계 판정 모듈 (ISO 18738 / Otis TUNE 규격 참고)
class VibrationMetrics {
  /// P2P (Peak-to-Peak): 배열 내 최대값과 최소값의 차이 도출
  static double calculateP2P(List<double> series) {
    if (series.isEmpty) return 0.0;
    double minVal = series[0];
    double maxVal = series[0];
    for (final val in series) {
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    return double.parse((maxVal - minVal).toStringAsFixed(2));
  }

  /// A95 (95th Percentile Maximum): 배열 내 절대값 크기 기준 상위 5% (95백분위수) 도출
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
  static List<double> calculateJerkSeries(List<double> accelSeries, {double sampleRate = 256.0}) {
    if (accelSeries.isEmpty) return [];
    final List<double> jerk = [0.0];
    final double dt = 1.0 / sampleRate;
    for (int i = 1; i < accelSeries.length; i++) {
      final double da = accelSeries[i] - accelSeries[i - 1];
      jerk.add(double.parse((da / dt).toStringAsFixed(2)));
    }
    return jerk;
  }

  /// 가속도 수치 적분을 통한 속도 시계열 배열 산출 (mg -> m/s 근사 변환 포함)
  static List<double> calculateSpeedSeries(List<double> accelSeries, {double sampleRate = 256.0}) {
    if (accelSeries.isEmpty) return [];
    final List<double> speed = [];
    double currentSpeed = 0.0;
    final double dt = 1.0 / sampleRate;
    // 1mg = 0.00980665 m/s²
    const double mgToMs2 = 0.00980665;

    for (int i = 0; i < accelSeries.length; i++) {
      currentSpeed += accelSeries[i] * mgToMs2 * dt;
      speed.add(double.parse(math.max(0.0, currentSpeed).toStringAsFixed(2)));
    }
    return speed;
  }

  /// 속도 수치 적분을 통한 이동 거리 시계열 배열 산출 (m)
  static List<double> calculatePositionSeries(List<double> speedSeries, {double sampleRate = 256.0}) {
    if (speedSeries.isEmpty) return [];
    final List<double> pos = [];
    double currentPos = 0.0;
    final double dt = 1.0 / sampleRate;

    for (int i = 0; i < speedSeries.length; i++) {
      currentPos += speedSeries[i] * dt;
      pos.add(double.parse(currentPos.toStringAsFixed(2)));
    }
    return pos;
  }
}
