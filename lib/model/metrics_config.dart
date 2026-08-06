/// 축별 진동 성분 필터 종류
enum VibrationFilterType {
  /// 2차 Butterworth band-limit (HP + LP), 인과 biquad 적용 — 레거시 Z축
  butterworthBandLimit,

  /// ISO 8041 Wd(수평 진동 가중) 필터 캐스케이드: band-limit HP → band-limit LP → 가속도-속도 천이 — X/Y축
  isoWdWeighting,

  /// ISO 8041 Wk(수직 좌석 진동 가중) 필터 캐스케이드: band-limit HP → LP → 천이 → upward-step — Z축
  isoWkWeighting,
}

/// 측정 엔진 필터, 윈도우, 임계값 파라미터 단일 정의 (OI-1 캘리브레이션 단일 지점)
/// - 모든 필터 및 임계 수치는 본 파일에만 정의되어야 하며, 타 파일에 리터럴 하드코딩 금지
/// - 이 수치들은 실패 검증으로 확정됨. 변경 시 연구노트 대조 필수. X/Y Aptp는 OI-1(Phase7 현장 캘리브레이션) 대기 중이라 미확정.
/// - 진동 지표(Aptp) 필터 아키텍처: X/Y축은 ISO 8041 Wd(수평 진동 가중) 필터 캐스케이드,
///   Z축은 2차 Butterworth band-limit(HP 1.0Hz~LP 30.0Hz)를 적용. (ISO 8041 Wk는
///   isoWkWeighting으로 선택 가능). 모두 인과(causal) biquad 1회 순방향 적용.
///   거리/속도 산출용 motion 분리(motionLowpassCutoffHz)는 기존과 동일하게 이동평균을 사용한다.
class MetricsConfig {
  /// 기준선 보정 적용 시간 (초): 측정 시작 후 처음 1.0초간의 평균을 0점으로 잡음
  final double baselineSec;

  /// 저역통과필터(LPF) 차단 주파수 (Hz): 이동 성분(Motion) 분리 기준 (기본 0.1 Hz)
  final double motionLowpassCutoffHz;

  /// 진동 산출용 high-pass 성격 분리 컷오프 (Hz): 출발/정지 저주파 성분 제거
  /// - X/Y 기본값(0.4Hz)은 ISO 8041 Wd 대역 제한 HP(f1)
  /// - Z 기본값(1.0Hz)은 2차 Butterworth band-limit HP
  final double vibrationHighpassCutoffHz;
  final double vibrationHighpassCutoffHzX;
  final double vibrationHighpassCutoffHzY;
  final double vibrationHighpassCutoffHzZ;

  /// 진동 산출용 low-pass 성격 분리 컷오프 (Hz): 고주파 노이즈 제거
  /// - X/Y 기본값(100.0Hz)은 ISO 8041 Wd 대역 제한 LP(f2). 0.45×sampleRate 초과 시 클램프
  /// - Z 기본값(30.0Hz)은 2차 Butterworth band-limit LP
  final double vibrationLowpassCutoffHz;
  final double vibrationLowpassCutoffHzX;
  final double vibrationLowpassCutoffHzY;
  final double vibrationLowpassCutoffHzZ;

  /// 축별 진동 필터 종류 (기본: X/Y=ISO 8041 Wd 가중, Z=2차 Butterworth band-limit)
  final VibrationFilterType vibrationFilterTypeX;
  final VibrationFilterType vibrationFilterTypeY;
  final VibrationFilterType vibrationFilterTypeZ;

  /// ISO 8041 Wk 가속도-속도 천이 필터 특성 주파수 (f3 = f4, Hz) — Z축 전용
  final double wkTransitionHz;

  /// ISO 8041 Wk 가속도-속도 천이 필터 Q값 (Q4) — Z축 전용
  final double wkTransitionQ;

  /// ISO 8041 Wk upward-step 필터 f5 (Hz) — Z축 전용
  final double wkUpwardStepHz;

