import 'sensor_sample.dart';

/// raw_readable.txt 생성 설정
///
/// - [raw.txt]는 EVIMP1 기계 포맷 그대로 (변경 없음)
/// - 이 파일은 256Hz 전체 샘플을 빠짐없이 출력 (1초 = 256블록)
class RawReadableExport {
  /// 원본 센서 샘플레이트 (Hz)
  static const double defaultSampleRateHz = 256;

  /// 256Hz에서 샘플 하나당 시간 간격 (초) ≈ 0.00390625
  static double samplePeriodSec(double sampleRateHz) {
    return sampleRateHz > 0 ? 1.0 / sampleRateHz : 1.0 / defaultSampleRateHz;
  }

  /// 첫 tsUs 기준 상대 시간(초)
  static double relativeTimeSec(int tsUs, int baseTsUs) {
    return (tsUs - baseTsUs) / 1000000.0;
  }
}

/// 한 시점의 원초(raw) + 중력보정(motion) 적분 결과
class ReadableIntegrationRow {
  /// 원초 센서값 (mg) — rawX/Y/Z, 없으면 linear
  final double rawX;
  final double rawY;
  final double rawZ;

  /// 원초 1차 적분 = 속도 (m/s)
  final double rawIntegral1X;
  final double rawIntegral1Y;
  final double rawIntegral1Z;

  /// 원초 2차 적분 = 누적 거리 (m)
  final double rawIntegral2X;
  final double rawIntegral2Y;
  final double rawIntegral2Z;

  /// 중력보정값 (mg) — raw − gravity, 없으면 linear
  final double motionX;
  final double motionY;
  final double motionZ;

  /// 중력보정 1차 적분 = 속도 (m/s)
  final double motionIntegral1X;
  final double motionIntegral1Y;
  final double motionIntegral1Z;

  /// 중력보정 2차 적분 = 누적 거리 (m)
  final double motionIntegral2X;
  final double motionIntegral2Y;
  final double motionIntegral2Z;

  const ReadableIntegrationRow({
    required this.rawX,
    required this.rawY,
    required this.rawZ,
    required this.rawIntegral1X,
    required this.rawIntegral1Y,
    required this.rawIntegral1Z,
    required this.rawIntegral2X,
    required this.rawIntegral2Y,
    required this.rawIntegral2Z,
    required this.motionX,
    required this.motionY,
    required this.motionZ,
    required this.motionIntegral1X,
    required this.motionIntegral1Y,
    required this.motionIntegral1Z,
    required this.motionIntegral2X,
    required this.motionIntegral2Y,
    required this.motionIntegral2Z,
  });

  static const zero = ReadableIntegrationRow(
    rawX: 0,
    rawY: 0,
    rawZ: 0,
    rawIntegral1X: 0,
    rawIntegral1Y: 0,
    rawIntegral1Z: 0,
    rawIntegral2X: 0,
    rawIntegral2Y: 0,
    rawIntegral2Z: 0,
    motionX: 0,
    motionY: 0,
    motionZ: 0,
    motionIntegral1X: 0,
    motionIntegral1Y: 0,
    motionIntegral1Z: 0,
    motionIntegral2X: 0,
    motionIntegral2Y: 0,
    motionIntegral2Z: 0,
  );
}

/// 원초(raw)와 중력보정(motion) 각각 사다리꼴 이중적분
///
/// - 필터·baseline 없음 (검증용)
/// - 앱 최종 distance/maxSpeed 와 무관
class ReadableSensorIntegrator {
  static const double maxValidDtSec = 1.0;

  static double rawValueX(SensorSample s) => s.rawX ?? s.x;
  static double rawValueY(SensorSample s) => s.rawY ?? s.y;
  static double rawValueZ(SensorSample s) => s.rawZ ?? s.z;

  static List<ReadableIntegrationRow> compute(List<SensorSample> samples) {
    if (samples.isEmpty) return [];

    final rows = List<ReadableIntegrationRow>.filled(
      samples.length,
      ReadableIntegrationRow.zero,
    );

    // 원초(raw) 적분 상태
    double rawVelX = 0, rawVelY = 0, rawVelZ = 0;
    double rawDistX = 0, rawDistY = 0, rawDistZ = 0;
    double prevRawAccelX = 0, prevRawAccelY = 0, prevRawAccelZ = 0;

    // 중력보정(motion) 적분 상태
    double motVelX = 0, motVelY = 0, motVelZ = 0;
    double motDistX = 0, motDistY = 0, motDistZ = 0;
    double prevMotAccelX = 0, prevMotAccelY = 0, prevMotAccelZ = 0;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];

      final rawX = rawValueX(s);
      final rawY = rawValueY(s);
      final rawZ = rawValueZ(s);
      final motionX = s.motionX;
      final motionY = s.motionY;
      final motionZ = s.motionZ;

      final rawAccelX = rawX * SensorSample.mgToMetersPerSecondSquared;
      final rawAccelY = rawY * SensorSample.mgToMetersPerSecondSquared;
      final rawAccelZ = rawZ * SensorSample.mgToMetersPerSecondSquared;

