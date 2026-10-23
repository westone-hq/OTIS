import 'dart:convert';

import 'package:vibration_checker/domain/analysis/device_response.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';

/// 작성: 2026-07-03 15:21:58 · 박건준
/// 수정: 2026-10-22 15:00:00 · 박건준
/// 클래스: MeasurementResult
/// 목적: 측정 한 건을 리포트 · 목록 · 메일이 읽는 형태로 담는다.
///       `MeasurementAssembler` 가 격자 환산 결과에서 만들고,
///       `MeasurementRepository` 가 JSON 파일로 저장 · 복원한다.
class MeasurementResult {
  /// 결과 식별자
  final String id;

  /// 제번
  final String jobNo;

  /// 현장명
  final String siteName;

  /// 현장 주소. 입력하지 않았거나 주소를 받기 전의 측정이면 빈 문자열
  final String address;

  /// 최하층
  final int bottomFloor;

  /// 최상층
  final int topFloor;

  /// 운전 방향
  final String direction;

  /// 엘리베이터 기종 ("Gen2", "기타" 등). null 이면 입력되지 않았다
  final String? model;

  /// 하중. 입력한 숫자 그대로이고 단위는 `loadUnit` 이다 — 환산하지
  /// 않는다. null 이면 하중을 받기 전의 예전 측정이다
  final double? load;

  /// 하중 단위. 새 결과는 늘 `SiteInfo.loadUnit`("kg")이다. 단위를 고를 수
  /// 있던 빌드(2026-10-11 ~ 10-13)로 저장한 결과는 "lb" 일 수 있다. null
  /// 이면 `load` 와 같은 이유
  final String? loadUnit;

  /// 해석 종류 (`SiteInfo.analysisTypeOptions` 가운데 하나, 예: "층간 시험").
  /// null 이면 해석 종류를 받기 전의 예전 측정이다
  final String? analysisType;

  /// 우편번호 (숫자 5자리 문자열). null 이면 우편번호를 받기 전의 예전
  /// 측정이다
  final String? postalCode;

  /// 추가 참고사항. 메일 본문에만 쓰고 리포트에는 찍지 않는다. 비워
  /// 두었거나 예전 측정이면 null
  final String? notes;

  /// 측정을 저장할 때 로그인해 있던 작업자의 성명. 리포트 엔지니어 칸에
  /// 찍힌다. 나중에 다른 사람이 로그인해도 이 값은 바뀌지 않는다.
  /// 로그인이 생기기 전(2026-10-18 전) 결과는 설정에 손으로 적은 이름이고,
  /// 그때 설정이 비어 있었거나 더 예전 측정이면 null
  final String? engineerName;

  /// 측정을 저장할 때 로그인해 있던 작업자의 사번. 로그인이 생기기 전
  /// (2026-10-18 전) 결과면 null
  final String? employeeId;

  /// 측정을 저장할 때 로그인해 있던 작업자의 업체명. 명단에 업체가 비어
  /// 있는 작업자(OTIS 직원)이거나 2026-10-18 전 결과면 null
  final String? company;

  /// 측정을 저장할 때 로그인해 있던 작업자의 관리팀. null 의 뜻은
  /// `company` 와 같다
  final String? team;

  /// 측정 일시
  final DateTime dateTime;

  /// X축 진동 최대 P2P (mg). 운행 구간(`travelWindow`) 안에서 가중
  /// (`RideWeighting`)한 시계열의 반주기 P2P 가운데 가장 큰 값이다.
  /// 가중 · 운행 구간이 들어가기 전(2026-10-15 전) 결과는 시계열 전체의
  /// 최대 − 최소이고, 신호 처리(`signalConditioning`)가 null 인 더 예전
  /// 결과는 처리 전 256Hz 원시 시계열의 값이다. null 이면 계산하지 않았거나
  /// 운행 구간을 정하지 못한 측정이다
  final double? xPtp;

  /// Y축 진동 최대 P2P (mg). 정의와 null 의 뜻은 `xPtp` 와 같다
  final double? yPtp;

