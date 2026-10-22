import 'dart:io';

import 'package:vibration_checker/domain/capture/grid_resampler.dart';

/// 작성: 2026-08-18 23:43:06 · 박건준
/// 수정: 2026-10-23 00:50:00 · nada
/// 클래스: EvimpWriter
/// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산 결과를
///       참조 파일과 같은 구조의 텍스트 파일(`raw.txt`)로 기록한다. 집계
///       파일(`meta.txt`)은 `MetaWriter` 가 쓴다.
///
///       참조한 OTIS 데이터 텍스트 파일에서 확인한 구조:
///       1줄  포맷 식별자
///       2줄  초당 행 수
///       3줄~ 값들, 공백 구분, 소수점 최대 3자리(뒤 0 제거), 줄 끝은
///       참조 파일과 같은 줄바꿈 문자(`lineEnding` 참고)로 되어 있다.
///       시간 열은 없다. 시각은 행 번호로만 결정된다.
///
///       이번 산출물은 소음 열이 붙은 4열 EVIMP1(회사 EVA 진동측정 장비가
///       쓰는 표준 데이터 포맷)이다.
class EvimpWriter {
  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 변수: formatId
  /// 목적: 이번 산출물의 포맷 식별자. X Y Z 소음 4열이므로 EVIMP1 을 쓴다.
  /// 근거: 인용 — 참조한 OTIS 데이터 텍스트 파일 1줄이 EVIMP1, 4열(X Y Z 소음) 구조.
  static const String formatId = 'EVIMP1';

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 변수: columnCount
  /// 목적: 이번 산출물의 열 수 (X Y Z 소음)
  static const int columnCount = 4;

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 변수: decimalDigits
  /// 목적: 값 하나의 소수점 자리 수
  /// 근거: 인용 — 참조 파일 값의 소수점 자리가 최대 3자리
  static const int decimalDigits = 3;

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 변수: lineEnding
  /// 목적: 줄바꿈 문자
  /// 근거: 인용 — 참조 파일의 줄바꿈 문자가 이 두 글자(`\r\n`)와 같다
  static const String lineEnding = '\r\n';

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-10-21 23:20:00 · nada
  /// 함수: encode
  /// 목적: 격자 환산 결과를 참조 파일과 같은 구조의 문자열로 만든다.
  ///       1줄에 포맷 식별자, 2줄에 초당 행 수를 쓰고, 그 뒤로 격자
  ///       행마다 진동·소음 값(X Y Z 소음)을 한 줄씩 이어붙인다.
  ///       진동 세 축은 축마다 내보내는 행 전체의 평균(`axisMeans()`)을 빼고
  ///       쓴다(2026-10-21). OTIS EVIMP1 내보내기와 같은 관례다. 정지 →
  ///       운행 → 정지 기록은 가속도 전체 평균이 물리적으로 0 이라, 빼는
  ///       것은 가속도계 영점 오차뿐이다. 손대지 않은 원본은 안드로이드
  ///       원본(`native_raw.txt`)에 따로 남고, 뺀 평균은 집계 파일
  ///       (`MetaWriter.encodeMeta()`)에 적는다. 소음 열은 그대로다.
  /// 인자: result — 격자 환산 결과. `result.samples`에 격자 행마다
  ///       하나씩, 원본 가속도에서 중력 성분을 뺀 진동 값과 소음이 들어있다
  /// 반환: 머리말 2줄과 값 행들이 `lineEnding`으로 이어진 문자열
  /// 식: 값_축(i) = 격자_축(i) - 평균_축(격자_축(0..n-1))
  /// 근거: 측정 — 2026-10-21 오티스폰 EVIMP1 내보내기(otis_* 3건)와 원본
  ///       리포트 기록(ride_reference)의 축별 평균이 X · Y 0.0000, Z −0.002
  ///       ~ −0.012 mg 다. 개발폰 하강 기록은 영점 오차로 정지 Z 가
  ///       −13.6 mg 였다
  static String encode(GridResampleResult result) {
    // → 로직 이동: axisMeans()
    final mean = axisMeans(result); // 축마다 뺄 평균 (mg)
    final rateHz = 1000000000 ~/ result.gridIntervalNs; // 1초(10억 나노초)를 격자
    // 간격(나노초)으로 나눈 값 — 1초에 몇 행이 들어가는지
    final buffer = StringBuffer(); // 완성할 문자열을 쌓아갈 버퍼
    buffer.write(formatId);
    buffer.write(lineEnding);
    buffer.write('$rateHz');
    buffer.write(lineEnding);
    for (final s in result.samples) {
      // s: 격자 행 하나의 진동 값(X Y Z, mg)과 소음(dBA)
      // → 로직 이동: formatValue()
      buffer.write(formatValue(s.xMg - mean.x));
      buffer.write(' ');
      buffer.write(formatValue(s.yMg - mean.y));
      buffer.write(' ');
      buffer.write(formatValue(s.zMg - mean.z));
      buffer.write(' ');
      buffer.write(formatValue(s.noiseDba));
      buffer.write(lineEnding);
    }
    return buffer.toString();
  }

  /// 작성: 2026-10-21 23:20:00 · nada
  /// 함수: axisMeans
  /// 목적: 값 파일에서 뺄 축별 평균을 낸다. 내보내는 격자 행 전체의
  ///       평균이다. 행이 없으면(환산 실패) 0 을 돌려준다 — 그때는 값 파일을
  ///       쓰지 않고(`write()`), 집계 파일에도 적지 않는다(`MetaWriter.encodeMeta()`).
  /// 인자: result — 격자 환산 결과
  /// 반환: X · Y · Z 평균 (mg)
  static ({double x, double y, double z}) axisMeans(GridResampleResult result) {
    final rows = result.samples; // 격자 행
    if (rows.isEmpty) return (x: 0.0, y: 0.0, z: 0.0);
    var sx = 0.0; // X 합
    var sy = 0.0; // Y 합
    var sz = 0.0; // Z 합
    for (final s in rows) {
      sx += s.xMg;
      sy += s.yMg;
      sz += s.zMg;
    }
    final n = rows.length; // 행 수
    return (x: sx / n, y: sy / n, z: sz / n);
  }

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 함수: formatValue
  /// 목적: 값 하나(mg)를 참조 파일과 같은 표기로 바꾼다. 소수점 3자리로
  ///       자른 뒤, 뒤에 남는 0 은 떼어낸다. 표기 예시는 참조한 OTIS
  ///       데이터 텍스트 파일을 참고한다.
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

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 함수: write
  /// 목적: 격자 환산 결과를 값 파일로 기록한다. `MetaWriter.writeMeta()`와 달리
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
}
