import 'dart:io';

import 'package:vibration_checker/domain/analysis/measurement_assembler.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-10-21 10:05:00 · nada
/// 수정: 2026-10-23 01:10:00 · nada
/// 변수: rideReferencePath
/// 목적: 원본 TUNE 리포트를 만든 레퍼런스폰 기록 경로. 실측 기록으로 남은
///       회귀 기준이다(`docs/experiments/ride_reference_기준값.md`).
const String rideReferencePath = 'test/fixtures/records/ride_reference.txt';

/// 작성: 2026-10-21 10:05:00 · nada
/// 수정: 2026-10-23 01:10:00 · nada
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
/// 수정: 2026-10-23 01:10:00 · nada
/// 함수: assembleRecord
/// 목적: 원시데이터 한 건을 앱 저장 절차와 같은 길(신호 처리 → 조립)로
///       측정 결과로 바꾼다.
/// 인자: path — 저장소 루트 기준 EVIMP1 파일 경로
///       site — 현장 정보. 안 주면 상승 1 → 8층 시험용 현장
///       deviceModel — 기종 이름. 안 주면 기종 응답 보정 없음(외부 기록)
/// 반환: 조립 결과(측정 결과와 움직인 구간)
MeasurementAssembleResult assembleRecord(
  String path, {
  SiteInfo? site,
  String? deviceModel,
}) {
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
    deviceModel: deviceModel,
  );
}
