/// 수집 계층 설정값 단일 정의.
///
/// 수집(캡처) 관련 모든 수치는 이 파일에만 정의한다.
/// 타 파일에 리터럴 하드코딩 금지. (예외: 0, 1, -1)
/// 각 값에는 근거를 표기한다 — 표준 / 인용 / 측정 / 미정 중 하나.
class CaptureConfig {
  /// 목적: 수집 설정값 묶음을 만든다.
  ///
  /// 값을 지정하지 않으면 아래 정의된 기본값을 쓴다.
  const CaptureConfig({
    this.targetSampleRateHz = defaultTargetSampleRateHz,
    this.normalIntervalMinUs = defaultNormalIntervalMinUs,
    this.normalIntervalMaxUs = defaultNormalIntervalMaxUs,
  });

  /// 목표 수집 주기 (헤르츠).
  ///
  /// 아젠다 1에 따라 256 / 128 / 64 를 각각 지정해 개별 측정한다.
  /// 근거: 미정 — 주기별 비교 측정(8/8) 후 운용 주기 확정, 8/11 회의
  final int targetSampleRateHz;

  /// 정상으로 판정할 샘플 간격의 하한 (마이크로초).
  ///
  /// 이보다 짧은 간격은 비정상 간격으로 집계한다.
  /// 근거: 미정 — 실측 간격 분포 확인(8/8) 후 확정. 초기값은
  ///       목표 주기 256Hz 간격(3906us)의 절반 수준으로 임시 설정
  final int normalIntervalMinUs;

  /// 정상으로 판정할 샘플 간격의 상한 (마이크로초).
  ///
  /// 이보다 긴 간격은 비정상 간격(수신 지연·유실 의심)으로 집계한다.
  /// 근거: 미정 — 실측 간격 분포 확인(8/8) 후 확정. 초기값은
  ///       목표 주기 256Hz 간격(3906us)의 2배 수준으로 임시 설정
  final int normalIntervalMaxUs;

  /// 기본 목표 수집 주기 (헤르츠).
  /// 근거: 미정 — 아젠다 1 비교 측정 후 확정, 8/11 회의
  static const int defaultTargetSampleRateHz = 256;

  /// 기본 정상 간격 하한 (마이크로초).
  /// 근거: 미정 — 위 normalIntervalMinUs 와 동일
  static const int defaultNormalIntervalMinUs = 1950;

  /// 기본 정상 간격 상한 (마이크로초).
  /// 근거: 미정 — 위 normalIntervalMaxUs 와 동일
  static const int defaultNormalIntervalMaxUs = 7900;

  /// 목적: 목표 주기에 대응하는 이상적 샘플 간격을 구한다.
  /// 인자: 없음 (targetSampleRateHz 를 사용)
  /// 반환: 간격 (마이크로초). 주기가 0 이하면 0
  /// 식:   intervalUs = 1,000,000 / targetSampleRateHz
  /// 근거: 표준 — 단위 정의 (1초 = 1,000,000 마이크로초)
  int get idealIntervalUs {
    if (targetSampleRateHz <= 0) return 0;
    return 1000000 ~/ targetSampleRateHz;
  }
}
