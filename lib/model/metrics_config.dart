/// 축별 진동 성분을 걸러내는 수학 필터 종류
enum VibrationFilterType {
  /// 목적: 특정 주파수(예: 0.5~10Hz) 구간만 깔끔하게 통과시키는 기본 필터
  /// 현재값: Z축(상하 진동)의 기본 필터로 사용됨
  /// 하는일: 엘리베이터가 수직 이동할 때 발생하는 진동을 효과적으로 필터링합니다.
  butterworthBandLimit,

  /// 목적: 국제 표준(ISO)에 맞춰 좌우(수평) 흔들림의 잡음을 걸러내는 맞춤형 필터
  /// 현재값: X, Y축(좌우, 전후 진동)의 기본 필터로 사용됨
  /// 하는일: 가이드레일 변형 등으로 발생하는 횡방향 결함을 정확히 도출합니다.
  isoWdWeighting,

  /// 목적: 국제 표준(ISO)에 맞춰 위아래(수직) 덜컹거림의 잡음을 걸러내는 맞춤형 필터
  /// 현재값: 선택 사항 (현재 Z축은 기본 필터 사용 중)
  /// 하는일: 롤러 마모 등으로 발생하는 수직 결함을 잡아냅니다.
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
/// [주의: ISO 8041 표준 준수를 위한 필수 고정값]
/// 아래 하드코딩된 특정 수치들(예: Wk/Wd 필터의 12.5Hz, 2.0Hz, 0.63 등)은 임의로 변경해선 안 되는 필수 상수입니다.
/// 이 값들은 ISO(국제 표준화 기구)에서 제정한 'ISO 8041 (진동 측정 표준)' 규격에 명시되어 있으며,
/// 측정 기기(스마트폰)가 글로벌 공인 전문 장비(EVA 등)와 동일한 신뢰도의 측정 결과를 산출하도록 보장하는 핵심 스펙입니다.
/// 임의로 수치를 변경할 경우 국제 표준 규격 미달로 간주되어 분석 결과의 공신력을 잃게 됩니다.
class MetricsConfig {
  /// 목적: 측정 시작 극초반의 불안정한 데이터를 0점(기준선)으로 잡기 위한 시간
  /// 현재값: 1.0 (초)
  /// 하는일: 기기 조작 등으로 인해 발생하는 초기 불안정 진동 구간(첫 1초)을 평균 내어 정지 상태(0점)로 영점 조절합니다.
  final double baselineSec;

  /// 목적: 엘리베이터의 순수 이동 궤적(Motion)을 분리하기 위한 기준 주파수
  /// 현재값: 0.1 (Hz)
  /// 하는일: 기계적 진동이 아닌 지구 중력 방향의 변화나 기기 자체의 기울어짐 등 극히 느린 변화를 계산에서 제외합니다.
  final double motionLowpassCutoffHz;

  /// 목적: 지나치게 느린 저주파 진동을 제외하는 하한선
  /// 현재값: X/Y축 0.4Hz, Z축 1.0Hz
  /// 하는일: 엘리베이터 가감속 시 발생하는 묵직한 쏠림 현상을 기계적 결함으로 오해하지 않도록, 이 수치 이하의 느린 변화를 제거합니다.
  final double vibrationHighpassCutoffHz;
  final double vibrationHighpassCutoffHzX;
  final double vibrationHighpassCutoffHzY;
  final double vibrationHighpassCutoffHzZ;

  /// 목적: 불필요한 고주파 진동을 제외하는 상한선
  /// 현재값: X/Y축 100.0Hz, Z축 30.0Hz
  /// 하는일: 구조적 결함과 무관한 모터 구동 소음이나 부품 간 미세 마찰에 의한 고주파 노이즈를 결함 평가에서 제외합니다.
  final double vibrationLowpassCutoffHz;
  final double vibrationLowpassCutoffHzX;
  final double vibrationLowpassCutoffHzY;
  final double vibrationLowpassCutoffHzZ;

