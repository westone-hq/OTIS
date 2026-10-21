import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/report_page1.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-16 09:12:40 · nada
/// 변수: _outputPath
/// 목적: 만들어 낸 1쪽을 남겨 둘 자리. 표와 신호등이 서식 위에 제대로
///       얹혔는지는 숫자로 재기 어려워 눈으로 열어 봐야 한다. 시험이
///       끝나도 지우지 않는 이유가 그것이다.
const _outputPath = 'build/report_page1_test.pdf';

/// 작성: 2026-09-16 09:12:40 · nada
/// 함수: _result
/// 목적: 1쪽을 그려 보려고 만드는 측정 결과. 지금 값을 낼 수 있는 두
///       지표만 채우고 나머지는 비운다 — 실제 측정이 지금 그렇다.
/// 반환: 1쪽 렌더링에 넣을 측정 결과
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260915-130837',
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-10-11 19:15:25 · nada
/// 함수: _siteResult
/// 목적: 현장 정보 새 항목을 모두 채운 측정 결과를 만든다.
/// 인자: loadUnit — 하중 단위
///       analysisType — 해석 종류
///       model — 기종
/// 반환: 머리말 문구를 볼 측정 결과
MeasurementResult _siteResult({
  String loadUnit = 'kg',
  String analysisType = '층간 시험',
  String model = 'Gen2',
}) {
  return _result().copyWith(
    address: '덕양구 오금동, 고양시, 경기도',
    postalCode: '10575',
    model: model,
    load: 2000.0,
    loadUnit: loadUnit,
    analysisType: analysisType,
    engineerName: '홍길동',
  );
}

