import 'dart:convert';
import 'package:vibration_checker/model/sensor_sample.dart';

/// 목적: 진동 분석 엔진이 계산을 마친 최종 결과(성적표) 데이터를 담는다.
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
  final double fullXPtp; // 전체 주행 구간 X P-P (mg)
  final double fullYPtp; // 전체 주행 구간 Y P-P (mg)
  final double fullZPtp; // 전체 주행 구간 Z P-P (mg)
  final double constantXPtp; // 정속 구간 X P-P (mg)
  final double constantYPtp; // 정속 구간 Y P-P (mg)
  final double constantZPtp; // 정속 구간 Z P-P (mg)
  final double preFilterFullXPtp; // 필터 전 전체 주행 구간 X P-P (mg)
  final double preFilterFullYPtp; // 필터 전 전체 주행 구간 Y P-P (mg)
  final double preFilterFullZPtp; // 필터 전 전체 주행 구간 Z P-P (mg)
  final double preFilterConstantXPtp; // 필터 전 정속 구간 X P-P (mg)
  final double preFilterConstantYPtp; // 필터 전 정속 구간 Y P-P (mg)
  final double preFilterConstantZPtp; // 필터 전 정속 구간 Z P-P (mg)

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
  final bool usedDetectedConstantSpeed; // 정속 구간 자동 검출 성공 여부
  final int constantSpeedSampleCount; // 정속 구간 샘플 수
  final int totalVibrationSampleCount; // 진동 분석 전체 샘플 수
  final double constantSpeedRatio; // 전체 대비 정속 구간 비율
  final List<SensorSample>? rawSamples; // RAW 데이터 보관 (EVIMP1 저장용)
  final bool lowMotionWarning; // 움직임 미감지 경고 플래그
  final Map<String, double> debugMetrics; // 실측 진단용 임시 지표

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
    this.fullXPtp = 0.0,
    this.fullYPtp = 0.0,
    this.fullZPtp = 0.0,
    this.constantXPtp = 0.0,
    this.constantYPtp = 0.0,
    this.constantZPtp = 0.0,
    this.preFilterFullXPtp = 0.0,
    this.preFilterFullYPtp = 0.0,
    this.preFilterFullZPtp = 0.0,
    this.preFilterConstantXPtp = 0.0,
    this.preFilterConstantYPtp = 0.0,
    this.preFilterConstantZPtp = 0.0,
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
    this.usedDetectedConstantSpeed = false,
    this.constantSpeedSampleCount = 0,
    this.totalVibrationSampleCount = 0,
    this.constantSpeedRatio = 0.0,
    this.rawSamples,
    this.lowMotionWarning = false,
    this.debugMetrics = const {},
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
    double? fullXPtp,
    double? fullYPtp,
    double? fullZPtp,
    double? constantXPtp,
    double? constantYPtp,
    double? constantZPtp,
    double? preFilterFullXPtp,
    double? preFilterFullYPtp,
    double? preFilterFullZPtp,
    double? preFilterConstantXPtp,
    double? preFilterConstantYPtp,
    double? preFilterConstantZPtp,
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
    bool? usedDetectedConstantSpeed,
    int? constantSpeedSampleCount,
    int? totalVibrationSampleCount,
    double? constantSpeedRatio,
    List<SensorSample>? rawSamples,
    bool? lowMotionWarning,
    Map<String, double>? debugMetrics,
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
      fullXPtp: fullXPtp ?? this.fullXPtp,
      fullYPtp: fullYPtp ?? this.fullYPtp,
      fullZPtp: fullZPtp ?? this.fullZPtp,
      constantXPtp: constantXPtp ?? this.constantXPtp,
      constantYPtp: constantYPtp ?? this.constantYPtp,
      constantZPtp: constantZPtp ?? this.constantZPtp,
      preFilterFullXPtp: preFilterFullXPtp ?? this.preFilterFullXPtp,
      preFilterFullYPtp: preFilterFullYPtp ?? this.preFilterFullYPtp,
      preFilterFullZPtp: preFilterFullZPtp ?? this.preFilterFullZPtp,
      preFilterConstantXPtp:
          preFilterConstantXPtp ?? this.preFilterConstantXPtp,
      preFilterConstantYPtp:
          preFilterConstantYPtp ?? this.preFilterConstantYPtp,
      preFilterConstantZPtp:
          preFilterConstantZPtp ?? this.preFilterConstantZPtp,
      xSeries: xSeries ?? this.xSeries,
      ySeries: ySeries ?? this.ySeries,
      zSeries: zSeries ?? this.zSeries,
      noiseSeries: noiseSeries ?? this.noiseSeries,
      positionSeries: positionSeries ?? this.positionSeries,
      speedSeries: speedSeries ?? this.speedSeries,
      accelSeries: accelSeries ?? this.accelSeries,
      jerkSeries: jerkSeries ?? this.jerkSeries,
      sampleRate: sampleRate ?? this.sampleRate,
      usedDetectedRideSegment:
          usedDetectedRideSegment ?? this.usedDetectedRideSegment,
      constantSpeedRange: constantSpeedRange ?? this.constantSpeedRange,
      usedDetectedConstantSpeed:
          usedDetectedConstantSpeed ?? this.usedDetectedConstantSpeed,
      constantSpeedSampleCount:
          constantSpeedSampleCount ?? this.constantSpeedSampleCount,
      totalVibrationSampleCount:
          totalVibrationSampleCount ?? this.totalVibrationSampleCount,
      constantSpeedRatio: constantSpeedRatio ?? this.constantSpeedRatio,
      rawSamples: rawSamples ?? this.rawSamples,
      lowMotionWarning: lowMotionWarning ?? this.lowMotionWarning,
      debugMetrics: debugMetrics ?? this.debugMetrics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobNo': jobNo,
      'siteName': siteName,
      'bottomFloor': bottomFloor,
      'topFloor': topFloor,
      'direction': direction,
      'dateTime': dateTime.toIso8601String(),
      'xPtp': xPtp,
      'yPtp': yPtp,
      'zPtp': zPtp,
      'noiseMax': noiseMax,
      'distance': distance,
      'maxSpeed': maxSpeed,
      'fullXPtp': fullXPtp,
      'fullYPtp': fullYPtp,
      'fullZPtp': fullZPtp,
      'constantXPtp': constantXPtp,
      'constantYPtp': constantYPtp,
      'constantZPtp': constantZPtp,
      'preFilterFullXPtp': preFilterFullXPtp,
      'preFilterFullYPtp': preFilterFullYPtp,
      'preFilterFullZPtp': preFilterFullZPtp,
      'preFilterConstantXPtp': preFilterConstantXPtp,
      'preFilterConstantYPtp': preFilterConstantYPtp,
      'preFilterConstantZPtp': preFilterConstantZPtp,
      'sampleRate': sampleRate,
      'usedDetectedRideSegment': usedDetectedRideSegment,
      'constantSpeedRange': constantSpeedRange,
      'usedDetectedConstantSpeed': usedDetectedConstantSpeed,
      'constantSpeedSampleCount': constantSpeedSampleCount,
      'totalVibrationSampleCount': totalVibrationSampleCount,
      'constantSpeedRatio': constantSpeedRatio,
      'lowMotionWarning': lowMotionWarning,
      'debugMetrics': debugMetrics,
      'xSeries': xSeries,
      'ySeries': ySeries,
      'zSeries': zSeries,
      'noiseSeries': noiseSeries,
      'positionSeries': positionSeries,
      'speedSeries': speedSeries,
      'accelSeries': accelSeries,
      'jerkSeries': jerkSeries,
    };
  }

  factory MeasurementResult.fromMap(Map<String, dynamic> map) {
    List<double> toDoubleList(dynamic list) {
      if (list == null) return [];
      return (list as List).map((e) => (e as num).toDouble()).toList();
    }

    return MeasurementResult(
      id: map['id'] as String? ?? '',
      jobNo: map['jobNo'] as String? ?? '',
      siteName: map['siteName'] as String? ?? '',
      bottomFloor: map['bottomFloor'] as int? ?? 1,
      topFloor: map['topFloor'] as int? ?? 1,
      direction: map['direction'] as String? ?? '',
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      xPtp: (map['xPtp'] as num?)?.toDouble() ?? 0.0,
      yPtp: (map['yPtp'] as num?)?.toDouble() ?? 0.0,
      zPtp: (map['zPtp'] as num?)?.toDouble() ?? 0.0,
      noiseMax: (map['noiseMax'] as num?)?.toDouble() ?? 0.0,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble() ?? 0.0,
      fullXPtp: (map['fullXPtp'] as num?)?.toDouble() ?? 0.0,
      fullYPtp: (map['fullYPtp'] as num?)?.toDouble() ?? 0.0,
      fullZPtp: (map['fullZPtp'] as num?)?.toDouble() ?? 0.0,
      constantXPtp: (map['constantXPtp'] as num?)?.toDouble() ?? 0.0,
      constantYPtp: (map['constantYPtp'] as num?)?.toDouble() ?? 0.0,
      constantZPtp: (map['constantZPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterFullXPtp: (map['preFilterFullXPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterFullYPtp: (map['preFilterFullYPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterFullZPtp: (map['preFilterFullZPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterConstantXPtp:
          (map['preFilterConstantXPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterConstantYPtp:
          (map['preFilterConstantYPtp'] as num?)?.toDouble() ?? 0.0,
      preFilterConstantZPtp:
          (map['preFilterConstantZPtp'] as num?)?.toDouble() ?? 0.0,
      sampleRate: (map['sampleRate'] as num?)?.toDouble() ?? 256.0,
      usedDetectedRideSegment: map['usedDetectedRideSegment'] as bool? ?? true,
      constantSpeedRange: map['constantSpeedRange'] as String? ?? '전체 구간',
      usedDetectedConstantSpeed:
          map['usedDetectedConstantSpeed'] as bool? ?? false,
      constantSpeedSampleCount:
          (map['constantSpeedSampleCount'] as num?)?.toInt() ?? 0,
      totalVibrationSampleCount:
          (map['totalVibrationSampleCount'] as num?)?.toInt() ?? 0,
      constantSpeedRatio:
          (map['constantSpeedRatio'] as num?)?.toDouble() ?? 0.0,
      lowMotionWarning: map['lowMotionWarning'] as bool? ?? false,
      debugMetrics:
          (map['debugMetrics'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0.0),
          ) ??
          const {},
      xSeries: toDoubleList(map['xSeries']),
      ySeries: toDoubleList(map['ySeries']),
      zSeries: toDoubleList(map['zSeries']),
      noiseSeries: toDoubleList(map['noiseSeries']),
      positionSeries: toDoubleList(map['positionSeries']),
      speedSeries: toDoubleList(map['speedSeries']),
      accelSeries: toDoubleList(map['accelSeries']),
      jerkSeries: toDoubleList(map['jerkSeries']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MeasurementResult.fromJson(String source) =>
      MeasurementResult.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// 목적: X축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(10.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get xExceeded => xPtp > 10.0;
  
  /// 목적: Y축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(10.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get yExceeded => yPtp > 10.0;
  
  /// 목적: Z축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(15.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get zExceeded => zPtp > 15.0;
  
  /// 목적: 최대 소음이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(50.0dBA) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get noiseExceeded => noiseMax > 50.0;

  /// 목적: UI 화면 디자인 및 테스트를 위한 가상의 측정 결과 데이터를 생성한다.
  ///       실제 센서 측정 없이도 그래프와 결과 화면이 잘 뜨는지 확인하기 위해 쓴다.
  /// 인자: 없음
  /// 반환: 가상의 파동 데이터와 진폭이 채워진 MeasurementResult 객체
  /// 근거: 미정 — UI 테스트용 임시 데이터
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
      fullXPtp: 12.0,
      fullYPtp: 16.4,
      fullZPtp: 28.5,
      constantXPtp: 8.2,
      constantYPtp: 12.9,
      constantZPtp: 22.2,
      preFilterFullXPtp: 14.2,
      preFilterFullYPtp: 18.6,
      preFilterFullZPtp: 34.0,
      preFilterConstantXPtp: 10.1,
      preFilterConstantYPtp: 15.2,
      preFilterConstantZPtp: 28.8,
      xSeries: xList,
      ySeries: yList,
      zSeries: zList,
      noiseSeries: noiseList,
      positionSeries: posList,
      speedSeries: spdList,
      accelSeries: accList,
      jerkSeries: jrkList,
      constantSpeedRange: '2.1초 ~ 16.8초',
      usedDetectedConstantSpeed: true,
      constantSpeedSampleCount: 3200,
      totalVibrationSampleCount: 4200,
      constantSpeedRatio: 3200 / 4200,
    );
  }

  /// 목적: 과거 측정 이력 화면(리스트)을 테스트하기 위한 가상의 결과 목록을 생성한다.
  /// 인자: 없음
  /// 반환: 3개의 가상 측정 결과를 담은 목록
  /// 근거: 미정 — UI 테스트용 임시 데이터
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
        fullXPtp: 6.1,
        fullYPtp: 5.0,
        fullZPtp: 10.2,
        constantXPtp: 5.2,
        constantYPtp: 4.1,
        constantZPtp: 8.9,
        preFilterFullXPtp: 7.3,
        preFilterFullYPtp: 6.0,
        preFilterFullZPtp: 13.1,
        preFilterConstantXPtp: 6.2,
        preFilterConstantYPtp: 5.0,
        preFilterConstantZPtp: 11.0,
        xSeries: base.xSeries.map((v) => v * 0.4).toList(),
        ySeries: base.ySeries.map((v) => v * 0.5).toList(),
        zSeries: base.zSeries.map((v) => v * 0.4).toList(),
        noiseSeries: base.noiseSeries.map((v) => v * 0.6).toList(),
        positionSeries: base.positionSeries,
        speedSeries: base.speedSeries,
        accelSeries: base.accelSeries,
        jerkSeries: base.jerkSeries,
        constantSpeedRange: '1.8초 ~ 22.4초',
        usedDetectedConstantSpeed: true,
        constantSpeedSampleCount: 4100,
        totalVibrationSampleCount: 5200,
        constantSpeedRatio: 4100 / 5200,
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
        fullXPtp: 18.3,
        fullYPtp: 9.2,
        fullZPtp: 17.1,
        constantXPtp: 11.5,
        constantYPtp: 7.0,
        constantZPtp: 14.2,
        preFilterFullXPtp: 22.0,
        preFilterFullYPtp: 11.0,
        preFilterFullZPtp: 21.3,
        preFilterConstantXPtp: 14.8,
        preFilterConstantYPtp: 9.2,
        preFilterConstantZPtp: 18.5,
        xSeries: base.xSeries.map((v) => v * 0.9).toList(),
        ySeries: base.ySeries.map((v) => v * 0.8).toList(),
        zSeries: base.zSeries.map((v) => v * 0.6).toList(),
        noiseSeries: base.noiseSeries.map((v) => v * 0.75).toList(),
        positionSeries: base.positionSeries,
        speedSeries: base.speedSeries,
        accelSeries: base.accelSeries,
        jerkSeries: base.jerkSeries,
        constantSpeedRange: '2.0초 ~ 28.7초',
        usedDetectedConstantSpeed: true,
        constantSpeedSampleCount: 5300,
        totalVibrationSampleCount: 6800,
        constantSpeedRatio: 5300 / 6800,
      ),
    ];
  }
}
