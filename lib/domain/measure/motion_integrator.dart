import 'sensor_sample.dart';

/// 수직축(Z축) 모션 성분 적분 결과
class IntegrationResult {
  /// 수직축 가속도 시계열 (m/s²) - 모션 성분 변환값
  final List<double> accelSeriesMs2;

  /// 수직축 저크 시계열 (m/s³) - 가속도 미분
  final List<double> jerkSeriesMs3;

  /// 부호 있는 속도 시계열 (m/s)
  final List<double> signedSpeedSeriesMs;

  /// 표시용 속도 시계열 |v| (m/s)
  final List<double> displaySpeedSeriesMs;

  /// 부호 있는 변위 시계열 (m)
  final List<double> signedPositionSeriesM;

  /// 표시용 변위 시계열 |s| (m)
  final List<double> displayPositionSeriesM;

  /// 최대 운행 속도 max|v| (m/s)
  final double maxSpeedMs;

  /// 총 운행 거리 |s(end)| (m)
  final double distanceM;

  const IntegrationResult({
    required this.accelSeriesMs2,
    required this.jerkSeriesMs3,
    required this.signedSpeedSeriesMs,
    required this.displaySpeedSeriesMs,
    required this.signedPositionSeriesM,
    required this.displayPositionSeriesM,
    required this.maxSpeedMs,
    required this.distanceM,
  });

  factory IntegrationResult.empty() => const IntegrationResult(
        accelSeriesMs2: [],
        jerkSeriesMs3: [],
        signedSpeedSeriesMs: [],
        displaySpeedSeriesMs: [],
        signedPositionSeriesM: [],
        displayPositionSeriesM: [],
        maxSpeedMs: 0.0,
        distanceM: 0.0,
      );
}

/// 수직축(Z) 모션 성분 부호 유지 수치 적분기 (속도, 거리, 저크 연산)
class MotionIntegrator {
  /// 모션 신호 배열을 적분하여 속도, 변위 및 미분(저크) 산출
  /// - 클램프(math.max(0, ...)) 제거로 하강 운행 시 음수 속도/변위 정상 허용
  /// - 루프 내 toStringAsFixed 반올림 제거 (고정정밀도 유지)
  static IntegrationResult integrate(
    List<SensorSample> motionSamples, {
    double sampleRate = 256.0,
  }) {
    if (motionSamples.isEmpty) {
      return IntegrationResult.empty();
    }

    final int n = motionSamples.length;
    final List<double> accel = List<double>.filled(n, 0.0);
    final List<double> jerk = List<double>.filled(n, 0.0);
    final List<double> signedSpeed = List<double>.filled(n, 0.0);
    final List<double> displaySpeed = List<double>.filled(n, 0.0);
    final List<double> signedPos = List<double>.filled(n, 0.0);
    final List<double> displayPos = List<double>.filled(n, 0.0);

    final double defaultDt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 256.0;

    // 1. 가속도(m/s²) 변환
    for (int i = 0; i < n; i++) {
      accel[i] =
          motionSamples[i].z * SensorSample.mgToMetersPerSecondSquared;
    }

    // 2. 저크(m/s³) 산출 (가속도 미분)
    jerk[0] = 0.0;
    for (int i = 1; i < n; i++) {
      double dt = (motionSamples[i].tsUs - motionSamples[i - 1].tsUs) / 1000000.0;
      if (dt <= 0.0) dt = defaultDt;
      jerk[i] = (accel[i] - accel[i - 1]) / dt;
    }

    // 3. 속도(m/s) 적분: v[i] = v[i-1] + a[i] * dt (부호 유지, 클램프 없음)
    // 부호 유지 적분: abs 클램프 시 하강 운행에서 속도·거리가 0 고착.
    double maxSpd = 0.0;
    signedSpeed[0] = 0.0;
    displaySpeed[0] = 0.0;

    for (int i = 1; i < n; i++) {
      double dt = (motionSamples[i].tsUs - motionSamples[i - 1].tsUs) / 1000000.0;
      if (dt <= 0.0) dt = defaultDt;
      signedSpeed[i] = signedSpeed[i - 1] + accel[i] * dt;
      final double absSpd = signedSpeed[i].abs();
      displaySpeed[i] = absSpd;
      if (absSpd > maxSpd) {
        maxSpd = absSpd;
      }
    }

    // 4. 변위(m) 적분: s[i] = s[i-1] + v[i] * dt
    signedPos[0] = 0.0;
    displayPos[0] = 0.0;

    for (int i = 1; i < n; i++) {
      double dt = (motionSamples[i].tsUs - motionSamples[i - 1].tsUs) / 1000000.0;
      if (dt <= 0.0) dt = defaultDt;
      signedPos[i] = signedPos[i - 1] + signedSpeed[i] * dt;
      displayPos[i] = signedPos[i].abs();
    }

    final double dist = n > 0 ? displayPos.last : 0.0;

    return IntegrationResult(
      accelSeriesMs2: accel,
      jerkSeriesMs3: jerk,
      signedSpeedSeriesMs: signedSpeed,
      displaySpeedSeriesMs: displaySpeed,
      signedPositionSeriesM: signedPos,
      displayPositionSeriesM: displayPos,
      maxSpeedMs: maxSpd,
      distanceM: dist,
    );
  }
}
