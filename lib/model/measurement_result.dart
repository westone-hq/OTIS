import 'dart:convert';

import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/sensor_sample.dart';

/// 클래스: MeasurementResult
/// 목적: 진동 분석 엔진이 계산을 마친 최종 측정 결과 데이터를 담는다.
class MeasurementResult {
  /// 결과 식별자
  final String id;

  /// 제번
  final String jobNo;

  /// 현장명
  final String siteName;

  /// 최하층
  final int bottomFloor;

  /// 최상층
  final int topFloor;

  /// 운전 방향
  final String direction;

  /// 엘리베이터 기종 ("Gen2", "기타" 등). null 이면 입력되지 않았다
  final String? model;

  /// 측정 일시
  final DateTime dateTime;

  /// X축 진동 P2P (mg). null 이면 아직 계산하지 않았다 — 진동 필터가
  /// 확정되지 않아 값을 채우지 않는다
  final double? xPtp;

  /// Y축 진동 P2P (mg). null 이면 아직 계산하지 않았다 — `xPtp` 와 같은 이유
  final double? yPtp;

  /// Z축 진동 P2P (mg). null 이면 아직 계산하지 않았다 — `xPtp` 와 같은 이유
  final double? zPtp;

  /// 소음 최대값 (dBA). null 이면 미수집 — 소음 센서 수집 경로가 아직 없다
  final double? noiseMax;

  /// 운행 거리 (m). 방향과 무관한 누적 이동량이다. null 이면 수직
  /// 가속도가 없어 구하지 못했다
  final double? distance;

  /// 최대 속도 (m/s). 속도 절댓값의 최대. null 이면 `distance` 와 같은 이유
  final double? maxSpeed;

  /// 전체 주행 구간 X축 P-P (mg)
  final double fullXPtp;

  /// 전체 주행 구간 Y축 P-P (mg)
  final double fullYPtp;

  /// 전체 주행 구간 Z축 P-P (mg)
  final double fullZPtp;

  /// 정속 구간 X축 P-P (mg)
  final double constantXPtp;

  /// 정속 구간 Y축 P-P (mg)
  final double constantYPtp;

  /// 정속 구간 Z축 P-P (mg)
  final double constantZPtp;

  /// 필터 적용 전 전체 주행 구간 X축 P-P (mg)
  final double preFilterFullXPtp;

  /// 필터 적용 전 전체 주행 구간 Y축 P-P (mg)
  final double preFilterFullYPtp;

  /// 필터 적용 전 전체 주행 구간 Z축 P-P (mg)
  final double preFilterFullZPtp;

  /// 필터 적용 전 정속 구간 X축 P-P (mg)
  final double preFilterConstantXPtp;

  /// 필터 적용 전 정속 구간 Y축 P-P (mg)
  final double preFilterConstantYPtp;

  /// 필터 적용 전 정속 구간 Z축 P-P (mg)
  final double preFilterConstantZPtp;

  // 시계열 목록 (실제 측정 파싱 데이터)
  /// X축 진동 시계열 (mg)
  final List<double> xSeries;

  /// Y축 진동 시계열 (mg)
  final List<double> ySeries;

  /// Z축 진동 시계열 (mg)
  final List<double> zSeries;

  /// 소음 시계열 (dBA)
  final List<double> noiseSeries;

  /// 누적 이동량 시계열 (m). 방향과 무관하게 움직인 거리를 더해 나간 값
  final List<double> positionSeries;

  /// 속도 시계열 (m/s)
  final List<double> speedSeries;

  /// 수직 가속도 시계열 (m/s²). 전체 평균을 뺀 값
  final List<double> accelSeries;

  /// 저크(가속도가 얼마나 빠르게 변하는지) 시계열 (m/s³)
  final List<double> jerkSeries;

  // 분석 상세·진단용 확장 필드 (정속 구간 검출, 실측 샘플레이트 등)
  /// 실측 샘플레이트 (Hz)
  final double sampleRate;

  /// 주행 구간 자동 검출 성공 여부
  final bool usedDetectedRideSegment;

  /// 정속 구간 시간 범위 요약 문구
  final String constantSpeedRange;

  /// 정속 구간 자동 검출 성공 여부
  final bool usedDetectedConstantSpeed;

  /// 정속 구간 샘플 수
  final int constantSpeedSampleCount;

