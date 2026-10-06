import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

/// 작성: 2026-10-07 01:44:43 · nada
/// 변수: _unitCasesPath
/// 목적: 단위 시험 픽스처 경로. 300표본 입력, 그 입력을 SciPy 1.18.1 로
///       거른 결과(`filtfilt`)와 재표본한 결과(`resample_25_64`), 설계한
///       필터 계수(`sos`)가 들어 있다. 재표본 결과는 거르기 전 입력을
///       바로 재표본한 값이다.
const _unitCasesPath = 'test/fixtures/conditioning_unit_cases.json';

/// 작성: 2026-10-07 01:44:43 · nada
/// 함수: _unitCases
/// 목적: 단위 시험 픽스처를 읽는다.
/// 반환: 열 이름 → 값 목록
Map<String, dynamic> _unitCases() =>
    jsonDecode(File(_unitCasesPath).readAsStringSync()) as Map<String, dynamic>;

/// 작성: 2026-10-07 01:44:43 · nada
/// 함수: _doubles
/// 목적: JSON 숫자 목록을 실수 목록으로 바꾼다. 소수점 없이 적힌 값은
///       정수로 읽히므로 실수로 맞춘다.
/// 인자: values — JSON 에서 읽은 숫자 목록
/// 반환: 실수 목록
List<double> _doubles(Object? values) => [
  for (final v in values! as List<dynamic>) (v as num).toDouble(),
];

/// 작성: 2026-10-07 01:44:43 · nada
/// 함수: _defaultSections
/// 목적: 기본 설정(256Hz 격자, 40Hz 4차)으로 설계한 필터를 만든다.
/// 반환: 2차 구간 목록
List<SosSection> _defaultSections() {
  const config = CaptureConfig(); // 기본 설정
  return ButterworthLowpass.design(
    order: config.lowpassOrder,
    cutoffHz: config.lowpassCutoffHz.toDouble(),
    sampleRateHz: config.targetSampleRateHz.toDouble(),
  );
}

/// 작성: 2026-10-07 02:01:58 · nada
/// 변수: _inputPath
/// 목적: 실측 입력 픽스처 경로. 2026-10-06 개발폰 실측을 앱이 앞뒤 0.5초씩
///       버리고 256Hz 격자로 만든 EVIMP1 파일이다 (9,439행).
const _inputPath = 'test/fixtures/conditioning_input_dev_256hz.txt';

/// 작성: 2026-10-07 02:01:58 · nada
/// 변수: _expectedPath
/// 목적: 실측 입력의 기대 출력 픽스처 경로. 기준선 제거 → `sosfiltfilt()`
///       → `resample_poly(25, 64)` 를 SciPy 1.18.1 로 적용한 X · Y · Z 다
///       (3,688행). `#` 로 시작하는 머리말 한 줄이 있다.
const _expectedPath = 'test/fixtures/conditioning_expected_100hz.txt';

/// 작성: 2026-10-07 02:01:58 · nada
/// 함수: _readColumns
/// 목적: 공백으로 나뉜 숫자 열 파일을 행마다 실수 목록으로 읽는다. 줄바꿈이
///       CRLF 여도 `LineSplitter` 가 `\r` 까지 잘라 낸다.
/// 인자: path — 읽을 파일 경로
///       headerLines — 앞에서 건너뛸 머리말 줄 수
/// 반환: 데이터 행마다 열 값 목록
List<List<double>> _readColumns(String path, {required int headerLines}) {
  return const LineSplitter()
      .convert(File(path).readAsStringSync())
      .skip(headerLines)
      .where((line) => line.trim().isNotEmpty)
      .map(
        (line) => [
          for (final field in line.trim().split(RegExp(r'\s+')))
            double.parse(field),
        ],
      )
      .toList();
}

/// 작성: 2026-10-07 02:01:58 · nada
/// 함수: _grid
/// 목적: 기본 설정 간격(256Hz)의 시험용 격자를 만든다. 집계값을 모두 서로
///       다른 0 아닌 값으로 둬, 처리 결과가 그대로 옮겼는지 볼 수 있게 한다.
/// 인자: samples — 격자 행 목록
/// 반환: 시험용 격자 환산 결과
GridResampleResult _grid(List<GridSample> samples) {
  return GridResampleResult(
    samples: samples,
    t0Ns: 123456789,
    gridIntervalNs: const CaptureConfig().idealIntervalNs,
    rawUsedCount: 11,
    gravityUsedCount: 12,
    droppedZeroCount: 13,
    droppedBackwardCount: 14,
    droppedLinearCount: 15,
    headTrimmedRows: 16,
    tailTrimmedRows: 17,
    edgeTrimmedRows: 18,
    rawMaxSpanNs: 19,
    gravityMaxSpanNs: 20,
    degenerateSpanCount: 21,
  );
}

