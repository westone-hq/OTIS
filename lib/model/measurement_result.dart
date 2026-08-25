import 'dart:convert';
import 'package:vibration_checker/model/sensor_sample.dart';

/// 클래스: MeasurementResult
/// 목적: 진동 분석 엔진이 계산을 마친 최종 측정 결과 데이터를 담는다.
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

  // 분석 상세·진단용 확장 필드 (정속 구간 검출, 실측 샘플레이트 등)
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

  factory MeasurementResult.fromJson(String source) =>
      MeasurementResult.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// 함수: xExceeded
  /// 목적: X축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(10.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get xExceeded => xPtp > 10.0;

  /// 함수: yExceeded
  /// 목적: Y축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(10.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get yExceeded => yPtp > 10.0;

  /// 함수: zExceeded
  /// 목적: Z축 진동이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(15.0mg) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get zExceeded => zPtp > 15.0;

  /// 함수: noiseExceeded
  /// 목적: 최대 소음이 위험 기준치를 넘었는지 확인한다.
  /// 반환: 기준치(50.0dBA) 초과 시 true
  /// 근거: 측정 — 기준 초과 알림 로직
  bool get noiseExceeded => noiseMax > 50.0;
}
