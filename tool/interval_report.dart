import 'dart:io';

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/sample_interval.dart';

/// 목적: 측정 원본 파일(raw_native_*.txt)에서 간격 통계 보고를 출력한다.
///       주기 확인·간격 편차 판정의 회의 자료를 만드는 명령줄 도구.
/// 사용: dart run tool/interval_report.dart <파일경로> [목표주기Hz]
///       목표주기를 생략하면 기본값(CaptureConfig)을 쓴다.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('사용법: dart run tool/interval_report.dart <파일경로> [목표주기Hz]');
    exitCode = 2;
    return;
  }
  final path = args[0];
  if (!File(path).existsSync()) {
    stdout.writeln('파일이 없습니다: $path');
    exitCode = 2;
    return;
  }
  final targetHz = args.length > 1
      ? int.tryParse(args[1]) ?? CaptureConfig.defaultTargetSampleRateHz
      : CaptureConfig.defaultTargetSampleRateHz;
  final config = CaptureConfig(targetSampleRateHz: targetHz);

  final result = await NativeEventRecord.readFile(path);
  stdout.writeln('파일: $path');
  stdout.writeln(
    '판독: ${result.events.length}건, 폐기 ${result.skippedLineCount}건',
  );
  stdout.writeln('');

  for (final type in [NativeEventType.accel, NativeEventType.gravity]) {
    final intervals = SampleInterval.intervalsUs(result.events, type);
    final stats = IntervalStats.from(intervals, config: config);
    stdout.writeln(stats.toReportText(label: type.name, config: config));

    final mismatch =
        SampleInterval.recordedDtMismatchCount(result.events, type);
    stdout.writeln('  기록 dtUs 대조 불일치: $mismatch건 (0이어야 정상)');
    stdout.writeln('');
  }
}
