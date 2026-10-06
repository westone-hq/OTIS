/// 작성: 2026-08-19 08:04:05 · 박건준
/// 수정: 2026-10-07 01:44:43 · nada
/// 클래스: CaptureConfig
/// 목적: 스마트폰 센서 데이터 수집에 쓰는 속도(Hz)와 불량 판정 기준(us)을 이 파일에서만 정의한다.
///       지표를 내기 전 신호 처리(기준선 0 맞춤 · 저역 필터 · 재표본)의
///       수치도 여기에 둔다. 다른 파일에 같은 수치를 하드코딩하지 않는다.
class CaptureConfig {
  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 수정: 2026-10-07 01:44:43 · nada
  /// 함수: CaptureConfig
  /// 목적: 수집 설정 객체를 생성한다. 값을 지정하지 않으면 기본값이 적용된다.
  /// 인자: targetSampleRateHz — 격자 환산의 목표 수집 속도 (Hz), 기본 256
  ///       normalIntervalMinUs — 정상 수신 간격의 하한 (마이크로초)
  ///       normalIntervalMaxUs — 정상 수신 간격의 상한 (마이크로초)
  ///       edgeTrimMs — 격자를 만들 때 앞뒤에서 각각 버리는 길이 (밀리초)
  ///       conditionedRateHz — 지표 계산 전에 다시 맞추는 표본 속도 (Hz)
  ///       lowpassCutoffHz — 재표본 전 저역 필터의 차단 주파수 (Hz)
  ///       lowpassOrder — 저역 필터 차수. 짝수
  ///       baselineWindowMs — 기준선을 구하는 측정 첫 구간 길이 (밀리초)
  const CaptureConfig({
    this.targetSampleRateHz = defaultTargetSampleRateHz,
    this.normalIntervalMinUs = defaultNormalIntervalMinUs,
    this.normalIntervalMaxUs = defaultNormalIntervalMaxUs,
    this.edgeTrimMs = defaultEdgeTrimMs,
    this.conditionedRateHz = defaultConditionedRateHz,
    this.lowpassCutoffHz = defaultLowpassCutoffHz,
    this.lowpassOrder = defaultLowpassOrder,
    this.baselineWindowMs = defaultBaselineWindowMs,
  });

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: targetSampleRateHz
  /// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산의 목표
  ///       수집 속도다. 네이티브에는 전달하지 않는다 — 네이티브는
  ///       SENSOR_DELAY_FASTEST 로 받고, 이 값은 Dart 쪽 격자 계산에만 쓴다.
  final int targetSampleRateHz;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: normalIntervalMinUs
  /// 목적: 정상 수신 간격의 하한이다. 이보다 짧은 간격은 지연 폭주로 보고 집계한다.
  /// 근거: 인용 — 도입 시 목표 주기 간격의 절반과 두 배 수준으로 임시 설정했다.
  ///       계산상 절반·두 배와 일치한다.
  ///       미확인: 이 창은 목표 격자 주기를 기준으로 잡혔으나 판정
  ///       대상은 원본 채널의 수신 간격이다. 원본은 격자보다 항상 빠르므로
  ///       기준이 맞지 않는다. 대상 기기 실측 간격은 하한까지 여유가
  ///       10퍼센트 미만이며, 더 빠른 기기에서는 정상 수신이 이상으로 집계된다.
  ///       하드웨어 실측 주기를 기준으로 다시 정해야 한다.
  ///       현재 앱 동작에는 영향이 없다. 이 판정은 명령줄 도구의 출력에만 쓰인다.
  final int normalIntervalMinUs;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: normalIntervalMaxUs
  /// 목적: 정상 수신 간격의 상한이다. 이보다 긴 간격은 수신 지연·유실로 보고 집계한다.
  /// 근거: 인용 — 도입 시 목표 주기 간격의 절반과 두 배 수준으로 임시 설정했다.
  ///       계산상 절반·두 배와 일치한다.
  ///       미확인: 이 창은 목표 격자 주기를 기준으로 잡혔으나 판정
  ///       대상은 원본 채널의 수신 간격이다. 원본은 격자보다 항상 빠르므로
  ///       기준이 맞지 않는다. 대상 기기 실측 간격은 하한까지 여유가
  ///       10퍼센트 미만이며, 더 빠른 기기에서는 정상 수신이 이상으로 집계된다.
  ///       하드웨어 실측 주기를 기준으로 다시 정해야 한다.
  ///       현재 앱 동작에는 영향이 없다. 이 판정은 명령줄 도구의 출력에만 쓰인다.
  final int normalIntervalMaxUs;

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 변수: edgeTrimMs
  /// 목적: 두 센서가 함께 값을 낸 구간의 앞과 뒤에서 각각 이만큼을 버리고
  ///       격자를 만든다 (밀리초). 측정을 시작 · 종료하려고 화면 버튼이나
  ///       볼륨키를 누르는 충격이 진동 지표에 들어가지 않게 하려는 것이다.
  ///       안드로이드 원본 기록(`native_raw.txt`)은 자르지 않는다.
  /// 근거: 미정 — 2026-10-05 사용자 결정. 2026-10-04 코드 점검 보고서가
  ///       시험 자료 끝 0.25초에서 종료 입력 충격을 짚었고, 그보다 넉넉히
  ///       잡았다
  /// 미확인: 볼륨키를 누를 때 충격이 이어지는 길이. 실기기로 확인해야 한다
  final int edgeTrimMs;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: conditionedRateHz
  /// 목적: 지표 · 리포트를 계산하기 전에 격자를 다시 맞추는 표본 속도다
  ///       (Hz). 오티스폰(OTIS iOS 앱)이 담을 수 있는 주파수 범위만 남겨
  ///       두 기기의 지표를 견줄 수 있게 한다. `raw.txt` 는 이 속도로
  ///       바꾸지 않고 `targetSampleRateHz` 격자 그대로 쓴다.
  /// 근거: 인용 — 오티스폰의 측정 주기 100Hz
  final int conditionedRateHz;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: lowpassCutoffHz
  /// 목적: 재표본 전에 거는 저역 필터(정한 주파수 위 성분을 줄이는 계산)의
  ///       차단 주파수다 (Hz). 개발폰 격자는 128Hz 까지 담지만 오티스폰은
  ///       50Hz 가 한계라, 그 위 성분이 개발폰의 최대 P2P 를 키운다.
  /// 근거: 표준 — 100Hz 측정이 담을 수 있는 한계(표본 속도의 절반)
  ///       50Hz 의 80%.
  ///       측정 — 2026-10-07 오티스폰 · 개발폰 동시 측정 6쌍에서 오티스폰
  ///       스펙트럼이 30Hz 부터 줄어 40Hz 부근에서 저주파의 약 1/6 이다
  final int lowpassCutoffHz;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: lowpassOrder
  /// 목적: 저역 필터의 차수다. 짝수여야 한다 — 홀수면 1차 구간이 생기는데
  ///       설계 함수(`ButterworthLowpass.design()`)가 다루지 않고
  ///       `ArgumentError` 를 던진다.
  /// 근거: 미정 — 일반 관행. 비교 측정을 더 모아 조정할 수 있다
  final int lowpassOrder;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: baselineWindowMs
  /// 목적: 기준선(정지 상태에서 0 이어야 할 값)을 구하는 측정 첫 구간
  ///       길이다 (밀리초). 이 구간의 축별 평균을 그 축 전체에서 뺀다.
  /// 근거: 측정 — 2026-10-07 동시 측정 6쌍 모두 카 출발이 3.7초 이후라
  ///       첫 1초는 정지 구간이다
  final int baselineWindowMs;

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 변수: defaultEdgeTrimMs
  /// 목적: edgeTrimMs 기본값이다.
  static const int defaultEdgeTrimMs = 500;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: defaultConditionedRateHz
  /// 목적: `conditionedRateHz` 기본값이다.
  static const int defaultConditionedRateHz = 100;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: defaultLowpassCutoffHz
  /// 목적: `lowpassCutoffHz` 기본값이다.
  static const int defaultLowpassCutoffHz = 40;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: defaultLowpassOrder
  /// 목적: `lowpassOrder` 기본값이다.
  static const int defaultLowpassOrder = 4;

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 변수: defaultBaselineWindowMs
  /// 목적: `baselineWindowMs` 기본값이다.
  static const int defaultBaselineWindowMs = 1000;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: defaultTargetSampleRateHz
  /// 목적: targetSampleRateHz 기본값이다.
  static const int defaultTargetSampleRateHz = 256;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: defaultNormalIntervalMinUs
  /// 목적: normalIntervalMinUs 기본값이다.
  static const int defaultNormalIntervalMinUs = 1950;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 변수: defaultNormalIntervalMaxUs
  /// 목적: normalIntervalMaxUs 기본값이다.
  static const int defaultNormalIntervalMaxUs = 7900;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: idealIntervalNs
  /// 목적: 격자 한 칸의 간격을 나노초로 반환한다. `GridResampler`가
  ///       격자 행 시각을 정할 때 이 값을 쓴다. 마이크로초 단위로
  ///       반올림하면 1,000,000 / 256 = 3906.25처럼 소수점이 남아
  ///       등간격 격자를 만들 수 없다. 나노초는 3,906,250으로
  ///       정확히 나뉜다.
  /// 반환: 격자 간격 (나노초)
  /// 식: 1,000,000,000 / targetSampleRateHz
  int get idealIntervalNs => 1000000000 ~/ targetSampleRateHz;

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: edgeTrimNs
  /// 목적: 앞뒤에서 각각 버리는 길이를 나노초로 반환한다.
  /// 반환: 버리는 길이 (나노초)
  int get edgeTrimNs => edgeTrimMs * 1000000;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: isGridExact
  /// 목적: 목표 주기가 나노초 정수 간격으로 나뉘는지 알려준다. 나뉘지
  ///       않으면 등간격 격자를 만들 수 없으므로 `GridResampler.resample()`
  ///       은 이 값이 false면 환산을 거부하고 실패 결과를 반환한다.
  /// 반환: 정확히 나뉘면 true
  bool get isGridExact => 1000000000 % targetSampleRateHz == 0;

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: resampleUp
  /// 목적: 격자를 `conditionedRateHz` 로 재표본할 때 늘리는 배수를 반환한다.
  ///       두 속도를 최대공약수로 나눠 가장 작은 정수비로 맞춘다.
  /// 반환: 늘리는 배수. 기본값이면 25
  /// 식: conditionedRateHz / gcd(conditionedRateHz, targetSampleRateHz)
  /// 근거: 표준 — 정수비 재표본. 256 x 25 / 64 = 100 으로 정확히 나뉜다
  int get resampleUp =>
      conditionedRateHz ~/ conditionedRateHz.gcd(targetSampleRateHz);

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: resampleDown
  /// 목적: 격자를 `conditionedRateHz` 로 재표본할 때 줄이는 배수를 반환한다.
  /// 반환: 줄이는 배수. 기본값이면 64
  /// 식: targetSampleRateHz / gcd(conditionedRateHz, targetSampleRateHz)
  int get resampleDown =>
      targetSampleRateHz ~/ conditionedRateHz.gcd(targetSampleRateHz);

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: conditionedIntervalNs
  /// 목적: 재표본한 격자 한 칸의 간격을 나노초로 반환한다. 지표 계산
  ///       (`MeasurementAssembler`)이 이 간격으로 표본 속도를 다시 구한다.
  /// 반환: 재표본 격자 간격 (나노초). 기본값이면 10,000,000
  /// 식: 1,000,000,000 / conditionedRateHz
  int get conditionedIntervalNs => 1000000000 ~/ conditionedRateHz;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: isConditionedGridExact
  /// 목적: 재표본 속도가 나노초 정수 간격으로 나뉘는지 알려준다. 나뉘지
  ///       않으면 `SignalConditioner.condition()` 이 사유를 담아 실패한다.
  /// 반환: 정확히 나뉘면 true
  bool get isConditionedGridExact => 1000000000 % conditionedRateHz == 0;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: baselineWindowRows
  /// 목적: 기준선 구간에 드는 격자 행 수를 반환한다. 행 시각이 구간 길이
  ///       보다 앞서는 행(0 ≤ t < `baselineWindowMs`)을 센다.
  /// 반환: 기준선 구간 행 수. 기본값이면 256
  /// 식: ceil(baselineWindowMs x targetSampleRateHz / 1000)
  int get baselineWindowRows =>
      (baselineWindowMs * targetSampleRateHz + 999) ~/ 1000;

  /// 작성: 2026-10-07 02:22:28 · nada
  /// 함수: minimumRecordMs
  /// 목적: 지표를 낼 수 있는 가장 짧은 측정 길이를 반환한다 (밀리초).
  ///       앞뒤에서 `edgeTrimMs` 씩 버린 뒤에도 기준선 구간이 남아야 한다.
  ///       측정 화면이 "측정 시간이 너무 짧다"고 안내할 때 이 길이를 보여
  ///       준다.
  /// 반환: 최소 측정 길이 (밀리초). 기본값이면 2000
  /// 식: 2 x edgeTrimMs + baselineWindowMs
  int get minimumRecordMs => 2 * edgeTrimMs + baselineWindowMs;
}