  /// Z축 진동 최대 P2P (mg). 2026-10-21 부터는 정속 구간(`motionZones`)
  /// 안 최대 반주기 P2P 다 — OTIS 리포트 수직 `a_z,ptp` 와 같은 정의다.
  /// 처리 방식에 `+zones(` 가 없는 그 전 결과는 운행 구간 전체의 최대이고,
  /// 그보다 예전 정의와 null 의 뜻은 `xPtp` 와 같다. 정속 구간을 정하지
  /// 못한 결과(`motionZonesFailure`)도 null 이다. 가중 전 예전 결과에는
  /// 엘리베이터 가감속이 섞여 있다
  final double? zPtp;

  /// Z축 가감속 구간 최대 P2P (mg). 정속 구간을 뺀 운행(출발 · 도착
  /// 가감속) 안 최대 반주기 P2P 로, OTIS 리포트 수직 차트의 `a_z,Jptp` 다.
  /// 리포트 2쪽 수직 차트에만 적고 1쪽 표에는 올리지 않는다. null 이면
  /// 2026-10-21 전 결과이거나 구간을 정하지 못했다
  final double? zJptp;

  /// `zPtp` 가 나온 순간의 위치 (m, 하부층 정지레벨 기준). 리포트 1쪽
  /// 수직 최대가 황색 · 적색일 때 문구에 쓴다. null 의 뜻은 `zJptp` 와 같다
  final double? zPtpPositionM;

  /// X축 진동 A95 (mg). `xPtp` 와 같은 반주기 P2P 값들의 95백분위다.
  /// null 이면 계산하지 않은 예전 측정이거나, 반주기가 두 개도 안 되거나,
  /// 운행 구간을 정하지 못한 측정이다
  final double? xA95;

  /// Y축 진동 A95 (mg). 정의와 null 의 뜻은 `xA95` 와 같다
  final double? yA95;

  /// Z축 진동 A95 (mg). 정의와 null 의 뜻은 `xA95` 와 같다
  final double? zA95;

  /// 소음 최대값 (dBA). 운행 구간(`travelWindow`) 안에서 0(미측정)을 뺀
  /// 최대다. 운행 구간이 들어가기 전 결과는 측정 전체의 최대다. null 이면
  /// 잴 수 있는 표본이 없었거나(마이크 권한 없음) 운행 구간을 정하지 못했다
  final double? noiseMax;

  /// 운행 거리 (m). 방향과 무관한 누적 이동량이다. null 이면 수직
  /// 가속도가 없어 구하지 못했다
  final double? distance;

  /// 최대 속도 (m/s). 속도 절댓값의 최대. null 이면 `distance` 와 같은 이유
  final double? maxSpeed;

  /// X축 진동 시계열 (mg). 지표를 낸 그 시계열이다 — 2026-10-15 부터는
  /// Wd 가중 뒤 값이고, 그 전 결과는 가중 전 값이다
  final List<double> xSeries;

  /// Y축 진동 시계열 (mg). `xSeries` 와 같다
  final List<double> ySeries;

  /// Z축 진동 시계열 (mg). 2026-10-15 부터는 1Hz 고역 + Wk 가중 뒤
  /// 값이라 가감속 경사가 없다. 가감속은 `accelSeries` 에 있다. 2026-10-22
  /// 부터는 보정 표에 있는 기종이면 그 뒤에 기종 응답 보정(양방향 저역,
  /// `DeviceResponse`, `deviceCompensation`)까지 건 값이다
  final List<double> zSeries;

  /// 소음 시계열 (dBA)
  final List<double> noiseSeries;

  /// 위치 시계열 (m). 2026-10-21 부터는 하부층 정지레벨 기준이라 상승은
  /// 0 → 운행 거리, 하강은 운행 거리 → 0 이다(OTIS 리포트 3쪽과 같다). 그
  /// 전 결과는 방향과 무관하게 움직인 거리를 더해 나간 값(늘 0 에서 오름)
  /// 이다. 운행 거리는 `distance` 가 따로 갖는다
  final List<double> positionSeries;

  /// 속도 시계열 (m/s). 부호 그대로다 — 위로 움직이면 양수, 아래로
  /// 움직이면 음수
  final List<double> speedSeries;

  /// 수직 가속도 시계열 (m/s²). 리포트 3쪽 차트에 그리는 값이다 — 움직인
  /// 구간 평균(치우침)을 빼고 10Hz 저역을 양방향으로 건 값이다
  /// (`CaptureConfig.accelChartLowpassHz`). 처리 방식에 `+acc(` 가 없는
  /// 2026-10-21 전 결과는 거르지 않은 가속도다
  final List<double> accelSeries;

