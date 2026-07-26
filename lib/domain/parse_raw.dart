import 'measure/axis_integration_export.dart';
import 'measure/measurement_engine.dart';
import 'measure/sensor_sample.dart';
import 'models/measurement_result.dart';

/// P9 · EVIMP1 형식 RAW 텍스트 파일 파싱, 직렬화(writer) 및 시계열 변환 유틸
class RawDataParser {
  /// EVIMP1 문자열 데이터를 파싱하여 MeasurementResult 인스턴스를 반환한다.
  /// - 헤더(EVIMP1, 샘플링 레이트) 인식
  /// - legacy 4컬럼(x y z noise) 및 확장 11/20컬럼 파싱
  /// - 20컬럼: 기존 11 + motionX/Y/Z velocityX/Y/Z distanceX/Y/Z
  /// - Phase 1 신규 통합 엔진(MeasurementEngine)을 연동하여 지표 및 시계열 도출
  static MeasurementResult parseEvimp1({
    required String rawContent,
    required String id,
    required String jobNo,
    required String siteName,
    required int bottomFloor,
    required int topFloor,
    required String direction,
    required DateTime dateTime,
  }) {
    final parseRes = parseEvimp1ToSamples(rawContent);
    final samples = parseRes.samples;

    final engine = MeasurementEngine();
    engine.addSamples(samples);

    return engine.analyze(
      id: id,
      jobNo: jobNo,
      siteName: siteName,
      bottomFloor: bottomFloor,
      topFloor: topFloor,
      direction: direction,
      dateTime: dateTime,
    );
  }

  /// EVIMP1 문자열을 파싱하여 SensorSample 리스트 및 샘플레이트를 반환
  static ({List<SensorSample> samples, int sampleRate}) parseEvimp1ToSamples(
    String rawContent,
  ) {
    final lines = rawContent.split(RegExp(r'\r?\n'));
    int sampleRate = 256;
    final List<SensorSample> samples = [];

    int index = 0;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line == 'EVIMP1') continue;

      if (samples.isEmpty &&
          int.tryParse(line) != null &&
          !line.contains('.')) {
        sampleRate = int.parse(line);
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 11) {
        final tsUs =
            int.tryParse(parts[0]) ?? double.tryParse(parts[0])?.round();
        final x = double.tryParse(parts[1]);
        final y = double.tryParse(parts[2]);
        final z = double.tryParse(parts[3]);
        final noise = double.tryParse(parts[4]);

        if (tsUs != null &&
            x != null &&
            y != null &&
            z != null &&
            noise != null) {
          samples.add(
            SensorSample(
              tsUs: tsUs,
              x: x,
              y: y,
              z: z,
              noiseDba: noise,
              rawX: _parseNullableDouble(parts[5]),
              rawY: _parseNullableDouble(parts[6]),
              rawZ: _parseNullableDouble(parts[7]),
              gravityX: _parseNullableDouble(parts[8]),
              gravityY: _parseNullableDouble(parts[9]),
              gravityZ: _parseNullableDouble(parts[10]),
            ),
          );
          index++;
        }
      } else if (parts.length >= 4) {
        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);
        final z = double.tryParse(parts[2]);
        final noise = double.tryParse(parts[3]);

        if (x != null && y != null && z != null && noise != null) {
          final int dtUs = (1000000 / sampleRate).round();
          samples.add(
            SensorSample(tsUs: index * dtUs, x: x, y: y, z: z, noiseDba: noise),
          );
          index++;
        }
      }
    }

    if (samples.isEmpty) {
      samples.add(
        const SensorSample(tsUs: 0, x: 0.0, y: 0.0, z: 0.0, noiseDba: 0.0),
      );
    }

    return (samples: samples, sampleRate: sampleRate);
  }

  /// SensorSample 리스트 및 샘플레이트를 EVIMP1 형식 문자열로 직렬화 (writer)
  ///
  /// 축별 motion/velocity/distance는 저장 시점에 [AxisIntegrationExport]로 계산한다.
  static String writeEvimp1(
    List<SensorSample> samples, {
    int sampleRate = 256,
  }) {
    final integrationRows = AxisIntegrationExport.compute(samples);

    final buffer = StringBuffer();
    buffer.writeln('EVIMP1');
    buffer.writeln(sampleRate);
    buffer.writeln(
      '# columns: tsUs linearX linearY linearZ noiseDba '
      'rawX rawY rawZ gravityX gravityY gravityZ '
      'motionX motionY motionZ '
      'velocityX velocityY velocityZ '
      'distanceX distanceY distanceZ',
    );
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final row = i < integrationRows.length
          ? integrationRows[i]
          : AxisIntegrationRow.zero;
      buffer.writeln(
        '${s.tsUs} ${_formatNum(s.x)} ${_formatNum(s.y)} ${_formatNum(s.z)} '
        '${_formatNum(s.noiseDba)} '
        '${_formatNullableNum(s.rawX)} ${_formatNullableNum(s.rawY)} '
        '${_formatNullableNum(s.rawZ)} '
        '${_formatNullableNum(s.gravityX)} ${_formatNullableNum(s.gravityY)} '
        '${_formatNullableNum(s.gravityZ)} '
        '${_formatNum(row.motionX)} ${_formatNum(row.motionY)} '
        '${_formatNum(row.motionZ)} '
        '${_formatIntegrationNum(row.velocityX)} '
        '${_formatIntegrationNum(row.velocityY)} '
        '${_formatIntegrationNum(row.velocityZ)} '
        '${_formatIntegrationNum(row.distanceX)} '
        '${_formatIntegrationNum(row.distanceY)} '
        '${_formatIntegrationNum(row.distanceZ)}',
      );
    }
    return buffer.toString();
  }

  static double? _parseNullableDouble(String val) {
    if (val == 'null' || val == '-' || val.isEmpty) return null;
    return double.tryParse(val);
  }

  static String _formatNullableNum(double? val) {
    if (val == null) return 'null';
    return _formatNum(val);
  }

  static String _formatNum(double val) {
    String str = val.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  /// 속도(m/s)·거리(m) — raw.txt 가독성용 (불필요한 0 제거)
  static String _formatIntegrationNum(double val) {
    return _formatNum(double.parse(val.toStringAsFixed(6)));
  }
}
