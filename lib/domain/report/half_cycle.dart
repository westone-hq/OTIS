/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: HalfCyclePeak
/// 목적: 반주기(신호가 0 을 지나 다음에 다시 0 을 지날 때까지) 하나의 가장
///       큰 크기와 그 자리.
class HalfCyclePeak {
  /// 그 반주기에서 크기가 가장 큰 표본의 자리 (시계열 첨자)
  final int index;

  /// 그 표본의 크기 (mg, 절댓값)
  final double magnitude;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: HalfCyclePeak
  /// 목적: 값을 담는다.
  /// 인자: index, magnitude — 위 필드
  const HalfCyclePeak(this.index, this.magnitude);
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: HalfCyclePeakToPeak
/// 목적: 이웃한 두 반주기(봉우리와 골) 크기의 합 하나와 그 두 자리.
class HalfCyclePeakToPeak {
  /// P2P (mg). 두 반주기 크기의 합
  final double value;

  /// 앞 반주기 봉우리(또는 골)의 자리 (시계열 첨자)
  final int firstIndex;

  /// 뒤 반주기 골(또는 봉우리)의 자리 (시계열 첨자)
  final int secondIndex;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: HalfCyclePeakToPeak
  /// 목적: 값을 담는다.
  /// 인자: value, firstIndex, secondIndex — 위 필드
  const HalfCyclePeakToPeak(this.value, this.firstIndex, this.secondIndex);
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: HalfCycle
/// 목적: 진동 지표 두 개(최대 P2P, A95)를 같은 정의 — 이웃한 봉우리 · 골
///       의 반주기 P2P — 에서 낸다. 정의를 이 한 곳에 둬 두 지표와 차트
///       표시점이 서로 다른 계산을 하지 않게 한다.
///       신호가 0 을 지날 때마다 반주기로 끊고, 반주기마다 가장 큰 크기를
///       잡는다. 이웃한 두 반주기의 크기를 더한 것이 반주기 P2P 다. 정확히
///       0 인 표본은 어느 쪽 부호도 아니라 반주기를 끊지 않는다.
/// 근거: 인용 — ISO 18738 의 P2P(0 을 한 번 지나는 사이 부호가 반대인 두
///       봉우리 크기의 합)와 A95(그 값들의 95%가 이하가 되는 값) 정의.
///       2026-10-15 점검 지시 "최대 P2P = 이웃한 봉우리 · 골(반주기) P2P 의
///       최댓값". 예전 "전체 최대 − 전체 최소" 는 출발 · 정지 가감속처럼
///       느린 흐름이 그대로 들어가 원본 리포트와 달랐다
abstract final class HalfCycle {
  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: peaks
  /// 목적: 구간 안의 반주기마다 가장 큰 크기와 그 자리를 차례로 모은다.
  /// 인자: series — 한 축 진동 시계열 (mg)
  ///       start — 볼 구간의 첫 첨자 (포함). 기본 0
  ///       end — 볼 구간의 끝 첨자 (포함). 기본 마지막
  /// 반환: 반주기 차례대로의 봉우리 목록. 구간이 비었으면 빈 목록
  static List<HalfCyclePeak> peaks(
    List<double> series, {
    int start = 0,
    int? end,
  }) {
    final last = end ?? series.length - 1; // 볼 구간의 끝 첨자 (포함)
    final result = <HalfCyclePeak>[]; // 모은 봉우리
    var current = 0.0; // 지금 반주기에서 본 가장 큰 크기 (mg)
    var currentIndex = -1; // 그 크기의 자리. 아직 못 봤으면 -1
    var sign = 0; // 지금 반주기의 부호. 아직 0 아닌 값을 못 봤으면 0
    for (var i = start; i <= last; i++) {
      final value = series[i]; // 이 표본 (mg)
      final s = value > 0 ? 1 : (value < 0 ? -1 : 0); // 이 표본의 부호
      if (s == 0) continue;
      if (sign != 0 && s != sign) {
        result.add(HalfCyclePeak(currentIndex, current));
        current = 0.0;
        currentIndex = -1;
      }
      sign = s;
      if (value.abs() > current) {
        current = value.abs();
        currentIndex = i;
      }
    }
    if (sign != 0) result.add(HalfCyclePeak(currentIndex, current));
    return result;
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: peakToPeaks
  /// 목적: 이웃한 두 반주기마다 P2P 를 만든다.
  /// 인자: series, start, end — `peaks()` 와 같다
  /// 반환: 반주기 P2P 목록 (시간 차례). 반주기가 두 개보다 적으면 빈 목록
  /// 식: P2P_i = |봉우리_i| + |봉우리_i+1|
  static List<HalfCyclePeakToPeak> peakToPeaks(
    List<double> series, {
    int start = 0,
    int? end,
  }) {
    // → 로직 이동: peaks()
    final found = peaks(series, start: start, end: end); // 반주기 봉우리
    return <HalfCyclePeakToPeak>[
      for (var i = 0; i + 1 < found.length; i++)
        HalfCyclePeakToPeak(
          found[i].magnitude + found[i + 1].magnitude,
          found[i].index,
          found[i + 1].index,
        ),
    ];
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: maximum
  /// 목적: 반주기 P2P 가운데 가장 큰 것을 찾는다. 리포트의 "최대 진동" 과
  ///       차트 빨간 점 두 자리가 이것이다. 같은 값이 여럿이면 처음 것.
  /// 인자: series, start, end — `peaks()` 와 같다
  /// 반환: 가장 큰 반주기 P2P. 하나도 못 만들면 null
  static HalfCyclePeakToPeak? maximum(
    List<double> series, {
    int start = 0,
    int? end,
  }) {
    HalfCyclePeakToPeak? best; // 여기까지 본 가장 큰 것
    // → 로직 이동: peakToPeaks()
    for (final p2p in peakToPeaks(series, start: start, end: end)) {
      if (best == null || p2p.value > best.value) best = p2p;
    }
    return best;
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: a95
  /// 목적: 반주기 P2P 의 95백분위를 낸다. 리포트의 "평균 진동" 이다.
  /// 인자: series, start, end — `peaks()` 와 같다
  /// 반환: A95 (mg). 반주기 P2P 를 하나도 못 만들면 null
  /// 식: A95 = 오름차순 정렬한 P2P 의 ceil(0.95 × n) 번째 값
  /// 근거: 인용 — ISO 18738 A95 정의.
  ///       미확인: 표준이 쓰는 백분위 보간 방식. 최근접 순위로 낸다
  static double? a95(List<double> series, {int start = 0, int? end}) {
    final values = <double>[
      // → 로직 이동: peakToPeaks()
      for (final p2p in peakToPeaks(series, start: start, end: end)) p2p.value,
    ]..sort(); // 반주기 P2P, 작은 것부터
    if (values.isEmpty) return null;
    final rank = (0.95 * values.length).ceil(); // 95백분위의 순위 (1부터)
    return values[rank - 1];
  }
}