  /// 저크(가속도가 얼마나 빠르게 변하는지) 시계열 (m/s³). 처리 방식에
  /// `+jerk(` 가 있으면 1.6Hz 저역 가속도를 미분한 값이고, 없는 2026-10-21 전
  /// 결과는 거르지 않은 가속도를 미분해 수십 배 크다
  final List<double> jerkSeries;

  /// 실측 샘플레이트 (Hz)
  final double sampleRate;

  /// 지표를 낸 처리 방식. `SignalConditioner.methodLabel` 뒤에
  /// `RideWeighting.methodLabel` · `DeviceResponse.methodLabel()` ·
  /// `Kinematics` 의 적분 · 저크 · 차트 가속도 표시 · `MotionZones.methodLabel`
  /// · `noiseMethodLabel()` 을 `+` 로 잇는다(`MeasurementRecorder.record()`,
  /// 조각 뜻은 `docs/spec/signal_processing.md`). 예전 결과는 앞 조각만
  /// 있다(예: `baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)`). null 이면 이
  /// 처리가 들어가기 전의 예전 측정이라 지표가 처리 전 원시 시계열에서
  /// 나왔다. 화면에는 보이지 않는다
  final String? signalConditioning;

  /// 진동 · 소음 지표를 낸 운행 구간. 정하지 못했으면(`travelWindowFailure`)
  /// 이나 운행 구간이 들어가기 전(2026-10-15 전) 예전 결과면 null
  final TravelWindow? travelWindow;

  /// 운행 구간을 정하지 못한 사유. 그때 진동 · 소음 지표는 null 이다.
  /// 구간을 정했거나 예전 결과면 null
  final String? travelWindowFailure;

  /// 수직 진동을 나눈 정속 · 가감속 구간(`MotionZones.of()`). 정하지
  /// 못했으면(`motionZonesFailure`) 이나 2026-10-21 전 결과면 null
  final MotionZones? motionZones;

  /// 정속 · 가감속 구간을 정하지 못한 사유. 그때 `zPtp` · `zJptp` 는
  /// null 이다. 정했거나 예전 결과면 null
  final String? motionZonesFailure;

  /// 측정할 때의 거치 방향(`Placement.name`, 예: "faceDown"). 수집 처음
  /// 1초의 중력 Z 평균으로 판정한다(`PlacementMonitor`). null 이면 판정하기
  /// 전(2026-10-22 전) 결과이거나 측정이 1초보다 짧았다
  final String? placement;

  /// 거치 방향 판정에 쓴 중력 Z 평균 (mg). null 의 뜻은 `placement` 와 같다
  final double? placementGravityZMg;

  /// 정속 구간(`motionZones`) 평균 속도 크기 (m/s). 화면 · 리포트에 보이지
  /// 않고, OTIS 최대 속도 표시 규칙을 다른 정격 속도 현장에서 견줄 때 쓰려고
  /// 남긴다(2026-10-22). null 이면 정속 구간을 정하지 못했거나 그 전 결과다
  final double? steadySpeedMps;

  /// 측정한 휴대폰 제조사(안드로이드 `Build.MANUFACTURER`, 예: "samsung").
  /// null 이면 2026-10-22 전 결과, 외부 기록(오티스폰 EVIMP1)이거나 정지
  /// 응답을 받지 못했다
  final String? deviceManufacturer;

  /// 측정한 휴대폰 기종 이름(안드로이드 `Build.MODEL`, 예: "SM-S901N").
  /// 기종 응답 보정(`DeviceResponse`)을 고르는 열쇠다. null 의 뜻은
  /// `deviceManufacturer` 와 같다
  final String? deviceModel;

  /// 수직 진동에 건 기종 응답 보정 필터 표시(예: "lp25.0bw2zp"). 보정 표에
  /// 없는 기종이면 `DeviceResponse.noneLabel`("none") — 결과 화면 · 메일이
  /// "미보정 기종" 으로 알린다. null 이면 보정을 정하기 전(2026-10-22 전)
  /// 결과다
  final String? deviceCompensation;

  /// 운행 끝(속도 크기가 `CaptureConfig.zoneRunSpeedMps` 를 넘은 마지막
  /// 행)부터 기록 끝까지의 시간 (초). `CaptureConfig.minimumStopMarginMs`
  /// 보다 짧으면 결과 화면이 "정지 후 1초 이상 기다린 뒤 종료" 를 알린다.
  /// null 이면 움직임이 없었거나 그 전 결과다
  final double? stopMarginSec;