      final motAccelX = motionX * SensorSample.mgToMetersPerSecondSquared;
      final motAccelY = motionY * SensorSample.mgToMetersPerSecondSquared;
      final motAccelZ = motionZ * SensorSample.mgToMetersPerSecondSquared;

      if (i == 0) {
        prevRawAccelX = rawAccelX;
        prevRawAccelY = rawAccelY;
        prevRawAccelZ = rawAccelZ;
        prevMotAccelX = motAccelX;
        prevMotAccelY = motAccelY;
        prevMotAccelZ = motAccelZ;

        rows[i] = ReadableIntegrationRow(
          rawX: rawX,
          rawY: rawY,
          rawZ: rawZ,
          rawIntegral1X: 0,
          rawIntegral1Y: 0,
          rawIntegral1Z: 0,
          rawIntegral2X: 0,
          rawIntegral2Y: 0,
          rawIntegral2Z: 0,
          motionX: motionX,
          motionY: motionY,
          motionZ: motionZ,
          motionIntegral1X: 0,
          motionIntegral1Y: 0,
          motionIntegral1Z: 0,
          motionIntegral2X: 0,
          motionIntegral2Y: 0,
          motionIntegral2Z: 0,
        );
        continue;
      }

      double dt = (samples[i].tsUs - samples[i - 1].tsUs) / 1000000.0;
      final bool validDt = dt > 0 && dt <= maxValidDtSec;

      if (validDt) {
        rawVelX += (prevRawAccelX + rawAccelX) * 0.5 * dt;
        rawVelY += (prevRawAccelY + rawAccelY) * 0.5 * dt;
        rawVelZ += (prevRawAccelZ + rawAccelZ) * 0.5 * dt;

        rawDistX += (rows[i - 1].rawIntegral1X + rawVelX) * 0.5 * dt;
        rawDistY += (rows[i - 1].rawIntegral1Y + rawVelY) * 0.5 * dt;
        rawDistZ += (rows[i - 1].rawIntegral1Z + rawVelZ) * 0.5 * dt;

        motVelX += (prevMotAccelX + motAccelX) * 0.5 * dt;
        motVelY += (prevMotAccelY + motAccelY) * 0.5 * dt;
        motVelZ += (prevMotAccelZ + motAccelZ) * 0.5 * dt;

        motDistX += (rows[i - 1].motionIntegral1X + motVelX) * 0.5 * dt;
        motDistY += (rows[i - 1].motionIntegral1Y + motVelY) * 0.5 * dt;
        motDistZ += (rows[i - 1].motionIntegral1Z + motVelZ) * 0.5 * dt;
      } else {
        rawVelX = rows[i - 1].rawIntegral1X;
        rawVelY = rows[i - 1].rawIntegral1Y;
        rawVelZ = rows[i - 1].rawIntegral1Z;
        rawDistX = rows[i - 1].rawIntegral2X;
        rawDistY = rows[i - 1].rawIntegral2Y;
        rawDistZ = rows[i - 1].rawIntegral2Z;

        motVelX = rows[i - 1].motionIntegral1X;
        motVelY = rows[i - 1].motionIntegral1Y;
        motVelZ = rows[i - 1].motionIntegral1Z;
        motDistX = rows[i - 1].motionIntegral2X;
        motDistY = rows[i - 1].motionIntegral2Y;
        motDistZ = rows[i - 1].motionIntegral2Z;
      }

      prevRawAccelX = rawAccelX;
      prevRawAccelY = rawAccelY;
      prevRawAccelZ = rawAccelZ;
      prevMotAccelX = motAccelX;
      prevMotAccelY = motAccelY;
      prevMotAccelZ = motAccelZ;

      rows[i] = ReadableIntegrationRow(
        rawX: rawX,
        rawY: rawY,
        rawZ: rawZ,
        rawIntegral1X: rawVelX,
        rawIntegral1Y: rawVelY,
        rawIntegral1Z: rawVelZ,
        rawIntegral2X: rawDistX,
        rawIntegral2Y: rawDistY,
        rawIntegral2Z: rawDistZ,
        motionX: motionX,
        motionY: motionY,
        motionZ: motionZ,
        motionIntegral1X: motVelX,
        motionIntegral1Y: motVelY,
        motionIntegral1Z: motVelZ,
        motionIntegral2X: motDistX,
        motionIntegral2Y: motDistY,
        motionIntegral2Z: motDistZ,
      );
    }

    return rows;
  }
}

