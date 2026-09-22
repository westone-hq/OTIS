import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

/// 작성: 2026-09-15 19:14:22 · nada
/// 변수: _fixturePath
/// 목적: 기준 측정 데이터 파일 경로. 원본 TUNE 리포트를 만든 실제 현장
///       측정 기록이며, 회귀는 이 파일로 고정한다.
const _fixturePath = 'test/fixtures/ride_reference.txt';

/// 작성: 2026-09-15 13:08:37 · nada
/// 함수: _grid
/// 목적: 시험에 쓸 격자 환산 결과를 만든다. 행 수와 격자 간격만 받고
///       나머지 집계값은 변환에 쓰이지 않으므로 0 으로 둔다.
/// 인자: samples — 격자 행 목록
///       gridIntervalNs — 격자 간격 (나노초)
/// 반환: 시험용 격자 환산 결과
GridResampleResult _grid(
  List<GridSample> samples, {
  int gridIntervalNs = 3906250,
}) {
  return GridResampleResult(
    samples: samples,
    t0Ns: 1000,
    gridIntervalNs: gridIntervalNs,
    rawUsedCount: samples.length,
    gravityUsedCount: samples.length,
    droppedZeroCount: 0,
    droppedBackwardCount: 0,
    droppedLinearCount: 0,
    headTrimmedRows: 0,
    tailTrimmedRows: 0,
    rawMaxSpanNs: 0,
    gravityMaxSpanNs: 0,
    degenerateSpanCount: 0,
  );
}

/// 작성: 2026-09-15 19:14:22 · nada
/// 함수: _fixtureFields
/// 목적: 기준 데이터 파일을 읽어 데이터 줄마다 열 값을 잘라 돌려준다.
///       EVIMP1 포맷이라 머리말이 두 줄(형식 태그, 샘플레이트)이고, 그
///       뒤로 X Y Z 소음 네 열이 공백으로 구분돼 있다.
///       줄바꿈이 CRLF 라 `\r` 가 남으면 마지막 열이 숫자로 읽히지
///       않는다. `LineSplitter` 가 `\r\n` 를 통째로 잘라내므로 값에
///       붙지 않는다.
/// 반환: 데이터 줄마다 열 문자열 네 개를 담은 목록
List<List<String>> _fixtureFields() {
  final lines = const LineSplitter()
      .convert(File(_fixturePath).readAsStringSync())
      .where((line) => line.trim().isNotEmpty)
      .toList(); // 빈 줄을 뺀 파일 전체 줄
  return lines
      .sublist(2)
      .map((line) => line.trim().split(RegExp(r'\s+')))
      .toList();
}

/// 작성: 2026-09-15 19:14:22 · nada
/// 함수: _fixtureRows
/// 목적: 기준 데이터를 격자 행으로 만든다. 세 진동 열만 쓰고 소음 열은
///       버린다 — 앱에 소음 수집 경로가 없어 변환이 소음을 받지 않는다.
/// 반환: 격자 행 11,388개
List<GridSample> _fixtureRows() {
  return _fixtureFields()
      .map(
        (fields) => GridSample(
          xMg: double.parse(fields[0]),
          yMg: double.parse(fields[1]),
          zMg: double.parse(fields[2]),
        ),
      )
      .toList();
}

/// 작성: 2026-09-15 14:32:07 · nada
/// 함수: _trapezoid
/// 목적: 승강기 한 번 운행을 흉내 낸 사다리꼴 속도 프로파일을 격자 행으로
///       만든다. 가속 · 정속 · 감속 세 구간이고, 수직 진동에만 값이 있다.
///       실측이 아니라 합성 입력이며, Dart 계산이 파이썬 프로토타입과
///       같은 값을 내는지 확인하는 데만 쓴다. 회귀 기준은 실측
///       데이터(`_fixtureRows()`)가 갖는다.
/// 반환: 격자 행 8,942개 (256Hz 로 약 34.9초)
/// 식: 가속 구간 길이 = 최대속도 / 가속도
///     가속 구간 이동량 = 최대속도² / (2 x 가속도)
///     정속 구간 길이 = (운행 거리 - 가속·감속 이동량) / 최대속도
List<GridSample> _trapezoid() {
  const fs = 256.0; // 샘플레이트 (Hz)
  const peak = 1.75; // 최대 속도 (m/s)
  const acc = 0.8; // 가·감속도 (m/s²)
  const targetDistance = 57.3; // 목표 운행 거리 (m)

  const dt = 1.0 / fs; // 행 사이 시간 간격 (초)
  const accelSeconds = peak / acc; // 가속 구간 길이 (초)
  const accelDistance = peak * peak / (2 * acc); // 가속 구간 이동량 (m)
  final cruiseSeconds =
      (targetDistance - 2 * accelDistance) / peak; // 정속 구간 길이 (초)

  final accelRows = (accelSeconds / dt).round(); // 가속 구간 행 수
  final cruiseRows = (cruiseSeconds / dt).round(); // 정속 구간 행 수

  const mgPerMetersPerSecondSquared = 1 / 9.80665e-3; // m/s² → mg 환산 계수
  final rows = <GridSample>[]; // 만들어 쌓을 격자 행
  void push(double accelMps2, int count) {
    final zMg = accelMps2 * mgPerMetersPerSecondSquared; // 수직 진동값 (mg)
    for (var i = 0; i < count; i++) {
      rows.add(GridSample(xMg: 0.0, yMg: 0.0, zMg: zMg));
    }
  }

  push(acc, accelRows);
  push(0.0, cruiseRows);
  push(-acc, accelRows);
  return rows;
}

