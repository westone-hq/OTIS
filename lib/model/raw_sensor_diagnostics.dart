import 'sensor_sample.dart';

/// 단일 채널(min/max/mean/P-P) 통계
class ChannelStats {
  final bool available;
  final double min;
  final double max;
  final double mean;
  final double peakToPeak;

  const ChannelStats({
    required this.available,
    this.min = 0,
    this.max = 0,
    this.mean = 0,
    this.peakToPeak = 0,
  });

  static const unavailable = ChannelStats(available: false);

  factory ChannelStats.fromValues(List<double> values) {
    if (values.isEmpty) return unavailable;
    double minVal = values.first;
    double maxVal = values.first;
    double sum = 0;
    for (final v in values) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
      sum += v;
    }
    return ChannelStats(
      available: true,
      min: minVal,
      max: maxVal,
      mean: sum / values.length,
      peakToPeak: maxVal - minVal,
    );
  }
}

/// 원본 센서 RAW 샘플 요약 (결과 화면 진단용)
class RawSensorDiagnostics {
  final int sampleCount;
  final double durationSec;
  final double sampleRateHz;
  final bool hasExtendedRaw;
  final int tsUsStart;
  final int tsUsEnd;

  final ChannelStats linearX;
  final ChannelStats linearY;
  final ChannelStats linearZ;
  final ChannelStats rawX;
  final ChannelStats rawY;
  final ChannelStats rawZ;
  final ChannelStats gravityX;
  final ChannelStats gravityY;
  final ChannelStats gravityZ;
  final ChannelStats motionX;
  final ChannelStats motionY;
  final ChannelStats motionZ;
  final ChannelStats noise;

  const RawSensorDiagnostics({
    required this.sampleCount,
    required this.durationSec,
    required this.sampleRateHz,
    required this.hasExtendedRaw,
    required this.tsUsStart,
    required this.tsUsEnd,
    required this.linearX,
    required this.linearY,
    required this.linearZ,
    required this.rawX,
    required this.rawY,
    required this.rawZ,
    required this.gravityX,
    required this.gravityY,
    required this.gravityZ,
    required this.motionX,
    required this.motionY,
    required this.motionZ,
    required this.noise,
  });

  factory RawSensorDiagnostics.fromSamples(
    List<SensorSample> samples, {
    double sampleRateHz = 256,
  }) {
    if (samples.isEmpty) {
      return RawSensorDiagnostics(
        sampleCount: 0,
        durationSec: 0,
        sampleRateHz: sampleRateHz,
        hasExtendedRaw: false,
        tsUsStart: 0,
        tsUsEnd: 0,
        linearX: ChannelStats.unavailable,
        linearY: ChannelStats.unavailable,
        linearZ: ChannelStats.unavailable,
        rawX: ChannelStats.unavailable,
        rawY: ChannelStats.unavailable,
        rawZ: ChannelStats.unavailable,
        gravityX: ChannelStats.unavailable,
        gravityY: ChannelStats.unavailable,
        gravityZ: ChannelStats.unavailable,
        motionX: ChannelStats.unavailable,
        motionY: ChannelStats.unavailable,
        motionZ: ChannelStats.unavailable,
        noise: ChannelStats.unavailable,
      );
    }

    final hasExtended = samples.any(
      (s) => s.rawX != null && s.gravityX != null,
    );

    List<double> pick(double? Function(SensorSample) get) {
      return samples
          .map(get)
          .whereType<double>()
          .toList(growable: false);
    }

    List<double> pickMotion(double Function(SensorSample) get) {
      return samples.map(get).toList(growable: false);
    }

    final tsStart = samples.first.tsUs;
    final tsEnd = samples.last.tsUs;
    final duration = (tsEnd - tsStart) / 1000000.0;

    return RawSensorDiagnostics(
      sampleCount: samples.length,
      durationSec: duration > 0 ? duration : samples.length / sampleRateHz,
      sampleRateHz: sampleRateHz,
      hasExtendedRaw: hasExtended,
      tsUsStart: tsStart,
      tsUsEnd: tsEnd,
      linearX: ChannelStats.fromValues(samples.map((s) => s.x).toList()),
      linearY: ChannelStats.fromValues(samples.map((s) => s.y).toList()),
      linearZ: ChannelStats.fromValues(samples.map((s) => s.z).toList()),
      rawX: ChannelStats.fromValues(pick((s) => s.rawX)),
      rawY: ChannelStats.fromValues(pick((s) => s.rawY)),
      rawZ: ChannelStats.fromValues(pick((s) => s.rawZ)),
      gravityX: ChannelStats.fromValues(pick((s) => s.gravityX)),
      gravityY: ChannelStats.fromValues(pick((s) => s.gravityY)),
      gravityZ: ChannelStats.fromValues(pick((s) => s.gravityZ)),
      motionX: ChannelStats.fromValues(pickMotion((s) => s.motionX)),
      motionY: ChannelStats.fromValues(pickMotion((s) => s.motionY)),
      motionZ: ChannelStats.fromValues(pickMotion((s) => s.motionZ)),
      noise: ChannelStats.fromValues(samples.map((s) => s.noiseDba).toList()),
    );
  }
}

