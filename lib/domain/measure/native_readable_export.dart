import 'dense_interpolated_export.dart';

/// 저장 파일명
const String kRaw3to7BySecondFileName = 'raw_3to7ms_초별.txt';
const String kRaw1to3BySecondFileName = 'raw_1to3ms_초별.txt';

/// line-protocol native dump → 초별 보기 쉬운 텍스트
///
/// [title] 예: raw_3to7ms_초별.txt
/// [requestLabel] 예: SENSOR_DELAY_FASTEST (≈3~7ms)
String buildNativeBySecondReadableText(
  String nativeLineProtocol, {
  required String title,
  required String requestLabel,
}) {
  final events = parseRawNativeText(nativeLineProtocol);
  final buf = StringBuffer();
  buf.writeln('[$title]');
  buf.writeln('요청: $requestLabel');
  buf.writeln('의미: 보간·256개 제한 없이, 센서가 준 이벤트를 초 단위로 모아 출력');
  buf.writeln('형식: type | 상대시각(s) | x_mg | y_mg | z_mg | dt_ms(같은type)');
  buf.writeln('type: raw(=rawX/Y/Z, 중력포함) | gravity | linear');
  buf.writeln('');

  if (events.isEmpty) {
    buf.writeln('(이벤트 없음)');
    return buf.toString();
  }

  final t0 = events.first.tsUs;
  final bySec = <int, List<NativeSensorEvent>>{};
  for (final e in events) {
    final sec = ((e.tsUs - t0) / 1000000.0).floor();
    bySec.putIfAbsent(sec, () => <NativeSensorEvent>[]).add(e);
  }

  final secs = bySec.keys.toList()..sort();
  buf.writeln('총 구간: ${secs.length}초 · 총 이벤트: ${events.length}');
  buf.writeln('');

  for (final sec in secs) {
    final list = bySec[sec]!;
    final rawN = list.where((e) => e.type == 'raw').length;
    final gravity = list.where((e) => e.type == 'gravity').length;
    final linear = list.where((e) => e.type == 'linear').length;
    buf.writeln(
      '======== ${sec + 1}초 '
      '(raw=$rawN, gravity=$gravity, linear=$linear, 합=${list.length}) ========',
    );
    buf.writeln(
      '${_pad('type', 8)} ${_pad('t_sec', 10)} '
      '${_pad('x_mg', 12)} ${_pad('y_mg', 12)} ${_pad('z_mg', 12)} '
      '${_pad('dt_ms', 8)}',
    );

    final lastTs = <String, int>{};
    for (final e in list) {
      final prev = lastTs[e.type];
      final dtUs = (prev != null && e.tsUs > prev) ? e.tsUs - prev : 0;
      lastTs[e.type] = e.tsUs;
      final tSec = (e.tsUs - t0) / 1000000.0;
      final dtMs = dtUs / 1000.0;
      buf.writeln(
        '${_pad(e.type, 8)} ${_pad(tSec.toStringAsFixed(6), 10)} '
        '${_pad(e.xMg.toStringAsFixed(3), 12)} '
        '${_pad(e.yMg.toStringAsFixed(3), 12)} '
        '${_pad(e.zMg.toStringAsFixed(3), 12)} '
        '${_pad(dtMs.toStringAsFixed(3), 8)}',
      );
    }
    buf.writeln('');
  }

  buf.writeln('--- 초별 raw 개수 요약 (256 제한 없음) ---');
  for (final sec in secs) {
    final rawN = bySec[sec]!.where((e) => e.type == 'raw').length;
    buf.writeln('${sec + 1}초: raw $rawN 개');
  }
  return buf.toString();
}

String _pad(String s, int w) {
  if (s.length >= w) return s;
  return s.padRight(w);
}