  /// 가감속 구간(Jptp)을 운행 끝 뒤로 넓힐 때 기록 끝에 막혀 넓힐 수 있는
  /// 데까지만 썼는지. null 이면 정속 구간을 정하지 못했거나 그 전 결과다
  final bool? zJptpClippedAtEnd;

  /// 신호 처리 기준선을 어디서 냈는지(`BaselineSource.name`). null 이면
  /// 2026-10-22 전 결과다(늘 처음 1초)
  final String? baselineSource;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: MeasurementResult
  /// 목적: 측정 결과 값들을 그대로 담는 생성자.
  /// 인자: id — 결과 식별자
  ///       jobNo — 제번
  ///       siteName — 현장명
  ///       address — 현장 주소. 안 주면 빈 문자열
  ///       bottomFloor — 최하층
  ///       topFloor — 최상층
  ///       direction — 방향
  ///       model — 엘리베이터 기종. 입력되지 않았으면 null
  ///       load — 하중 (입력 숫자, 단위는 loadUnit). 예전 측정이면 null
  ///       loadUnit — 하중 단위. 예전 측정이면 null
  ///       analysisType — 해석 종류. 예전 측정이면 null
  ///       postalCode — 우편번호 (숫자 5자리). 예전 측정이면 null
  ///       notes — 추가 참고사항. 비웠거나 예전 측정이면 null
  ///       engineerName — 저장 시점 엔지니어 이름(로그인 작업자 성명).
  ///       없으면 null
  ///       employeeId, company, team — 저장 시점 로그인 작업자의 사번 ·
  ///       업체명 · 관리팀. 없으면 null
  ///       dateTime — 측정 일시
  ///       xPtp, yPtp, zPtp — 축별 진동 P2P (mg). 계산하지 않은 예전
  ///       측정이면 null
  ///       xA95, yA95, zA95 — 축별 진동 A95 (mg). 계산하지 않았으면 null
  ///       noiseMax — 소음 최대 (dBA). 잴 수 있는 표본이 없으면 null
  ///       distance — 운행거리 (m). 방향 무관 누적 이동량
  ///       maxSpeed — 최대속도 (m/s)
  ///       xSeries/ySeries/zSeries/noiseSeries/positionSeries/speedSeries/
  ///       accelSeries/jerkSeries — 시계열 데이터 목록
  ///       sampleRate — 실측 샘플레이트 (Hz), 기본 256.0
  ///       signalConditioning — 지표 계산 전 신호 처리 방식. 처리 전
  ///       예전 측정이면 null
  ///       travelWindow — 지표를 낸 운행 구간. 없으면 null
  ///       travelWindowFailure — 운행 구간을 정하지 못한 사유. 없으면 null
  ///       zJptp — 수직 가감속 구간 최대 P2P (mg). 없으면 null
  ///       zPtpPositionM — 수직 최대가 나온 위치 (m). 없으면 null
  ///       motionZones — 정속 · 가감속 구간. 없으면 null
  ///       motionZonesFailure — 그 구간을 정하지 못한 사유. 없으면 null
  ///       placement — 거치 방향 이름. 없으면 null
  ///       placementGravityZMg — 판정에 쓴 중력 Z 평균 (mg). 없으면 null
  ///       steadySpeedMps — 정속 구간 평균 속도 크기 (m/s). 없으면 null
  ///       deviceManufacturer, deviceModel — 측정한 휴대폰 제조사 · 기종
  ///       이름. 없으면 null
  ///       deviceCompensation — 기종 응답 보정 표시. 없으면 null
  ///       stopMarginSec — 운행 끝부터 기록 끝까지 (초). 없으면 null
  ///       zJptpClippedAtEnd — Jptp 넓힘이 기록 끝에 막혔는지. 없으면 null
  ///       baselineSource — 기준선 출처 이름. 없으면 null
  const MeasurementResult({
    required this.id,
    required this.jobNo,
    required this.siteName,
    this.address = '',
    required this.bottomFloor,
    required this.topFloor,
    required this.direction,
    this.model,
    this.load,
    this.loadUnit,
    this.analysisType,
    this.postalCode,
    this.notes,
    this.engineerName,
    this.employeeId,
    this.company,
    this.team,
    required this.dateTime,
    this.xPtp,
    this.yPtp,
    this.zPtp,
    this.xA95,
    this.yA95,
    this.zA95,
    this.noiseMax,
    this.distance,
    this.maxSpeed,
    required this.xSeries,
    required this.ySeries,
    required this.zSeries,
    required this.noiseSeries,
    required this.positionSeries,
    required this.speedSeries,
    required this.accelSeries,
    required this.jerkSeries,
    this.sampleRate = 256.0,
    this.signalConditioning,
    this.travelWindow,
    this.travelWindowFailure,
    this.zJptp,
    this.zPtpPositionM,
    this.motionZones,
    this.motionZonesFailure,
    this.placement,
    this.placementGravityZMg,
    this.steadySpeedMps,
    this.deviceManufacturer,
    this.deviceModel,
    this.deviceCompensation,
    this.stopMarginSec,
    this.zJptpClippedAtEnd,
    this.baselineSource,
  });

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: copyWith
  /// 목적: 일부 값만 바꾼 사본을 만든다. 넘기지 않은 값은 이 결과의 값을
  ///       그대로 쓴다. 값을 null 로 되돌리는 데는 쓸 수 없다 — null 을
  ///       넘기면 "바꾸지 않음"으로 읽힌다.
  /// 인자: 생성자 `MeasurementResult` 와 같다. 모두 생략할 수 있다
  /// 반환: 새 측정 결과
  MeasurementResult copyWith({
    String? id,
    String? jobNo,
    String? siteName,
    String? address,
    int? bottomFloor,
    int? topFloor,
    String? direction,
    String? model,
    double? load,
    String? loadUnit,
    String? analysisType,
    String? postalCode,
    String? notes,
    String? engineerName,
    String? employeeId,
    String? company,
    String? team,
    DateTime? dateTime,
    double? xPtp,
    double? yPtp,
    double? zPtp,
    double? xA95,
    double? yA95,
    double? zA95,
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
    String? signalConditioning,
    TravelWindow? travelWindow,
    String? travelWindowFailure,
    double? zJptp,
    double? zPtpPositionM,
    MotionZones? motionZones,
    String? motionZonesFailure,
    String? placement,
    double? placementGravityZMg,
    double? steadySpeedMps,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceCompensation,
    double? stopMarginSec,
    bool? zJptpClippedAtEnd,
    String? baselineSource,
  }) {
    return MeasurementResult(
      id: id ?? this.id,
      jobNo: jobNo ?? this.jobNo,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      bottomFloor: bottomFloor ?? this.bottomFloor,
      topFloor: topFloor ?? this.topFloor,
      direction: direction ?? this.direction,
      model: model ?? this.model,
      load: load ?? this.load,
      loadUnit: loadUnit ?? this.loadUnit,
      analysisType: analysisType ?? this.analysisType,
      postalCode: postalCode ?? this.postalCode,
      notes: notes ?? this.notes,
      engineerName: engineerName ?? this.engineerName,
      employeeId: employeeId ?? this.employeeId,
      company: company ?? this.company,
      team: team ?? this.team,
      dateTime: dateTime ?? this.dateTime,
      xPtp: xPtp ?? this.xPtp,
      yPtp: yPtp ?? this.yPtp,
      zPtp: zPtp ?? this.zPtp,
      xA95: xA95 ?? this.xA95,
      yA95: yA95 ?? this.yA95,
      zA95: zA95 ?? this.zA95,
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
      signalConditioning: signalConditioning ?? this.signalConditioning,
      travelWindow: travelWindow ?? this.travelWindow,
      travelWindowFailure: travelWindowFailure ?? this.travelWindowFailure,
      zJptp: zJptp ?? this.zJptp,
      zPtpPositionM: zPtpPositionM ?? this.zPtpPositionM,
      motionZones: motionZones ?? this.motionZones,
      motionZonesFailure: motionZonesFailure ?? this.motionZonesFailure,
      placement: placement ?? this.placement,
      placementGravityZMg: placementGravityZMg ?? this.placementGravityZMg,
      steadySpeedMps: steadySpeedMps ?? this.steadySpeedMps,
      deviceManufacturer: deviceManufacturer ?? this.deviceManufacturer,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceCompensation: deviceCompensation ?? this.deviceCompensation,
      stopMarginSec: stopMarginSec ?? this.stopMarginSec,
      zJptpClippedAtEnd: zJptpClippedAtEnd ?? this.zJptpClippedAtEnd,
      baselineSource: baselineSource ?? this.baselineSource,
    );
  }

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: toMap
  /// 목적: 저장용 표로 바꾼다. 날짜는 ISO 8601(국제 표준 날짜 · 시각 표기)
  ///       문자열로, 재지 않은 값은 null 그대로 둔다.
  ///       `MeasurementResult.fromMap` 이 이 표를 되읽는다.
  /// 반환: 필드 이름을 열쇠로 하는 표
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobNo': jobNo,
      'siteName': siteName,
      'address': address,
      'bottomFloor': bottomFloor,
      'topFloor': topFloor,
      'direction': direction,
      'model': model,
      'load': load,
      'loadUnit': loadUnit,
      'analysisType': analysisType,
      'postalCode': postalCode,
      'notes': notes,
      'engineerName': engineerName,
      'employeeId': employeeId,
      'company': company,
      'team': team,
      'dateTime': dateTime.toIso8601String(),
      'xPtp': xPtp,
      'yPtp': yPtp,
      'zPtp': zPtp,
      'xA95': xA95,
      'yA95': yA95,
      'zA95': zA95,
      'noiseMax': noiseMax,
      'distance': distance,
      'maxSpeed': maxSpeed,
      'sampleRate': sampleRate,
      'signalConditioning': signalConditioning,
      'travelWindow': travelWindow?.toMap(),
      'travelWindowFailure': travelWindowFailure,
      'zJptp': zJptp,
      'zPtpPositionM': zPtpPositionM,
      'motionZones': motionZones?.toMap(),
      'motionZonesFailure': motionZonesFailure,
      'placement': placement,
      'placementGravityZMg': placementGravityZMg,
      'steadySpeedMps': steadySpeedMps,
      'deviceManufacturer': deviceManufacturer,
      'deviceModel': deviceModel,
      'deviceCompensation': deviceCompensation,
      'stopMarginSec': stopMarginSec,
      'zJptpClippedAtEnd': zJptpClippedAtEnd,
      'baselineSource': baselineSource,
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

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 수정: 2026-10-23 11:00:00 · 박건준
  /// 함수: MeasurementResult.fromMap
  /// 목적: 저장돼 있던 Map 데이터로 측정 결과를 복원한다. 예전 파일에 남은
  ///       옛 정속 구간 자리(2026-10-04 에 지운 필드) · 진단용 열쇠는 읽지
  ///       않고 넘긴다.
  ///       값이 없는 항목은 기본값으로 채우되, 진동 P2P · 소음 최대 ·
  ///       운행 거리 · 최대 속도는 채우지 않고 null 로 둔다. 재지 않은
  ///       값을 0 으로 채우면 실제 측정값과 구분할 수 없게 된다.
  ///       기종도 같다. 없으면 빈 문자열로 대신하지 않고 null 로 둔다.
  ///       신호 처리 방식도 같다. 이 필드가 생기기 전의 파일이면 null 로
  ///       남겨 처리 전 측정임을 드러낸다.
  ///       하중 · 하중 단위 · 해석 종류 · 우편번호 · 참고사항 · 엔지니어
  ///       이름도 같다. 2026-10-11 이전 파일에는 없어 null 로 읽는다.
  ///       사번 · 업체명 · 관리팀도 같다. 2026-10-18 이전 파일에는 없다.
  ///       운행 구간 · 그 실패 사유도 같다. 2026-10-15 이전 파일에는 없다.
  ///       수직 가감속 최대 · 최대 위치 · 정속 구간 · 그 실패 사유도 같다.
  ///       2026-10-21 이전 파일에는 없다. 거치 방향 · 그 중력 Z 평균도 같다.
  ///       2026-10-22 이전 파일에는 없다. 정속 구간 평균 속도 · 휴대폰
  ///       제조사 · 기종 · 기종 응답 보정 · 정지 뒤 여유 · Jptp 넓힘 막힘 ·
  ///       기준선 출처도 같다.
  ///       측정 일시는 채우지 않는다 — 없거나 읽을 수 없으면 "지금" 으로
  ///       대신하지 않고 실패를 올린다. 대신 넣으면 예전 결과가 방금 잰
  ///       것처럼 보이고 목록 차례도 틀어진다(관통 원칙 1 · 4).
  /// 인자: map — 저장돼 있던 Map 데이터
  /// 반환: 복원된 측정 결과. 측정 일시가 없거나 읽을 수 없으면
  ///       `FormatException`
  factory MeasurementResult.fromMap(Map<String, dynamic> map) {
    List<double> toDoubleList(dynamic list) {
      if (list == null) return [];
      return (list as List).map((e) => (e as num).toDouble()).toList();
    }

    return MeasurementResult(
      id: map['id'] as String? ?? '',
      jobNo: map['jobNo'] as String? ?? '',
      siteName: map['siteName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      bottomFloor: map['bottomFloor'] as int? ?? 1,
      topFloor: map['topFloor'] as int? ?? 1,
      direction: map['direction'] as String? ?? '',
      model: map['model'] as String?,
      load: (map['load'] as num?)?.toDouble(),
      loadUnit: map['loadUnit'] as String?,
      analysisType: map['analysisType'] as String?,
      postalCode: map['postalCode'] as String?,
      notes: map['notes'] as String?,
      engineerName: map['engineerName'] as String?,
      employeeId: map['employeeId'] as String?,
      company: map['company'] as String?,
      team: map['team'] as String?,
      // → 로직 이동: _dateTimeOf()
      dateTime: _dateTimeOf(map['dateTime']),
      xPtp: (map['xPtp'] as num?)?.toDouble(),
      yPtp: (map['yPtp'] as num?)?.toDouble(),
      zPtp: (map['zPtp'] as num?)?.toDouble(),
      xA95: (map['xA95'] as num?)?.toDouble(),
      yA95: (map['yA95'] as num?)?.toDouble(),
      zA95: (map['zA95'] as num?)?.toDouble(),
      noiseMax: (map['noiseMax'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
      sampleRate: (map['sampleRate'] as num?)?.toDouble() ?? 256.0,
      signalConditioning: map['signalConditioning'] as String?,
      travelWindow: map['travelWindow'] is Map<String, dynamic>
          // → 로직 이동: TravelWindow.fromMap()
          ? TravelWindow.fromMap(map['travelWindow'] as Map<String, dynamic>)
          : null,
      travelWindowFailure: map['travelWindowFailure'] as String?,
      zJptp: (map['zJptp'] as num?)?.toDouble(),
      zPtpPositionM: (map['zPtpPositionM'] as num?)?.toDouble(),
      motionZones: map['motionZones'] is Map<String, dynamic>
          // → 로직 이동: MotionZones.fromMap()
          ? MotionZones.fromMap(map['motionZones'] as Map<String, dynamic>)
          : null,
      motionZonesFailure: map['motionZonesFailure'] as String?,
      placement: map['placement'] as String?,
      placementGravityZMg: (map['placementGravityZMg'] as num?)?.toDouble(),
      steadySpeedMps: (map['steadySpeedMps'] as num?)?.toDouble(),
      deviceManufacturer: map['deviceManufacturer'] as String?,
      deviceModel: map['deviceModel'] as String?,
      deviceCompensation: map['deviceCompensation'] as String?,
      stopMarginSec: (map['stopMarginSec'] as num?)?.toDouble(),
      zJptpClippedAtEnd: map['zJptpClippedAtEnd'] as bool?,
      baselineSource: map['baselineSource'] as String?,
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: _dateTimeOf
  /// 목적: 저장된 측정 일시를 읽는다.
  /// 인자: raw — 저장된 값 (ISO 8601 문자열). 없으면 null
  /// 반환: 측정 일시. 없거나 읽을 수 없으면 `FormatException`
  static DateTime _dateTimeOf(Object? raw) {
    if (raw == null) throw const FormatException('측정 일시(dateTime)가 없다');
    final parsed = DateTime.tryParse(raw.toString()); // 읽은 일시, 못 읽으면 null
    if (parsed == null) {
      throw FormatException('측정 일시(dateTime)를 읽을 수 없다', raw.toString());
    }
    return parsed;
  }

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 함수: fromJson
  /// 목적: JSON 문자열을 MeasurementResult 객체로 복원한다.
  /// 인자: source — JSON 형식 문자열
  /// 반환: 복원된 MeasurementResult 객체
  factory MeasurementResult.fromJson(String source) =>
      MeasurementResult.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: xExceeded
  /// 목적: X축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.xPtpRedMg`) 초과 시 true. `xPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — `ReportThresholds` 의 적색 기준(2026-10-15 사용자
  ///       지시, 원본 TUNE 리포트 서식의 적색 값). 리포트 신호등은
  ///       황색 단계도 보지만 이 게터는 적색 초과만 알린다
  bool? get xExceeded =>
      ReportThresholds.exceeds(xPtp, ReportThresholds.xPtpRedMg);

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: yExceeded
  /// 목적: Y축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.yPtpRedMg`) 초과 시 true. `yPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — `ReportThresholds` 의 적색 기준(2026-10-15 사용자
  ///       지시, 원본 TUNE 리포트 서식의 적색 값). 리포트 신호등은
  ///       황색 단계도 보지만 이 게터는 적색 초과만 알린다
  bool? get yExceeded =>
      ReportThresholds.exceeds(yPtp, ReportThresholds.yPtpRedMg);

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: zExceeded
  /// 목적: Z축 진동이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.zPtpRedMg`) 초과 시 true. `zPtp` 가 null 이면
  ///       null — 아직 재지 않은 값을 "정상"으로 보고하지 않기 위해서다
  /// 근거: 인용 — `ReportThresholds` 의 적색 기준(2026-10-15 사용자
  ///       지시, 원본 TUNE 리포트 서식의 적색 값). 리포트 신호등은
  ///       황색 단계도 보지만 이 게터는 적색 초과만 알린다
  bool? get zExceeded =>
      ReportThresholds.exceeds(zPtp, ReportThresholds.zPtpRedMg);

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: noiseExceeded
  /// 목적: 최대 소음이 위험 기준치를 넘었는지 확인한다. 기준 숫자는
  ///       여기 적지 않고 `ReportThresholds` 에서 가져온다 — 저장소
  ///       안에서 기준이 적힌 곳을 한 군데로 두기 위해서다.
  /// 반환: 기준치(`ReportThresholds.noiseMaxRedDba`) 초과 시 true.
  ///       `noiseMax` 가 null 이면 null — 아직 재지 않은 값을 "정상"으로
  ///       보고하지 않기 위해서다
  /// 근거: 인용 — `ReportThresholds` 의 적색 기준(2026-10-15 사용자
  ///       지시, 원본 TUNE 리포트 서식의 적색 값). 리포트 신호등은
  ///       황색 단계도 보지만 이 게터는 적색 초과만 알린다
  bool? get noiseExceeded =>
      ReportThresholds.exceeds(noiseMax, ReportThresholds.noiseMaxRedDba);

  /// 작성: 2026-10-22 09:30:00 · 박건준
  /// 함수: placementKind
  /// 목적: 저장된 거치 방향 이름을 `Placement` 로 바꾼다.
  /// 반환: 거치 방향. 판정하지 않은 예전 결과면 null
  Placement? get placementKind =>
      // → 로직 이동: Placement.fromName()
      Placement.fromName(placement);

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: uncompensatedDevice
  /// 목적: 보정 표에 없는 기종(또는 기종을 모르는 측정)이라 기종 응답 보정을
  ///       걸지 않았는지. 결과 화면 · 메일이 "미보정 기종" 을 알린다. 보정을
  ///       정하기 전(2026-10-22 전) 결과는 false 다.
  bool get uncompensatedDevice =>
      deviceCompensation == DeviceResponse.noneLabel;

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: stoppedTooSoon
  /// 목적: 운행 끝 뒤 `CaptureConfig.minimumStopMarginMs` 를 못 채우고 측정을
  ///       끝냈는지. 결과 화면이 "정지 후 1초 이상 기다린 뒤 종료" 를 알린다.
  ///       여유를 모르는 결과(움직임 없음 · 그 전 결과)는 false 다.
  bool get stoppedTooSoon {
    final margin = stopMarginSec; // 정지 뒤 여유 (초), 없으면 null
    return margin != null && margin * 1000 < CaptureConfig.minimumStopMarginMs;
  }

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: baselineContaminated
  /// 목적: 기준선 구간이 움직임에 섞였는데 줄이거나 끝 정지 구간으로 옮기지
  ///       못했는지(`BaselineSource.contaminated`). 결과 화면이 "시작 후 2초
  ///       기다린 뒤 출발" 을 알린다.
  bool get baselineContaminated =>
      baselineSource == BaselineSource.contaminated.name;
}
