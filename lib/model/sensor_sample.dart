/// 목적: 1초에 수백 번씩 찍히는 개별 센서 측정치 '한 점'의 데이터를 정의한다.
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

  /// 목적: 안드로이드 기본 가속도 단위(m/s²)를 엘리베이터 업계 표준 진동 단위(mg)로 환산하기 위한 상수
  /// 식: 1 m/s² = (1000 / 9.80665) mg
  /// 근거: 표준 — 국제단위계(SI) 중력가속도 환산 공식
  static const double metersPerSecondSquaredToMg = 101.97162129779283; 
  
  /// 목적: 엘리베이터 업계 표준 진동 단위(mg)를 안드로이드 기본 가속도 단위(m/s²)로 환산하기 위한 상수
  /// 식: 1 mg = (9.80665 / 1000) m/s²
  /// 근거: 표준 — 국제단위계(SI) 중력가속도 환산 공식
  static const double mgToMetersPerSecondSquared = 0.00980665;

  /// 목적: m/s² 단위로 들어오는 외부 센서 데이터를 앱 내부 표준인 mg 단위로 자동 변환하여 샘플을 생성한다.
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

  /// 목적: 안드로이드 네이티브(EventChannel)나 JSON 문자열에서 넘어온 Map 데이터를 SensorSample 객체로 조립한다.
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

  /// 목적: 구형 UI 코드와의 호환성을 위해 마이크로초(us)를 밀리초(ms)로 환산하여 반환한다.
  double get timestamp => tsUs / 1000.0;

  /// 목적: 계산의 편의를 위해 마이크로초(us)를 초(s) 단위로 환산하여 반환한다.
  double get timestampSec => tsUs / 1000000.0;

  @override
  String toString() =>
      'SensorSample(tsUs: $tsUs, x: ${x.toStringAsFixed(2)} mg, y: ${y.toStringAsFixed(2)} mg, z: ${z.toStringAsFixed(2)} mg, noise: ${noiseDba.toStringAsFixed(1)} dBA)';
}
