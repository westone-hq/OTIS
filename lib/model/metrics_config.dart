/// 축별 진동 성분을 걸러내는 수학 필터 종류
enum VibrationFilterType {
  /// 목적: 특정 주파수 구간만 통과시키는 필터다.
  butterworthBandLimit,

  /// 목적: 국제 표준(ISO)에 맞춰 좌우(수평) 흔들림의 잡음을 걸러내는 필터다.
  isoWdWeighting,

  /// 목적: 국제 표준(ISO)에 맞춰 위아래(수직) 덜컹거림의 잡음을 걸러내는 필터다.
  isoWkWeighting,
}

/// 현재 상태: 이 파일의 값은 분석 계층(필터, 최대 진폭 산출, 판정)에서 쓸
/// 설정이며, 현재 어느 곳에서도 사용되지 않는다.
/// 값의 근거가 검증되지 않았다. 분석 계층을 구현할 때 각 값을 다시 확인해야 한다.
/// 확인된 불일치: vibrationLowpassCutoffHz 의 값이 축별 값(X/Y, Z)과 어긋난다.
/// 필드별 근거 표기가 하나도 없다. 클래스 레벨의 한 줄(ISO 8041 및 사내 기준)로
/// 모든 값을 덮고 있어, 어느 값이 표준에서 왔고 어느 값이 임의로 정해진 것인지
/// 구분할 수 없다. 따라서 이 값을 정해진 값으로 취급하지 않는다.
/// 확인된 문제: (1) 축 무관 필터 필드(vibrationHighpassCutoffHz, vibrationLowpassCutoffHz)의
/// 기본값이 축별 필드의 기본값과 서로 다르다. 축별 값이 도입되기 전의 값이
/// 남아 있는 것이며, 해당 필드의 주석은 축별 값을 설명하고 있어 코드와도
/// 어긋난다. 현재 어느 필드도 사용되지 않으므로 동작에는 영향이 없다.
/// 분석 계층 구현 시 축 무관 필드를 없애고 축별 필드만 남길지 결정한다.
/// (2) 판정 임계값 xyThresholdMg / zThresholdMg / noiseThresholdDba 가 참조
/// 장비 출력물의 기준과 다르다. 분석 계층 구현 시 참조 출력물과 대조해 다시 정한다.
///
/// 목적: 측정 엔진에서 사용하는 필터, 윈도우, 임계값 파라미터를 통합 관리하는 설정 클래스.
///       모든 기준 수치는 이 파일에서만 관리되어야 하며, 다른 파일에 직접 숫자를 적는 것을 금지한다.
/// 근거: 표준 — ISO 8041 규격 및 사내 엘리베이터 결함 검증 기준
///
/// [주의] Wk/Wd 필터 상수(12.5Hz, 2.0Hz, 0.63 등)는 임의로 바꾸지 않는다.
/// 이 값들은 ISO 8041(진동 측정 표준) 규격에 명시된 값이라고 기존 주석에 적혀 있다.
class MetricsConfig {
  /// 목적: 측정 시작 초반의 불안정한 구간을 0점(기준선)으로 잡기 위한 시간이다.
  final double baselineSec;

  /// 목적: 엘리베이터의 순수 이동 궤적(motion)을 분리하기 위한 저역통과 기준 주파수다.
  final double motionLowpassCutoffHz;

  /// 목적: 저주파 진동을 제외하는 하한 주파수다.
  final double vibrationHighpassCutoffHz;
  final double vibrationHighpassCutoffHzX;
  final double vibrationHighpassCutoffHzY;
  final double vibrationHighpassCutoffHzZ;

  /// 목적: 고주파 진동을 제외하는 상한 주파수다.
  final double vibrationLowpassCutoffHz;
  final double vibrationLowpassCutoffHzX;
  final double vibrationLowpassCutoffHzY;
  final double vibrationLowpassCutoffHzZ;

  /// 목적: 축별로 적용할 진동 필터 종류다.
  final VibrationFilterType vibrationFilterTypeX;
  final VibrationFilterType vibrationFilterTypeY;
  final VibrationFilterType vibrationFilterTypeZ;

  /// 목적: Z축 가속도를 속도·변위로 변환할 때 쓰는 특성 주파수다 (Wk 공식).
  final double wkTransitionHz;

  /// 목적: Z축 가속도-속도 변환 곡선의 완만함 비율(Q)이다.
  final double wkTransitionQ;

  /// 목적: Z축에서 특정 대역을 증폭하는 저역 한계 주파수다.
  final double wkUpwardStepHz;

  /// 목적: Z축 증폭 대역의 고역 한계 주파수다.
  final double wkUpwardStepHighHz;

  /// 목적: Z축 증폭 곡선의 완만함 비율(Q)이다.
  final double wkUpwardStepQ;

  /// 목적: X/Y축 가속도를 속도·변위로 변환할 때 쓰는 특성 주파수다 (Wd 공식).
  final double wdTransitionHz;

  /// 목적: X/Y축 가속도-속도 변환 곡선의 완만함 비율(Q)이다.
  final double wdTransitionQ;

