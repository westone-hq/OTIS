import 'package:vibration_checker/domain/dsp/sos_section.dart';

/// 작성: 2026-10-15 16:50:04 · 박건준
/// 클래스: AnalogBiquad
/// 목적: 아날로그 2차 전달함수(라플라스 변수 s 의 2차식 ÷ 2차식) 하나를
///       담는다. ISO 8041 가중 필터는 이 꼴의 단계 몇 개를 곱한 것으로
///       정의된다.
///       H(s) = (b2 s² + b1 s + b0) / (a2 s² + a1 s + a0)
class AnalogBiquad {
  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: AnalogBiquad
  /// 목적: 계수를 그대로 담는 생성자.
  /// 인자: b2, b1, b0 — 분자의 s², s, 상수 계수
  ///       a2, a1, a0 — 분모의 s², s, 상수 계수
  const AnalogBiquad({
    required this.b2,
    required this.b1,
    required this.b0,
    required this.a2,
    required this.a1,
    required this.a0,
  });

  /// 분자 s² 계수
  final double b2;

  /// 분자 s 계수
  final double b1;

  /// 분자 상수 계수
  final double b0;

  /// 분모 s² 계수
  final double a2;

  /// 분모 s 계수
  final double a1;

  /// 분모 상수 계수
  final double a0;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: toDigital
  /// 목적: 쌍선형 변환(아날로그 필터를 디지털 필터로 옮기는 표준 변환식)
  ///       으로 디지털 2차 구간을 만든다. 주파수를 미리 당기지 않는다 —
  ///       ISO 8041 가중은 아날로그 정의를 그대로 옮기고, 가중이 크게
  ///       변하는 주파수(≤ 12.5Hz)가 표본 속도(100Hz)의 절반보다 한참
  ///       낮아 휘는 정도가 작다.
  /// 인자: sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: a0 = 1 로 나눈 디지털 2차 구간
  /// 식: s = K (z - 1) / (z + 1),  K = 2 x sampleRateHz
  ///     B0 = b2 K² + b1 K + b0,  B1 = 2 b0 - 2 b2 K²,  B2 = b2 K² - b1 K + b0
  ///     (분모도 같은 꼴) 뒤 A0 로 나눈다
  /// 근거: 표준 — SciPy 1.18.1 `scipy.signal.bilinear(b, a, fs)` 와 같은 식
  SosSection toDigital(double sampleRateHz) {
    final k = 2 * sampleRateHz; // 쌍선형 변환 상수 K
    final kk = k * k; // K²
    final num0 = b2 * kk + b1 * k + b0; // 디지털 분자 z⁰ 계수 (정규화 전)
    final num1 = 2 * b0 - 2 * b2 * kk; // 디지털 분자 z⁻¹ 계수
    final num2 = b2 * kk - b1 * k + b0; // 디지털 분자 z⁻² 계수
    final den0 = a2 * kk + a1 * k + a0; // 디지털 분모 z⁰ 계수 (정규화 기준)
    final den1 = 2 * a0 - 2 * a2 * kk; // 디지털 분모 z⁻¹ 계수
    final den2 = a2 * kk - a1 * k + a0; // 디지털 분모 z⁻² 계수
    return SosSection(
      b0: num0 / den0,
      b1: num1 / den0,
      b2: num2 / den0,
      a1: den1 / den0,
      a2: den2 / den0,
    );
  }
}