  /// 진동 분석 전체 샘플 수
  final int totalVibrationSampleCount;

  /// 전체 대비 정속 구간 비율 (0~1)
  final double constantSpeedRatio;

  /// 원본 센서 데이터 보관 (EVIMP1, 회사 EVA 진동측정 장비가 쓰는
  /// 표준 데이터 포맷 저장용). 없으면 null
  final List<SensorSample>? rawSamples;

  /// 움직임 미감지 경고 여부
  final bool lowMotionWarning;

  /// 실측 진단용 임시 지표
  final Map<String, double> debugMetrics;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-09-15 14:32:07 · nada
  /// 함수: MeasurementResult
  /// 목적: 측정 결과 값들을 그대로 담는 생성자. 확장 필드는 기본값을 갖는다.
  /// 인자: id — 결과 식별자
  ///       jobNo — 제번
  ///       siteName — 현장명
  ///       bottomFloor — 최하층
  ///       topFloor — 최상층
  ///       direction — 방향
  ///       model — 엘리베이터 기종. 입력되지 않았으면 null
  ///       dateTime — 측정 일시
  ///       xPtp, yPtp, zPtp — 축별 진동 P2P (mg). 필터 미확정이라
  ///       지금은 null
  ///       noiseMax — 소음 최대 (dBA). 수집 경로가 없어 지금은 null
  ///       distance — 운행거리 (m). 방향 무관 누적 이동량
  ///       maxSpeed — 최대속도 (m/s)
  ///       fullXPtp/fullYPtp/fullZPtp — 전체 주행 구간 축별 P-P (mg), 기본 0.0
  ///       constantXPtp/constantYPtp/constantZPtp — 정속 구간 축별 P-P
  ///       (mg), 기본 0.0
  ///       preFilterFullXPtp/preFilterFullYPtp/preFilterFullZPtp — 필터 전
  ///       전체 주행 구간 축별 P-P (mg), 기본 0.0
  ///       preFilterConstantXPtp/preFilterConstantYPtp/preFilterConstantZPtp
  ///       — 필터 전 정속 구간 축별 P-P (mg), 기본 0.0
  ///       xSeries/ySeries/zSeries/noiseSeries/positionSeries/speedSeries/
  ///       accelSeries/jerkSeries — 시계열 데이터 목록
  ///       sampleRate — 실측 샘플레이트 (Hz), 기본 256.0
  ///       usedDetectedRideSegment — 주행 구간 자동 검출 성공 여부, 기본
  ///       false. 검출한 적이 없는데 성공으로 남지 않게 한다
  ///       constantSpeedRange — 정속 구간 시간 범위 요약, 기본 '미검출'
  ///       usedDetectedConstantSpeed — 정속 구간 자동 검출 성공 여부, 기본 false
  ///       constantSpeedSampleCount — 정속 구간 샘플 수, 기본 0
  ///       totalVibrationSampleCount — 진동 분석 전체 샘플 수, 기본 0
  ///       constantSpeedRatio — 전체 대비 정속 구간 비율, 기본 0.0
  ///       rawSamples — 원본 데이터 보관, 없으면 null
  ///       lowMotionWarning — 움직임 미감지 경고 여부, 기본 false
  ///       debugMetrics — 실측 진단용 임시 지표, 기본 빈 Map
  const MeasurementResult({
    required this.id,
    required this.jobNo,
    required this.siteName,
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    this.model,
    required this.dateTime,
    this.xPtp,
    this.yPtp,
    this.zPtp,
    this.noiseMax,
    this.distance,
    this.maxSpeed,
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
    this.usedDetectedRideSegment = false,
    this.constantSpeedRange = '미검출',
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
    String? model,
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
      model: model ?? this.model,
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
      'model': model,
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

  /// 수정: 2026-09-15 13:22:45 · nada
  /// 함수: MeasurementResult.fromMap
  /// 목적: 저장돼 있던 Map 데이터로 측정 결과를 복원한다.
  ///       값이 없는 항목은 기본값으로 채우되, 진동 P2P · 소음 최대 ·
  ///       운행 거리 · 최대 속도는 채우지 않고 null 로 둔다. 재지 않은
  ///       값을 0 으로 채우면 실제 측정값과 구분할 수 없게 된다.
  ///       기종도 같다. 없으면 빈 문자열로 대신하지 않고 null 로 둔다.
  /// 인자: map — 저장돼 있던 Map 데이터
  /// 반환: 복원된 측정 결과
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
      model: map['model'] as String?,
      dateTime: map['dateTime'] != null
          ? DateTime.tryParse(map['dateTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      xPtp: (map['xPtp'] as num?)?.toDouble(),
      yPtp: (map['yPtp'] as num?)?.toDouble(),
      zPtp: (map['zPtp'] as num?)?.toDouble(),
      noiseMax: (map['noiseMax'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
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

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 함수: fromJson
  /// 목적: JSON 문자열을 MeasurementResult 객체로 복원한다.
  /// 인자: source — JSON 형식 문자열
  /// 반환: 복원된 MeasurementResult 객체
  factory MeasurementResult.fromJson(String source) =>
      MeasurementResult.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// 수정: 2026-09-15 20:13:49 · nada
  /// 함수: xExceeded
  /// 목적: X축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.xPtpRedMg`) 초과 시 true. `xPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — 요구사항서 `Vibration_Checking_App_Development_20260630.pdf`
  ///       6쪽 "결과 Report 파일에 포함되어야 하는 정보" 표가 리포트에 실을
  ///       값과 적색 표시 기준을 정했다. 거기서 X축 진동 p2p 의 적색 기준을
  ///       정했고, 황색 단계는 두지 않았다. 요구사항서 자체는
  ///       저장소에 없고, 그 내용은 `pdf_report_dev/README.md` "판정 기준"
  ///       절이 옮겨 적어 두었다
  bool? get xExceeded =>
      ReportThresholds.exceeds(xPtp, ReportThresholds.xPtpRedMg);

  /// 수정: 2026-09-15 20:13:49 · nada
  /// 함수: yExceeded
  /// 목적: Y축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.yPtpRedMg`) 초과 시 true. `yPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — 요구사항서 `Vibration_Checking_App_Development_20260630.pdf`
  ///       6쪽 "결과 Report 파일에 포함되어야 하는 정보" 표가 리포트에 실을
  ///       값과 적색 표시 기준을 정했다. 거기서 Y축 진동 p2p 의 적색 기준을
  ///       정했고, 황색 단계는 두지 않았다. 요구사항서 자체는
  ///       저장소에 없고, 그 내용은 `pdf_report_dev/README.md` "판정 기준"
  ///       절이 옮겨 적어 두었다
  bool? get yExceeded =>
      ReportThresholds.exceeds(yPtp, ReportThresholds.yPtpRedMg);

  /// 수정: 2026-09-15 20:13:49 · nada
  /// 함수: zExceeded
  /// 목적: Z축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.zPtpRedMg`) 초과 시 true. `zPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — 요구사항서 `Vibration_Checking_App_Development_20260630.pdf`
  ///       6쪽 "결과 Report 파일에 포함되어야 하는 정보" 표가 리포트에 실을
  ///       값과 적색 표시 기준을 정했다. 거기서 Z축 진동 p2p 의 적색 기준을
  ///       정했고, 황색 단계는 두지 않았다. 요구사항서 자체는
  ///       저장소에 없고, 그 내용은 `pdf_report_dev/README.md` "판정 기준"
  ///       절이 옮겨 적어 두었다
  bool? get zExceeded =>
      ReportThresholds.exceeds(zPtp, ReportThresholds.zPtpRedMg);

  /// 수정: 2026-09-15 20:13:49 · nada
  /// 함수: noiseExceeded
  /// 목적: 최대 소음이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.noiseMaxRedDba`) 초과 시 true.
  ///       `noiseMax` 가 null 이면 null — 아직 재지 않은 값을 "정상"으로
  ///       보고하지 않기 위해서다
  /// 근거: 인용 — 요구사항서 `Vibration_Checking_App_Development_20260630.pdf`
  ///       6쪽 "결과 Report 파일에 포함되어야 하는 정보" 표가 리포트에 실을
  ///       값과 적색 표시 기준을 정했다. 거기서 최대 소음의 적색 기준을
  ///       정했고, 황색 단계는 두지 않았다. 요구사항서 자체는
  ///       저장소에 없고, 그 내용은 `pdf_report_dev/README.md` "판정 기준"
  ///       절이 옮겨 적어 두었다
  bool? get noiseExceeded =>
      ReportThresholds.exceeds(noiseMax, ReportThresholds.noiseMaxRedDba);
}
