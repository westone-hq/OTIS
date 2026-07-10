/// 측정 엔진 표준 센서 단일 샘플 모델
/// - 가속도 단위: mg (1 m/s² = 101.97 mg)
/// - 소음 단위: dBA
/// - 타임스탬프: 마이크로초(us) 단위 상대 또는 절대 시간
class SensorSample {
  final int tsUs; // 타임스탬프 (마이크로초 us)
  final double x; // X축 linear acceleration (mg)
  final double y; // Y축 linear acceleration (mg)
  final double z; // Z축 linear acceleration (mg)
  final double noiseDba; // 소음 (dBA)
  final double? rawX; // X축 accelerometer 원값 (mg, 중력 포함)
  final double? rawY; // Y축 accelerometer 원값 (mg, 중력 포함)
  final double? rawZ; // Z축 accelerometer 원값 (mg, 중력 포함)
  final double? gravityX; // X축 gravity 추정값 (mg)
  final double? gravityY; // Y축 gravity 추정값 (mg)
  final double? gravityZ; // Z축 gravity 추정값 (mg)

  const SensorSample({
    required this.tsUs,
    required this.x,
    required this.y,
    required this.z,
    required this.noiseDba,
    this.rawX,
    this.rawY,
    this.rawZ,
    this.gravityX,
    this.gravityY,
    this.gravityZ,
  });

  /// develop(m/s²) 모델 및 일반 초/밀리초/마이크로초 단위 변환 상수
  static const double metersPerSecondSquaredToMg =
      101.97162129779283; // 1000 / 9.80665
  static const double mgToMetersPerSecondSquared = 0.00980665;

  /// develop의 SensorSample(DateTime, x, y, z in m/s²) 등에서 변환
  factory SensorSample.fromMps2({
    required int tsUs,
    required double xMps2,
    required double yMps2,
    required double zMps2,
    double noiseDba = 0.0,
  }) {
    return SensorSample(
      tsUs: tsUs,
      x: xMps2 * metersPerSecondSquaredToMg,
      y: yMps2 * metersPerSecondSquaredToMg,
      z: zMps2 * metersPerSecondSquaredToMg,
      noiseDba: noiseDba,
    );
  }

  /// Map(EventChannel 수신 또는 JSON 파싱)에서 변환
  factory SensorSample.fromMap(Map<dynamic, dynamic> map) {
    final num? ts = map['tsUs'] as num? ?? map['timestamp'] as num?;
    int timestampUs = 0;
    if (ts != null) {
      if (map.containsKey('tsUs')) {
        timestampUs = ts.toInt();
      } else {
        // 기존 timestamp 밀리초(ms) 규격을 us로 환산
        timestampUs = (ts.toDouble() * 1000.0).round();
      }
    }
    return SensorSample(
      tsUs: timestampUs,
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      z: (map['z'] as num?)?.toDouble() ?? 0.0,
      noiseDba: (map['noiseDba'] as num?)?.toDouble() ?? 0.0,
      rawX: (map['rawX'] as num?)?.toDouble(),
      rawY: (map['rawY'] as num?)?.toDouble(),
      rawZ: (map['rawZ'] as num?)?.toDouble(),
      gravityX: (map['gravityX'] as num?)?.toDouble(),
      gravityY: (map['gravityY'] as num?)?.toDouble(),
      gravityZ: (map['gravityZ'] as num?)?.toDouble(),
    );
  }

  double get motionX =>
      rawX != null && gravityX != null ? rawX! - gravityX! : x;
  double get motionY =>
      rawY != null && gravityY != null ? rawY! - gravityY! : y;
  double get motionZ =>
      rawZ != null && gravityZ != null ? rawZ! - gravityZ! : z;

  /// 기존 feature-ui 호환용 timestamp(ms) 게터
  double get timestamp => tsUs / 1000.0;

  /// 초 단위 상대 타임스탬프 (s)
  double get timestampSec => tsUs / 1000000.0;

  @override
  String toString() =>
      'SensorSample(tsUs: $tsUs, x: ${x.toStringAsFixed(2)} mg, y: ${y.toStringAsFixed(2)} mg, z: ${z.toStringAsFixed(2)} mg, noise: ${noiseDba.toStringAsFixed(1)} dBA)';
}
