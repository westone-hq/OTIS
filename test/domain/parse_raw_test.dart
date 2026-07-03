import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/parse_raw.dart';

void main() {
  group('P9 · EVIMP1 RAW 데이터 파싱 및 시계열 변환 유닛 테스트', () {
    const sampleText = '''
EVIMP1
256
-3.351 3.545 -1.787 58.073
-2.074 2.49 -1.255 59.165
0.268 0.732 1.422 60.644
3.987 1.773 -0.549 63.884
''';

    test('parseEvimp1 - 헤더 인식, 4컬럼 배열 파싱 및 지표 산출 정확도 검증', () {
      final result = RawDataParser.parseEvimp1(
        rawContent: sampleText,
        id: 'test_id',
        jobNo: '2024F 1447R01',
        siteName: '테스트 현장',
        bottomFloor: 1,
        topFloor: 8,
        direction: '상향',
        dateTime: DateTime(2026, 7, 3),
      );

      // 1. 4개 샘플 배열 파싱 확인
      expect(result.xSeries.length, 4);
      expect(result.ySeries.length, 4);
      expect(result.zSeries.length, 4);
      expect(result.noiseSeries.length, 4);

      // 2. X축 P2P 산출 검증: max(3.987) - min(-3.351) = 7.338 => 7.34
      expect(result.xPtp, 7.34);

      // 3. 소음 최대치 산출 검증: max(63.884) => 63.88
      expect(result.noiseMax, 63.88);

      // 4. 수치 연산 파생 배열(속도, 거리, 가속도, 저크) 생성 확인
      expect(result.speedSeries.length, 4);
      expect(result.positionSeries.length, 4);
      expect(result.accelSeries.length, 4);
      expect(result.jerkSeries.length, 4);
    });

    test('parseEvimp1 - 빈 데이터 입력 시 안전한 0 배열 처리 검증', () {
      final result = RawDataParser.parseEvimp1(
        rawContent: '# empty file\nEVIMP1\n256\n',
        id: 'empty_id',
        jobNo: '0000',
        siteName: '빈 현장',
        bottomFloor: 1,
        topFloor: 2,
        direction: '상향',
        dateTime: DateTime.now(),
      );

      expect(result.xSeries, [0.0]);
      expect(result.xPtp, 0.0);
      expect(result.distance, 0.0);
    });
  });
}
