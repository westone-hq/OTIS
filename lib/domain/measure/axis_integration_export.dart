import 'sensor_sample.dart';

/// raw.txt 검증용 축별 적분 중간값 (한 샘플)
class AxisIntegrationRow {
  final double motionX;
  final double motionY;
  final double motionZ;
  final double velocityX;
  final double velocityY;
  final double velocityZ;
  final double distanceX;
  final double distanceY;
  final double distanceZ;

  const AxisIntegrationRow({
    required this.motionX,
    required this.motionY,
    required this.motionZ,
    required this.velocityX,
    required this.velocityY,
    required this.velocityZ,
    required this.distanceX,
    required this.distanceY,
    required this.distanceZ,
  });

  static const zero = AxisIntegrationRow(
    motionX: 0,
    motionY: 0,
    motionZ: 0,
    velocityX: 0,
    velocityY: 0,
    velocityZ: 0,
    distanceX: 0,
    distanceY: 0,
    distanceZ: 0,
  );
}

/// raw.txt 내보내기 전용 X/Y/Z 축별 motion·속도·거리 적분
///
/// - 기존 [MotionIntegrator.integrate] 및 최종 거리·속도 결과와 분리
/// - 사다리꼴 적분 사용
/// - 새 측정마다 [compute] 호출 시 속도·거리는 0에서 시작
class AxisIntegrationExport {
  /// 비정상 dt(초) 상한 — 이보다 크면 해당 구간 적분 건너뜀
  static const double maxValidDtSec = 1.0;

  static List<AxisIntegrationRow> compute(List<SensorSample> samples) {
    if (samples.isEmpty) return [];

    final rows = List<AxisIntegrationRow>.filled(
      samples.length,
      AxisIntegrationRow.zero,
    );

    double velX = 0, velY = 0, velZ = 0;
    double distX = 0, distY = 0, distZ = 0;
    double prevAccelX = 0, prevAccelY = 0, prevAccelZ = 0;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final motionX = s.motionX;
      final motionY = s.motionY;
      final motionZ = s.motionZ;

      final accelX = motionX * SensorSample.mgToMetersPerSecondSquared;
      final accelY = motionY * SensorSample.mgToMetersPerSecondSquared;
      final accelZ = motionZ * SensorSample.mgToMetersPerSecondSquared;

      if (i == 0) {
        prevAccelX = accelX;
        prevAccelY = accelY;
        prevAccelZ = accelZ;
        rows[i] = AxisIntegrationRow(
          motionX: motionX,
          motionY: motionY,
          motionZ: motionZ,
          velocityX: 0,
          velocityY: 0,
          velocityZ: 0,
          distanceX: 0,
          distanceY: 0,
          distanceZ: 0,
        );
        continue;
      }

      double dt =
          (samples[i].tsUs - samples[i - 1].tsUs) / 1000000.0;
      final bool validDt = dt > 0 && dt <= maxValidDtSec;

      if (validDt) {
        velX += (prevAccelX + accelX) * 0.5 * dt;
        velY += (prevAccelY + accelY) * 0.5 * dt;
        velZ += (prevAccelZ + accelZ) * 0.5 * dt;

        final prevVelX = rows[i - 1].velocityX;
        final prevVelY = rows[i - 1].velocityY;
        final prevVelZ = rows[i - 1].velocityZ;

        distX += (prevVelX + velX) * 0.5 * dt;
        distY += (prevVelY + velY) * 0.5 * dt;
        distZ += (prevVelZ + velZ) * 0.5 * dt;
      } else {
        // dt 비정상: 속도·거리는 이전 값 유지
        velX = rows[i - 1].velocityX;
        velY = rows[i - 1].velocityY;
        velZ = rows[i - 1].velocityZ;
        distX = rows[i - 1].distanceX;
        distY = rows[i - 1].distanceY;
        distZ = rows[i - 1].distanceZ;
      }

      prevAccelX = accelX;
      prevAccelY = accelY;
      prevAccelZ = accelZ;

      rows[i] = AxisIntegrationRow(
        motionX: motionX,
        motionY: motionY,
        motionZ: motionZ,
        velocityX: velX,
        velocityY: velY,
        velocityZ: velZ,
        distanceX: distX,
        distanceY: distY,
        distanceZ: distZ,
      );
    }

    return rows;
  }
}
