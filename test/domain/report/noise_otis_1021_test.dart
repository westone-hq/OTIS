import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';

import '../../support/reference_records.dart';

/// 작성: 2026-10-22 18:30:00 · nada
/// 함수: main
/// 목적: 2026-10-21 개발폰 3회 기록의 소음 평균 · 최대(Fast 열, 운행 구간)를
///       고정한다. 2026-10-22 에 최대만 Slow(1초)로 냈다가 같은 날 되돌려,
///       평균 · 최대 · 차트가 모두 저장된 Fast 열에서 나온다.
///       OTIS PDF 최대(59.3 / 57.3 / 60.4) 대비 +5.3 / +2.5 / +3.6 dB 는 폰
///       위치 오프셋과 개발폰 마이크 차이로 보고 코드로 맞추지 않는다
///       (docs/experiments/noise_otis_offset_notes.md).
void main() {
  const pinned = <String, (double, double)>{
    'dev_up1': (50.7, 64.6),
    'dev_up2': (49.6, 59.8),
    'dev_down3': (50.0, 64.0),
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
      expect(metrics.noiseMax.display, '${peak.toStringAsFixed(1)}dBA');
      expect(metrics.noiseMax.value, result.noiseMax, reason: '저장 값 그대로');
    });
  }
}
