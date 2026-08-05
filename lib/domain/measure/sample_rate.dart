/// 분석용 리샘플 샘플레이트 단일 정의.
///
/// 원본 센서 콜백은 불규칙(≈2~7ms)이고, 분석/저장 시계열은 이 Hz로
/// 선형 보간한다. 간격 = 1/[hz] ≈ 3.906ms (3906µs).
///
/// Android [SensorStreamHandler.start]도 Flutter가 넘긴 이 값을 사용한다.
/// 변경 시 Kotlin 기본값(`TARGET_SAMPLE_RATE_HZ`)과 함께 맞출 것.
class SampleRate {
  SampleRate._();

  /// 목표 샘플레이트 (Hz) — 초당 샘플 수
  static const int hz = 256;

  /// double 표기 (엔진/결과 모델 기본값용)
  static const double hzDouble = 256.0;

  /// 샘플 간격 (초) = 1/256 ≈ 0.00390625
  static const double periodSec = 1.0 / hz;

  /// 샘플 간격 (마이크로초) ≈ 3906
  static const int periodUs = 1000000 ~/ hz;
}
