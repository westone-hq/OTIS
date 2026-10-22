import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/device_response.dart';
import 'package:vibration_checker/domain/analysis/measurement_assembler.dart';
import 'package:vibration_checker/domain/analysis/ride_weighting.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

/// 작성: 2026-09-15 19:14:22 · nada
/// 변수: _fixturePath
/// 목적: 기준 측정 데이터 파일 경로. 원본 TUNE 리포트를 만든 실제 현장
///       측정 기록이며, 회귀는 이 파일로 고정한다.
const _fixturePath = 'test/fixtures/records/ride_reference.txt';

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
/// 목적: 기준 데이터를 격자 행으로 만든다. 진동 세 열과 소음 열을 모두
///       싣는다 — 수집 계층이 격자 행에 소음을 실어 주므로 실제 경로와
///       같은 모양이다.
/// 반환: 격자 행 11,388개
List<GridSample> _fixtureRows() {
  return _fixtureFields()
      .map(
        (fields) => GridSample(
          xMg: double.parse(fields[0]),
          yMg: double.parse(fields[1]),
          zMg: double.parse(fields[2]),
          noiseDba: double.parse(fields[3]),
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
  // 같은 가속도(m/s²)로 count 행을 rows 끝에 붙이는 지역 함수
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
/// 수정: 2026-10-21 10:05:00 · nada
/// 변수: _shortRows
/// 목적: 최소 행 수 조건(16행, 저크 저역 필터의 양 끝 덧댐 15행 + 1)을
///       넘기려고 두는, 값 자체는 뜻이 없는 격자 행 16개. 행 수 말고 다른
///       것을 보는 시험에서 쓴다.
final _shortRows = List<GridSample>.filled(
  16,
  const GridSample(xMg: 0.0, yMg: 0.0, zMg: 0.0),
);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _rideWithNoise
/// 목적: 사다리꼴 운행(`_trapezoid()`)에 소음을 얹은 격자 행을 만든다.
///       운행 구간(출발 · 정지 0.5 m 제외)이 생기는 입력이라 구간 안 ·
///       밖 소음을 나눠 볼 수 있다. 256Hz 에서 0.5 m 는 출발 뒤 약 1.12초
///       (286행)다.
/// 인자: noise — 행 첨자마다 소음 (dBA)
/// 반환: 격자 행 8,942개
List<GridSample> _rideWithNoise(double Function(int index) noise) {
  final ride = _trapezoid(); // 소음 없는 운행
  return <GridSample>[
    for (var i = 0; i < ride.length; i++)
      GridSample(
        xMg: ride[i].xMg,
        yMg: ride[i].yMg,
        zMg: ride[i].zMg,
        noiseDba: noise(i),
      ),
  ];
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _conditionedReference
/// 목적: 기준 데이터(ride_reference)를 앱과 같은 길 — 신호 처리
///       (`SignalConditioner`) 뒤 조립 — 으로 측정 결과로 만든다.
/// 반환: 조립한 측정 결과
MeasurementResult _conditionedReference() {
  final conditioned = const SignalConditioner(
    config: CaptureConfig(),
  ).condition(_grid(_fixtureRows())); // 100Hz 로 처리한 격자
  return MeasurementAssembler.assemble(
    grid: conditioned.grid,
    site: _site,
    id: 'id',
    measuredAt: DateTime(2026, 1, 14, 11, 3, 59),
  ).result!;
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _expectedReference
/// 목적: 같은 기준 데이터를 SciPy 로 재계산한 기대값을 읽는다
///       (`tool/fixtures/gen_conditioning_fixtures.py --weighting`).
/// 반환: 항목 이름을 열쇠로 하는 기대값 표
Map<String, dynamic> _expectedReference() =>
    (jsonDecode(
              File(
                'test/fixtures/scipy/weighting_expected_metrics.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>)['ride_reference']
        as Map<String, dynamic>;

/// 작성: 2026-09-15 13:08:37 · nada
/// 수정: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 캡처 결과를 측정 결과 모델로 바꾸는 변환을 시험한다.
///       - 진동 시계열과 샘플레이트가 제대로 옮겨지는지
///       - 아직 재지 않은 소음이 0 이 아니라 비어 있는 채로 남는지
///       - 진동 · 소음 지표가 가중한 시계열의 운행 구간 안에서 나오는지,
///         구간을 못 정하면 비우고 사유를 남기는지
///       - 기준 데이터(원본 리포트를 만든 측정)에서 SciPy 재계산 값과
///         같고, 원본 리포트 목표값과 허용 오차 안이며 신호등이 같은지
///       - 기종이 버려지지 않고 실리는지, 비었으면 null 인지
///       - 환산 실패와 행 부족을 삼키지 않고 그대로 올리는지
///       - 실측 기준 데이터에서 파생 물리량이 프로토타입과 같은 값을
///         내는지
void main() {
  group('MeasurementAssembler.assemble', () {
    final measuredAt = DateTime(2026, 9, 15, 13, 8, 37); // 시험용 측정 시각

    test('격자 행을 가중해 시계열로 싣고 현장 정보를 옮긴다', () {
      // 최소 16행이면 가중을 걸 수 있는 길이라 시계열은 격자 값에 가중을
      // 건 값이다(지표를 낸 그 값, CLAUDE.md "result.json")
      final xs = [for (var i = 0; i < 16; i++) i + 1.0]; // X (mg)
      final ys = [for (var i = 0; i < 16; i++) -(i + 2.0)]; // Y (mg)
      final zs = [for (var i = 0; i < 16; i++) (i % 3).toDouble()]; // Z (mg)
      final result = MeasurementAssembler.assemble(
        grid: _grid(<GridSample>[
          for (var i = 0; i < 16; i++)
            GridSample(xMg: xs[i], yMg: ys[i], zMg: zs[i]),
        ]),
        site: _site,
        id: '20260915-130837',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.isSuccess, isTrue);
      final model = result.result!; // 변환된 측정 결과
      expect(model.xSeries, RideWeighting.horizontal(xs, 256.0));
      expect(model.ySeries, RideWeighting.horizontal(ys, 256.0));
      // 기종을 모르는 기록은 기종 응답 보정 없이 가중만 건 값이다
      // (2026-10-22, 그 전 모든 기록의 수직 20Hz 저역을 없앰)
      expect(model.zSeries, RideWeighting.vertical(zs, 256.0));
      expect(model.deviceCompensation, DeviceResponse.noneLabel);
      expect(model.id, '20260915-130837');
      expect(model.jobNo, 'T-1001');
      expect(model.bottomFloor, 1);
      expect(model.topFloor, 8);
      expect(model.dateTime, measuredAt);
      expect(model.zSeries, hasLength(16));
    });

    test('보정 표에 있는 기종은 가중한 수직에만 보정 저역을 건다', () {
      // 2026-10-22: 갤럭시 S22(SM-S901…) 기록은 수직에 2차 25Hz 저역을
      // 양방향으로 건다. 수평은 그대로다
      final rows = <GridSample>[
        for (var i = 0; i < 400; i++)
          GridSample(
            xMg: (i % 5) - 2.0,
            yMg: (i % 7) - 3.0,
            zMg: (i % 3) - 1.0,
          ),
      ]; // 100Hz 격자 4초
      final zs = [for (final r in rows) r.zMg]; // Z (mg)
      final xs = [for (final r in rows) r.xMg]; // X (mg)
      final result = MeasurementAssembler.assemble(
        grid: _grid(rows, gridIntervalNs: 10000000),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
        deviceManufacturer: 'samsung',
        deviceModel: 'SM-S901N',
      ).result!; // 변환된 측정 결과
      final filter = DeviceResponse.filterFor('SM-S901N')!; // S22 보정

      expect(filter.order, 2);
      expect(filter.lowpassHz, 25.0);
      expect(
        result.zSeries,
        DeviceResponse.apply(filter, RideWeighting.vertical(zs, 100), 100),
      );
      expect(result.xSeries, RideWeighting.horizontal(xs, 100));
      expect(result.deviceManufacturer, 'samsung');
      expect(result.deviceModel, 'SM-S901N');
      expect(result.deviceCompensation, 'lp25.0bw2zp');
    });

    test('표에 없는 기종은 보정하지 않고 미보정으로 남긴다', () {
      final rows = <GridSample>[
        for (var i = 0; i < 400; i++)
          GridSample(xMg: 0, yMg: 0, zMg: (i % 3) - 1.0),
      ]; // 100Hz 격자 4초
      final result = MeasurementAssembler.assemble(
        grid: _grid(rows, gridIntervalNs: 10000000),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
        deviceModel: 'SM-S908N', // S22 Ultra — S22 와 다른 기종
      ).result!; // 변환된 측정 결과

      expect(
        result.zSeries,
        RideWeighting.vertical([for (final r in rows) r.zMg], 100),
      );
      expect(result.deviceCompensation, DeviceResponse.noneLabel);
      expect(result.uncompensatedDevice, isTrue);
    });

    test('샘플레이트를 격자 간격에서 구한다', () {
      final result = MeasurementAssembler.assemble(
        grid: _grid(_shortRows, gridIntervalNs: 3906250),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ); // 변환 결과

      expect(result.result!.sampleRate, closeTo(256.0, 1e-9));
    });

    test('소음은 0 이 아니라 비어 있다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries, everyElement(0.0), reason: '격자에 소음이 없다');
      expect(model.noiseMax, isNull, reason: '0 뿐이면 잰 것이 없다');
    });

    test('운행 구간을 못 정한 짧은 격자는 진동 · 소음 지표를 비우고 사유를 남긴다', () {
      // 반주기 P2P · A95 의 정의 자체는 half_cycle_test 가 본다. 여기서는
      // 움직이지 않은 측정에서 0 이나 지어낸 값을 싣지 않는지 본다
      final model = MeasurementAssembler.assemble(
        grid: _grid(<GridSample>[
          for (var i = 0; i < 16; i++)
            GridSample(
              xMg: i.isEven ? 1.0 : -2.0,
              yMg: i.isEven ? 4.0 : -2.0,
              zMg: 0.5,
              noiseDba: 45.0 + i % 3,
            ),
        ]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      for (final value in [
        model.xPtp,
        model.yPtp,
        model.zPtp,
        model.xA95,
        model.yA95,
        model.zA95,
        model.noiseMax,
      ]) {
        expect(value, isNull);
      }
      expect(model.travelWindow, isNull);
      expect(model.travelWindowFailure, isNotNull);
    });

    test('소음 말고 시계열 일곱 개가 채워진다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(<GridSample>[
          for (var i = 0; i < 16; i++)
            GridSample(xMg: i + 1.0, yMg: i + 2.0, zMg: i + 3.0),
        ]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.xSeries.length, 16);
      expect(model.ySeries.length, 16);
      expect(model.zSeries.length, 16);
      expect(model.positionSeries.length, 16);
      expect(model.speedSeries.length, 16);
      expect(model.accelSeries.length, 16);
      expect(model.jerkSeries.length, 16);
      expect(model.noiseSeries, everyElement(0.0));
      expect(model.maxSpeed, isNotNull);
      expect(model.distance, isNotNull);
    });

    test('재지 않은 소음의 판정은 정상이 아니라 null 이다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseExceeded, isNull);
    });

    test('기종을 버리지 않고 함께 옮긴다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.model, 'Gen2');
    });

    test('기종이 비어 있으면 빈 문자열이 아니라 null 이다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
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

    test('현장 정보 새 항목을 공백을 지워 옮기고 하중은 숫자로 바꾼다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
        site: const SiteInfo(
          jobNo: 'T-1001',
          siteName: '서울 본사',
          address: ' 서울시 중구 ',
          bottomFloor: '1',
          topFloor: '8',
          direction: '하부 → 상부',
          model: 'Gen2',
          load: ' 1350.5 ',
          analysisType: '문 열림 사이클',
          postalCode: ' 04524 ',
          notes: '  도어 쪽 소음 큼  ',
        ),
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.address, '서울시 중구');
      expect(model.load, 1350.5);
      expect(model.loadUnit, 'kg', reason: '하중 단위는 kg 고정이다');
      expect(model.analysisType, '문 열림 사이클');
      expect(model.postalCode, '04524');
      expect(model.notes, '도어 쪽 소음 큼');
    });

    test('비어 있는 하중 · 우편번호 · 참고사항은 빈 문자열이 아니라 null 이다', () {
      final model = MeasurementAssembler.assemble(
        grid: _grid(_shortRows),
        site: const SiteInfo(
          jobNo: 'T-1001',
          siteName: '서울 본사',
          bottomFloor: '1',
          topFloor: '8',
          direction: '하부 → 상부',
          model: 'Gen2',
          load: '  ',
          postalCode: '',
          notes: '   ',
        ),
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.load, isNull);
      expect(model.loadUnit, isNull, reason: '하중이 없으면 단위도 뜻이 없다');
      expect(model.postalCode, isNull);
      expect(model.notes, isNull);
      expect(model.analysisType, SiteInfo.defaultAnalysisType);
    });

    test('하중 판정이 홈 화면 검사와 저장 변환에서 어긋나지 않는다', () {
      // 홈은 통과했는데 측정 뒤 저장이 거절되는 일이 없어야 한다. 두 곳이
      // `SiteInfo.parseLoad()` 하나를 쓰는지 같은 입력으로 본다
      for (final load in <String>[
        'abc',
        '0',
        '-5',
        'Infinity',
        'NaN',
        ' 2000 ',
        '1.5',
      ]) {
        final site = SiteInfo(
          jobNo: 'T-1001',
          siteName: '서울 본사',
          address: '서울시',
          bottomFloor: '1',
          topFloor: '8',
          direction: '하부 → 상부',
          model: 'Gen2',
          load: load,
          postalCode: '04524',
        ); // 하중만 바꾼 현장 정보
        final passes = site.validate().isEmpty; // 홈 화면 검사 통과 여부
        final assembled = MeasurementAssembler.assemble(
          grid: _grid(_shortRows),
          site: site,
          id: 'id',
          measuredAt: measuredAt,
        ); // 저장 변환 결과

        expect(assembled.isSuccess, passes, reason: '"$load"');
        if (passes) {
          expect(assembled.result!.load, SiteInfo.parseLoad(load));
        }
      }
    });

    test('하중을 0 보다 큰 숫자로 바꿀 수 없으면 사유를 올린다', () {
      for (final load in <String>['abc', '0', '-5', 'Infinity', 'NaN']) {
        final result = MeasurementAssembler.assemble(
          grid: _grid(_shortRows),
          site: SiteInfo(
            jobNo: 'T-1001',
            siteName: '서울 본사',
            bottomFloor: '1',
            topFloor: '8',
            direction: '하부 → 상부',
            model: 'Gen2',
            load: load,
          ),
          id: 'id',
          measuredAt: measuredAt,
        ); // 변환 결과

        expect(result.isSuccess, isFalse, reason: load);
        expect(result.failureReason, contains('하중'), reason: load);
      }
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
        grid: _grid(_shortRows),
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
        grid: _grid(_shortRows),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries, everyElement(0.0));
      expect(model.noiseMax, isNull);
    });

    test('격자가 실어 온 소음을 그대로 옮기고 최대는 운행 구간 안에서 센다', () {
      // 출발 직후(100행, 0.5 m 전)의 70 dBA 는 구간 밖이라 최대에 들지 않는다
      final model = MeasurementAssembler.assemble(
        grid: _grid(
          _rideWithNoise((i) => i == 100 ? 70.0 : (i == 4000 ? 52.0 : 44.0)),
        ),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseSeries.length, 8942);
      expect(model.noiseSeries[100], 70.0, reason: '시계열은 자르지 않는다');
      expect(model.travelWindow!.startIndex, greaterThan(100));
      expect(model.noiseMax, closeTo(52.0, 1e-9));
    });

    test('마이크가 꺼진 측정을 "소음 정상" 으로 찍지 않는다', () {
      // 권한이 거부되면 수집 계층이 0 만 내보낸다. 그 0 을 최대로 쓰면
      // 기준치 아래라 초록 신호등이 찍혀, 재지도 않은 소음을 정상이라고
      // 보고하게 된다
      final model = MeasurementAssembler.assemble(
        grid: _grid(
          List<GridSample>.filled(
            16,
            const GridSample(xMg: 0, yMg: 0, zMg: 0, noiseDba: 0.0),
          ),
        ),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseMax, isNull);
      expect(model.noiseExceeded, isNull, reason: 'false 면 정상으로 읽힌다');
    });

    test('0 인 표본은 빼고 최대를 센다', () {
      // 마이크 첫 창이 찰 때까지 수집 계층이 0 을 내보낸다. 구간 안에 0 이
      // 섞여도 최대는 0 아닌 표본에서 센다
      final model = MeasurementAssembler.assemble(
        grid: _grid(_rideWithNoise((i) => i < 2000 ? 0.0 : 41.5)),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.noiseMax, closeTo(41.5, 1e-9));
    });

    test('격자 행이 16개보다 적으면 0 을 지어내지 않고 사유를 올린다', () {
      // 저크 저역 필터는 양 끝을 15행 덧대 거르므로 그보다 짧으면 거를 수
      // 없다. 거르지 않은 값이나 0 을 결과로 내보내면 재서 나온 측정과
      // 구분되지 않으므로 아예 변환하지 않는다
      for (final rowCount in [0, 1, 2, 15]) {
        final result = MeasurementAssembler.assemble(
          grid: _grid(_shortRows.sublist(0, rowCount)),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ); // 변환 결과

        expect(result.isSuccess, isFalse, reason: '$rowCount행');
        expect(result.result, isNull, reason: '$rowCount행');
        expect(result.failureReason, contains('격자 행이 16개보다 적어'));
        expect(result.failureReason, contains('$rowCount행'));
      }
    });

    test('차트 가속도는 m/s² 로 바꿔 평균을 빼고 10Hz 저역을 양방향으로 건 값이다', () {
      // 0 · 2 mg 를 번갈아 두고 1 Hz 로 천천히 오르내리는 성분을 더한다.
      // 움직인 구간이 없어 전체 평균을 뺀다. 번갈아 바뀌는 128Hz 성분은
      // 10Hz 저역에 걸러지고 느린 성분만 남는다
      final zs = <double>[
        for (var i = 0; i < 64; i++)
          (i.isEven ? 0.0 : 2.0) + math.sin(2 * math.pi * i / 256),
      ]; // 수직 진동 (mg)
      final model = MeasurementAssembler.assemble(
        grid: _grid(<GridSample>[
          for (final z in zs) GridSample(xMg: 0.0, yMg: 0.0, zMg: z),
        ]),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      final mean = zs.reduce((a, b) => a + b) / zs.length; // 평균 (mg)
      final expected = Butterworth.filtfilt(
        Butterworth.lowpass(order: 4, cutoffHz: 10, sampleRateHz: 256),
        <double>[for (final z in zs) (z - mean) * 9.80665e-3],
      ); // 기대하는 차트 가속도 (m/s²)
      for (var i = 0; i < zs.length; i++) {
        expect(model.accelSeries[i], closeTo(expected[i], 1e-12), reason: '$i');
      }
    });

    group('움직인 구간만 적분한다', () {
      // 정지 구간 행 수만큼 0 에 가까운 잡음을 붙인다. 잡음은 같은 씨앗의
      // 의사 난수라 매번 같다. ±1.5 mg 고르게 흩어져 적분하면 속도가 조금씩
      // 떠다닌다 — 실기기 정지 기록과 같은 성질이다
      List<GridSample> still(int rows, math.Random random) => <GridSample>[
        for (var i = 0; i < rows; i++)
          GridSample(
            xMg: 0.0,
            yMg: 0.0,
            zMg: (random.nextDouble() - 0.5) * 3.0,
          ),
      ];

      // 앞 정지 · 운행(사다리꼴) · 뒤 정지를 이어 운동을 계산한다
      MeasurementAssembleResult rideWithStill(int leadRows, int tailRows) {
        final random = math.Random(7); // 같은 잡음을 내는 씨앗
        return MeasurementAssembler.assemble(
          grid: _grid(<GridSample>[
            ...still(leadRows, random),
            ..._trapezoid(),
            ...still(tailRows, random),
          ]),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        );
      }

      test('움직임이 없는 측정은 운행 거리 · 최대 속도가 0 이고 구간이 없다', () {
        final assembled = MeasurementAssembler.assemble(
          grid: _grid(still(256 * 60, math.Random(3))),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ); // 1분 정지

        expect(assembled.motion, isNull);
        expect(assembled.result!.distance, 0.0);
        expect(assembled.result!.maxSpeed, 0.0);
        expect(assembled.result!.speedSeries, everyElement(0.0));
      });

      test('도착 뒤 기다린 시간이 달라도 운행 거리가 같다', () {
        final short = rideWithStill(512, 256).result!.distance!; // 뒤 1초
        final long = rideWithStill(512, 256 * 20).result!.distance!; // 뒤 20초

        expect((long - short).abs(), lessThan(0.05));
        expect(short, closeTo(57.3, 0.1));
      });

      test('정지 구간의 속도는 0 이고 이동량은 변하지 않는다', () {
        final assembled = rideWithStill(512, 256 * 5); // 앞 2초 · 뒤 5초
        final result = assembled.result!; // 변환된 측정 결과
        final motion = assembled.motion!; // 움직인 구간

        expect(
          result.speedSeries.sublist(0, motion.startIndex),
          everyElement(0.0),
        );
        expect(
          result.speedSeries.sublist(motion.endIndex + 1),
          everyElement(0.0),
        );
        expect(
          result.positionSeries.last,
          result.positionSeries[motion.endIndex],
        );
        expect(motion.clippedAtStart, isFalse);
        expect(motion.clippedAtEnd, isFalse);
      });

      test('정지 전에 측정을 끝내면 구간이 기록 끝에서 잘렸다고 알린다', () {
        final assembled = rideWithStill(512, 0); // 도착하자마자 끝낸 측정

        expect(assembled.motion!.clippedAtEnd, isTrue);
        expect(assembled.motion!.clippedAtStart, isFalse);
      });
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

      test('실측 데이터에서 파이썬 독립 계산과 같은 값을 낸다', () {
        // 기준값은 처리 전 256Hz 이 파일에 움직인 구간 적분(2026-10-20,
        // `tool/fixtures/gen_conditioning_fixtures.py` 의 `_pipeline()` 운동
        // 계산과 같은 식)을 numpy 로 따로 계산해 얻은 것이다. 값이 흔들리면
        // 적분 경로가 바뀐 것이다
        final model = MeasurementAssembler.assemble(
          grid: _grid(_fixtureRows()),
          site: _site,
          id: 'id',
          measuredAt: measuredAt,
        ).result!; // 변환된 측정 결과

        expect(model.zSeries.length, 11388);
        expect(model.sampleRate, closeTo(256.0, 1e-9));
        expect(model.maxSpeed!, closeTo(1.736991639, 1e-6));
        expect(model.distance!, closeTo(56.840220602, 1e-6));
        expect(model.speedSeries.first, closeTo(0.0, 1e-9));
        expect(model.speedSeries.last, closeTo(0.0, 1e-9));
      });

      test('앱과 같은 길로 낸 지표가 SciPy 재계산 값과 같다', () {
        final model = _conditionedReference(); // 앱과 같은 길로 만든 결과
        final expected = _expectedReference(); // SciPy 기대값

        expect(model.sampleRate, 100.0);
        expect(model.travelWindow!.startIndex, expected['startIndex']);
        expect(model.travelWindow!.endIndex, expected['endIndex']);
        expect(
          model.motionZones!.steadyStartIndex,
          expected['steadyStartIndex'],
        );
        expect(model.motionZones!.steadyEndIndex, expected['steadyEndIndex']);
        for (final entry in <String, double?>{
          'xPtp': model.xPtp,
          'yPtp': model.yPtp,
          'zPtp': model.zPtp,
          'zJptp': model.zJptp,
          'xA95': model.xA95,
          'yA95': model.yA95,
          'zA95': model.zA95,
          'noiseMax': model.noiseMax,
          'maxSpeed': model.maxSpeed,
          'distance': model.distance,
        }.entries) {
          expect(
            entry.value,
            closeTo((expected[entry.key] as num).toDouble(), 1e-6),
            reason: entry.key,
          );
        }
        expect(
          ReportMetrics.from(model).noiseAvg.value,
          closeTo((expected['noiseAvg'] as num).toDouble(), 1e-6),
        );
      });

      test('원본 리포트 목표값과 허용 오차 안이다', () {
        // 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관) 1쪽 값. 이 기록이
        // 그 리포트를 만든 측정이다. 진동 ±15%, 소음 ±1.5 dBA, 속도 · 거리
        // ±1% (2026-10-15 점검 지시)
        final metrics = ReportMetrics.from(_conditionedReference()); // 앱 리포트 지표
        // 수직 최대는 2026-10-21 2차 ~ 10-22 에 모든 기록에 건 20Hz 저역
        // 때문에 −14% 로 경계에 붙어 빼 두었다. 이 기록은 오티스폰 기록이라
        // 기종 응답 보정(2026-10-22)이 걸리지 않아 다시 −9% 다
        const vibration = <String, double>{
          'vert_max': 6.1,
          'vert_avg': 3.6,
          'horiz_avg': 4.8,
          'horiz_max': 11.3,
        }; // 원본 진동 (milli-G)
        for (final entry in vibration.entries) {
          final value = metrics.byKey(entry.key)!.value!; // 앱 값
          expect(
            (value - entry.value).abs() / entry.value,
            lessThanOrEqualTo(0.15),
            reason: '${entry.key}: 앱 $value / 원본 ${entry.value}',
          );
        }
        expect(metrics.noiseAvg.value!, closeTo(45.5, 1.5));
        expect(metrics.noiseMax.value!, closeTo(48.7, 1.5));
        expect(metrics.maxSpeed.value!, closeTo(1.75, 1.75 * 0.01));
        expect(metrics.travelDistance.value!, closeTo(57.3, 57.3 * 0.01));
      });

      test('신호등이 원본 리포트와 같다 (초록 6, 원 없음 2)', () {
        final verdicts = ReportMetrics.from(
          _conditionedReference(),
        ).rows.map((metric) => metric.verdict).toList(); // 행마다 신호등

        expect(verdicts, <ReportVerdict>[
          ...List<ReportVerdict>.filled(6, ReportVerdict.green),
          ReportVerdict.none,
          ReportVerdict.none,
        ]);
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

        final speedGap = (model.maxSpeed! - 1.75).abs() / 1.75; // 최대 속도가 어긋난 비율
        final distanceGap =
            (model.distance! - 57.3).abs() / 57.3; // 운행 거리가 어긋난 비율

        expect(speedGap, lessThan(0.01), reason: '최대 속도 ${model.maxSpeed}');
        expect(distanceGap, lessThan(0.01), reason: '운행 거리 ${model.distance}');
      });
    });

    test('합성 프로파일에서도 파이썬 독립 계산과 같은 값을 낸다', () {
      // 실측 회귀는 위 `기준 데이터 ride_reference` 가 갖는다. 이 시험은 Dart
      // 계산이 numpy 로 따로 낸 값과 같은지 확인하는 용도로만 남겨둔다 —
      // 합성 입력이라 양 끝 가속도가 정확히 ±0.8 로 떨어져, 어긋나면
      // 어디가 틀어졌는지 알아보기 쉽다. 정지 구간 없이 바로 출발 · 정지라
      // 움직인 구간이 기록 전체이고 양 끝이 잘린 것으로 적힌다. 거리는
      // 설계한 57.3 m 에 한 행(1/256초) 차이로 맞는다
      final model = MeasurementAssembler.assemble(
        grid: _grid(_trapezoid()),
        site: _site,
        id: 'id',
        measuredAt: measuredAt,
      ).result!; // 변환된 측정 결과

      expect(model.zSeries.length, 8942);
      expect(model.maxSpeed!, closeTo(1.75, 1e-6));
      expect(model.distance!, closeTo(57.298828125, 1e-6));
      expect(model.accelSeries.first, closeTo(0.8, 1e-9));
      expect(model.accelSeries.last, closeTo(-0.8, 1e-9));
    });
  });
}
