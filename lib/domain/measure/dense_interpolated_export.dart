/// raw_native.txt 원본 이벤트 → 고밀도 선형 보간 CSV (그래프 확대용)
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
  final String type; // accel | gravity | linear
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

/// raw_native.txt 본문 파싱
List<NativeSensorEvent> parseRawNativeText(String content) {
  final out = <NativeSensorEvent>[];
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 5) continue;
    final type = parts[0];
    if (type != 'accel' && type != 'gravity' && type != 'linear') continue;
    final ts = int.tryParse(parts[1]);
    final x = double.tryParse(parts[2]);
    final y = double.tryParse(parts[3]);
    final z = double.tryParse(parts[4]);
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
}) {
  final buf = StringBuffer();
  buf.writeln('# $fileLabel');
  buf.writeln('# INTERPOLATED / VISUALIZATION ONLY / NOT MEASURED SAMPLE');
  buf.writeln('# source: raw_native.txt');
  buf.writeln('# method: linear interpolation between native sensor events');
  buf.writeln('# target_rate_hz: $targetHz');
  buf.writeln(
    '# note: smartphone sensors do not actually sample at this rate; '
    'use for MATLAB/Excel zoom review only. '
    'Distance/speed/vibration analysis must use resampled 256Hz (raw.txt).',
  );
  buf.writeln(
    't_sec,accel_x_mg,accel_y_mg,accel_z_mg,'
    'gravity_x_mg,gravity_y_mg,gravity_z_mg,'
    'linear_x_mg,linear_y_mg,linear_z_mg',
  );

  if (events.isEmpty || targetHz <= 0) {
    return buf.toString();
  }

  final accel = events.where((e) => e.type == 'accel').toList();
  final gravity = events.where((e) => e.type == 'gravity').toList();
  final linear = events.where((e) => e.type == 'linear').toList();

  final tStart = events.first.tsUs;
  final tEnd = events.last.tsUs;
  if (tEnd <= tStart) {
    return buf.toString();
  }

  final periodUs = 1000000.0 / targetHz;
  final durationUs = (tEnd - tStart).toDouble();
  final count = (durationUs / periodUs).floor() + 1;
  // 과도한 파일 방지 (약 30분@25.6kHz 상한보다 훨씬 작게: 2e6행)
  final safeCount = count.clamp(1, 2000000);

  for (int i = 0; i < safeCount; i++) {
    final t = tStart + (i * periodUs).round();
    if (t > tEnd) break;
    final tSec = (t - tStart) / 1000000.0;
    final a = _interpAt(accel, t);
    final g = _interpAt(gravity, t);
    final l = _interpAt(linear, t);
    buf.writeln(
      '${_fmt(tSec)},'
      '${_fmtOpt(a?.$1)},${_fmtOpt(a?.$2)},${_fmtOpt(a?.$3)},'
      '${_fmtOpt(g?.$1)},${_fmtOpt(g?.$2)},${_fmtOpt(g?.$3)},'
      '${_fmtOpt(l?.$1)},${_fmtOpt(l?.$2)},${_fmtOpt(l?.$3)}',
    );
  }
  return buf.toString();
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
