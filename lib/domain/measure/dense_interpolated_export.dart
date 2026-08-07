/// raw_native.txt 또는 검증용 *_원본.txt → 고밀도 선형 보간 CSV
///
/// 주의: 실제 센서 측정값이 아님. visualization only / interpolated.
library;

/// dense 출력 스펙 (파일명 → 목표 Hz)
const Map<String, int> kDenseInterpolatedSpecs = {
  'dense_interpolated_512.csv': 512,
  'dense_interpolated_1024.csv': 1024,
  'dense_interpolated_50x.csv': 256 * 50, // 12,800 Hz
  'dense_interpolated_100x.csv': 256 * 100, // 25,600 Hz
};

class NativeSensorEvent {
  /// raw | gravity | linear  (구버전 파일의 accel → raw로 정규화)
  final String type;
  final int tsUs;
  final double xMg;
  final double yMg;
  final double zMg;

  const NativeSensorEvent({
    required this.type,
    required this.tsUs,
    required this.xMg,
    required this.yMg,
    required this.zMg,
  });
}

/// 원본 본문 파싱 (`raw` = accelerometer / 구버전 `accel` 호환)
///
/// 지원 형식:
/// - raw_native: `type tsUs x_mg y_mg z_mg dtUs`
/// - 센서 검증: `type tsUs dtUs x_mg y_mg z_mg`
///
/// `# columns:` 헤더가 있으면 열 이름으로 위치를 찾고, 없으면 raw_native 순서를 쓴다.
List<NativeSensorEvent> parseRawNativeText(String content) {
  final out = <NativeSensorEvent>[];
  var typeIndex = 0;
  var tsIndex = 1;
  var xIndex = 2;
  var yIndex = 3;
  var zIndex = 4;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      if (line.startsWith('# columns:')) {
        final columns = line
            .substring('# columns:'.length)
            .trim()
            .split(RegExp(r'\s+'));
        final indexes = <String, int>{
          for (var i = 0; i < columns.length; i++) columns[i]: i,
        };
        typeIndex = indexes['type'] ?? typeIndex;
        tsIndex = indexes['tsUs'] ?? tsIndex;
        xIndex = indexes['x_mg'] ?? xIndex;
        yIndex = indexes['y_mg'] ?? yIndex;
        zIndex = indexes['z_mg'] ?? zIndex;
      }
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    final lastRequiredIndex = [
      typeIndex,
      tsIndex,
      xIndex,
      yIndex,
      zIndex,
    ].reduce((a, b) => a > b ? a : b);
    if (parts.length <= lastRequiredIndex) continue;
    var type = parts[typeIndex];
    if (type == 'accel') type = 'raw'; // 구버전 호환
    if (type != 'raw' && type != 'gravity' && type != 'linear') continue;
    final ts = int.tryParse(parts[tsIndex]);
    final x = double.tryParse(parts[xIndex]);
    final y = double.tryParse(parts[yIndex]);
    final z = double.tryParse(parts[zIndex]);
    if (ts == null || x == null || y == null || z == null) continue;
    out.add(NativeSensorEvent(type: type, tsUs: ts, xMg: x, yMg: y, zMg: z));
  }
  out.sort((a, b) => a.tsUs.compareTo(b.tsUs));
  return out;
}

/// 단일 목표 Hz에 대한 dense CSV 문자열 생성
String buildDenseInterpolatedCsv(
  List<NativeSensorEvent> events, {
  required int targetHz,
  required String fileLabel,
}) =>
    '${buildDenseInterpolatedLines(events, targetHz: targetHz, fileLabel: fileLabel).join('\n')}\n';