/// 작성: 2026-10-07 02:01:58 · nada
/// 함수: _fixtureGrid
/// 목적: 실측 입력 픽스처를 격자로 만든다. 소음 열도 싣는다.
/// 반환: 9,439행 격자
GridResampleResult _fixtureGrid() {
  final rows = _readColumns(_inputPath, headerLines: 2); // X Y Z 소음 행
  return _grid([
    for (final r in rows)
      GridSample(xMg: r[0], yMg: r[1], zMg: r[2], noiseDba: r[3]),
  ]);
}

/// 작성: 2026-10-07 02:01:58 · nada
/// 함수: _noiseGrid
/// 목적: 진동은 모두 0 이고 소음만 주어진 값인 격자를 만든다.
/// 인자: noise — 행마다 소음 (dBA). 0 이면 미측정
/// 반환: 시험용 격자
GridResampleResult _noiseGrid(List<double> noise) => _grid([
  for (final v in noise) GridSample(xMg: 0, yMg: 0, zMg: 0, noiseDba: v),
]);

/// 작성: 2026-10-07 02:01:58 · nada
/// 함수: _conditionNoise
/// 목적: 기본 설정으로 처리한 뒤 소음 열만 꺼낸다. 출력 행 수가 진동 열
///       재표본 길이와 같은지도 확인한다.
/// 인자: noise — 입력 행마다 소음 (dBA)
/// 반환: 100Hz 격자의 소음 (dBA)
List<double> _conditionNoise(List<double> noise) {
  final result = const SignalConditioner(
    config: CaptureConfig(),
  ).condition(_noiseGrid(noise)); // 처리 결과
  expect(result.isSuccess, isTrue, reason: result.failureReason);
  expect(
    result.rowCount,
    PolyphaseResampler(up: 25, down: 64).outputLength(noise.length),
  );
  return [for (final s in result.grid.samples) s.noiseDba];
}

