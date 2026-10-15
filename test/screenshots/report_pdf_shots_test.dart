@Tags(['screenshot'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/model/measurement_result.dart';

import 'shot_harness.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _reference
/// 목적: 원본 리포트를 만든 기록(ride_reference)을 앱과 같은 길로 조립한다.
///       변경 전 · 후 코드에 모두 있는 함수만 쓴다.
/// 반환: 조립한 측정 결과
MeasurementResult _reference() {
  final lines = const LineSplitter()
      .convert(File('test/fixtures/ride_reference.txt').readAsStringSync())
      .where((line) => line.trim().isNotEmpty)
      .toList(); // 파일 줄
  final rows = <GridSample>[
    for (final line in lines.sublist(2))
      () {
        final f = line.trim().split(RegExp(r'\s+')); // 열 값
        return GridSample(
          xMg: double.parse(f[0]),
          yMg: double.parse(f[1]),
          zMg: double.parse(f[2]),
          noiseDba: double.parse(f[3]),
        );
      }(),
  ]; // 256Hz 격자 행
  final grid = GridResampleResult(
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
  ); // 격자
  return MeasurementAssembler.assemble(
    grid: const SignalConditioner(config: CaptureConfig()).condition(grid).grid,
    site: const SiteInfo(
      jobNo: '2025F 1234R01',
      siteName: '시험 현장',
      address: '경기도 고양시 덕양구 오금동',
      postalCode: '10575',
      bottomFloor: '1',
      topFloor: '8',
      direction: SiteInfo.directionUp,
      model: 'Gen2',
      load: '2000',
    ),
    id: 'shot',
    measuredAt: DateTime.utc(2026, 1, 14, 2, 3, 59),
    engineerName: '홍길동',
  ).result!;
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 리포트 PDF 세 가지를 만든다. 예전 커밋에서도 이 파일을 돌려 변경
///       전 PDF 를 얻는다. 파일 이름 머리는 `SHOT_PREFIX`.
///       - a 실측 — ride_reference
///       - b 신호등 — 같은 자료에서 지표만 바꿔 초록 · 노랑 · 빨강이 다 나옴
///       - c 예전 결과 — 진동 · 소음 지표가 없는(미측정) 처리 전 결과
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final prefix = Platform.environment['SHOT_PREFIX'] ?? '후'; // 전 · 후 표시

  test('리포트 PDF', () async {
    final out = shotOutputDir(); // 쓸 폴더
    final real = _reference(); // 실측 결과
    final colors = real.copyWith(
      zA95: 15.0, // 황색 (14 초과)
      zPtp: 31.0, // 적색 (30 초과)
      xA95: 12.0, // 황색 (9 초과)
      yA95: 3.0,
      xPtp: 26.0, // 적색 (25.5 초과)
      yPtp: 8.0,
      noiseMax: 73.0, // 황색 (72 초과)
    ); // 세 색이 다 나오는 결과
    final legacy = MeasurementResult(
      id: 'legacy',
      jobNo: '2024F 0001R01',
      siteName: '예전 현장',
      bottomFloor: 1,
      topFloor: 5,
      direction: '하부 → 상부',
      dateTime: DateTime.utc(2025, 12, 1, 1),
      distance: real.distance,
      maxSpeed: real.maxSpeed,
      xSeries: real.xSeries,
      ySeries: real.ySeries,
      zSeries: real.zSeries,
      noiseSeries: real.noiseSeries,
      positionSeries: real.positionSeries,
      speedSeries: real.speedSeries,
      accelSeries: real.accelSeries,
      jerkSeries: real.jerkSeries,
      sampleRate: real.sampleRate,
    ); // 지표가 없는 예전 결과

    for (final entry in <String, MeasurementResult>{
      'a_실측': real,
      'b_신호등': colors,
      'c_예전결과': legacy,
    }.entries) {
      final builder = await TuneReportBuilder.load(); // 리포트 한 부
      File(
        '${out.path}/${prefix}_${entry.key}.pdf',
      ).writeAsBytesSync(await builder.build(entry.value));
    }
  });
}
