import 'dart:io';
import 'dart:math';

void main(List<String> args) {
  final rawPath = args.isNotEmpty
      ? args[0]
      : r'c:\Users\박희정\Downloads\raw (3).txt';

  final lines = File(rawPath).readAsLinesSync();
  final data = <Map<String, double>>[];

  for (final ln in lines.skip(3)) {
    if (ln.trim().isEmpty) continue;
    final p = ln.split(RegExp(r'\s+'));
    if (p.length < 20) continue;
    data.add({
      'tsUs': double.parse(p[0]),
      'linX': double.parse(p[1]),
      'linY': double.parse(p[2]),
      'linZ': double.parse(p[3]),
      'noise': double.parse(p[4]),
      'rawX': double.parse(p[5]),
      'rawY': double.parse(p[6]),
      'rawZ': double.parse(p[7]),
      'gX': double.parse(p[8]),
      'gY': double.parse(p[9]),
      'gZ': double.parse(p[10]),
      'mX': double.parse(p[11]),
      'mY': double.parse(p[12]),
      'mZ': double.parse(p[13]),
      'vX': double.parse(p[14]),
      'vY': double.parse(p[15]),
      'vZ': double.parse(p[16]),
      'dX': double.parse(p[17]),
      'dY': double.parse(p[18]),
      'dZ': double.parse(p[19]),
    });
  }

  print('samples: ${data.length}');
  final base = data.first['tsUs']!;
  final dur = (data.last['tsUs']! - base) / 1e6;
  print('duration_sec: ${dur.toStringAsFixed(3)}');

  double avg(List<Map<String, double>> s, String k) =>
      s.map((e) => e[k]!).reduce((a, b) => a + b) / s.length;

  double ptp(List<Map<String, double>> s, String k) {
    var minV = s.first[k]!;
    var maxV = s.first[k]!;
    for (final e in s) {
      minV = min(minV, e[k]!);
      maxV = max(maxV, e[k]!);
    }
    return maxV - minV;
  }

  Map<String, double> interval(int start, int count) {
    final s = data.sublist(start, start + count);
    final last = s.last;
    return {
      'linX_avg': avg(s, 'linX'),
      'linX_ptp': ptp(s, 'linX'),
      'rawX_avg': avg(s, 'rawX'),
      'gX_avg': avg(s, 'gX'),
      'mX_avg': avg(s, 'mX'),
      'mX_check': s.map((e) => e['rawX']! - e['gX']!).reduce((a, b) => a + b) / s.length,
      'vX': last['vX']!,
      'dX': last['dX']!,
      'mY_avg': avg(s, 'mY'),
      'vY': last['vY']!,
      'dY': last['dY']!,
      'mZ_avg': avg(s, 'mZ'),
      'vZ': last['vZ']!,
      'dZ': last['dZ']!,
      'noise_avg': avg(s, 'noise'),
    };
  }

  bool close(double got, double exp, double tol) => (got - exp).abs() <= tol;

  void check(String name, double got, double exp, {double tol = 0.05}) {
    final ok = close(got, exp, tol);
    print('  $name: got=${got.toStringAsFixed(6)} exp=$exp ${ok ? "OK" : "MISMATCH"}');
  }

  print('\n=== [0.0~0.1s] 26 samples ===');
  final i1 = interval(0, 26);
  check('X Linear avg', i1['linX_avg']!, 0.79);
  check('X P-P', i1['linX_ptp']!, 6.11);
  check('X Raw avg', i1['rawX_avg']!, 16.27);
  check('X Gravity avg', i1['gX_avg']!, 14.88);
  check('X Motion avg', i1['mX_avg']!, 1.39);
  check('X Velocity last', i1['vX']!, 0.001393, tol: 0.000001);
  check('X Distance last', i1['dX']!, 0.000074, tol: 0.000001);
  check('Y Motion avg', i1['mY_avg']!, 0.28);
  check('Z Motion avg', i1['mZ_avg']!, 15.10);
  check('Z Velocity last', i1['vZ']!, 0.014506, tol: 0.000001);
  check('Z Distance last', i1['dZ']!, 0.000761, tol: 0.000001);
  check('Motion=raw-g X', i1['mX_avg']!, i1['mX_check']!, tol: 0.001);

  print('\n=== [0.1~0.2s] 26 samples ===');
  final i2 = interval(26, 26);
  check('X Raw avg', i2['rawX_avg']!, 15.52);
  check('X Motion avg', i2['mX_avg']!, 0.07);
  check('X Velocity last', i2['vX']!, 0.001477, tol: 0.000001);
  check('X Distance last', i2['dX']!, 0.000246, tol: 0.000001);
  check('Z Velocity last', i2['vZ']!, 0.029214, tol: 0.000001);
  check('Z Distance last', i2['dZ']!, 0.003015, tol: 0.000001);

  var motionBad = 0;
  for (final x in data) {
    for (final ax in ['X', 'Y', 'Z']) {
      final raw = x['raw$ax']!;
      final g = x['g$ax']!;
      final m = x['m$ax']!;
      if ((raw - g - m).abs() > 0.001) motionBad++;
    }
  }
  print('\nmotion=raw-gravity mismatches: $motionBad / ${data.length * 3}');

  // time-based 0.1s intervals
  final counts = <int>[];
  var idx = 0;
  while (idx < data.length) {
    final startTs = data[idx]['tsUs']!;
    final endTs = startTs + 100000;
    var j = idx;
    while (j < data.length && data[j]['tsUs']! < endTs) {
      j++;
    }
    if (j == idx) j++;
    counts.add(j - idx);
    idx = j;
  }
  print('time-based intervals: ${counts.length}, sample sum: ${counts.reduce((a, b) => a + b)}');
  print('first 5 counts: ${counts.take(5).toList()}');

  Map<String, double> timeInterval(int intervalIndex) {
    final startTs = base + intervalIndex * 100000;
    final endTs = startTs + 100000;
    final s = data
        .where((e) => e['tsUs']! >= startTs && e['tsUs']! < endTs)
        .toList();
    if (s.isEmpty) return {};
    final last = s.last;
    return {
      'count': s.length.toDouble(),
      'linX_avg': avg(s, 'linX'),
      'rawX_avg': avg(s, 'rawX'),
      'mZ_avg': avg(s, 'mZ'),
      'vZ': last['vZ']!,
      'dZ': last['dZ']!,
      'noise_avg': avg(s, 'noise'),
    };
  }

  print('\n=== time-based [0.0~0.1s] ===');
  final t1 = timeInterval(0);
  check('count', t1['count']!, 26, tol: 0.5);
  check('X Raw avg', t1['rawX_avg']!, 16.27);
  check('Z vel last', t1['vZ']!, 0.014506, tol: 0.000001);
  check('Z dist last', t1['dZ']!, 0.000761, tol: 0.000001);

  print('\n=== time-based [30.4~30.5s] last block ===');
  final tLast = timeInterval(304);
  check('count', tLast['count']!, 25, tol: 0.5);
  check('Z Velocity last', tLast['vZ']!, 4.414034, tol: 0.000001);
  check('Z Distance last', tLast['dZ']!, 93.006105, tol: 0.000001);
  check('X Raw avg', tLast['rawX_avg']!, 12.62, tol: 0.1);

  // last raw sample values
  final lastSample = data.last;
  print('\n=== very last sample in raw.txt ===');
  print('  vZ=${lastSample['vZ']} dZ=${lastSample['dZ']}');
  print('  summary last block dZ=93.006105 (last sample OF interval, not file end)');
}
