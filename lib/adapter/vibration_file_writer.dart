// 작성: 2026-08-18 23:43:06
// 작성자: 박건준

import 'dart:io';

import 'package:vibration_checker/domain/capture/grid_resampler.dart';

/// 클래스: VibrationFileWriter
/// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산 결과를
///       참조 파일과 같은 구조의 텍스트 파일로 기록한다.
///
///       참조 파일(H6N1AP65.txt)에서 확인한 구조:
///       1줄  포맷 식별자
///       2줄  초당 행 수
///       3줄~ 값들, 공백 구분, 소수점 최대 3자리(뒤 0 제거), 줄 끝은
///       참조 파일과 같은 줄바꿈 문자(`lineEnding` 참고)로 되어 있다.
///       시간 열은 없다. 시각은 행 번호로만 결정된다.
///
///       이번 산출물은 소음 열이 없는 3열이므로 EVIMP1(회사 EVA 진동측정 장비가
///       쓰는 표준 데이터 포맷) 이 아니다.
///       소음 열이 붙어 4열이 되는 시점에 formatId 와 columnCount 만 바꾸면 된다.
class VibrationFileWriter {
  /// 목적: 이번 산출물의 포맷 식별자. 소음 열이 없어 EVIMP1 을 쓰지 않는다.
  /// 근거: 인용 — 참조 파일 H6N1AP65.txt 1줄이 EVIMP1, 4열(X Y Z 소음) 구조.
  ///       3열 파일에 같은 식별자를 쓰면 판독 측이 4열로 읽어 어긋난다
  static const String formatId = 'OTIS-VIB3';

  /// 목적: 이번 산출물의 열 수 (X Y Z)
  static const int columnCount = 3;

  /// 목적: 값 하나의 소수점 자리 수
  /// 근거: 인용 — 참조 파일 값의 소수점 자리가 최대 3자리
  static const int decimalDigits = 3;

  /// 목적: 줄바꿈 문자
  /// 근거: 인용 — 참조 파일의 줄바꿈 문자가 이 두 글자(`\r\n`)와 같다
  static const String lineEnding = '\r\n';

  /// 함수: encode
  /// 목적: 격자 환산 결과를 참조 파일과 같은 구조의 문자열로 만든다.
  ///       1줄에 포맷 식별자, 2줄에 초당 행 수를 쓰고, 그 뒤로 격자
  ///       행마다 진동 값(X Y Z, mg)을 한 줄씩 이어붙인다.
  /// 인자: result — 격자 환산 결과. `result.samples`에 격자 행마다
  ///       하나씩, 원본 가속도에서 중력 성분을 뺀 진동 값이 들어있다
  /// 반환: 머리말 2줄과 값 행들이 `lineEnding`으로 이어진 문자열
  static String encode(GridResampleResult result) {
    // gridIntervalNs는 격자 행 사이 시간 간격(나노초)이다. 1초(10억
    // 나노초)를 이 값으로 나누면 1초에 몇 행이 들어가는지가 나온다
    final rateHz = 1000000000 ~/ result.gridIntervalNs;
    // 완성할 문자열을 쌓아갈 버퍼(값을 잠시 담아 두는 임시 저장 공간)
    final buffer = StringBuffer();
    buffer.write(formatId);
    buffer.write(lineEnding);
    buffer.write('$rateHz');
    buffer.write(lineEnding);
    for (final s in result.samples) {
      // s: 격자 행 하나의 진동 값(X Y Z, mg). GridResampler가 그
      // 시각의 원본 가속도값에서 중력값을 뺀 결과다
      // → 로직 이동: formatValue()
      buffer.write(formatValue(s.xMg));
      buffer.write(' ');
      buffer.write(formatValue(s.yMg));
      buffer.write(' ');
      buffer.write(formatValue(s.zMg));
      buffer.write(lineEnding);
    }
    return buffer.toString();
  }