/// rawSamples에서 시작/중간/끝 대표 행 추출
List<SensorSample> selectRawPreviewSamples(
  List<SensorSample> samples, {
  int edgeCount = 3,
}) {
  if (samples.length <= edgeCount * 2) return List.from(samples);
  final mid = samples.length ~/ 2;
  return [
    ...samples.take(edgeCount),
    samples[mid],
    ...samples.skip(samples.length - edgeCount),
  ];
}

String formatRawSampleLine(SensorSample s, {required bool extended}) {
  if (!extended) {
    return '${s.x.toStringAsFixed(2)} ${s.y.toStringAsFixed(2)} '
        '${s.z.toStringAsFixed(2)} ${s.noiseDba.toStringAsFixed(1)}';
  }
  String n(double? v) => v == null ? 'null' : v.toStringAsFixed(1);
  return '${s.tsUs} ${s.x.toStringAsFixed(1)} ${s.y.toStringAsFixed(1)} '
      '${s.z.toStringAsFixed(1)} ${s.noiseDba.toStringAsFixed(1)} '
      '${n(s.rawX)} ${n(s.rawY)} ${n(s.rawZ)} '
      '${n(s.gravityX)} ${n(s.gravityY)} ${n(s.gravityZ)}';
}

/// raw.txt를 사람이 읽기 쉽게 정리한 요약 텍스트 (메일 첨부용)
String writeRawSummaryText(
  List<SensorSample> samples, {
  double sampleRateHz = 256,
  String? jobNo,
  String? siteName,
  DateTime? dateTime,
}) {
  final diag = RawSensorDiagnostics.fromSamples(
    samples,
    sampleRateHz: sampleRateHz,
  );
  final buf = StringBuffer();

  buf.writeln('[OTIS 원본 센서 데이터 정리본]');
  buf.writeln('※ 이 파일은 필터/Aptp 적용 전 센서 기록 요약입니다.');
  buf.writeln('※ 전체 샘플 원본은 raw.txt 를 보세요.');
  buf.writeln('----------------------------------------');
  if (jobNo != null) buf.writeln('제번: $jobNo');
  if (siteName != null) buf.writeln('현장: $siteName');
  if (dateTime != null) {
    buf.writeln(
      '일시: ${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}',
    );
  }
  buf.writeln('샘플 수: ${diag.sampleCount}');
  buf.writeln('측정 시간: ${diag.durationSec.toStringAsFixed(2)} 초');
  buf.writeln('샘플레이트: ${diag.sampleRateHz.toStringAsFixed(0)} Hz');
  buf.writeln('단위: mg (가속도), dBA (소음)');
  buf.writeln(
    '포맷: ${diag.hasExtendedRaw ? '확장(linear+raw+gravity)' : '기본(linear만)'}',
  );
  buf.writeln('----------------------------------------');

  String ch(String name, ChannelStats s, {String unit = 'mg'}) {
    if (!s.available) return '$name: (데이터 없음)';
    return '$name: min ${s.min.toStringAsFixed(2)} / '
        'max ${s.max.toStringAsFixed(2)} / '
        'mean ${s.mean.toStringAsFixed(2)} / '
        'P-P ${s.peakToPeak.toStringAsFixed(2)} $unit';
  }

  buf.writeln('[1] Linear XYZ (중력 제외 · 진동용)');
  buf.writeln(ch('  X', diag.linearX));
  buf.writeln(ch('  Y', diag.linearY));
  buf.writeln(ch('  Z', diag.linearZ));
  buf.writeln('');
  buf.writeln('[2] Raw XYZ (가속도계 원값 · 중력 포함)');
  buf.writeln(ch('  X', diag.rawX));
  buf.writeln(ch('  Y', diag.rawY));
  buf.writeln(ch('  Z', diag.rawZ));
  buf.writeln('');
  buf.writeln('[3] Gravity XYZ (중력 추정)');
  buf.writeln(ch('  X', diag.gravityX));
  buf.writeln(ch('  Y', diag.gravityY));
  buf.writeln(ch('  Z', diag.gravityZ));
  buf.writeln('');
  buf.writeln('[4] Motion XYZ (raw - gravity · 거리/속도용)');
  buf.writeln(ch('  X', diag.motionX));
  buf.writeln(ch('  Y', diag.motionY));
  buf.writeln(ch('  Z', diag.motionZ));
  buf.writeln('');
  buf.writeln('[5] 소음');
  buf.writeln(ch('  noise', diag.noise, unit: 'dBA'));
  buf.writeln('----------------------------------------');
  buf.writeln('[6] 대표 샘플 (시작·중간·끝)');
  buf.writeln(
    diag.hasExtendedRaw
        ? '# tsUs linX linY linZ noise rawX rawY rawZ gX gY gZ'
        : '# linX linY linZ noise',
  );
  for (final s in selectRawPreviewSamples(samples, edgeCount: 8)) {
    buf.writeln(formatRawSampleLine(s, extended: diag.hasExtendedRaw));
  }
  buf.writeln('----------------------------------------');
  buf.writeln('끝.');
  return buf.toString();
}
