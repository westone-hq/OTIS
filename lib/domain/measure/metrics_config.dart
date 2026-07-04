/// 측정 엔진 필터, 윈도우, 임계값 파라미터 단일 정의 (OI-1 캘리브레이션 단일 지점)
/// - 모든 필터 및 임계 수치는 본 파일에만 정의되어야 하며, 타 파일에 리터럴 하드코딩 금지
class MetricsConfig {
  /// 기준선 보정 적용 시간 (초): 측정 시작 후 처음 1.0초간의 평균을 0점으로 잡음
  final double baselineSec;

  /// 저역통과필터(LPF) 차단 주파수 (Hz): 이동 성분(Motion) 분리 기준 (기본 0.1 Hz)
  final double motionLowpassCutoffHz;

  /// 주행 구간 감지 속도 임계값 (m/s): |v(t)| > 0.05 m/s 인 구간을 주행 중으로 인식
  final double rideSpeedThreshold;

  /// 주행 앞뒤 패딩 시간 (초): 주행 시작 전후로 버퍼를 추가 (기본 0.8초 = 800ms)
  final double rideActivityPaddingSec;

  /// 최소 주행 지속 시간 (초): 최소 3.0초 이상 주행해야 유효 구간으로 인정
  final double minRideDurationSec;

  /// 정속 구간 판단 속도 비율: 주행 구간 내 최대 속도 대비 90% (0.9) 이상인 연속 구간
  final double constantSpeedRatio;

  /// Aptp(A95 P2P) 산출용 텀블링 윈도우 크기 (초): 기본 0.5초 (축별 오버라이드 가능)
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

  const MetricsConfig({
    this.baselineSec = 1.0,
    this.motionLowpassCutoffHz = 0.1,
    this.rideSpeedThreshold = 0.05,
    this.rideActivityPaddingSec = 0.8,
    this.minRideDurationSec = 3.0,
    this.constantSpeedRatio = 0.9,
    this.aptpWindowSec = 0.5,
    double? aptpWindowSecX,
    double? aptpWindowSecY,
    double? aptpWindowSecZ,
    this.aptpPercentile = 0.95,
    this.xyThresholdMg = 10.0,
    this.zThresholdMg = 15.0,
    this.noiseThresholdDba = 50.0,
  })  : aptpWindowSecX = aptpWindowSecX ?? aptpWindowSec,
        aptpWindowSecY = aptpWindowSecY ?? aptpWindowSec,
        aptpWindowSecZ = aptpWindowSecZ ?? aptpWindowSec;

  /// 기본 전역 인스턴스
  static const MetricsConfig defaultConfig = MetricsConfig();
}
