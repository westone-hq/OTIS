import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-10-11 16:58:59 · 박건준
/// 수정: 2026-10-13 13:17:56 · 박건준
/// 함수: _site
/// 목적: 새 항목까지 모두 채운 현장 정보를 만든다.
/// 반환: 시험용 현장 정보
SiteInfo _site() => const SiteInfo(
  jobNo: '2025F 1234R01',
  siteName: '시험 현장',
  bottomFloor: '1',
  topFloor: '8',
  direction: SiteInfo.directionDown,
  model: '유압',
  load: '4400',
  analysisType: '브레이크 기능',
  notes: '참고',
);

/// 작성: 2026-10-11 17:28:28 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 함수: _siteWith
/// 목적: 검사를 통과하는 현장 정보에서 몇 칸만 바꾼 것을 만든다.
/// 인자: load, notes, bottomFloor, topFloor — 바꿀 값. 안 주면 통과하는 값
/// 반환: 시험용 현장 정보
SiteInfo _siteWith({
  String load = '2000',
  String notes = '',
  String bottomFloor = '1',
  String topFloor = '8',
}) => SiteInfo(
  jobNo: '2025F 1234R01',
  siteName: '시험 현장',
  bottomFloor: bottomFloor,
  topFloor: topFloor,
  direction: SiteInfo.directionUp,
  model: 'Gen2',
  load: load,
  notes: notes,
);

