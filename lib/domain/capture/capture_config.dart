// 작성: 2026-08-19 08:04:05
// 작성자: 박건준

/// 클래스: CaptureConfig
/// 목적: 스마트폰 센서 데이터 수집에 쓰는 속도(Hz)와 불량 판정 기준(us)을 이 파일에서만 정의한다.
///       다른 파일에 같은 수치를 하드코딩하지 않는다.
class CaptureConfig {
  /// 목적: 수집 설정 객체를 생성한다. 값을 지정하지 않으면 기본값이 적용된다.
  const CaptureConfig({
    this.targetSampleRateHz = defaultTargetSampleRateHz,
    this.normalIntervalMinUs = defaultNormalIntervalMinUs,
    this.normalIntervalMaxUs = defaultNormalIntervalMaxUs,
  });

  /// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산의 목표
  ///       수집 속도다. 네이티브에는 전달하지 않는다 — 네이티브는
  ///       SENSOR_DELAY_FASTEST 로 받고, 이 값은 Dart 쪽 격자 계산에만 쓴다.
  final int targetSampleRateHz;

  /// 목적: 정상 수신 간격의 하한이다. 이보다 짧은 간격은 지연 폭주로 보고 집계한다.
  /// 근거: 인용 — 도입 시 목표 주기 간격의 절반과 두 배 수준으로 임시 설정했다.
  ///       계산상 절반·두 배와 일치한다.
  ///       확인된 어긋남: 이 창은 목표 격자 주기를 기준으로 잡혔으나 판정
  ///       대상은 원본 채널의 수신 간격이다. 원본은 격자보다 항상 빠르므로
  ///       기준이 맞지 않는다. 대상 기기 실측 간격은 하한까지 여유가
  ///       10퍼센트 미만이며, 더 빠른 기기에서는 정상 수신이 이상으로 집계된다.
  ///       하드웨어 실측 주기를 기준으로 다시 정해야 한다.
  ///       현재 앱 동작에는 영향이 없다. 이 판정은 명령줄 도구의 출력에만 쓰인다.
  final int normalIntervalMinUs;

  /// 목적: 정상 수신 간격의 상한이다. 이보다 긴 간격은 수신 지연·유실로 보고 집계한다.
  /// 근거: 인용 — 도입 시 목표 주기 간격의 절반과 두 배 수준으로 임시 설정했다.
  ///       계산상 절반·두 배와 일치한다.
  ///       확인된 어긋남: 이 창은 목표 격자 주기를 기준으로 잡혔으나 판정
  ///       대상은 원본 채널의 수신 간격이다. 원본은 격자보다 항상 빠르므로
  ///       기준이 맞지 않는다. 대상 기기 실측 간격은 하한까지 여유가
  ///       10퍼센트 미만이며, 더 빠른 기기에서는 정상 수신이 이상으로 집계된다.
  ///       하드웨어 실측 주기를 기준으로 다시 정해야 한다.
  ///       현재 앱 동작에는 영향이 없다. 이 판정은 명령줄 도구의 출력에만 쓰인다.
  final int normalIntervalMaxUs;

  /// 목적: targetSampleRateHz 기본값이다.
  static const int defaultTargetSampleRateHz = 256;

  /// 목적: normalIntervalMinUs 기본값이다.
  static const int defaultNormalIntervalMinUs = 1950;

  /// 목적: normalIntervalMaxUs 기본값이다.
  static const int defaultNormalIntervalMaxUs = 7900;

  /// 목적: 목표 주기를 마이크로초 간격으로 역계산한 값이다. 표시·통계용이며,
  ///       격자 계산에는 idealIntervalNs 를 쓴다 — 마이크로초는 소수점이 손실된다.
  /// 식: 1,000,000 / targetSampleRateHz
  int get idealIntervalUs {
    if (targetSampleRateHz <= 0) return 0;
    return 1000000 ~/ targetSampleRateHz;
  }

  /// 함수: idealIntervalNs
  /// 목적: 격자 한 칸의 간격을 나노초로 반환한다. `GridResampler`가
  ///       격자 행 시각을 정할 때 이 값을 쓴다. 마이크로초 단위로
  ///       반올림하면 1,000,000 / 256 = 3906.25처럼 소수점이 남아
  ///       등간격 격자를 만들 수 없다. 나노초는 3,906,250으로
  ///       정확히 나뉜다.
  /// 인자: 없음 (targetSampleRateHz 사용)
  /// 반환: 격자 간격 (나노초)
  /// 식: 1,000,000,000 / targetSampleRateHz
  int get idealIntervalNs => 1000000000 ~/ targetSampleRateHz;

  /// 함수: isGridExact
  /// 목적: 목표 주기가 나노초 정수 간격으로 나뉘는지 알려준다. 나뉘지
  ///       않으면 등간격 격자를 만들 수 없으므로 `GridResampler.resample()`
  ///       은 이 값이 false면 환산을 거부하고 실패 결과를 반환한다.
  /// 인자: 없음 (targetSampleRateHz 사용)
  /// 반환: 정확히 나뉘면 true
  bool get isGridExact => 1000000000 % targetSampleRateHz == 0;
}