  /// 함수: formatValue
  /// 목적: 값 하나(mg)를 참조 파일과 같은 표기로 바꾼다. 소수점 3자리로
  ///       자른 뒤, 뒤에 남는 0 은 떼어낸다. 표기 예시는 참조 파일
  ///       (H6N1AP65.txt)을 참고한다.
  /// 인자: value — 기록할 값 (mg)
  /// 반환: 표기 문자열. 숫자가 아니거나(NaN) 무한대면 '0'
  static String formatValue(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    var text = value.toStringAsFixed(decimalDigits); // 소수점 3자리로 자른 표기
    if (text.contains('.')) {
      while (text.endsWith('0')) {
        text = text.substring(0, text.length - 1);
      }
      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }
    }
    if (text == '-0') return '0';
    return text;
  }

  /// 함수: write
  /// 목적: 격자 환산 결과를 값 파일로 기록한다. `writeMeta()`와 달리
  ///       환산이 실패한 결과는 기록하지 않고 예외를 던진다 — 값이
  ///       없는 값 파일을 만들어도 판독 측이 쓸 수 없기 때문이다.
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과
  /// 반환: 기록한 파일
  static Future<File> write(String path, GridResampleResult result) async {
    if (!result.isSuccess) {
      throw StateError('격자 환산 실패 결과는 기록하지 않는다: ${result.failureReason}');
    }
    final file = File(path); // 기록할 파일 객체
    await file.parent.create(recursive: true);
    // → 로직 이동: encode()
    await file.writeAsString(encode(result));
    return file;
  }

  /// 함수: encodeMeta
  /// 목적: 환산 과정에서 폐기되거나 특이하게 처리된 표본 수를 모아
  ///       사람이 읽을 수 있는 집계 문자열로 만든다. 값 파일(`encode()`
  ///       가 만드는 문자열)에는 이 집계를 섞지 않는다. 판독 측이 값
  ///       행만 읽기 때문이다.
  /// 인자: result — 격자 환산 결과
  /// 반환: 집계 항목이 줄바꿈으로 이어진 문자열
  static String encodeMeta(GridResampleResult result) {
    final buffer = StringBuffer(); // 집계 문자열을 쌓아갈 버퍼
    void line(String text) {
      buffer.write(text);
      buffer.write(lineEnding);
    }

    line('# OTIS 계측 집계');
    line('format: $formatId ($columnCount열)');
    line('gridRateHz: ${1000000000 ~/ result.gridIntervalNs}');
    line('gridIntervalNs: ${result.gridIntervalNs}');
    line('t0Ns: ${result.t0Ns}');
    line('rowCount: ${result.rowCount}');
    line('durationSec: ${result.durationSec.toStringAsFixed(6)}');
    line('');
    // rawUsedCount · gravityUsedCount: 원본 가속도 · 중력 두 센서에서
    // 격자를 채우는 데 실제로 쓰인 표본 수. rawMaxSpanUs ·
    // gravityMaxSpanUs: 그 표본들 사이 시간 간격 중 가장 컸던 값(마이
    // 크로초) — 넓을수록 그만큼 성긴 원본 데이터로 비례 계산했다는 뜻
    line('rawUsedCount: ${result.rawUsedCount}');
    line('gravityUsedCount: ${result.gravityUsedCount}');
    line('rawMaxSpanUs: ${result.rawMaxSpanNs ~/ 1000}');
    line('gravityMaxSpanUs: ${result.gravityMaxSpanNs ~/ 1000}');
    line('');
    // 환산 과정에서 그대로 못 쓰고 버리거나 대체한 표본 수.
    // droppedZeroCount: 측정 시작 직후처럼 X Y Z가 전부 0으로 온
    // 표본(그대로 쓰면 없는 진동이 만들어져 버린다).
    // droppedBackwardCount: 시각이 직전 표본보다 거꾸로 온 표본.
    // droppedLinearCount: 안드로이드가 자체 계산해 보내는(쓰지 않기로
    // 한) linear 값. degenerateSpanCount: 비례 계산에 쓸 앞뒤 두
    // 실측값의 시각이 같아 계산 대신 앞 값을 그대로 쓴 횟수.
    // headTrimmedRows · tailTrimmedRows는 바로 아래 설명대로다.
    line('droppedZeroCount: ${result.droppedZeroCount}');
    line('droppedBackwardCount: ${result.droppedBackwardCount}');
    line('droppedLinearCount: ${result.droppedLinearCount}');
    line('degenerateSpanCount: ${result.degenerateSpanCount}');
    line('headTrimmedRows: ${result.headTrimmedRows}');
    line('tailTrimmedRows: ${result.tailTrimmedRows}');
    line('');
    line('# headTrimmedRows / tailTrimmedRows 는 두 센서의 수신 구간이');
    line('# 어긋난 만큼 격자를 만들지 않은 행 수다. 직전 값 복사는 하지 않는다.');
    return buffer.toString();
  }

  /// 함수: writeMeta
  /// 목적: 집계 파일을 기록한다. 격자 환산이 실패하면 `result`에는
  ///       표본 없이 실패 사유(`failureReason`)만 담겨 오는데, 이때도
  ///       집계 파일은 그대로 만들고 그 사유를 파일 끝에 한 줄
  ///       추가한다. 나중에 왜 실패했는지 찾아볼 수 있어야 하기
  ///       때문이다. (반면 값 파일을 쓰는 `write()`는 실패한 결과면
  ///       아예 쓰지 않고 예외를 던진다.)
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과. 실패했으면 `failureReason`에
  ///       사유가 들어있다
  /// 반환: 기록한 파일
  static Future<File> writeMeta(String path, GridResampleResult result) async {
    final file = File(path); // 기록할 파일 객체
    await file.parent.create(recursive: true);
    // → 로직 이동: encodeMeta()
    final body = StringBuffer(encodeMeta(result)); // 집계 파일 본문
    if (result.failureReason != null) {
      body.write('failureReason: ${result.failureReason}');
      body.write(lineEnding);
    }
    await file.writeAsString(body.toString());
    return file;
  }
}