/// 작성: 2026-10-11 16:58:59 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 함수: _result
/// 목적: 현장 정보만 의미 있는 측정 결과를 만든다. 주소 · 우편번호는
///       2026-10-27 전 결과처럼 채워 둔다 — 되살릴 때 버리는지 본다.
/// 인자: load, loadUnit, analysisType, postalCode, notes — 새 항목. 안
///       주면 null(예전 측정)
///       bottomFloor, topFloor — 층 번호. 안 주면 1 · 8
/// 반환: 시험용 측정 결과
MeasurementResult _result({
  double? load,
  String? loadUnit,
  String? analysisType,
  String? postalCode,
  String? notes,
  int bottomFloor = 1,
  int topFloor = 8,
}) {
  return MeasurementResult(
    id: '20261011-165859',
    jobNo: '2025F 1234R01',
    siteName: '시험 현장',
    address: '서울시',
    bottomFloor: bottomFloor,
    topFloor: topFloor,
    direction: SiteInfo.directionUp,
    model: 'Gen2',
    load: load,
    loadUnit: loadUnit,
    analysisType: analysisType,
    postalCode: postalCode,
    notes: notes,
    dateTime: DateTime(2026, 10, 11),
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

/// 작성: 2026-10-11 16:58:59 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 함수: main
/// 목적: 현장 정보의 새 항목(하중 · 해석 종류 · 참고사항 · 지하층)을
///       시험한다. 기기 저장 표 왕복, 선택지 밖 값의 기본값 처리, kg 고정
///       뒤 예전 lb 저장 표 · 결과 읽기, 주소 · 우편번호를 받지 않게 된 뒤
///       예전 표 · 결과 읽기, 저장된 결과에서 되살리기, 필수 검사, 층 표기,
///       하중 문자열 만들기, 선택지 목록을 본다.
void main() {
  group('SiteInfo 저장 표', () {
    test('toMap → fromMap 왕복에서 새 항목이 그대로 남는다', () {
      final restored = SiteInfo.fromMap(_site().toMap()); // 되읽은 현장 정보

      expect(restored.load, '4400');
      expect(restored.analysisType, '브레이크 기능');
    });

    test('주소 · 우편번호는 저장 표에 넣지 않고 예전 표에 있어도 버린다', () {
      expect(_site().toMap().containsKey('address'), isFalse);
      expect(_site().toMap().containsKey('postalCode'), isFalse);
      final restored = SiteInfo.fromMap(<String, String?>{
        'jobNo': 'J-1',
        'address': '서울시',
        'postalCode': '04524',
      }); // 2026-10-27 전 빌드가 남긴 표

      expect(restored.jobNo, 'J-1');
      expect(restored.toMap().containsKey('address'), isFalse);
    });

    test('참고사항은 저장 표에 넣지 않아 다음 입력은 빈 칸에서 시작한다', () {
      final map = _site().toMap(); // 기기에 저장할 표

      expect(map.containsKey('notes'), isFalse);
      expect(SiteInfo.fromMap(map).notes, '');
    });

    test('하중 단위는 저장 표에 넣지 않는다 (kg 고정)', () {
      expect(_site().toMap().containsKey('loadUnit'), isFalse);
    });

    test('예전 저장 표에 loadUnit: lb 가 남아 있어도 오류 없이 읽는다', () {
      final restored = SiteInfo.fromMap(<String, String?>{
        'jobNo': 'J-1',
        'load': '4400',
        'loadUnit': 'lb',
      });

      expect(restored.jobNo, 'J-1');
      expect(restored.load, '4400');
      expect(restored.toMap().containsKey('loadUnit'), isFalse);
    });

    test('선택지에 없는 해석 종류는 기본값으로 읽는다', () {
      final restored = SiteInfo.fromMap(<String, String?>{
        'analysisType': '없어진 종류',
      });

      expect(restored.analysisType, SiteInfo.defaultAnalysisType);
    });

    test('새 항목이 없는 예전 저장 표는 빈 칸 · 기본값으로 읽는다', () {
      final restored = SiteInfo.fromMap(<String, String?>{
        'jobNo': 'J-1',
        'siteName': '현장',
      });

      expect(restored.load, '');
      expect(restored.analysisType, '층간 시험');
    });
  });

  group('SiteInfo.fromResult', () {
    test('저장된 결과의 새 항목을 되살리고 참고사항은 비운다', () {
      final site = SiteInfo.fromResult(
        _result(
          load: 2000.0,
          loadUnit: 'kg',
          analysisType: '일반',
          postalCode: '10575',
          notes: '지난 현장 메모',
        ),
      );

      expect(site.load, '2000');
      expect(site.analysisType, '일반');
      expect(site.notes, '');
      expect(
        site.validate(),
        isEmpty,
        reason: '주소 · 우편번호가 있던 예전 결과도 그대로 재실행된다',
      );
    });

    test('지하층 결과는 B 표기로 되살린다', () {
      final site = SiteInfo.fromResult(
        _result(load: 2000.0, loadUnit: 'kg', bottomFloor: -2, topFloor: 5),
      );

      expect(site.bottomFloor, 'B2');
      expect(site.topFloor, '5');
      expect(site.validate(), isEmpty);
    });

    test('새 항목이 없는 예전 결과는 빈 칸 · 기본값으로 되살린다', () {
      final site = SiteInfo.fromResult(_result());

      expect(site.load, '');
      expect(site.analysisType, SiteInfo.defaultAnalysisType);
    });

    test('lb 로 저장한 예전 결과는 하중을 빈 칸으로 되살려 검사에 걸린다', () {
      final site = SiteInfo.fromResult(
        _result(load: 4400.0, loadUnit: 'lb', postalCode: '10575'),
      );

      expect(site.load, '', reason: 'lb 숫자를 kg 로 다시 재면 안 된다');
      expect(site.validate(), contains(SiteFieldError.loadMissing));
    });
  });

  group('SiteInfo.copyWith', () {
    test('넘긴 값만 바꾸고 나머지 새 항목까지 그대로 옮긴다', () {
      final changed = _site().copyWith(direction: SiteInfo.directionUp);

      expect(changed.direction, SiteInfo.directionUp);
      expect(changed.load, '4400');
      expect(changed.analysisType, '브레이크 기능');
      expect(changed.notes, '참고');
    });
  });

  group('SiteInfo.validate — 새 필수 항목', () {
    test('모두 채우면 통과하고, 참고사항은 비어도 된다', () {
      expect(_siteWith().validate(), isEmpty);
      expect(_siteWith(notes: '').validate(), isEmpty);
      expect(_site().validate(), isEmpty);
    });

    test('지하층 B1 · B2 를 받고 지하가 지상보다 아래다', () {
      expect(_siteWith(bottomFloor: 'B2', topFloor: 'B1').validate(), isEmpty);
      expect(_siteWith(bottomFloor: 'b1', topFloor: '10').validate(), isEmpty);
      expect(_siteWith(bottomFloor: '1', topFloor: 'B1').validate(), [
        SiteFieldError.floorNotAscending,
      ]);
      for (final floor in <String>['0', 'B0', 'B', '1F', 'ㅠ1', '1.5']) {
        expect(_siteWith(bottomFloor: floor).validate(), [
          SiteFieldError.floorNotNumber,
        ], reason: floor);
      }
    });

    test('parseFloor · floorLabel 은 B 표기와 음수를 서로 바꾼다', () {
      expect(SiteInfo.parseFloor(' B1 '), -1);
      expect(SiteInfo.parseFloor('b12'), -12);
      expect(SiteInfo.parseFloor('8'), 8);
      expect(SiteInfo.parseFloor('-1'), -1, reason: '예전 빌드 입력');
      expect(SiteInfo.parseFloor('0'), isNull);
      expect(SiteInfo.floorLabel(-1), 'B1');
      expect(SiteInfo.floorLabel(-12), 'B12');
      expect(SiteInfo.floorLabel(8), '8');
    });

    test('하중이 비면 loadMissing, 0 보다 큰 유한한 수가 아니면 loadNotNumber', () {
      expect(_siteWith(load: ' ').validate(), [SiteFieldError.loadMissing]);
      for (final load in <String>['abc', '0', '-5', 'Infinity', 'NaN']) {
        expect(_siteWith(load: load).validate(), [
          SiteFieldError.loadNotNumber,
        ], reason: load);
      }
      for (final load in <String>[' 2000 ', '1.5', '0.01']) {
        expect(_siteWith(load: load).validate(), isEmpty, reason: load);
      }
    });

    test('parseLoad 는 0 보다 큰 유한한 수만 숫자로 돌려준다', () {
      expect(SiteInfo.parseLoad(' 2000 '), 2000.0);
      expect(SiteInfo.parseLoad('1.5'), 1.5);
      for (final load in <String>['', 'abc', '0', '-5', 'Infinity', 'NaN']) {
        expect(SiteInfo.parseLoad(load), isNull, reason: load);
      }
    });
  });

  group('SiteInfo 선택지와 하중 문자열', () {
    test('정수 하중은 소수점 없이, 소수 하중은 입력 자리까지 쓴다', () {
      expect(SiteInfo.loadText(2000.0), '2000');
      expect(SiteInfo.loadText(1.5), '1.5');
      expect(SiteInfo.loadText(1350.25), '1350.25');
    });

    test('하중 단위는 kg 이고 리포트 표기가 짝지어져 있다', () {
      expect(SiteInfo.loadUnit, 'kg');
      expect(SiteInfo.loadUnitReportLabels[SiteInfo.loadUnit], '킬로그램');
      expect(SiteInfo.loadUnitReportLabels['lb'], '파운드');
    });

    test('해석 종류는 지정된 다섯 가지이고 기본값은 층간 시험이다', () {
      expect(SiteInfo.analysisTypeOptions, const <String>[
        '일반',
        '층간 시험',
        '문 열림 사이클',
        '브레이크 기능',
        '사이클 저크(가속도증가율) 테스트',
      ]);
      expect(
        SiteInfo.analysisTypeOptions,
        contains(SiteInfo.defaultAnalysisType),
      );
    });
  });
}