/// 작성: 2026-10-07 01:44:43 · nada
/// 함수: main
/// 목적: 지표 계산 전 신호 처리가 SciPy 1.18.1 과 같은 결과를 내는지
///       시험한다.
void main() {
  test('40Hz 4차 버터워스 계수가 SciPy butter() 와 1e-8 이내로 맞는다', () {
    final sections = _defaultSections(); // 설계한 2차 구간
    final expected = _unitCases()['sos'] as List<dynamic>; // SciPy 계수 행
    expect(sections, hasLength(expected.length));
    for (var i = 0; i < sections.length; i++) {
      final row = _doubles(expected[i]); // [b0, b1, b2, a0, a1, a2]
      final s = sections[i]; // 같은 자리 구간
      expect(row[3], 1.0);
      final actual = [s.b0, s.b1, s.b2, s.a1, s.a2]; // a0 를 뺀 계수
      final want = [row[0], row[1], row[2], row[4], row[5]]; // 같은 순서
      for (var j = 0; j < actual.length; j++) {
        expect(actual[j], closeTo(want[j], 1e-8), reason: '구간 $i 계수 $j');
      }
    }
  });

  test('양방향 필터 출력이 SciPy sosfiltfilt() 와 1e-9 이내로 맞는다', () {
    final cases = _unitCases(); // 단위 시험 픽스처
    final input = _doubles(cases['input']); // 300표본 입력
    final expected = _doubles(cases['filtfilt']); // SciPy 출력
    final actual = ButterworthLowpass.filtfilt(
      _defaultSections(),
      input,
    ); // 거른 신호
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], closeTo(expected[i], 1e-9), reason: '표본 $i');
    }
  });

  test('홀수 차수는 릴리스 빌드에서도 ArgumentError 로 막는다', () {
    expect(
      () =>
          ButterworthLowpass.design(order: 3, cutoffHz: 40, sampleRateHz: 256),
      throwsArgumentError,
    );
  });

  test('256Hz → 100Hz 재표본이 SciPy resample_poly() 와 1e-9 이내로 맞는다', () {
    const config = CaptureConfig(); // 기본 설정
    expect(config.resampleUp, 25);
    expect(config.resampleDown, 64);
    final cases = _unitCases(); // 단위 시험 픽스처
    final input = _doubles(cases['input']); // 300표본 입력
    final expected = _doubles(cases['resample_25_64']); // SciPy 출력 118표본
    final actual = PolyphaseResampler(
      up: config.resampleUp,
      down: config.resampleDown,
    ).apply(input); // 재표본한 신호
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], closeTo(expected[i], 1e-9), reason: '표본 $i');
    }
  });

  test('재표본 출력 길이가 SciPy 와 같게 ceil(n x 25 / 64) 다', () {
    final resampler = PolyphaseResampler(up: 25, down: 64); // 기본 비율
    // 입력 길이 → SciPy 1.18.1 `resample_poly()` 출력 길이
    const lengths = {1: 1, 63: 25, 64: 25, 65: 26};
    lengths.forEach((n, want) {
      final out = resampler.apply(List<double>.filled(n, 1.0)); // 재표본 결과
      expect(out, hasLength(want), reason: '입력 $n 표본');
    });
  });

  test('차단 주파수가 0 이하이거나 표본 속도의 절반 이상이면 ArgumentError', () {
    for (final cutoff in [0.0, -1.0, 128.0, 200.0]) {
      expect(
        () => ButterworthLowpass.design(
          order: 4,
          cutoffHz: cutoff,
          sampleRateHz: 256,
        ),
        throwsArgumentError,
        reason: '차단 $cutoff Hz',
      );
    }
  });

  test('실측 입력 전체 처리 결과가 SciPy 기대 출력과 1e-6mg 이내로 맞는다', () {
    final input = _fixtureGrid(); // 9,439행 실측 격자
    final result = const SignalConditioner(
      config: CaptureConfig(),
    ).condition(input); // 처리 결과
    final expected = _readColumns(_expectedPath, headerLines: 1); // X Y Z
    expect(input.rowCount, 9439);
    expect(result.isSuccess, isTrue, reason: result.failureReason);
    expect(result.rowCount, 3688);
    expect(expected, hasLength(3688));
    expect(result.sampleRateHz, 100.0);
    expect(result.failureCause, isNull);
    expect(
      const SignalConditioner(config: CaptureConfig()).methodLabel,
      'baseline+lp40bw4zp+rs100',
    );

    final grid = result.grid; // 100Hz 격자
    expect(grid.gridIntervalNs, 10000000);
    expect(grid.t0Ns, input.t0Ns);
    expect(
      [
        grid.rawUsedCount,
        grid.gravityUsedCount,
        grid.droppedZeroCount,
        grid.droppedBackwardCount,
        grid.droppedLinearCount,
        grid.headTrimmedRows,
        grid.tailTrimmedRows,
        grid.edgeTrimmedRows,
        grid.rawMaxSpanNs,
        grid.gravityMaxSpanNs,
        grid.degenerateSpanCount,
      ],
      [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
    );

    for (var k = 0; k < expected.length; k++) {
      final s = grid.samples[k]; // 처리한 k 행
      expect(s.xMg, closeTo(expected[k][0], 1e-6), reason: 'X $k 행');
      expect(s.yMg, closeTo(expected[k][1], 1e-6), reason: 'Y $k 행');
      expect(s.zMg, closeTo(expected[k][2], 1e-6), reason: 'Z $k 행');
    }
  });

  test('실측 입력의 기준선은 X -0.0427, Y 0.0375, Z -4.1543mg 이다', () {
    final result = const SignalConditioner(
      config: CaptureConfig(),
    ).condition(_fixtureGrid()); // 처리 결과
    expect(result.baselineXMg, closeTo(-0.0427, 1e-4));
    expect(result.baselineYMg, closeTo(0.0375, 1e-4));
    expect(result.baselineZMg, closeTo(-4.1543, 1e-4));
    // 기대값: NumPy `std()`(모표준편차)로 첫 256행에서 구한 값
    expect(result.baselineStdXMg, closeTo(2.0807, 1e-4));
    expect(result.baselineStdYMg, closeTo(1.3480, 1e-4));
    expect(result.baselineStdZMg, closeTo(1.9471, 1e-4));
  });

  test('차단 주파수가 재표본 속도의 절반(50Hz) 이상이면 ArgumentError', () {
    const conditioner = SignalConditioner(
      config: CaptureConfig(lowpassCutoffHz: 50),
    ); // 차단 50Hz 설정
    expect(
      () => conditioner.condition(_noiseGrid(List<double>.filled(600, 50.0))),
      throwsArgumentError,
    );
  });

  test('실측 입력을 처리해 조립한 지표가 오티스폰 비교 기준값과 맞는다', () {
    final conditioned = const SignalConditioner(
      config: CaptureConfig(),
    ).condition(_fixtureGrid()); // 처리 결과
    final assembled = MeasurementAssembler.assemble(
      grid: conditioned.grid,
      site: const SiteInfo(
        jobNo: '2025F 1234R01',
        siteName: '시험 현장',
        bottomFloor: '1',
        topFloor: '8',
        direction: SiteInfo.directionUp,
        model: SiteInfo.defaultModel,
      ),
      id: '20261006-091841',
      measuredAt: DateTime(2026, 10, 6, 9, 18, 41),
    ); // 조립 결과
    expect(assembled.isSuccess, isTrue, reason: assembled.failureReason);
    final r = assembled.result!; // 측정 결과
    expect(r.sampleRate, 100.0);
    expect(r.xPtp, closeTo(14.2125, 1e-3));
    expect(r.yPtp, closeTo(10.6430, 1e-3));
    expect(r.zPtp, closeTo(108.3677, 1e-3));
    expect(r.xA95, closeTo(4.1739, 1e-3));
    expect(r.yA95, closeTo(5.4624, 1e-3));
    expect(r.zA95, closeTo(6.2209, 1e-3));
  });

  test('기준선 구간 256행보다 짧은 격자는 사유를 담아 실패한다', () {
    final result = const SignalConditioner(
      config: CaptureConfig(),
    ).condition(_noiseGrid(List<double>.filled(255, 50.0))); // 255행 처리 결과
    expect(result.isSuccess, isFalse);
    expect(result.failureReason, contains('255행'));
    expect(result.failureReason, contains('256행'));
    expect(result.rowCount, 0);
    expect(result.failureCause, ConditioningFailure.gridTooShort);
    expect(result.baselineXMg, isNull);
    expect(result.baselineYMg, isNull);
    expect(result.baselineZMg, isNull);
  });

  test('소음은 100Hz 시각에 선형 보간하고, 마지막 입력 뒤는 마지막 값을 쓴다', () {
    // 259행이면 마지막 출력(101행)의 시각 258.56행이 마지막 입력 258행 뒤다
    final noise = [for (var j = 0; j < 259; j++) 50.0 + 0.1 * j]; // 입력 소음
    final out = _conditionNoise(noise); // 100Hz 소음
    expect(out, hasLength(102));
    for (var k = 0; k < out.length; k++) {
      final p = k * 64 / 25; // 입력 행 번호로 잰 출력 시각
      final want = p >= 258 ? noise.last : 50.0 + 0.1 * p; // 기대 소음
      expect(out[k], closeTo(want, 1e-9), reason: '$k 행');
    }
    expect(out.last, noise.last);
  });

  test('소음이 전부 0 이면 결과도 전부 0 이다', () {
    final out = _conditionNoise(List<double>.filled(600, 0.0)); // 100Hz 소음
    expect(out.every((v) => v == 0.0), isTrue);
  });

  test('0 과 측정값 경계에서는 섞은 중간값 대신 0 을 쓴다', () {
    // 300행부터 측정값: 117행(299.52)은 0 과 60 사이라 0, 118행(302.08)은 60
    final rising = _conditionNoise([
      for (var j = 0; j < 600; j++) j < 300 ? 0.0 : 60.0,
    ]); // 0 → 측정값 경계
    for (var k = 0; k < rising.length; k++) {
      expect(rising[k], k <= 117 ? 0.0 : 60.0, reason: '$k 행');
    }

    // 300행부터 0: 116행(296.96)은 60, 117행(299.52)은 60 과 0 사이라 0
    final falling = _conditionNoise([
      for (var j = 0; j < 600; j++) j < 300 ? 60.0 : 0.0,
    ]); // 측정값 → 0 경계
    for (var k = 0; k < falling.length; k++) {
      expect(falling[k], k <= 116 ? 60.0 : 0.0, reason: '$k 행');
    }

    // 출력 25행은 입력 64행과 시각이 정확히 겹쳐 그 행 값을 쓴다. 다음 행이
    // 0 이어도 섞을 값이 없으므로 측정값 그대로다
    final exact = _conditionNoise([
      for (var j = 0; j < 600; j++) j <= 64 ? 60.0 : 0.0,
    ]); // 겹치는 시각 바로 뒤가 0 인 경계
    expect(exact[25], 60.0);
    expect(exact[26], 0.0);
  });
}