/// 대용량 50배·100배 결과를 메모리에 한꺼번에 올리지 않고 한 줄씩 생성한다.
Iterable<String> buildDenseInterpolatedLines(
  List<NativeSensorEvent> events, {
  required int targetHz,
  required String fileLabel,
}) sync* {
  yield '# $fileLabel';
  yield '# INTERPOLATED / VISUALIZATION ONLY / NOT MEASURED SAMPLE';
  yield '# source: raw_native.txt or verification original txt';
  yield '# method: linear interpolation between native sensor events';
  yield '# target_rate_hz: $targetHz';
  yield '# note: smartphone sensors do not actually sample at this rate; '
      'use for MATLAB/Excel zoom review only. '
      'Distance/speed/vibration analysis must use resampled 256Hz (raw.txt).';
  yield 't_sec,raw_x_mg,raw_y_mg,raw_z_mg,'
      'gravity_x_mg,gravity_y_mg,gravity_z_mg,'
      'linear_x_mg,linear_y_mg,linear_z_mg';

  if (events.isEmpty || targetHz <= 0) return;

  final raw = events.where((e) => e.type == 'raw').toList();
  final gravity = events.where((e) => e.type == 'gravity').toList();
  final linear = events.where((e) => e.type == 'linear').toList();

  final tStart = events.first.tsUs;
  final tEnd = events.last.tsUs;
  if (tEnd <= tStart) return;

  final periodUs = 1000000.0 / targetHz;
  final durationUs = (tEnd - tStart).toDouble();
  final count = (durationUs / periodUs).floor() + 1;
  // 과도한 파일 방지 (약 30분@25.6kHz 상한보다 훨씬 작게: 2e6행)
  final safeCount = count.clamp(1, 2000000);

  for (int i = 0; i < safeCount; i++) {
    final t = tStart + (i * periodUs).round();
    if (t > tEnd) break;
    final tSec = (t - tStart) / 1000000.0;
    final a = _interpAt(raw, t);
    final g = _interpAt(gravity, t);
    final l = _interpAt(linear, t);
    yield ('${_fmt(tSec)},'
        '${_fmtOpt(a?.$1)},${_fmtOpt(a?.$2)},${_fmtOpt(a?.$3)},'
        '${_fmtOpt(g?.$1)},${_fmtOpt(g?.$2)},${_fmtOpt(g?.$3)},'
        '${_fmtOpt(l?.$1)},${_fmtOpt(l?.$2)},${_fmtOpt(l?.$3)}');
  }
}

/// 스펙 전부에 대한 파일명→본문 맵
Map<String, String> buildAllDenseInterpolatedCsv(String nativeText) {
  final events = parseRawNativeText(nativeText);
  final out = <String, String>{};
  for (final entry in kDenseInterpolatedSpecs.entries) {
    out[entry.key] = buildDenseInterpolatedCsv(
      events,
      targetHz: entry.value,
      fileLabel: entry.key,
    );
  }
  return out;
}

(double, double, double)? _interpAt(List<NativeSensorEvent> series, int tUs) {
  if (series.isEmpty) return null;
  if (tUs <= series.first.tsUs) {
    final s = series.first;
    return (s.xMg, s.yMg, s.zMg);
  }
  if (tUs >= series.last.tsUs) {
    final s = series.last;
    return (s.xMg, s.yMg, s.zMg);
  }

  // binary search for right index
  int lo = 0;
  int hi = series.length - 1;
  while (lo + 1 < hi) {
    final mid = (lo + hi) >> 1;
    if (series[mid].tsUs <= tUs) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = series[lo];
  final b = series[hi];
  final dt = (b.tsUs - a.tsUs).toDouble();
  if (dt <= 0) return (a.xMg, a.yMg, a.zMg);
  final alpha = ((tUs - a.tsUs) / dt).clamp(0.0, 1.0);
  return (
    a.xMg + alpha * (b.xMg - a.xMg),
    a.yMg + alpha * (b.yMg - a.yMg),
    a.zMg + alpha * (b.zMg - a.zMg),
  );
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(9);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}

String _fmtOpt(double? v) => v == null ? '' : _fmt(v);
