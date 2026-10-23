import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';

/// 작성: 2026-10-15 15:53:26 · 박건준
/// 함수: main
/// 목적: `KoreaTime.of()` 가 같은 순간을 늘 한국 시간 글자로 바꾸는지 본다.
///       기기 시간대가 무엇이든 UTC 로 준 순간과 그 순간의 현지 시각이
///       같은 결과를 내야 한다.
void main() {
  test('UTC 순간을 9시간 뒤 벽시계로 바꾼다', () {
    final kst = KoreaTime.of(DateTime.utc(2026, 10, 15, 6, 53, 26)); // 한국 시각
    expect(
      DateFormat('yyyy-MM-dd HH:mm:ss').format(kst),
      '2026-10-15 15:53:26',
    );
  });

  test('UTC 자정 직전은 한국에서 다음 날이다', () {
    final kst = KoreaTime.of(DateTime.utc(2026, 12, 31, 23, 0)); // 한국 시각
    expect(DateFormat('yyyyMMdd-HHmmss').format(kst), '20270101-080000');
  });

  test('같은 순간이면 현지 시각으로 줘도 결과가 같다', () {
    final moment = DateTime.utc(2026, 1, 14, 2, 3, 59); // 기준 순간
    expect(KoreaTime.of(moment.toLocal()), KoreaTime.of(moment));
  });

  test('화면 · 메일 글자는 분까지, 측정 ID 는 초까지 한국 시각이다', () {
    final moment = DateTime.utc(2026, 10, 15, 6, 53, 26); // 기준 순간
    expect(KoreaTime.minuteLabel(moment), '2026-10-15 15:53');
    expect(KoreaTime.idStamp(moment), '20261015-155326');
    expect(KoreaTime.minuteLabel(moment.toLocal()), '2026-10-15 15:53');
  });
}
