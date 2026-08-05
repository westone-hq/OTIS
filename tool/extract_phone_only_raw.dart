import 'dart:io';

/// raw.txt에서 폰(Android)이 준 값만 추출
/// - 포함: tsUs, linearX/Y/Z, noiseDba, rawX/Y/Z, gravityX/Y/Z
/// - 제외: motion, velocity, distance (앱 계산값)
void main(List<String> args) {
  final input = args.isNotEmpty
      ? args[0]
      : r'c:\Users\박희정\Downloads\raw (3).txt';
  final output = args.length > 1
      ? args[1]
      : r'c:\Users\박희정\Downloads\raw_phone_only.txt';

  final lines = File(input).readAsLinesSync();
  final buf = StringBuffer();

  buf.writeln('[OTIS · 폰 센서 원값만]');
  buf.writeln('출처: Android TYPE_LINEAR_ACCELERATION / ACCELEROMETER / GRAVITY + mic');
  buf.writeln('제외: motion, velocity, distance (앱 계산)');
  buf.writeln('단위: 가속도 mg · 소음 dBA · 시간 tsUs(μs)');
  buf.writeln('${'=' * 70}');
  buf.writeln('');
  buf.writeln('EVIMP1_PHONE');
  buf.writeln('256');
  buf.writeln(
    '# columns: tsUs linearX linearY linearZ noiseDba '
    'rawX rawY rawZ gravityX gravityY gravityZ',
  );

  var count = 0;
  var skippedRate = false;
  for (final ln in lines) {
    final line = ln.trim();
    if (line.isEmpty || line.startsWith('#') || line == 'EVIMP1') continue;
    if (!skippedRate && int.tryParse(line) != null && !line.contains('.')) {
      skippedRate = true;
      continue;
    }

    final p = line.split(RegExp(r'\s+'));
    if (p.length < 11) continue;

    // 폰 값 11열 only
    buf.writeln(
      '${p[0]} ${p[1]} ${p[2]} ${p[3]} ${p[4]} '
      '${p[5]} ${p[6]} ${p[7]} ${p[8]} ${p[9]} ${p[10]}',
    );
    count++;
  }

  buf.writeln('');
  buf.writeln('${'=' * 70}');
  buf.writeln('총 샘플 수: $count');

  File(output).writeAsStringSync(buf.toString());
  print('Wrote $count samples -> $output');
}
