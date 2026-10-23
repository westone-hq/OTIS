import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/storage/evimp_writer.dart';
import 'package:vibration_checker/adapter/storage/meta_writer.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';

/// 작성: 2026-10-21 23:20:00 · 박건준
/// 함수: _grid
/// 목적: 축마다 영점 오차(치우침)가 얹힌 256Hz 격자를 만든다. 진동은
///       사인파, 소음은 50 dBA 근처다.
/// 반환: 격자 환산 결과
GridResampleResult _grid() {
  final rows = <GridSample>[
    for (var i = 0; i < 1024; i++)
      GridSample(
        xMg: 5.0 + 2 * math.sin(2 * math.pi * i / 37),
        yMg: -3.0 + math.sin(2 * math.pi * i / 23),
        zMg: -13.6 + 4 * math.sin(2 * math.pi * i / 51),
        noiseDba: 50.0 + (i % 7),
      ),
  ]; // 격자 행
  return GridResampleResult(
    samples: rows,
    t0Ns: 0,
    gridIntervalNs: 3906250,
    rawUsedCount: rows.length,
    gravityUsedCount: rows.length,
    droppedZeroCount: 0,
    droppedBackwardCount: 0,
    droppedLinearCount: 0,
    headTrimmedRows: 0,
    tailTrimmedRows: 0,
    rawMaxSpanNs: 0,
    gravityMaxSpanNs: 0,
    degenerateSpanCount: 0,
  );
}

/// 작성: 2026-10-21 23:20:00 · 박건준
/// 함수: main
/// 목적: 값 파일(raw.txt)이 OTIS EVIMP1 관례대로 축별 전체 평균을 빼고
///       쓰이는지, 소음 열은 그대로인지, 뺀 평균이 집계 파일에 남는지 본다.
void main() {
  test('raw.txt 의 진동 세 축은 평균이 0 이고 소음은 그대로다', () {
    final grid = _grid(); // 치우친 격자
    final lines = EvimpWriter.encode(
      grid,
    ).split(EvimpWriter.lineEnding).where((l) => l.isNotEmpty).toList();
    expect(lines.sublist(0, 2), <String>['EVIMP1', '256']);

    final rows = <List<double>>[
      for (final line in lines.skip(2))
        line.split(' ').map(double.parse).toList(),
    ]; // 값 행
    for (var axis = 0; axis < 3; axis++) {
      final mean =
          rows.map((r) => r[axis]).reduce((a, b) => a + b) / rows.length;
      expect(mean.abs(), lessThan(0.01), reason: '축 $axis');
    }
    // 평균만 빠지고 모양은 그대로다
    final mean = EvimpWriter.axisMeans(grid); // 뺀 평균
    expect(rows[10][2], closeTo(grid.samples[10].zMg - mean.z, 0.0005));
    for (var i = 0; i < rows.length; i++) {
      expect(rows[i][3], grid.samples[i].noiseDba, reason: '소음 $i');
    }
  });

  test('뺀 평균을 집계 파일에 적는다', () {
    final meta = MetaWriter.encodeMeta(_grid()); // 집계 문자열
    final mean = EvimpWriter.axisMeans(_grid()); // 뺀 평균
    expect(mean.z, closeTo(-13.6, 0.1));
    expect(meta, contains('rawExportMeanZmg: ${mean.z.toStringAsFixed(3)}'));
    expect(meta, contains('rawExportMeanXmg: '));
    expect(meta, contains('rawExportMeanYmg: '));
  });
}
