import 'dart:convert';
import 'dart:io';

/// 작성: 2026-09-26 14:10:00 · nada
/// 함수: pdfContentStreams
/// 목적: PDF 에서 눌러 담긴 쪽 내용 스트림을 풀어 꺼낸다. 시험이 "무엇이
///       그려졌는지" 를 눈이 아니라 값으로 확인할 수 있게 하려고 둔다.
///       풀리지 않는 조각은 글꼴이나 그림이라 쪽 내용이 아니다.
/// 인자: bytes — 살펴볼 PDF 내용
/// 반환: 풀어낸 쪽 내용 문자열 목록. 쪽 차례대로다
List<String> pdfContentStreams(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true); // 스트림을 찾을 문자열
  final out = <String>[]; // 모아 갈 내용 스트림
  for (final match in RegExp(r'stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', match.end); // 이 스트림이 끝나는 자리
    if (end < 0) continue;
    try {
      out.add(
        latin1.decode(
          ZLibDecoder().convert(latin1.encode(text.substring(match.end, end))),
          allowInvalid: true,
        ),
      );
    } catch (_) {
      // 풀리지 않는 조각은 쪽 내용이 아니다
    }
  }
  return out;
}

/// 작성: 2026-09-26 14:10:00 · nada
/// 함수: pdfChartStreams
/// 목적: 차트가 그려진 쪽의 내용 스트림만 고른다. 차트를 그리면 점선
///       격자가 반드시 들어가므로 그것으로 가른다.
/// 인자: bytes — 살펴볼 PDF 내용
/// 반환: 차트가 있는 쪽의 내용 스트림 목록
List<String> pdfChartStreams(List<int> bytes) {
  return pdfContentStreams(
    bytes,
  ).where((stream) => stream.contains('[1.2 1.2] 0 d')).toList();
}

/// 작성: 2026-09-26 14:10:00 · nada
/// 함수: verticalGridLines
/// 목적: 쪽 하나에서 차트마다 세로 격자선이 가로 어디에 놓였는지 뽑는다.
///       세로 격자선은 가로축 눈금 자리에 그어지므로, 그 자리가 같으면 두
///       차트가 같은 시간대를 그린 것이다.
///       격자는 점선으로 긋고 다 그린 뒤 실선으로 되돌리므로, 점선 무늬를
///       켠 구간만 잘라 보면 격자만 걸러진다.
/// 인자: stream — 쪽 하나의 내용 스트림
/// 반환: 차트마다의 세로 격자선 가로 자리 목록
List<List<String>> verticalGridLines(String stream) {
  final dashed = RegExp(
    r'\[1\.2 1\.2\] 0 d(.*?)\[\] 0 d',
    dotAll: true,
  ); // 점선을 켜고 끈 사이 구간
  final segment = RegExp(
    r'([-\d.]+) ([-\d.]+) m\s+([-\d.]+) ([-\d.]+) l',
  ); // 선분 하나
  final charts = <List<String>>[]; // 차트별 결과

  for (final grid in dashed.allMatches(stream)) {
    final xs = <String>[]; // 이 차트의 세로 격자선 가로 자리
    for (final line in segment.allMatches(grid.group(1)!)) {
      // 세로선은 양 끝의 가로 자리가 같다
      if (line.group(1) == line.group(3)) xs.add(line.group(1)!);
    }
    charts.add(xs);
  }
  return charts;
}

/// 작성: 2026-09-26 14:10:00 · nada
/// 변수: markerColorOperand
/// 목적: 차트 표시점 색(`ReportColors.chartMarker`)이 PDF 에 적히는 모양.
///       0~1 로 나눈 세 값이라 원래 색 값과 생김새가 다르다.
/// 근거: 측정 — 0xE0/255 = 0.87843, 0x30/255 = 0.18824
const String markerColorOperand = '0.87843 0.18824 0.18824';
