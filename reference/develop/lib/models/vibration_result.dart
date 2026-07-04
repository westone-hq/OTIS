class AxisRideResult {
  const AxisRideResult({
    required this.maxPeakToPeak,
    required this.a95PeakToPeak,
  });

  final double maxPeakToPeak;
  final double a95PeakToPeak;

  double get maxPeakToPeakMg => VibrationResult.toMg(maxPeakToPeak);
  double get a95PeakToPeakMg => VibrationResult.toMg(a95PeakToPeak);
}

class VibrationResult {
  const VibrationResult({
    required this.sampleCount,
    required this.reportSampleCount,
    required this.usedDetectedRideSegment,
    required this.reportDurationSeconds,
    required this.xRide,
    required this.yRide,
    required this.zRide,
    required this.xPeakToPeak,
    required this.yPeakToPeak,
    required this.zPeakToPeak,
    required this.totalVibrationPeakToPeak,
    required this.rms,
    required this.a95,
    required this.maxVibration,
    required this.suspectedImpactSampleCount,
    required this.constantSpeedCandidateSampleCount,
  });

  static const double metersPerSecondSquaredToMg = 101.97;

  final int sampleCount;
  final int reportSampleCount;
  final bool usedDetectedRideSegment;
  final double reportDurationSeconds;
  final AxisRideResult xRide;
  final AxisRideResult yRide;
  final AxisRideResult zRide;
  final double xPeakToPeak;
  final double yPeakToPeak;
  final double zPeakToPeak;
  final double totalVibrationPeakToPeak;
  final double rms;
  final double a95;
  final double maxVibration;
  final int suspectedImpactSampleCount;
  final int constantSpeedCandidateSampleCount;

  double get xPeakToPeakMg => toMg(xPeakToPeak);
  double get yPeakToPeakMg => toMg(yPeakToPeak);
  double get zPeakToPeakMg => toMg(zPeakToPeak);
  double get totalVibrationPeakToPeakMg => toMg(totalVibrationPeakToPeak);
  double get rmsMg => toMg(rms);
  double get a95Mg => toMg(a95);
  double get maxVibrationMg => toMg(maxVibration);

  bool get isXWarning => xRide.a95PeakToPeakMg > 10;
  bool get isYWarning => yRide.a95PeakToPeakMg > 10;
  bool get isZWarning => zRide.a95PeakToPeakMg > 15;

  String get overallGrade {
    final worst = [
      xRide.a95PeakToPeakMg / 10,
      yRide.a95PeakToPeakMg / 10,
      zRide.a95PeakToPeakMg / 15,
    ].reduce((a, b) => a > b ? a : b);

    if (worst < 0.8) {
      return '?묓샇';
    }
    if (worst < 1.5) {
      return '二쇱쓽';
    }
    return '?먭? ?꾩슂';
  }

  static double toMg(double value) {
    return value * metersPerSecondSquaredToMg;
  }
}
