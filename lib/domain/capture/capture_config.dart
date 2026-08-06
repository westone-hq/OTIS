/// 목적: 스마트폰 센서에서 데이터를 수집할 때 필요한 속도(Hz)와 불량 판정 기준(us) 등을 단일 파일에 정의한다.
///       모든 수집 관련 수치는 이 파일에서만 관리되어야 하며 다른 파일에 하드코딩하는 것을 금지한다.
class CaptureConfig {
  /// 목적: 새로운 수집 환경 설정 객체를 생성한다. 값을 지정하지 않으면 기본 세팅(256Hz)이 적용된다.
  const CaptureConfig({
    this.targetSampleRateHz = defaultTargetSampleRateHz,
    this.normalIntervalMinUs = defaultNormalIntervalMinUs,
    this.normalIntervalMaxUs = defaultNormalIntervalMaxUs,
  });

  /// 목적: 안드로이드 기기(하드웨어)에게 지시할 목표 센서 수집 속도
  /// 현재값: 256 (Hz)
  /// 하는일: 1초에 센서값을 256번 측정하도록 기기에 지시하는 기준입니다.
  final int targetSampleRateHz;

  /// 목적: 기기가 센서 데이터를 비정상적으로 대량 발생시키는 '지연 폭주' 현상을 걸러내기 위한 최소 간격 마지노선
  /// 현재값: 1950 (마이크로초, 약 0.00195초)
  /// 하는일: 센서 데이터가 이전 데이터보다 1950마이크로초 미만의 간격으로 너무 빨리 수집되면, 기기 오류로 발생한 '불량 데이터'로 간주합니다.
  final int normalIntervalMinUs;

  /// 목적: 기기 과부하 등으로 인해 데이터 수집이 지연되는 현상을 걸러내기 위한 최대 간격 마지노선
  /// 현재값: 7900 (마이크로초, 약 0.0079초)
  /// 하는일: 센서 데이터가 7900마이크로초를 초과하여 수집되지 않으면, 해당 구간을 '데이터가 유실된 비정상 구간'으로 간주합니다.
  final int normalIntervalMaxUs;

  /// 목적: 목표 수집 속도 기본값
  /// 현재값: 256 (Hz)
  /// 하는일: 앱 초기 구동 시 기본적으로 256Hz로 작동하도록 세팅합니다.
  static const int defaultTargetSampleRateHz = 256;

  /// 목적: 정상 간격 하한 기본값
  /// 현재값: 1950 (마이크로초)
  /// 하는일: (normalIntervalMinUs 변수에 들어갈 기본 템플릿 값입니다)
  static const int defaultNormalIntervalMinUs = 1950;

  /// 목적: 정상 간격 상한 기본값
  /// 현재값: 7900 (마이크로초)
  /// 하는일: (normalIntervalMaxUs 변수에 들어갈 기본 템플릿 값입니다)
  static const int defaultNormalIntervalMaxUs = 7900;

  /// 목적: 256Hz 속도를 시간(간격)으로 역계산한 수학적 이상값
  /// 현재값: 3906 (마이크로초)
  /// 하는일: 1초(1,000,000마이크로초)를 256번으로 나누어 산출된 이상적인 측정 간격(3906마이크로초)입니다. 이를 기준으로 실제 데이터 간격의 오차를 판단합니다.
  int get idealIntervalUs {
    if (targetSampleRateHz <= 0) return 0;
    return 1000000 ~/ targetSampleRateHz;
  }
}
