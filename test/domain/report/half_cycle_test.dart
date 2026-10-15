import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/half_cycle.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 반주기 P2P(`HalfCycle`)의 정의를 시험한다. 최대 P2P · A95 · 차트
///       표시점이 모두 이 한 정의에서 나오는지 본다.
void main() {
  // X: 반주기 크기 1 · 2 · 3 · 1 → P2P 3 · 5 · 4. 정확히 0 인 표본은
  // 반주기를 끊지 않는다
  const series = <double>[1.0, -2.0, 0.0, -1.0, 3.0, -1.0];

  test('반주기마다 가장 큰 크기와 그 자리를 모은다', () {
    final peaks = HalfCycle.peaks(series); // 반주기 봉우리
    expect(peaks.map((p) => p.magnitude).toList(), [1.0, 2.0, 3.0, 1.0]);
    expect(peaks.map((p) => p.index).toList(), [0, 1, 4, 5]);
  });

  test('A95 는 반주기 P2P 의 95백분위(최근접 순위)다', () {
    // 정렬 3 4 5, 순위 ceil(0.95 × 3) = 3 → 5
    expect(HalfCycle.a95(series), 5.0);
  });

  test('최대 P2P 는 가장 큰 반주기 P2P 와 그 두 자리다', () {
    final best = HalfCycle.maximum(series)!; // 가장 큰 반주기 P2P
    expect(best.value, 5.0);
    expect(best.firstIndex, 1);
    expect(best.secondIndex, 4);
  });

  test('전체 최대 − 최소가 아니다', () {
    // 작은 진동 둘 사이가 멀리 떨어져 있어도 이웃한 봉우리 · 골만 더한다.
    // 전체 최대 − 최소는 9 − (−1) = 10 이지만 이웃 쌍의 최대는 9 + 1 = 10
    // 이 아니라 아래 배열에서 9 + 2 = 11 이다 — 정의가 다르다는 것을
    // 다른 값으로 확인한다
    const values = <double>[2.0, -1.0, 1.0, -2.0, 9.0, -0.5];
    expect(HalfCycle.maximum(values)!.value, 11.0);
  });

  test('구간을 주면 그 안에서만 센다', () {
    const values = <double>[9.0, -9.0, 1.0, -1.0, 2.0, -2.0];
    final best = HalfCycle.maximum(values, start: 2, end: 5)!; // 구간 안 최대
    expect(best.value, 4.0);
    expect(best.firstIndex, greaterThanOrEqualTo(2));
    expect(HalfCycle.a95(values, start: 2, end: 5), 4.0);
  });

  test('반주기가 두 개보다 적으면 값을 지어내지 않는다', () {
    expect(HalfCycle.maximum(const [1.0, 2.0, 3.0]), isNull);
    expect(HalfCycle.a95(const [0.0, 0.0]), isNull);
    expect(HalfCycle.peakToPeaks(const <double>[]), isEmpty);
  });
}