  /// 목적: 축별 진동 성분을 분리하기 위한 수학 필터 지정
  /// 현재값: X/Y축은 국제표준 수평필터(Wd), Z축은 기본필터(Butterworth)
  /// 하는일: 수평 이동과 수직 이동 시 발생하는 진동 특성이 다르므로, 각각에 최적화된 필터를 적용하여 노이즈를 제거합니다.
  final VibrationFilterType vibrationFilterTypeX;
  final VibrationFilterType vibrationFilterTypeY;
  final VibrationFilterType vibrationFilterTypeZ;

  /// 목적: 가속도 데이터를 속도/변위로 변환 시 적용되는 특성 주파수 (Z축 전용)
  /// 현재값: 12.5 (Hz)
  /// 하는일: 국제 표준 공식(Wk)에 따라 센서가 수집한 가속도 데이터를 수직 결함 판정에 적합한 형태로 변환합니다.
  final double wkTransitionHz;

  /// 목적: 가속도-속도 변환 시 곡선의 완만함을 결정하는 비율 (Z축 전용)
  /// 현재값: 0.63
  /// 하는일: 변환 그래프가 급격히 꺾이지 않도록 곡선의 완만함(Q Factor)을 조정하여 부드러운 필터 특성을 유지합니다.
  final double wkTransitionQ;

  /// 목적: 특정 주파수 대역을 증폭시키는 저역 주파수 한계선 (Z축 전용)
  /// 현재값: 2.37 (Hz)
  /// 하는일: 수직 결함이 뚜렷하게 관찰되는 특정 저주파 대역의 신호를 증폭시켜 민감도를 높입니다.
  final double wkUpwardStepHz;

  /// 목적: 특정 주파수 대역을 증폭시키는 고역 주파수 한계선 (Z축 전용)
  /// 현재값: 3.3 (Hz)
  /// 하는일: 증폭이 적용되는 주파수 대역의 상한을 설정하여 결함 분석 범위를 확립합니다.
  final double wkUpwardStepHighHz;

  /// 목적: 증폭 시 적용되는 곡선의 완만함 비율 (Z축 전용)
  /// 현재값: 0.91
  /// 하는일: 신호 증폭 시 왜곡이 발생하지 않도록 필터 곡선의 완만함(Q Factor)을 조정합니다.
  final double wkUpwardStepQ;

  /// 목적: 가속도 데이터를 속도/변위로 변환 시 적용되는 특성 주파수 (X/Y축 전용)
  /// 현재값: 2.0 (Hz)
  /// 하는일: 수평 결함(레일 휨 등) 분석에 최적화된 주파수 대역으로 가속도 데이터를 변환합니다 (국제 표준 Wd 기준).
  final double wdTransitionHz;

  /// 목적: 가속도-속도 변환 시 곡선의 완만함을 결정하는 비율 (X/Y축 전용)
  /// 현재값: 0.63
  /// 하는일: 변환 그래프가 급격히 꺾이지 않도록 곡선의 완만함(Q Factor)을 조정합니다.
  final double wdTransitionQ;

  /// 목적: 주행 상태를 판단하는 최소 속도 기준
  /// 현재값: 0.05 (m/s)
  /// 하는일: 정지 상태에서의 미세 흔들림을 제외하고, 속도가 이 값을 초과하는 시점부터 유효한 주행 구간으로 간주합니다.
  final double rideSpeedThreshold;

  /// 목적: 주행 시작 및 종료 시점의 데이터 유실을 막기 위한 여유 버퍼(Padding) 시간
  /// 현재값: 0.8 (초)
  /// 하는일: 출발 직전의 초기 진동이나 도착 직후의 잔여 진동을 포함하기 위해 분석 구간을 앞뒤로 0.8초씩 연장합니다.
  final double rideActivityPaddingSec;