  /// 목적: 주행 상태로 판단하는 최소 속도 기준이다.
  final double rideSpeedThreshold;

  /// 목적: 주행 시작·종료 시점의 데이터 유실을 막기 위해 분석 구간 앞뒤에 두는 여유 시간이다.
  final double rideActivityPaddingSec;

  /// 목적: 유효한 측정으로 인정하는 최소 주행 유지 시간이다.
  final double minRideDurationSec;

  /// 목적: 정속 구간을 추출하는 기준이 되는, 최고 속도 대비 도달 비율이다.
  final double constantSpeedRatio;

  /// 목적: 최대 진폭(P2P, 구간 내 최댓값과 최솟값의 차) 산출에 쓰는 슬라이딩 윈도우 크기다.
  final double aptpWindowSec;
  final double aptpWindowSecX;
  final double aptpWindowSecY;
  final double aptpWindowSecZ;

  /// 목적: 최대 진폭 대표값(A95, 구간별 값을 정렬해 상위 5퍼센트를 제외한 대표값)을
  ///       구하는 백분위수다.
  final double aptpPercentile;

  /// 목적: 좌우(X/Y축) 진동의 불량 판정 기준치다.
  final double xyThresholdMg;

  /// 목적: 상하(Z축) 진동의 불량 판정 기준치다.
  final double zThresholdMg;

  /// 목적: 실내 소음(dBA, 사람 귀의 감도를 반영한 소음 단위)의 불량 판정 기준치다.
  final double noiseThresholdDba;

  /// 목적: 기기 센서 소음값(dBFS, 기기 내부 최대 입력을 0으로 잡은 상대 단위)을
  ///       dBA 로 바꾸는 보정 오프셋이다.
  final double micDbfsToDbaOffset;

  /// 목적: 측정이 유효하다고 보는 최소 소요 시간이다.
  final double minMeasureDurationSec;

  /// 목적: 유효한 층간 이동으로 보는 최소 도달 속도다.
  final double minValidMaxSpeed;

  /// 목적: 유효한 층간 이동으로 보는 최소 이동 거리다.
  final double minValidDistance;

  const MetricsConfig({
    this.baselineSec = 1.0,
    this.motionLowpassCutoffHz = 0.1,
    this.vibrationHighpassCutoffHz = 0.5,
    double? vibrationHighpassCutoffHzX,
    double? vibrationHighpassCutoffHzY,
    double? vibrationHighpassCutoffHzZ,
    this.vibrationLowpassCutoffHz = 10.0,
    double? vibrationLowpassCutoffHzX,
    double? vibrationLowpassCutoffHzY,
    double? vibrationLowpassCutoffHzZ,
    this.rideSpeedThreshold = 0.05,
    this.rideActivityPaddingSec = 0.8,
    this.minRideDurationSec = 3.0,
    this.constantSpeedRatio = 0.9,
    this.aptpWindowSec = 1.0,
    double? aptpWindowSecX,
    double? aptpWindowSecY,
    double? aptpWindowSecZ,
    this.aptpPercentile = 0.95,
    this.xyThresholdMg = 10.0,
    this.zThresholdMg = 15.0,
    this.noiseThresholdDba = 50.0,
    this.micDbfsToDbaOffset = 85.0,
    this.minMeasureDurationSec = 8.0,
    this.minValidMaxSpeed = 0.1,
    this.minValidDistance = 0.5,
    this.vibrationFilterTypeX = VibrationFilterType.isoWdWeighting,
    this.vibrationFilterTypeY = VibrationFilterType.isoWdWeighting,
    this.vibrationFilterTypeZ = VibrationFilterType.butterworthBandLimit,
    this.wdTransitionHz = 2.0,
    this.wdTransitionQ = 0.63,
    this.wkTransitionHz = 12.5,
    this.wkTransitionQ = 0.63,
    this.wkUpwardStepHz = 2.37,
    this.wkUpwardStepHighHz = 3.3,
    this.wkUpwardStepQ = 0.91,
  }) : vibrationHighpassCutoffHzX = vibrationHighpassCutoffHzX ?? 0.4,
       vibrationHighpassCutoffHzY = vibrationHighpassCutoffHzY ?? 0.4,
       vibrationHighpassCutoffHzZ = vibrationHighpassCutoffHzZ ?? 1.0,
       vibrationLowpassCutoffHzX = vibrationLowpassCutoffHzX ?? 100.0,
       vibrationLowpassCutoffHzY = vibrationLowpassCutoffHzY ?? 100.0,
       vibrationLowpassCutoffHzZ = vibrationLowpassCutoffHzZ ?? 30.0,
       aptpWindowSecX = aptpWindowSecX ?? aptpWindowSec,
       aptpWindowSecY = aptpWindowSecY ?? aptpWindowSec,
       aptpWindowSecZ = aptpWindowSecZ ?? aptpWindowSec;

  /// 기본 전역 인스턴스
  static const MetricsConfig defaultConfig = MetricsConfig();
}
