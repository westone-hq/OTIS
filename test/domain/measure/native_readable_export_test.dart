import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/native_readable_export.dart';

void main() {
  test('초별 가독 텍스트 — raw 표기, 1초당 개수, 256 제한 없음', () {
    final buf = StringBuffer();
    for (int i = 0; i < 300; i++) {
      buf.writeln('raw ${i * 3000} ${(10 + i).toDouble()} 0 0 0');
    }
    final text = buildNativeBySecondReadableText(
      buf.toString(),
      title: kRaw1to3BySecondFileName,
      requestLabel: '1~3ms',
    );
    expect(text, contains(kRaw1to3BySecondFileName));
    expect(text, contains('1~3ms'));
    expect(text, contains('======== 1초'));
    expect(text, contains('raw='));
    expect(text, contains('초별 raw 개수 요약'));
    expect(text, contains('raw 300 개'));
  });

  test('구버전 accel 타입도 raw로 인식', () {
    final text = buildNativeBySecondReadableText(
      'accel 0 1 0 0 0\naccel 5000 2 0 0 0\n',
      title: kRaw3to7BySecondFileName,
      requestLabel: '3~7ms',
    );
    expect(text, contains('raw='));
    expect(text, contains('raw 2 개'));
  });
}
