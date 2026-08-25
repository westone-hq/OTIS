/// 클래스: SensorSample
/// 목적: 1초에 수백 번씩 찍히는 개별 센서 측정치 '한 점'의 데이터를 정의한다.
class SensorSample {
  /// 타임스탬프 (마이크로초 us)
  final int tsUs;

  /// X축 진동값. 중력을 뺀 순가속도 (mg)
  final double x;

  /// Y축 진동값. 중력을 뺀 순가속도 (mg)
  final double y;

  /// Z축 진동값. 중력을 뺀 순가속도 (mg)
  final double z;

  /// X축 가속도 원값. 중력 포함, 없으면 null (mg)
  final double? rawX;

  /// Y축 가속도 원값. 중력 포함, 없으면 null (mg)
  final double? rawY;

  /// Z축 가속도 원값. 중력 포함, 없으면 null (mg)
  final double? rawZ;

  /// X축 중력 추정값, 없으면 null (mg)
  final double? gravityX;

  /// Y축 중력 추정값, 없으면 null (mg)
  final double? gravityY;

  /// Z축 중력 추정값, 없으면 null (mg)
  final double? gravityZ;

  /// 작성: 2026-07-04 10:36:25 · 박건준
  /// 함수: SensorSample
  /// 목적: 센서 측정치 한 점의 값을 그대로 담는 생성자.
  /// 인자: tsUs — 타임스탬프 (마이크로초)
  ///       x, y, z — 세 축 진동값 (mg)
  ///       rawX, rawY, rawZ — 세 축 가속도 원값, 없으면 null (mg)
  ///       gravityX, gravityY, gravityZ — 세 축 중력 추정값, 없으면 null (mg)
  const SensorSample({
    required this.tsUs,
    required this.x,
    required this.y,
    required this.z,
    this.rawX,
    this.rawY,
    this.rawZ,
    this.gravityX,
    this.gravityY,
    this.gravityZ,
  });

  /// 변수: metersPerSecondSquaredToMg
  /// 목적: 안드로이드 기본 가속도 단위(m/s²)를 엘리베이터 업계 표준 진동 단위(mg)로 환산하기 위한 상수
  /// 식: 1 m/s² = (1000 / 9.80665) mg
  /// 근거: 표준 — 국제단위계(SI) 중력가속도 환산 공식
  static const double metersPerSecondSquaredToMg = 101.97162129779283;

  /// 함수: SensorSample.fromMps2
  /// 목적: m/s² 단위로 들어오는 외부 센서 데이터를 앱 내부 표준인 mg 단위로 자동 변환하여 샘플을 생성한다.
  /// 인자: tsUs — 타임스탬프 (마이크로초)
  ///       xMps2, yMps2, zMps2 — 세 축 가속도 값 (m/s²)
  factory SensorSample.fromMps2({
    required int tsUs,
    required double xMps2,
    required double yMps2,
    required double zMps2,
  }) {
    return SensorSample(
      tsUs: tsUs,
      x: xMps2 * metersPerSecondSquaredToMg,
      y: yMps2 * metersPerSecondSquaredToMg,
      z: zMps2 * metersPerSecondSquaredToMg,
    );
  }

  /// 함수: SensorSample.fromMap
  /// 목적: 안드로이드 네이티브(EventChannel)나 JSON 문자열에서 넘어온 Map 데이터를 SensorSample 객체로 조립한다.
  /// 인자: map — 안드로이드 또는 JSON에서 전달받은 Map 데이터
  factory SensorSample.fromMap(Map<dynamic, dynamic> map) {
    final num? ts = map['tsUs'] as num? ?? map['timestamp'] as num?;
    int timestampUs = 0;
    if (ts != null) {
      if (map.containsKey('tsUs')) {
        timestampUs = ts.toInt();
      } else {
        // timestamp 필드의 밀리초(ms) 값을 us로 환산
        timestampUs = (ts.toDouble() * 1000.0).round();
      }
    }
    return SensorSample(
      tsUs: timestampUs,
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      z: (map['z'] as num?)?.toDouble() ?? 0.0,
      rawX: (map['rawX'] as num?)?.toDouble(),
      rawY: (map['rawY'] as num?)?.toDouble(),
      rawZ: (map['rawZ'] as num?)?.toDouble(),
      gravityX: (map['gravityX'] as num?)?.toDouble(),
      gravityY: (map['gravityY'] as num?)?.toDouble(),
      gravityZ: (map['gravityZ'] as num?)?.toDouble(),
    );
  }

  /// 작성: 2026-07-04 10:36:25 · 박건준
  /// 함수: toString
  /// 목적: 로그에서 값을 바로 알아볼 수 있도록 사람이 읽기 좋은
  ///       문자열로 바꾼다.
  /// 반환: "SensorSample(tsUs: ..., x: ... mg, ...)" 형태의 문자열
  @override
  String toString() =>
      'SensorSample(tsUs: $tsUs, x: ${x.toStringAsFixed(2)} mg, y: ${y.toStringAsFixed(2)} mg, z: ${z.toStringAsFixed(2)} mg)';
}