  /// ISO 8041 Wk upward-step 필터 f6 (Hz) — Z축 전용
  final double wkUpwardStepHighHz;

  /// ISO 8041 Wk upward-step 필터 Q5/Q6 — Z축 전용
  final double wkUpwardStepQ;

  /// ISO 8041 Wd 가속도-속도 천이 필터 특성 주파수 (f3 = f4, Hz) — X/Y축 전용
  /// H_t(s) = (ω4²/ω3)·(s + ω3) / (s² + (ω4/Q4)·s + ω4²), ω = 2πf
  final double wdTransitionHz;

  /// ISO 8041 Wd 가속도-속도 천이 필터 Q값 (Q4) — X/Y축 전용
  final double wdTransitionQ;

  /// 주행 구간 감지 속도 임계값 (m/s): |v(t)| > 0.05 m/s 인 구간을 주행 중으로 인식
  final double rideSpeedThreshold;

  /// 주행 앞뒤 패딩 시간 (초): 주행 시작 전후로 버퍼를 추가 (기본 0.8초 = 800ms)
  final double rideActivityPaddingSec;

  /// 최소 주행 지속 시간 (초): 최소 3.0초 이상 주행해야 유효 구간으로 인정
  final double minRideDurationSec;

  /// 정속 구간 판단 속도 비율: 주행 구간 내 최대 속도 대비 90% (0.9) 이상인 연속 구간
  final double constantSpeedRatio;

  /// Aptp(A95 P2P) 산출용 슬라이딩 윈도우 크기 (초): 기본 1.0초 (축별 오버라이드 가능)
  final double aptpWindowSec;
  final double aptpWindowSecX;
  final double aptpWindowSecY;
  final double aptpWindowSecZ;

  /// Aptp 윈도우 백분위수: 상위 5% (95th Percentile = 0.95)
  final double aptpPercentile;

  /// 임계 규격 (D3): X/Y 진동 주의 임계값 (mg)
  final double xyThresholdMg;

  /// 임계 규격 (D3): Z 진동 주의 임계값 (mg)
  final double zThresholdMg;

  /// 임계 규격 (D3): 소음 주의 임계값 (dBA)
  final double noiseThresholdDba;

  /// 마이크 dBFS → dBA 환산 오프셋: dBA = dBFS + micDbfsToDbaOffset + calibrationOffsetDba
  // OI-4: 실측 캘리브레이션 전 임시 추정치. 기준 소음계 대비 기기별 보정 필요(Phase 7)
  final double micDbfsToDbaOffset;

  // 타당성 게이트: 미만이면 "움직임 미감지" 안내. 수치는 여기 단일 정의.
  final double minMeasureDurationSec; // 8.0
  final double minValidMaxSpeed; // 0.1 (m/s)
  final double minValidDistance; // 0.5 (m)

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
  }) : vibrationHighpassCutoffHzX =
           vibrationHighpassCutoffHzX ?? 0.4, // ISO 8041 Wd f1
       vibrationHighpassCutoffHzY =
           vibrationHighpassCutoffHzY ?? 0.4, // ISO 8041 Wd f1
       vibrationHighpassCutoffHzZ =
           vibrationHighpassCutoffHzZ ?? 1.0, // Butterworth band-limit HP
       vibrationLowpassCutoffHzX =
           vibrationLowpassCutoffHzX ?? 100.0, // ISO 8041 Wd f2
       vibrationLowpassCutoffHzY =
           vibrationLowpassCutoffHzY ?? 100.0, // ISO 8041 Wd f2
       vibrationLowpassCutoffHzZ =
           vibrationLowpassCutoffHzZ ?? 30.0, // Butterworth band-limit LP
       aptpWindowSecX = aptpWindowSecX ?? aptpWindowSec,
       aptpWindowSecY = aptpWindowSecY ?? aptpWindowSec,
       aptpWindowSecZ = aptpWindowSecZ ?? aptpWindowSec;

  /// 기본 전역 인스턴스
  static const MetricsConfig defaultConfig = MetricsConfig();
}