/// 작성: 2026-09-16 09:12:40 · nada
/// 수정: 2026-10-15 15:53:26 · nada
/// 함수: main
/// 목적: 1쪽 렌더링을 시험한다. 자리가 맞는지는 `ReportLayout` 과 대조하는
///       `report_layout_test.dart` 가 맡으므로, 여기서는 PDF 가 실제로
///       만들어지는지, 디버그 모드가 제품 흐름에 섞이지 않는지, 머리말
///       칸마다 찍을 문구가 맞는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPage1Renderer', () {
    test('1쪽 PDF 를 만들어 낸다', () async {
      final bytes = await renderReportPage1(result: _result()); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'PDF 머리말이 있어야 한다',
      );

      final file = File(_outputPath); // 대조 스크립트가 읽을 파일
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    });

    test('디버그 모드는 기본으로 꺼져 있다', () async {
      // 표식을 그리면 그만큼 내용이 늘어난다. 기본값으로 부른 결과가 더
      // 작아야 제품 흐름에 표식이 섞이지 않는다는 뜻이다
      final plain = await renderReportPage1(result: _result()); // 기본값
      final marked = await renderReportPage1(
        result: _result(),
        debug: true,
      ); // 표식을 켠 것

      expect(marked.length, greaterThan(plain.length));
    });
  });

  group('ReportPage1Renderer.headerValues — 머리말 문구', () {
    test('하중은 입력 숫자와 단위 표기를 이어 쓰고, 예전 lb 결과는 파운드다', () {
      expect(
        ReportPage1Renderer.headerValues(_siteResult())['load'],
        '2000 킬로그램',
      );
      expect(
        ReportPage1Renderer.headerValues(_siteResult(loadUnit: 'lb'))['load'],
        '2000 파운드',
      );
      final decimal = _siteResult().copyWith(load: 1350.5); // 소수 하중
      expect(ReportPage1Renderer.headerValues(decimal)['load'], '1350.5 킬로그램');
    });

    test('측정 칸은 해석 종류 문구 그대로다', () {
      for (final type in SiteInfo.analysisTypeOptions) {
        expect(
          ReportPage1Renderer.headerValues(
            _siteResult(analysisType: type),
          )['test_type'],
          type,
        );
      }
    });

    test('주소 칸은 주소 끝에 우편번호를 붙인다', () {
      expect(
        ReportPage1Renderer.headerValues(_siteResult())['address'],
        '덕양구 오금동, 고양시, 경기도, 10575',
      );
    });

    test('제품 칸은 엘리베이터와 기종이고 기종의 쉼표는 공백으로 바꾼다', () {
      expect(
        ReportPage1Renderer.headerValues(_siteResult())['product'],
        '엘리베이터, Gen2',
      );
      expect(
        ReportPage1Renderer.headerValues(
          _siteResult(model: '줄-로우프, 2:1'),
        )['product'],
        '엘리베이터, 줄-로우프 2:1',
      );
    });

    test('층 정보는 Start Floor · Stop Floor 로 적는다', () {
      expect(
        ReportPage1Renderer.headerValues(_siteResult())['floors'],
        'Start Floor : ${_siteResult().bottomFloor}, '
        'Stop Floor : ${_siteResult().topFloor}',
      );
    });

    test('하강이면 최상층에서 출발해 최하층에 선다', () {
      final down = _siteResult().copyWith(
        bottomFloor: 4,
        topFloor: 11,
        direction: SiteInfo.directionDown,
      ); // 하강 결과
      expect(
        ReportPage1Renderer.headerValues(down)['floors'],
        'Start Floor : 11, Stop Floor : 4',
      );
      final legacy = down.copyWith(direction: '상부 → 하부'); // 예전 표기
      expect(
        ReportPage1Renderer.headerValues(legacy)['floors'],
        'Start Floor : 11, Stop Floor : 4',
      );
      final up = down.copyWith(direction: SiteInfo.directionUp); // 상승
      expect(
        ReportPage1Renderer.headerValues(up)['floors'],
        'Start Floor : 4, Stop Floor : 11',
      );
    });

    test('측정 일시는 기기 시간대와 상관없이 한국 시간이다', () {
      final utc = _siteResult().copyWith(
        dateTime: DateTime.utc(2026, 1, 14, 2, 3, 59),
      ); // UTC 02:03:59 = 한국 11:03:59
      expect(
        ReportPage1Renderer.headerValues(utc)['datetime'],
        '14/01/2026 11:03:59 AM',
      );
      final evening = _siteResult().copyWith(
        dateTime: DateTime.utc(2026, 1, 14, 15, 30),
      ); // UTC 15:30 = 한국 다음 날 00:30
      expect(
        ReportPage1Renderer.headerValues(evening)['datetime'],
        '15/01/2026 12:30:00 AM',
      );
    });

    test('엔지니어 칸은 저장된 이름이다', () {
      expect(
        ReportPage1Renderer.headerValues(_siteResult())['engineer_name'],
        '홍길동',
      );
    });

    test('값이 없는 예전 결과는 빈 칸 대신 자리 표시와 기본 문구를 찍는다', () {
      final header = ReportPage1Renderer.headerValues(_result()); // 예전 결과

      expect(header['engineer_name'], ReportPage1.placeholder);
      expect(header['load'], ReportPage1.placeholder);
      expect(header['address'], ReportPage1.placeholder);
      expect(header['test_type'], '층간 시험');
      expect(header['product'], '엘리베이터');
      expect(header.values, everyElement(isNot(contains('null'))));
      expect(header.values, everyElement(isNot('0')));
    });

    test('주소만 있고 우편번호가 없으면 주소만 쓴다', () {
      final onlyAddress = _result().copyWith(address: '서울시'); // 예전 결과
      expect(ReportPage1Renderer.headerValues(onlyAddress)['address'], '서울시');
    });

    test('긴 주소 · 해석 종류도 PDF 를 만들어 낸다', () async {
      final long =
          _siteResult(
            analysisType: '사이클 저크(가속도증가율) 테스트',
            model: '줄-로우프, 2:1',
          ).copyWith(
            address:
                '경기도 고양시 덕양구 오금동 690 한화 고양 삼송 이지스 '
                '데이터센터 B동 지하 3층 승강기 기계실 옆',
          ); // 가장 긴 문구들
      final bytes = await renderReportPage1(result: long); // 만든 PDF

      expect(bytes.length, greaterThan(1000));
    });

    test('넘칠 수 있는 칸만 폭을 재고 폭은 오른쪽 여백까지다', () {
      expect(
        ReportPage1.maxWidthOf(ReportPage1.address),
        ReportPage1.headerRightLimitX - ReportPage1.address.x,
      );
      expect(ReportPage1.maxWidthOf(ReportPage1.testType), isNotNull);
      expect(ReportPage1.maxWidthOf(ReportPage1.measurementId), isNull);
    });
  });
}
