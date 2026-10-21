import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/noise_slow.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/travel_window.dart';

import '../../support/otis_1021_records.dart';

/// 작성: 2026-10-22 16:20:00 · nada
/// 함수: _window
/// 목적: 첨자만 보는 시험용 운행 구간. 초 · m 는 판정에 쓰지 않아 0 으로 둔다.
/// 인자: start, end — 구간 첫 · 끝 첨자 (끝 포함)
/// 반환: 운행 구간
TravelWindow _window(int start, int end) => TravelWindow(
  startIndex: start,
  endIndex: end,
  startSec: 0,
  endSec: 0,
  startM: 0,
  endM: 0,
);

/// 작성: 2026-10-22 16:20:00 · nada
/// 함수: main
/// 목적: 소음 최대용 Slow(1초) 평활(`NoiseSlow`)을 시험한다.
///       - 운행 구간 · 구간 실패 · 0(미측정) 표본을 다루는 규칙
///       - 2026-10-21 개발폰 3회 기록에서 평균은 Fast 그대로이고 최대가
///         점검 지시 값(60.3 / 56.7 / 59.8 dBA)과 ±0.2 dB 안인지
///       평활 식 자체는 `noise_weighting_test` 가 SciPy 정본과 견준다.
void main() {
  group('maxOf 규칙', () {
    test('운행 구간 밖의 큰 소리는 최대에 들지 않는다', () {
      final fast = <double>[
        ...List.filled(100, 60.0),
        ...List.filled(1000, 50.0),
      ];
      final peak = NoiseSlow.maxOf(
        fast,
        100,
        window: _window(900, 1099),
        windowFailed: false,
      ); // 구간 최대

      // 60 dBA 1초는 구간 밖이다. 그 여운(에너지 10배)은 8초 지나 e⁻⁸ 로
      // 줄어 구간 첫 표본이 50 에 0.02 dB 안이다
      expect(peak, closeTo(50.0, 0.02));
      expect(peak!, greaterThan(50.0), reason: 'Slow 여운은 남아 있다');
    });

    test('구간을 정하지 못하면 null, 구간이 없는 예전 결과는 전체', () {
      final fast = List<double>.filled(10, 55.0); // 고른 소음
      expect(
        NoiseSlow.maxOf(fast, 100, window: null, windowFailed: true),
        isNull,
      );
      expect(
        NoiseSlow.maxOf(fast, 100, window: null, windowFailed: false),
        closeTo(55.0, 1e-9),
      );
    });

    test('0(미측정)만 있으면 null 이다', () {
      expect(
        NoiseSlow.maxOf(
          List<double>.filled(10, 0.0),
          100,
          window: null,
          windowFailed: false,
        ),
        isNull,
      );
    });

    test('짧은 큰 소리는 Slow 에서 낮아진다', () {
      // 0.1초 70 dBA: Fast 최대는 70 이지만 Slow 는 1초 시정수로 덜 오른다
      final fast = <double>[
        ...List.filled(200, 50.0),
        ...List.filled(10, 70.0),
        ...List.filled(200, 50.0),
      ];
      final peak = NoiseSlow.maxOf(
        fast,
        100,
        window: null,
        windowFailed: false,
      )!; // Slow 최대

      expect(peak, lessThan(62.0));
      expect(peak, greaterThan(55.0));
    });
  });

  group('2026-10-21 개발폰 3회 (평균은 Fast 그대로, 최대 ±0.2 dB)', () {
    // 점검 지시 값. OTIS PDF 최대 대비 Fast +5.3 / +2.5 / +3.6 →
    // Slow +1.0 / −0.6 / −0.6 dB(docs/noise_otis_offset_notes.md)
    const pinned = <String, (double, double)>{
      'dev_up1': (50.7, 60.3),
      'dev_up2': (49.6, 56.7),
      'dev_down3': (50.0, 59.8),
    }; // 기록 → (평균, 최대) dBA

    for (final entry in pinned.entries) {
      test(entry.key, () {
        final result = assembleRecord(
          otis1021Records[entry.key]!,
          flipVertical: faceUpRecords.contains(entry.key),
        ).result!;
        final metrics = ReportMetrics.from(result); // 리포트 표
        final (average, peak) = entry.value;
        expect(metrics.noiseAvg.display, '${average.toStringAsFixed(1)}dBA');
        expect(metrics.noiseMax.value, closeTo(peak, 0.2));
        expect(result.noiseMax, closeTo(metrics.noiseMax.value!, 1e-9));
      });
    }
  });
}
