import '../measure/sensor_sample.dart';

/// 측정 결과 데이터 모델
/// - 순수 Dart로 작성된 측정 결과 및 시계열 데이터
class MeasurementResult {
  final String id;
  final String jobNo; // 제번
  final String siteName; // 현장명
  final int bottomFloor; // 최하층
  final int topFloor; // 최상층
  final String direction; // 방향
  final DateTime dateTime; // 일시

  final double xPtp; // X 진동 P2P (mg)
  final double yPtp; // Y 진동 P2P (mg)
  final double zPtp; // Z 진동 P2P (mg)
  final double noiseMax; // 소음 최대 (dBA)
  final double distance; // 운행거리 (m)
  final double maxSpeed; // 최대속도 (m/s)

  // 시계열 List들 (mock 또는 실제 파싱 데이터)
  final List<double> xSeries;
  final List<double> ySeries;
  final List<double> zSeries;
  final List<double> noiseSeries;
  final List<double> positionSeries;
  final List<double> speedSeries;
  final List<double> accelSeries;
  final List<double> jerkSeries;

  // Phase 1 확장 필드
  final double sampleRate; // 실측 샘플레이트 (Hz)
  final bool usedDetectedRideSegment; // 주행 자동 검출 성공 여부
  final String constantSpeedRange; // 정속 구간 시간 범위 요약
  final List<SensorSample>? rawSamples; // RAW 데이터 보관 (EVIMP1 저장용)

  const MeasurementResult({
    required this.id,
    required this.jobNo,
    required this.siteName,
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    required this.dateTime,
    required this.xPtp,
    required this.yPtp,
    required this.zPtp,
    required this.noiseMax,
    required this.distance,
    required this.maxSpeed,
    required this.xSeries,
    required this.ySeries,
    required this.zSeries,
    required this.noiseSeries,
    required this.positionSeries,
    required this.speedSeries,
    required this.accelSeries,
    required this.jerkSeries,
    this.sampleRate = 256.0,
    this.usedDetectedRideSegment = true,
    this.constantSpeedRange = '전체 구간',
    this.rawSamples,
  });

  MeasurementResult copyWith({
    String? id,
    String? jobNo,
    String? siteName,
    int? bottomFloor,
    int? topFloor,
    String? direction,
    DateTime? dateTime,
    double? xPtp,
    double? yPtp,
    double? zPtp,
    double? noiseMax,
    double? distance,
    double? maxSpeed,
    List<double>? xSeries,
    List<double>? ySeries,
    List<double>? zSeries,
    List<double>? noiseSeries,
    List<double>? positionSeries,
    List<double>? speedSeries,
    List<double>? accelSeries,
    List<double>? jerkSeries,
    double? sampleRate,
    bool? usedDetectedRideSegment,
    String? constantSpeedRange,
    List<SensorSample>? rawSamples,
  }) {
    return MeasurementResult(
      id: id ?? this.id,
      jobNo: jobNo ?? this.jobNo,
      siteName: siteName ?? this.siteName,
      bottomFloor: bottomFloor ?? this.bottomFloor,
      topFloor: topFloor ?? this.topFloor,
      direction: direction ?? this.direction,
      dateTime: dateTime ?? this.dateTime,
      xPtp: xPtp ?? this.xPtp,
      yPtp: yPtp ?? this.yPtp,
      zPtp: zPtp ?? this.zPtp,
      noiseMax: noiseMax ?? this.noiseMax,
      distance: distance ?? this.distance,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      xSeries: xSeries ?? this.xSeries,
      ySeries: ySeries ?? this.ySeries,
      zSeries: zSeries ?? this.zSeries,
      noiseSeries: noiseSeries ?? this.noiseSeries,
      positionSeries: positionSeries ?? this.positionSeries,
      speedSeries: speedSeries ?? this.speedSeries,
      accelSeries: accelSeries ?? this.accelSeries,
      jerkSeries: jerkSeries ?? this.jerkSeries,
      sampleRate: sampleRate ?? this.sampleRate,
      usedDetectedRideSegment: usedDetectedRideSegment ?? this.usedDetectedRideSegment,
      constantSpeedRange: constantSpeedRange ?? this.constantSpeedRange,
      rawSamples: rawSamples ?? this.rawSamples,
    );
  }

  // 임계 판정 getter (X·Y>10mg, Z>15mg, 소음>50dB -> 초과 시 true)
  bool get xExceeded => xPtp > 10.0;
  bool get yExceeded => yPtp > 10.0;
  bool get zExceeded => zPtp > 15.0;
  bool get noiseExceeded => noiseMax > 50.0;

