import 'dart:io';

import 'package:vibration_checker/domain/capture/grid_resampler.dart';

/// 목적: 격자 환산 결과를 참조 파일과 같은 구조의 텍스트 파일로 기록한다.
///
///       참조 파일(H6N1AP65.txt)에서 확인한 구조:
///       1줄  포맷 식별자
///       2줄  초당 행 수
///       3줄~ 값들, 공백 구분, 소수점 최대 3자리(뒤 0 제거), 줄바꿈 CRLF
///       시간 열은 없다. 시각은 행 번호로만 결정된다.
///
///       이번 산출물은 소음 열이 없는 3열이므로 EVIMP1 이 아니다.
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
  /// 근거: 인용 — 참조 파일 줄바꿈이 CRLF(0x0D 0x0A)
  static const String lineEnding = '\r\n';

  /// 목적: 격자 환산 결과를 파일 본문 문자열로 만든다.
  /// 인자: result — 격자 환산 결과
  /// 반환: 머리말 2줄과 값 행들이 CRLF 로 이어진 문자열
  static String encode(GridResampleResult result) {
    final rateHz = 1000000000 ~/ result.gridIntervalNs;
    final buffer = StringBuffer();
    buffer.write(formatId);
    buffer.write(lineEnding);
    buffer.write('$rateHz');
    buffer.write(lineEnding);
    for (final s in result.samples) {
      buffer.write(formatValue(s.xMg));
      buffer.write(' ');
      buffer.write(formatValue(s.yMg));
      buffer.write(' ');
      buffer.write(formatValue(s.zMg));
      buffer.write(lineEnding);
    }
    return buffer.toString();
  }

  /// 목적: 값 하나를 참조 파일과 같은 표기로 바꾼다.
  ///       소수점 3자리로 자른 뒤 뒤쪽 0 을 떼어낸다.
  ///       참조 파일에도 0.7, 44.94, 정수 표기가 섞여 있다.
  /// 인자: value — 기록할 값 (mg)
  /// 반환: 표기 문자열
  static String formatValue(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    var text = value.toStringAsFixed(decimalDigits);
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

  /// 목적: 격자 환산 결과를 실제 파일로 기록한다.
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과
  /// 반환: 기록한 파일. 환산이 실패한 결과면 기록하지 않고 예외를 던진다
  static Future<File> write(String path, GridResampleResult result) async {
    if (!result.isSuccess) {
      throw StateError('격자 환산 실패 결과는 기록하지 않는다: ${result.failureReason}');
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(encode(result));
    return file;
  }

  /// 목적: 환산 과정에서 폐기·이상으로 집계된 수치를 별도 파일 본문으로 만든다.
  ///       값 파일에는 집계를 섞지 않는다. 판독 측이 값 행만 읽기 때문이다.
  /// 인자: result — 격자 환산 결과
  /// 반환: 사람이 읽는 집계 문자열
  static String encodeMeta(GridResampleResult result) {
    final buffer = StringBuffer();
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
    line('rawUsedCount: ${result.rawUsedCount}');
    line('gravityUsedCount: ${result.gravityUsedCount}');
    line('rawMaxSpanUs: ${result.rawMaxSpanNs ~/ 1000}');
    line('gravityMaxSpanUs: ${result.gravityMaxSpanNs ~/ 1000}');
    line('');
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

  /// 목적: 집계 파일을 기록한다.
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과 (실패 결과도 기록한다. 사유 보존이 목적)
  /// 반환: 기록한 파일
  static Future<File> writeMeta(
    String path,
    GridResampleResult result,
  ) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final body = StringBuffer(encodeMeta(result));
    if (result.failureReason != null) {
      body.write('failureReason: ${result.failureReason}');
      body.write(lineEnding);
    }
    await file.writeAsString(body.toString());
    return file;
  }
}
