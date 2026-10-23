import 'package:intl/intl.dart';

/// 작성: 2026-10-15 15:53:26 · 박건준
/// 클래스: KoreaTime
/// 목적: 사람이 읽는 시각(리포트 머리말 · 측정 ID · 화면 · 메일 본문)을
///       기기의 시간대 설정과 상관없이 한국 시간(UTC+9)으로 맞춘다. 저장
///       값(`MeasurementResult.dateTime`)은 바꾸지 않고 보여 줄 때만
///       바꾼다.
/// 근거: 인용 — 2026-10-15 사용자 지시 "시간 같은건 다 한국 시간으로".
///       표준 — 한국 표준시는 UTC+9 이고 일광 절약 시간이 없다
class KoreaTime {
  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 함수: KoreaTime._
  /// 목적: 함수만 두는 클래스라 객체를 만들지 못하게 막는다.
  KoreaTime._();

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: offset
  /// 목적: 한국 표준시와 UTC 의 차이.
  /// 근거: 표준 — KST = UTC+9, 일광 절약 시간 없음
  static const Duration offset = Duration(hours: 9);

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 함수: of
  /// 목적: 한 순간을 한국 시간의 벽시계 값으로 바꾼다. 돌려준 값을
  ///       `DateFormat` 에 넘기면 한국 시간 글자가 나온다.
  /// 인자: moment — 바꿀 순간. 기기 현지 시각이든 UTC 든 같은 순간이면
  ///       같은 결과다
  /// 반환: 년 · 월 · 일 · 시 · 분 · 초가 한국 시간인 값. 표시 전용이다 —
  ///       UTC 표시가 붙어 있으므로 다른 순간과 견주거나 저장하지 않는다
  static DateTime of(DateTime moment) => moment.toUtc().add(offset);

  /// 작성: 2026-10-22 23:50:00 · 박건준
  /// 함수: minuteLabel
  /// 목적: 화면 · 메일 제목에 적는 분까지의 한국 시각 글자를 만든다. 결과
  ///       화면 머리 · 비교 배너 · 비교 시트 · 저장 결과 목록 · 메일 제목이
  ///       같은 모양을 쓴다.
  /// 인자: moment — 적을 순간
  /// 반환: `yyyy-MM-dd HH:mm` 꼴 한국 시각 (예: 2026-10-15 15:53)
  static String minuteLabel(DateTime moment) =>
      // → 로직 이동: of()
      DateFormat('yyyy-MM-dd HH:mm').format(of(moment));

  /// 작성: 2026-10-22 23:50:00 · 박건준
  /// 함수: idStamp
  /// 목적: 측정 ID(측정 폴더 이름)에 쓰는 초까지의 한국 시각 글자를 만든다.
  ///       글자 차례가 곧 시간 차례라 저장 결과 정리가 이 글자로 오래된
  ///       측정을 고른다.
  /// 인자: moment — 측정 시각
  /// 반환: `yyyyMMdd-HHmmss` 꼴 한국 시각 (예: 20261015-155326)
  static String idStamp(DateTime moment) =>
      // → 로직 이동: of()
      DateFormat('yyyyMMdd-HHmmss').format(of(moment));
}
