import 'dart:math' as math;

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/report/travel_window.dart';

/// 작성: 2026-10-22 16:20:00 · nada
/// 클래스: NoiseSlow
/// 목적: 저장된 소음열(안드로이드가 Fast 0.125초로 낸 dBA)에 1초 지수평활
///       (`CaptureConfig.noiseMaxSlowSec`, 에너지 기준)을 더해 Slow 시계열을
///       만들고, 그 운행 구간 최대를 소음 최대로 낸다. 소음 평균은 Fast 열
///       그대로다(`ReportMetrics`).
///       저장된 소음열에서 매번 다시 세므로, 2026-10-22 전 결과도 열면 최대가
///       Slow 기준으로 바뀐다(평균은 그대로).
abstract final class NoiseSlow {
  /// 작성: 2026-10-22 16:20:00 · nada
  /// 함수: methodLabel
  /// 목적: 소음 최대를 낸 방식을 결과 파일(result.json `signalConditioning`)에
  ///       남길 문자열. 소음 수집 표시(`noiseMethodLabel()`) 뒤에 붙인다.
  ///       - `noisemax(slow시정수s)` — 소음 최대는 저장된 Fast 열에 시정수
  ///         지수평활을 더한 Slow 시계열에서 냈다
  static String get methodLabel =>
      'noisemax(slow${CaptureConfig.noiseMaxSlowSec}s)';

  /// 작성: 2026-10-22 16:20:00 · nada
  /// 함수: series
  /// 목적: Fast 소음열을 Slow 시계열로 바꾼다. dB 를 에너지(10^(dB/10))로
  ///       되돌려 지수평활한 뒤 다시 dB 로 쓴다. 0(미측정) 표본은 0 그대로 두고
  ///       평활 상태도 건드리지 않는다. 첫 측정 표본은 평활 없이 그대로다.
  /// 인자: fastDba — 저장된 소음열 (dBA, 0 은 미측정)
  ///       sampleRate — 소음열 표본 속도 (Hz)
  /// 반환: Slow 소음 시계열 (dBA, 같은 길이)
  /// 식: k = 1 − exp(−(1 / sampleRate) / τ),  τ = noiseMaxSlowSec
  ///     e(i) = e(i−1) + k x (10^(L(i)/10) − e(i−1))
  ///     S(i) = 10 x log10(e(i))
  /// 근거: 표준 — IEC 61672-1 "Slow" 시정수 1초. 측정 — 2026-10-21 동시 측정
  ///       3회에서 최대가 OTIS PDF 와 +1.0 / −0.6 / −0.6 dB(Fast 는 +5.3 / +2.5
  ///       / +3.6). 이 평활로 평균을 내면 0.7 ~ 2.6 dB 올라 평균에는 쓰지
  ///       않는다(docs/noise_otis_offset_notes.md)
  static List<double> series(List<double> fastDba, double sampleRate) {
    final k = // 표본 하나만큼의 평활 비율
        1 - math.exp(-(1 / sampleRate) / CaptureConfig.noiseMaxSlowSec);
    final slow = List<double>.filled(fastDba.length, 0.0); // Slow 시계열
    double? energy; // 평활한 에너지, 첫 측정 표본 전이면 null
    for (var i = 0; i < fastDba.length; i++) {
      final level = fastDba[i]; // 이 표본 (dBA)
      if (level == 0) continue; // 미측정은 0 그대로, 상태도 그대로
      final power = math.pow(10, level / 10).toDouble(); // 이 표본 에너지
      final previous = energy; // 앞 표본까지 평활한 에너지
      if (previous == null) {
        // 첫 측정 표본은 dB 를 그대로 둔다 — 에너지로 바꿨다 되돌리면
        // 기준치와 같은 값이 반올림 오차로 "초과" 가 될 수 있다
        energy = power;
        slow[i] = level;
        continue;
      }
      final next = previous + k * (power - previous); // 평활한 에너지
      energy = next;
      slow[i] = 10 * math.log(next) / math.ln10;
    }
    return slow;
  }

  /// 작성: 2026-10-22 16:20:00 · nada
  /// 함수: maxOf
  /// 목적: 소음 최대를 낸다 — Slow 시계열(`series()`)의 운행 구간 안 0 이
  ///       아닌 표본의 최대.
  ///       - 운행 구간이 있으면 그 구간
  ///       - 구간을 정하지 못한 결과면 null(진동 지표와 같이 비운다)
  ///       - 둘 다 없는 예전 결과면 측정 전체
  /// 인자: fastDba — 저장된 소음열 (dBA)
  ///       sampleRate — 소음열 표본 속도 (Hz)
  ///       window — 운행 구간. 없으면 null
  ///       windowFailed — 운행 구간을 정하지 못했는지
  /// 반환: 소음 최대 (dBA). 쓸 표본이 없으면 null
  static double? maxOf(
    List<double> fastDba,
    double sampleRate, {
    required TravelWindow? window,
    required bool windowFailed,
  }) {
    if (windowFailed) return null;
    final slow = series(fastDba, sampleRate); // Slow 시계열
    final from = window == null
        ? 0
        : math.min(window.startIndex, slow.length); // 구간 시작
    final to = window == null
        ? slow.length
        : math.min(window.endIndex + 1, slow.length); // 구간 끝 (제외)
    double? peak; // 여기까지 본 최대
    for (var i = from; i < to; i++) {
      final value = slow[i]; // 이 표본 (dBA)
      if (value == 0) continue;
      if (peak == null || value > peak) peak = value;
    }
    return peak;
  }
}