/// 작성: 2026-09-15 13:08:37 · nada
/// 변수: _site
/// 목적: 시험에 쓸 현장 정보. 홈 화면이 실제로 넣는 값과 같은 형태다.
const _site = SiteInfo(
  jobNo: 'T-1001',
  siteName: '서울 본사',
  bottomFloor: '1',
  topFloor: '8',
  direction: '하부 → 상부',
  model: 'Gen2',
);

/// 작성: 2026-09-15 19:14:22 · nada
/// 변수: _threeRows
/// 목적: 최소 행 수 조건을 넘기려고 두는, 값 자체는 뜻이 없는 격자 행
///       세 개. 행 수 말고 다른 것을 보는 시험에서 쓴다.
const _threeRows = <GridSample>[
  GridSample(xMg: 0.0, yMg: 0.0, zMg: 0.0),
  GridSample(xMg: 0.0, yMg: 0.0, zMg: 0.0),
  GridSample(xMg: 0.0, yMg: 0.0, zMg: 0.0),
];

/// 작성: 2026-09-15 13:08:37 · nada
/// 수정: 2026-09-15 19:14:22 · nada
/// 함수: main
/// 목적: 캡처 결과를 측정 결과 모델로 바꾸는 변환을 시험한다.
///       - 진동 시계열과 샘플레이트가 제대로 옮겨지는지
///       - 아직 재지 않은 소음과 진동 P2P 가 0 이 아니라 비어 있는
///         채로 남는지
///       - 기종이 버려지지 않고 실리는지, 비었으면 null 인지
///       - 하지 않은 구간 검출이 성공으로 남지 않는지
///       - 환산 실패와 행 부족을 삼키지 않고 그대로 올리는지
///       - 실측 기준 데이터에서 파생 물리량이 프로토타입과 같은 값을
///         내는지
void main() {
  group('MeasurementAssembler.assemble', () {
    final measuredAt = DateTime(2026, 9, 15, 13, 8, 37); // 시험용 측정 시각

    test('격자 행이 시계열로 그대로 옮겨진다', () {
      final result = MeasurementAssembler.assemble(
        grid: _grid(const [
          GridSample(xMg: 1.0, yMg: -2.0, zMg: 3.0),
          GridSample(xMg: 4.0, yMg: -5.0, zMg: 6.0),
          GridSample(xMg: 7.0, yMg: -8.0, zMg: 9.0),
        ]),
        site: _site,
        id: '20260915-130837',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.isSuccess, isTrue);
      final model = result.result!; // 변환된 측정 결과
      expect(model.xSeries, [1.0, 4.0, 7.0]);
      expect(model.ySeries, [-2.0, -5.0, -8.0]);
      expect(model.zSeries, [3.0, 6.0, 9.0]);
      expect(model.id, '20260915-130837');
      expect(model.jobNo, 'T-1001');
      expect(model.bottomFloor, 1);
      expect(model.topFloor, 8);
      expect(model.dateTime, measuredAt);
      expect(model.totalVibrationSampleCount, 3);
    });

    test('샘플레이트를 격자 간격에서 구한다', () {
      final result = MeasurementAssembler.assemble(
        grid: _grid(_threeRows, gridIntervalNs: 3906250),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.result!.sampleRate, closeTo(256.0, 1e-9));
    });

    test('소음과 진동 P2P 는 0 이 아니라 비어 있다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries, isEmpty);
      expect(model.noiseMax, isNull);
      expect(model.xPtp, isNull);
      expect(model.yPtp, isNull);
      expect(model.zPtp, isNull);
    });

    test('소음 말고 시계열 일곱 개가 채워진다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(const [
          GridSample(xMg: 1.0, yMg: 2.0, zMg: 3.0),
          GridSample(xMg: 4.0, yMg: 5.0, zMg: 6.0),
          GridSample(xMg: 7.0, yMg: 8.0, zMg: 9.0),
        ]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.xSeries.length, 3);
      expect(model.ySeries.length, 3);
      expect(model.zSeries.length, 3);
      expect(model.positionSeries.length, 3);
      expect(model.speedSeries.length, 3);
      expect(model.accelSeries.length, 3);
      expect(model.jerkSeries.length, 3);
      expect(model.noiseSeries, isEmpty);
      expect(model.maxSpeed, isNotNull);
      expect(model.distance, isNotNull);
    });

    test('재지 않은 지표의 판정은 정상이 아니라 null 이다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.xExceeded, isNull);
      expect(model.yExceeded, isNull);
      expect(model.zExceeded, isNull);
      expect(model.noiseExceeded, isNull);
    });

    test('기종을 버리지 않고 함께 옮긴다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.model, 'Gen2');
    });

    test('기종이 비어 있으면 빈 문자열이 아니라 null 이다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: const SiteInfo(
          jobNo: 'T-1001',
          siteName: '서울 본사',
          bottomFloor: '1',
          topFloor: '8',
          direction: '하부 → 상부',
          model: '   ',
        ),
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.model, isNull);
    });

    test('검출하지 않은 구간을 성공으로 남기지 않는다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.usedDetectedRideSegment, isFalse);
      expect(model.usedDetectedConstantSpeed, isFalse);
      expect(model.constantSpeedRange, '미검출');
    });

    test('환산 실패는 삼키지 않고 사유를 그대로 올린다', () {
      final result = MeasurementAssembler.assemble(
        grid: GridResampleResult.failure(
          '두 센서의 수신 구간이 겹치지 않는다',
          gridIntervalNs: 3906250,
          rawUsedCount: 0,
          gravityUsedCount: 0,
          droppedZeroCount: 0,
          droppedBackwardCount: 0,
          droppedLinearCount: 0,
        ),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.isSuccess, isFalse);
      expect(result.result, isNull);
      expect(result.failureReason, '두 센서의 수신 구간이 겹치지 않는다');
    });

    test('층수를 숫자로 바꿀 수 없으면 사유를 올린다', () {
      final result = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: const SiteInfo(
          jobNo: 'T-1001',
          siteName: '서울 본사',
          bottomFloor: '지하 1',
          topFloor: '8',
          direction: '하부 → 상부',
          model: 'Gen2',
        ),
        id: 'id',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.isSuccess, isFalse);
      expect(result.failureReason, contains('층수를 숫자로 바꿀 수 없다'));
    });

    test('소음을 안 주면 시계열도 최대도 비어 있다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries, isEmpty);
      expect(model.noiseMax, isNull);
    });

    test('소음 시계열만 주면 그 최대로 noiseMax 를 채운다', () {
      // 수집 계층이 센서 최대를 못 실어 줄 때의 대비책이다
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
        noiseSeries: const <double>[44.0, 48.0, 46.0],
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries, const <double>[44.0, 48.0, 46.0]);
      expect(model.noiseMax, closeTo(48.0, 1e-9));
    });

    test('센서 최대를 주면 시계열 최대보다 그것을 앞세운다', () {
      // 소음은 약 8Hz 라 격자 시계열이 표본 사이 봉우리를 잃는다.
      // 센서가 본 최대가 있으면 그 값이 정본이다
      final model = MeasurementAssembler.assemble(
        grid: _grid(_threeRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
        noiseSeries: const <double>[44.0, 48.0, 46.0],
        noiseMax: 65.6,
      ).result!; // 변환된 측정 결과

      expect(model.noiseMax, closeTo(65.6, 1e-9));
    });

    test('격자 행이 세 개보다 적으면 0 을 지어내지 않고 사유를 올린다', () {
      // 행이 두 개 이하면 저크를 가운데 차분으로 구할 수 없어 파생
      // 물리량이 전부 0 이 된다. 그 0 을 결과로 내보내면 재서 0 이 나온
      // 측정과 구분되지 않으므로 아예 변환하지 않는다
      for (final rowCount in [0, 1, 2]) {
        final result = MeasurementAssembler.assemble(
          grid: _grid(_threeRows.sublist(0, rowCount)),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ); // 변환 결과

        expect(result.isSuccess, isFalse, reason: '$rowCount행');
        expect(result.result, isNull, reason: '$rowCount행');
        expect(result.failureReason, contains('격자 행이 3개보다 적어'));
        expect(result.failureReason, contains('$rowCount행'));
      }
    });

    test('가속도는 mg 를 m/s² 로 바꾸고 전체 평균을 뺀 값이다', () {
      // 0 · 2000 · 1000mg 의 평균은 1000mg(= 9.80665 m/s²)이고,
      // 평균을 뺀 가속도는 -9.80665 · +9.80665 · 0 이 된다
      final model = MeasurementAssembler.assemble(
        grid: _grid(const [
          GridSample(xMg: 0.0, yMg: 0.0, zMg: 0.0),
          GridSample(xMg: 0.0, yMg: 0.0, zMg: 2000.0),
          GridSample(xMg: 0.0, yMg: 0.0, zMg: 1000.0),
        ]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.accelSeries[0], closeTo(-9.80665, 1e-9));
      expect(model.accelSeries[1], closeTo(9.80665, 1e-9));
      expect(model.accelSeries[2], closeTo(0.0, 1e-9));
    });

    test('누적 이동량은 방향과 무관해 오르내려도 합산된다', () {
      // 같은 운행을 두 번 이어붙인다. 방향을 그대로 더하면 상쇄되지만,
      // 절댓값을 더하므로 이동량은 두 배에 가까워야 한다
      final once = MeasurementAssembler.assemble(
        grid: _grid(_trapezoid()),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!.distance!; // 한 번 운행한 이동량 (m)
      final twice = MeasurementAssembler.assemble(
        grid: _grid(<GridSample>[..._trapezoid(), ..._trapezoid()]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!.distance!; // 두 번 운행한 이동량 (m)

      expect(twice, greaterThan(once * 1.9));
    });

    group('기준 데이터 ride_reference', () {
      test('CRLF 파일을 읽어도 열 값에 \\r 가 남지 않는다', () {
        final raw = File(_fixturePath).readAsStringSync(); // 파일 원문
        expect(raw.contains('\r\n'), isTrue, reason: 'CRLF 파일이어야 한다');

        final fields = _fixtureFields(); // 데이터 줄마다 자른 열 값
        expect(fields.length, 11388);
        for (final line in [fields.first, fields.last]) {
          expect(line.length, 4, reason: 'X Y Z 소음 네 열');
          for (final value in line) {
            expect(value.contains('\r'), isFalse, reason: value);
            expect(double.tryParse(value), isNotNull, reason: value);
          }
        }
      });

      test('실측 데이터에서 프로토타입과 같은 값을 낸다', () {
        // 기준값은 pdf_report_dev 의 `metrics.derive_kinematics()` 에 이
        // 파일을 넣어 얻은 것이다. 값이 흔들리면 적분 경로가 바뀐 것이다
        final model = MeasurementAssembler.assemble(
          grid: _grid(_fixtureRows()),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ).result!; // 변환된 측정 결과

        expect(model.zSeries.length, 11388);
        expect(model.sampleRate, closeTo(256.0, 1e-9));
        expect(model.maxSpeed!, closeTo(1.743390961, 1e-6));
        expect(model.distance!, closeTo(57.093948064, 1e-6));
        expect(model.speedSeries.first, closeTo(0.0, 1e-9));
        expect(model.speedSeries.last, closeTo(0.0, 1e-9));
      });

      test('원본 리포트 값과 1% 이내로 맞는다', () {
        // 원본 TUNE 리포트는 1.75 m/s · 57.3 m 로 적고 있다. 원본이 어떤
        // 반올림과 구간 산정을 썼는지 몰라 소수점까지 맞추지 않고,
        // 어긋난 정도만 본다
        final model = MeasurementAssembler.assemble(
          grid: _grid(_fixtureRows()),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ).result!; // 변환된 측정 결과

        final speedGap =
            (model.maxSpeed! - 1.75).abs() / 1.75; // 최대 속도가 어긋난 비율
        final distanceGap =
            (model.distance! - 57.3).abs() / 57.3; // 운행 거리가 어긋난 비율

        expect(speedGap, lessThan(0.01), reason: '최대 속도 ${model.maxSpeed}');
        expect(distanceGap, lessThan(0.01), reason: '운행 거리 ${model.distance}');
      });
    });

    test('합성 프로파일에서도 프로토타입과 같은 값을 낸다', () {
      // 실측 회귀는 위 `기준 데이터 ride_reference` 가 갖는다. 이 시험은 Dart
      // 계산이 파이썬 프로토타입과 같은지 확인하는 용도로만 남겨둔다 —
      // 합성 입력이라 양 끝 가속도가 정확히 ±0.8 로 떨어져, 어긋나면
      // 어디가 틀어졌는지 알아보기 쉽다
      final model = MeasurementAssembler.assemble(
        grid: _grid(_trapezoid()),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.zSeries.length, 8942);
      expect(model.maxSpeed!, closeTo(1.749804272, 1e-6));
      expect(model.distance!, closeTo(57.244250488, 1e-6));
      expect(model.accelSeries.first, closeTo(0.8, 1e-9));
      expect(model.accelSeries.last, closeTo(-0.8, 1e-9));
    });
  });
}