/// raw.txt와 별도 — 256Hz 전체 샘플을 사람이 읽기 쉽게 출력
String writeRawReadableText(
  List<SensorSample> samples, {
  double sampleRateHz = RawReadableExport.defaultSampleRateHz,
  DateTime? dateTime,
}) {
  final buf = StringBuffer();
  final periodSec = RawReadableExport.samplePeriodSec(sampleRateHz);

  if (samples.isEmpty) {
    buf.writeln('[OTIS raw_readable.txt · 원초 센서 검증용]');
    buf.writeln('측정 시작 시간: (샘플 없음)');
    buf.writeln('총 측정 시간: 0.000000 초');
    buf.writeln('원본 샘플 수: 0');
    buf.writeln(
      '샘플레이트(${sampleRateHz.round()}Hz): ${sampleRateHz.toStringAsFixed(0)} Hz',
    );
    buf.writeln('출력: 전체 샘플 (다운샘플 없음)');
    buf.writeln('출력된 블록 수: 0');
    buf.writeln('');
    buf.writeln('※ 전체 원본 숫자열은 raw.txt 를 보세요.');
    return buf.toString();
  }

  final baseTsUs = samples.first.tsUs;
  final lastTsUs = samples.last.tsUs;
  final totalDurationSec =
      RawReadableExport.relativeTimeSec(lastTsUs, baseTsUs);

  final rows = ReadableSensorIntegrator.compute(samples);

  buf.writeln('[OTIS raw_readable.txt · 원초 센서 검증용]');
  buf.writeln(
    '※ 256Hz 전체 샘플 출력 (1초 = ${sampleRateHz.round()}블록). 다운샘플 없음.',
  );
  buf.writeln(
    '※ 각 블록: [원초] 기초값→적분→적분적분, [중력보정] 보정값→적분→적분적분',
  );
  buf.writeln('※ 필터·baseline 없음. 앱 화면 거리/속도와 다를 수 있습니다.');
  buf.writeln('----------------------------------------');
  if (dateTime != null) {
    buf.writeln(
      '측정 시작 시간: '
      '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}:'
      '${dateTime.second.toString().padLeft(2, '0')}',
    );
  } else {
    buf.writeln('측정 시작 시간: (메타 없음 · tsUs=${samples.first.tsUs})');
  }
  buf.writeln('총 측정 시간: ${totalDurationSec.toStringAsFixed(6)} 초');
  buf.writeln('원본 샘플 수: ${samples.length}');
  buf.writeln(
    '샘플레이트(${sampleRateHz.round()}Hz): ${sampleRateHz.toStringAsFixed(0)} Hz '
    '(샘플 간격 ≈ ${periodSec.toStringAsFixed(6)} 초)',
  );
  buf.writeln('출력: 전체 샘플 (다운샘플 없음, 1초당 ${sampleRateHz.round()}블록)');
  buf.writeln('출력된 블록 수: ${samples.length}');
  buf.writeln('----------------------------------------');
  buf.writeln('');

  // 256Hz 전체 — 샘플마다 1블록
  for (int i = 0; i < samples.length; i++) {
    final row = rows[i];
    final timeSec = RawReadableExport.relativeTimeSec(
      samples[i].tsUs,
      baseTsUs,
    );

    buf.writeln('=' * 50);
    buf.writeln(
      '시간 : ${timeSec.toStringAsFixed(6)}초  (#${i + 1}/${samples.length})',
    );
    buf.writeln('=' * 50);
    buf.writeln('');

    _writeAxisPair(
      buf,
      axisLabel: 'X축',
      rawValue: row.rawX,
      rawIntegral1: row.rawIntegral1X,
      rawIntegral2: row.rawIntegral2X,
      motionValue: row.motionX,
      motionIntegral1: row.motionIntegral1X,
      motionIntegral2: row.motionIntegral2X,
    );
    buf.writeln('');

    _writeAxisPair(
      buf,
      axisLabel: 'Y축',
      rawValue: row.rawY,
      rawIntegral1: row.rawIntegral1Y,
      rawIntegral2: row.rawIntegral2Y,
      motionValue: row.motionY,
      motionIntegral1: row.motionIntegral1Y,
      motionIntegral2: row.motionIntegral2Y,
    );
    buf.writeln('');

    _writeAxisPair(
      buf,
      axisLabel: 'Z축',
      rawValue: row.rawZ,
      rawIntegral1: row.rawIntegral1Z,
      rawIntegral2: row.rawIntegral2Z,
      motionValue: row.motionZ,
      motionIntegral1: row.motionIntegral1Z,
      motionIntegral2: row.motionIntegral2Z,
    );

    buf.writeln('');
    buf.writeln('');
  }

  return buf.toString();
}

/// 한 축: 원초 3줄 + 중력보정 3줄
void _writeAxisPair(
  StringBuffer buf, {
  required String axisLabel,
  required double rawValue,
  required double rawIntegral1,
  required double rawIntegral2,
  required double motionValue,
  required double motionIntegral1,
  required double motionIntegral2,
}) {
  buf.writeln('[$axisLabel · 원초]');
  buf.writeln('기초 센서값     : ${rawValue.toStringAsFixed(2)} mg');
  buf.writeln('적분값          : ${rawIntegral1.toStringAsFixed(3)} m/s');
  buf.writeln('적분적분값      : ${rawIntegral2.toStringAsFixed(3)} m');
  buf.writeln('');
  buf.writeln('[$axisLabel · 중력보정]');
  buf.writeln('중력보정값      : ${motionValue.toStringAsFixed(2)} mg');
  buf.writeln('적분값          : ${motionIntegral1.toStringAsFixed(3)} m/s');
  buf.writeln('적분적분값      : ${motionIntegral2.toStringAsFixed(3)} m');
}
