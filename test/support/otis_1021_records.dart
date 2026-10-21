import 'dart:io';

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

/// 작성: 2026-10-21 10:05:00 · nada
/// 변수: otis1021Records
/// 목적: 2026-10-21 서일대 동시 측정 원시데이터(EVIMP1 256Hz) 6건의 이름과
///       경로. 파일 이름이 헷갈리기 쉬워("(1)" 붙은 것이 하강) 시험은 이
///       이름으로만 부른다. 짝은 첫 데이터 행과 소음 · 진동 곡선 상관(0.98 ~
///       0.99)으로 맞췄다(작업메모_20261021.md).
///       - dev_* — 개발폰 앱 raw 내보내기, otis_* — 오티스폰 EVIMP1 내보내기
///       - up1 · up2 는 상승, down3 은 하강
const Map<String, String> otis1021Records = <String, String>{
  'dev_up1': 'docs/reference/Reference1.txt',
  'dev_up2': 'docs/reference/Reference2.txt',
  'dev_down3': 'docs/reference/Reference1 (1).txt',
  'otis_up1': 'docs/reference/OITS1.txt',
  'otis_up2': 'docs/reference/OITS2.txt',
  'otis_down3': 'docs/reference/OITS1 (1).txt',
};

/// 작성: 2026-10-21 10:05:00 · nada
/// 변수: rideReferencePath
/// 목적: 원본 리포트(H6N1AP65)를 만든 레퍼런스폰 기록 경로.
const String rideReferencePath = 'test/fixtures/ride_reference.txt';

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: readEvimpGrid
/// 목적: EVIMP1 파일(머리 2줄 뒤 "X Y Z 소음" 행)을 256Hz 격자로 읽는다.
///       앱이 저장 절차에서 만드는 격자와 같은 모양이다.
/// 인자: path — 저장소 루트 기준 파일 경로
/// 반환: 256Hz 격자 환산 결과
GridResampleResult readEvimpGrid(String path) {
  final lines = File(path)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(); // 빈 줄을 뺀 파일 줄
  final rows = <GridSample>[
    for (final line in lines.sublist(2))
      () {
        final f = line.split(RegExp(r'\s+')); // 열 값
        return GridSample(
          xMg: double.parse(f[0]),
          yMg: double.parse(f[1]),
          zMg: double.parse(f[2]),
          noiseDba: f.length > 3 ? double.parse(f[3]) : 0.0,
        );
      }(),
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

/// 작성: 2026-10-21 10:05:00 · nada
/// 함수: assembleRecord
/// 목적: 원시데이터 한 건을 앱 저장 절차와 같은 길(신호 처리 → 조립)로
///       측정 결과로 바꾼다.
/// 인자: path — 저장소 루트 기준 EVIMP1 파일 경로
///       site — 현장 정보. 안 주면 상승 1 → 8층 시험용 현장
/// 반환: 조립 결과(측정 결과와 움직인 구간)
MeasurementAssembleResult assembleRecord(String path, {SiteInfo? site}) {
  return MeasurementAssembler.assemble(
    grid: const SignalConditioner(
      config: CaptureConfig(),
    ).condition(readEvimpGrid(path)).grid,
    site:
        site ??
        const SiteInfo(
          jobNo: 'J',
          siteName: 'S',
          address: 'A',
          postalCode: '00000',
          bottomFloor: '1',
          topFloor: '8',
          direction: SiteInfo.directionUp,
          model: SiteInfo.defaultModel,
          load: '1000',
        ),
    id: 'id',
    measuredAt: DateTime.utc(2026, 10, 21),
  );
}