  /// 화면 예시용 Mock 인스턴스 (문서 요구사항 예시값, OI-1 엔진 실측치와는 다름)
  /// 제번 `2024F 1447R01`, 현장 `럭키종합건설/송정동근생`, 1층→8층
  /// X 8.2mg / Y 12.9mg / Z 22.2mg / 소음 71.7dBA / 21.0m / 1.50m/s
  static MeasurementResult get mock {
    const count = 40;
    final List<double> xList = [];
    final List<double> yList = [];
    final List<double> zList = [];
    final List<double> noiseList = [];
    final List<double> posList = [];
    final List<double> spdList = [];
    final List<double> accList = [];
    final List<double> jrkList = [];

    for (int i = 0; i < count; i++) {
      final t = i / count;
      xList.add(8.2 * (0.5 + 0.5 * ((i % 5) - 2) / 2));
      yList.add(12.9 * (0.6 + 0.4 * (((i + 2) % 4) - 1)));
      zList.add(22.2 * (0.7 + 0.3 * (((i + 1) % 6) - 2) / 2));
      noiseList.add(50.0 + 21.7 * (t < 0.5 ? t * 2 : (1 - t) * 2));
      posList.add(21.0 * t);
      spdList.add(
        1.50 * (t > 0.1 && t < 0.9 ? 1.0 : (t <= 0.1 ? t * 10 : (1 - t) * 10)),
      );
      accList.add(0.5 * ((i % 3) - 1));
      jrkList.add(0.2 * ((i % 5) - 2));
    }

    return MeasurementResult(
      id: '2024F1447R01',
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: 1,
      topFloor: 8,
      direction: '하부 → 상부',
      dateTime: DateTime(2024, 7, 3, 14, 30),
      xPtp: 8.2,
      yPtp: 12.9,
      zPtp: 22.2,
      noiseMax: 71.7,
      distance: 21.0,
      maxSpeed: 1.50,
      xSeries: xList,
      ySeries: yList,
      zSeries: zList,
      noiseSeries: noiseList,
      positionSeries: posList,
      speedSeries: spdList,
      accelSeries: accList,
      jerkSeries: jrkList,
    );
  }

  /// S5 저장 결과 목록용 Mock 데이터 3건 (실제 값 1건 + 변형 2건)
  static List<MeasurementResult> get mockList {
    final base = mock;
    return [
      base,
      // 변형 1: 정상 결과
      MeasurementResult(
        id: '2024F1448R02',
        jobNo: '2024F 1448R02',
        siteName: '현대그린빌/아산건설',
        bottomFloor: -1,
        topFloor: 15,
        direction: '상부 → 하부',
        dateTime: DateTime(2024, 7, 2, 10, 15),
        xPtp: 5.2,
        yPtp: 4.1,
        zPtp: 8.9,
        noiseMax: 45.0,
        distance: 45.0,
        maxSpeed: 2.00,
        xSeries: base.xSeries.map((v) => v * 0.4).toList(),
        ySeries: base.ySeries.map((v) => v * 0.5).toList(),
        zSeries: base.zSeries.map((v) => v * 0.4).toList(),
        noiseSeries: base.noiseSeries.map((v) => v * 0.6).toList(),
        positionSeries: base.positionSeries,
        speedSeries: base.speedSeries,
        accelSeries: base.accelSeries,
        jerkSeries: base.jerkSeries,
      ),
      // 변형 2: X축 및 소음 초과
      MeasurementResult(
        id: '2024F1449R03',
        jobNo: '2024F 1449R03',
        siteName: '삼성타운/강남프라임',
        bottomFloor: 1,
        topFloor: 20,
        direction: '하부 → 상부',
        dateTime: DateTime(2024, 7, 1, 16, 45),
        xPtp: 11.5,
        yPtp: 7.0,
        zPtp: 14.2,
        noiseMax: 52.3,
        distance: 60.0,
        maxSpeed: 2.50,
        xSeries: base.xSeries.map((v) => v * 0.9).toList(),
        ySeries: base.ySeries.map((v) => v * 0.8).toList(),
        zSeries: base.zSeries.map((v) => v * 0.6).toList(),
        noiseSeries: base.noiseSeries.map((v) => v * 0.75).toList(),
        positionSeries: base.positionSeries,
        speedSeries: base.speedSeries,
        accelSeries: base.accelSeries,
        jerkSeries: base.jerkSeries,
      ),
    ];
  }
}