  /// 목적: 유효한 측정을 판단하기 위한 최소 주행 유지 시간
  /// 현재값: 3.0 (초)
  /// 하는일: 엘리베이터 주행이 3초 미만으로 짧게 종료될 경우, 정상적인 측정으로 간주하지 않고 데이터를 기각합니다.
  final double minRideDurationSec;

  /// 목적: 최고 속도 구간(정속 주행)을 추출하기 위한 도달 비율
  /// 현재값: 0.9 (90%)
  /// 하는일: 전체 주행 중 최고 속도의 90% 이상을 유지하는 구간만 분리하여, 가감속 모터 영향을 제외한 순수 가이드레일 상태를 분석합니다.
  final double constantSpeedRatio;

  /// 목적: 최대 진폭(P2P) 산출을 위한 슬라이딩 윈도우 크기
  /// 현재값: 1.0 (초)
  /// 하는일: 전체 진동 데이터를 1초 간격의 윈도우로 분할하여, 각 구간 내에서 가장 큰 진폭값을 추출하며 분석을 진행합니다.
  final double aptpWindowSec;
  final double aptpWindowSecX;
  final double aptpWindowSecY;
  final double aptpWindowSecZ;

  /// 목적: 단발성 이상치(Outlier)를 배제하고 안정적인 최대 진동값을 추출하기 위한 백분위수
  /// 현재값: 0.95 (상위 5%)
  /// 하는일: 외부 충격 등으로 인한 일회성 비정상 극댓값을 배제하고, 지속적으로 발생하는 상위 5% 수준의 유효 최대 진폭(95th Percentile)을 산출합니다.
  final double aptpPercentile;

  /// 목적: 좌우 흔들림(X/Y축)의 불량 판정 기준치
  /// 현재값: 10.0 (mg)
  /// 하는일: 수평 진동이 해당 수치를 초과하면 경고(Warning) 상태로 판정하고 가이드레일 점검을 권고합니다.
  final double xyThresholdMg;

  /// 목적: 상하 덜컹거림(Z축)의 불량 판정 기준치
  /// 현재값: 15.0 (mg)
  /// 하는일: 수직 진동이 해당 수치를 초과하면 경고(Warning) 상태로 판정하고 모터 및 롤러 가이드 점검을 권고합니다.
  final double zThresholdMg;

  /// 목적: 엘리베이터 실내 소음의 불량 판정 기준치
  /// 현재값: 50.0 (dBA)
  /// 하는일: 탑승칸 내부 소음이 50dBA를 초과하면 경고(Warning) 상태로 판정하고 기계 마찰 및 방음 상태 점검을 권고합니다.
  final double noiseThresholdDba;

  /// 목적: 기기 센서 소음값(dBFS)을 환경 소음 기준(dBA)으로 변환하기 위한 보정 오프셋
  /// 현재값: 85.0 (오프셋)
  /// 하는일: 마이크가 측정한 원시 데이터(dBFS)에 보정값을 더하여 통상적인 소음 단위(dBA)로 스케일링합니다.
  final double micDbfsToDbaOffset;

  /// 목적: 전체 측정 과정의 유효성을 검증하기 위한 최소 소요 시간
  /// 현재값: 8.0 (초)
  /// 하는일: 측정 시작부터 종료까지 총 소요 시간이 8초 미만일 경우, 불완전한 측정이 이루어졌다고 판단하여 분석을 취소합니다.
  final double minMeasureDurationSec;

  /// 목적: 유효한 층간 이동을 검증하기 위한 최소 도달 속도
  /// 현재값: 0.1 (m/s)
  /// 하는일: 최고 속도가 0.1m/s를 초과하지 못할 경우, 실제 주행이 발생하지 않았다고 판단하여 분석을 취소합니다.
  final double minValidMaxSpeed;

  /// 목적: 유효한 층간 이동을 검증하기 위한 최소 이동 거리
  /// 현재값: 0.5 (미터)
  /// 하는일: 총 이동 거리가 0.5m 미만일 경우, 제자리에 머물렀다고 판단하여 분석을 취소합니다.
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
