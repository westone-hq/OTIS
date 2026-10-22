import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/dsp/polyphase_resampler.dart';
import 'package:vibration_checker/domain/dsp/units.dart';

/// 작성: 2026-10-07 02:22:28 · 박건준
/// 클래스: ConditioningFailure
/// 목적: 지표 계산 전 신호 처리가 실패한 원인의 종류. 화면이 사유 문자열을
///       비교하지 않고 이 값으로 안내 문구를 고른다.
///       - `gridTooShort` — 격자가 기준선 구간이나 필터 덧붙임 길이보다
///         짧다. 측정 시간이 모자란 경우다
///       - `invalidConfig` — 처리 설정(`CaptureConfig`)이 잘못됐다. 필터
///         차수 · 차단 주파수, 나노초로 나뉘지 않는 재표본 속도
enum ConditioningFailure { gridTooShort, invalidConfig }

/// 작성: 2026-10-22 19:00:00 · 박건준
/// 클래스: BaselineSource
/// 목적: 기준선(정지 상태 오프셋)을 어느 구간에서 냈는지. 기준선은 처음
///       `baselineWindowMs` 를 정지로 가정하는데, 측정을 시작하자마자
///       승강기가 움직이면 그 가정이 깨진다(2026-10-22 개발폰 하강, 수집 약
///       1.4초 출발).
///       - `start` — 처음 `baselineWindowMs` 그대로(움직임 없음)
///       - `startShortened` — 처음 구간을 움직임 앞까지 줄였다
///         (`baselineMinimumMs` 이상)
///       - `end` — 처음 구간이 너무 짧아 기록 끝 정지 구간에서 냈다
///       - `contaminated` — 둘 다 안 돼 처음 구간을 그대로 썼다. 결과 화면이
///         "시작 후 2초 기다린 뒤 출발" 을 알린다
enum BaselineSource { start, startShortened, end, contaminated }

/// 작성: 2026-10-07 02:01:58 · 박건준
/// 수정: 2026-10-22 19:00:00 · 박건준
/// 클래스: ConditionedGrid
/// 목적: 지표 계산 전 신호 처리(`SignalConditioner.condition()`)의 결과를
///       담는다. 처리한 격자는 `GridResampleResult` 형태 그대로라 지표
///       계산(`MeasurementAssembler`)이 받는 모양이 바뀌지 않는다. 각 축에서
///       뺀 기준선 값과 기준선 구간의 표준편차는 집계 파일(`meta.txt`)에
///       남기려고 함께 싣는다.
class ConditionedGrid {
  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: ConditionedGrid
  /// 목적: 처리에 성공한 격자와 기준선 값 · 표준편차를 그대로 담는 생성자.
  /// 인자: grid — 처리한 격자 (`CaptureConfig.conditionedRateHz` 간격)
  ///       baselineXMg, baselineYMg, baselineZMg — 각 축에서 뺀 기준선
  ///       값 (mg)
  ///       baselineStdXMg, baselineStdYMg, baselineStdZMg — 각 축 기준선
  ///       구간의 표준편차 (mg)
  ///       baselineSource — 기준선을 낸 구간의 종류
  ///       baselineStartRow, baselineRows — 그 구간의 첫 행 · 행 수 (입력
  ///       격자 기준)
  const ConditionedGrid({
    required this.grid,
    required BaselineSource this.baselineSource,
    required int this.baselineStartRow,
    required int this.baselineRows,
    required double this.baselineXMg,
    required double this.baselineYMg,
    required double this.baselineZMg,
    required double this.baselineStdXMg,
    required double this.baselineStdYMg,
    required double this.baselineStdZMg,
  }) : failureCause = null;

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: ConditionedGrid.failure
  /// 목적: 처리하지 못한 결과를 만든다. 기준선과 표준편차는 구하지
  ///       못했으므로 null 로 두고 0 으로 채우지 않는다.
  /// 인자: grid — 사유를 담은 실패 격자 (`GridResampleResult.failure`)
  ///       cause — 실패 원인의 종류
  const ConditionedGrid.failure(this.grid, ConditioningFailure cause)
    : failureCause = cause,
      baselineSource = null,
      baselineStartRow = null,
      baselineRows = null,
      baselineXMg = null,
      baselineYMg = null,
      baselineZMg = null,
      baselineStdXMg = null,
      baselineStdYMg = null,
      baselineStdZMg = null;

  /// 처리한 격자. 실패면 행이 없고 `failureReason` 에 사유가 있다. 행 수 이외
  /// 집계값(사용 · 폐기 이벤트 수, 앞뒤에서 버린 행 수)은 입력 격자 값을
  /// 그대로 옮긴 것이라 행 수 집계는 입력 격자(`targetSampleRateHz`) 기준이다
  final GridResampleResult grid;

  /// 실패 원인의 종류. 성공이면 null
  final ConditioningFailure? failureCause;

  /// 기준선을 낸 구간의 종류. 실패면 null
  final BaselineSource? baselineSource;

  /// 기준선 구간의 첫 행 (입력 격자 기준). 실패면 null
  final int? baselineStartRow;

  /// 기준선 구간의 행 수 (입력 격자 기준). 실패면 null
  final int? baselineRows;

  /// X축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineXMg;

  /// Y축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineYMg;

  /// Z축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineZMg;

  /// X축 기준선 구간의 표준편차 (mg). 기준선 구간에 손 움직임 같은 진동이
  /// 섞였는지 나중에 집계 파일에서 보려는 값이고, 판정에는 쓰지 않는다.
  /// 실패면 null
  final double? baselineStdXMg;

  /// Y축 기준선 구간의 표준편차 (mg). 실패면 null
  final double? baselineStdYMg;

  /// Z축 기준선 구간의 표준편차 (mg). 실패면 null
  final double? baselineStdZMg;

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: isSuccess
  /// 목적: 처리에 성공했는지 알려준다.
  bool get isSuccess => grid.isSuccess;

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: failureReason
  /// 목적: 처리 실패 사유를 반환한다. 성공이면 null.
  String? get failureReason => grid.failureReason;

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: rowCount
  /// 목적: 처리한 격자의 행 수를 반환한다. 실패면 0.
  int get rowCount => grid.rowCount;

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: sampleRateHz
  /// 목적: 처리한 격자의 표본 속도를 반환한다 (Hz). 격자 간격에서 구해
  ///       지표 계산(`MeasurementAssembler`)과 같은 식을 쓴다.
  /// 반환: 표본 속도 (Hz). 기본 설정이면 100.0
  /// 식: 1,000,000,000 / gridIntervalNs
  double get sampleRateHz => 1000000000 / grid.gridIntervalNs;
}

/// 작성: 2026-10-07 02:01:58 · 박건준
/// 클래스: SignalConditioner
/// 목적: 격자를 지표 · 리포트 계산 전에 오티스폰(OTIS iOS 앱)과 견줄 수
///       있는 모양으로 바꾼다. 2026-10-07 오티스폰 · 개발폰 동시 측정 6쌍
///       비교에서 정한 처리다.
///       - 기준선 0 맞춤 — 정지 상태에서 0 이 아닌 고정 오프셋을 뺀다
///       - 40Hz 저역 필터(양방향) — 오티스폰이 담지 못하는 50Hz 위 성분을
///         뺀다
///       - 100Hz 재표본 — 오티스폰과 같은 표본 속도로 맞춘다
///       격자 파일(`raw.txt`)에는 이 처리를 하지 않는다. 원시 데이터를
///       보존하려는 것이다.
class SignalConditioner {
  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: SignalConditioner
  /// 목적: 처리 설정을 받아 처리기를 만든다.
  /// 인자: config — 격자 속도와 처리 수치를 담은 수집 설정. 입력 격자를
  ///       만든 `GridResampler` 와 같은 설정이어야 한다
  const SignalConditioner({required this.config});

  /// 격자 속도와 처리 수치를 담은 수집 설정
  final CaptureConfig config;

  /// 작성: 2026-10-07 02:22:28 · 박건준
  /// 함수: methodLabel
  /// 목적: 이 처리기가 하는 처리를 짧은 문자열로 반환한다. 측정 결과
  ///       (`result.json` 의 `signalConditioning`)에 남겨, 처리 방식이
  ///       바뀐 뒤에도 어느 결과가 어떤 처리로 나왔는지 가린다.
  /// 반환: 처리 방식 문자열. 기본 설정이면 `baseline+lp40bw4zp+rs100`
  ///       (기준선 0 맞춤 + 40Hz 저역, 버터워스 4차, 영위상 + 100Hz 재표본)
  String get methodLabel =>
      'baseline+lp${config.lowpassCutoffHz}bw${config.lowpassOrder}zp'
      '+rs${config.conditionedRateHz}';

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: condition
  /// 목적: 격자 하나를 처리한다. 순서대로 진행한다.
  ///       1. 차단 주파수가 재표본 속도의 절반보다 낮은지 확인한다. 아니면
  ///          `ArgumentError` 를 던진다
  ///       2. 재표본 속도가 나노초 정수 간격으로 나뉘는지, 격자가 기준선
  ///          구간과 필터 덧붙임 길이보다 긴지 확인한다. 아니면 지어내지
  ///          않고 사유를 담아 실패한다
  ///       3. 기준선 구간을 고른다(`_baselineWindow()`) — 처음
  ///          `baselineWindowMs`, 그 안에서 움직였으면 움직임 앞까지 또는
  ///          기록 끝 정지 구간. X · Y · Z 마다 그 구간 평균(기준선)과
  ///          표준편차를 구하고 평균을 뺀다 (`_baseline()`, `_baselineStd()`)
  ///       4. X · Y · Z 마다 저역 필터를 양방향으로 걸고
  ///          (`Butterworth.filtfilt()`), `conditionedRateHz` 로
  ///          재표본한다(`PolyphaseResampler.apply()`)
  ///       5. 소음 열은 거르지 않고 새 격자 시각에 선형 보간한다
  ///          (`_resampleNoise()`)
  ///       6. 시작 시각 · 집계값은 입력 격자 그대로 두고 간격만 바꾼 격자로
  ///          묶는다
  /// 인자: grid — 격자 환산(`GridResampler.resample()`)에 성공한 격자
  /// 반환: 처리한 격자와 기준선 · 표준편차. 격자가 짧거나 재표본 간격이
  ///       나뉘지 않으면 사유를 담은 실패 결과. 필터 설정(차수, 차단
  ///       주파수)이 잘못되면 `ArgumentError` 를 던진다
  /// 근거: 표준 — 재표본 속도의 절반 위 성분은 재표본 뒤 절반 아래로 접혀
  ///       들어와(앨리어싱) 없는 진동처럼 보인다. 필터가 그 위를 먼저
  ///       깎아야 한다
  ConditionedGrid condition(GridResampleResult grid) {
    if (config.lowpassCutoffHz * 2 >= config.conditionedRateHz) {
      throw ArgumentError.value(
        config.lowpassCutoffHz,
        'lowpassCutoffHz',
        '차단 주파수는 재표본 속도 ${config.conditionedRateHz} Hz 의 절반보다 '
            '낮아야 한다',
      );
    }
    final up = config.resampleUp; // 재표본에서 늘리는 배수
    final down = config.resampleDown; // 재표본에서 줄이는 배수
    // 두 배수는 두 속도를 최대공약수로 나눠 구하므로 늘 정확히 맞는다
    assert(
      config.targetSampleRateHz * up == config.conditionedRateHz * down,
      '재표본 비 $up/$down 이 ${config.targetSampleRateHz}Hz → '
      '${config.conditionedRateHz}Hz 와 맞지 않는다',
    );
    // 격자 환산기(`GridResampler`)와 같은 설정을 받으므로 늘 같다
    assert(
      grid.gridIntervalNs == config.idealIntervalNs,
      '입력 격자 간격 ${grid.gridIntervalNs}ns 가 설정 '
      '${config.idealIntervalNs}ns 와 다르다',
    );

    // 처리하지 못했을 때 입력 격자의 집계값을 실어 실패 결과를 만든다
    ConditionedGrid fail(String reason, ConditioningFailure cause) =>
        ConditionedGrid.failure(
          GridResampleResult.failure(
            reason,
            gridIntervalNs: config.conditionedIntervalNs,
            rawUsedCount: grid.rawUsedCount,
            gravityUsedCount: grid.gravityUsedCount,
            droppedZeroCount: grid.droppedZeroCount,
            droppedBackwardCount: grid.droppedBackwardCount,
            droppedLinearCount: grid.droppedLinearCount,
          ),
          cause,
        );

    if (!config.isConditionedGridExact) {
      return fail(
        '재표본 속도 ${config.conditionedRateHz} Hz 는 나노초 정수 간격으로 '
        '나뉘지 않아 등간격 격자를 만들 수 없다',
        ConditioningFailure.invalidConfig,
      );
    }
    final n = grid.rowCount; // 입력 격자 행 수
    final baselineRows = config.baselineWindowRows; // 기준선 구간 행 수
    if (n < baselineRows) {
      return fail(
        '격자가 $n행으로 기준선 구간 $baselineRows행'
        '(${config.baselineWindowMs}ms)보다 짧다',
        ConditioningFailure.gridTooShort,
      );
    }
    // → 로직 이동: Butterworth.lowpass()
    final sections = Butterworth.lowpass(
      order: config.lowpassOrder,
      cutoffHz: config.lowpassCutoffHz.toDouble(),
      sampleRateHz: config.targetSampleRateHz.toDouble(),
    ); // 저역 필터 2차 구간
    // → 로직 이동: Butterworth.padLength()
    final padRows = Butterworth.padLength(sections); // 덧붙임 길이
    if (n <= padRows) {
      // 기준선 구간이 덧붙임 길이보다 짧게 설정됐을 때만 온다
      return fail(
        '격자가 $n행으로 필터 덧붙임 길이 $padRows행보다 길지 않다',
        ConditioningFailure.gridTooShort,
      );
    }

    final resampler = PolyphaseResampler(up: up, down: down); // 축 공용 재표본기
    final samples = grid.samples; // 입력 격자 행
    final xs = samples.map((s) => s.xMg).toList(); // X 열 (mg)
    final ys = samples.map((s) => s.yMg).toList(); // Y 열 (mg)
    final zs = samples.map((s) => s.zMg).toList(); // Z 열 (mg)
    // → 로직 이동: _baselineWindow()
    final window = _baselineWindow(zs, baselineRows); // 기준선 구간
    final from = window.start; // 기준선 구간 첫 행
    final rows = window.rows; // 기준선 구간 행 수
    // → 로직 이동: _baseline()
    final baselineX = _baseline(xs, from, rows); // X 기준선 (mg)
    // → 로직 이동: _baseline()
    final baselineY = _baseline(ys, from, rows); // Y 기준선 (mg)
    // → 로직 이동: _baseline()
    final baselineZ = _baseline(zs, from, rows); // Z 기준선 (mg)
    // → 로직 이동: _baselineStd()
    final stdX = _baselineStd(xs, from, rows, baselineX); // X 표준편차
    // → 로직 이동: _baselineStd()
    final stdY = _baselineStd(ys, from, rows, baselineY); // Y 표준편차
    // → 로직 이동: _baselineStd()
    final stdZ = _baselineStd(zs, from, rows, baselineZ); // Z 표준편차

    // 한 축에서 기준선을 빼고 거른 뒤 재표본한다
    List<double> process(List<double> column, double baseline) {
      final shifted = [for (final v in column) v - baseline]; // 뺀 값 (mg)
      // → 로직 이동: Butterworth.filtfilt()
      final filtered = Butterworth.filtfilt(sections, shifted); // 거름
      // → 로직 이동: PolyphaseResampler.apply()
      return resampler.apply(filtered);
    }

    final outX = process(xs, baselineX); // 처리한 X (mg)
    final outY = process(ys, baselineY); // 처리한 Y (mg)
    final outZ = process(zs, baselineZ); // 처리한 Z (mg)
    // → 로직 이동: _resampleNoise()
    final outNoise = _resampleNoise(
      samples,
      up,
      down,
      outX.length,
    ); // 새 격자 시각의 소음 (dBA)

    return ConditionedGrid(
      grid: GridResampleResult(
        samples: [
          for (var k = 0; k < outX.length; k++)
            GridSample(
              xMg: outX[k],
              yMg: outY[k],
              zMg: outZ[k],
              noiseDba: outNoise[k],
            ),
        ],
        t0Ns: grid.t0Ns,
        gridIntervalNs: config.conditionedIntervalNs,
        rawUsedCount: grid.rawUsedCount,
        gravityUsedCount: grid.gravityUsedCount,
        droppedZeroCount: grid.droppedZeroCount,
        droppedBackwardCount: grid.droppedBackwardCount,
        droppedLinearCount: grid.droppedLinearCount,
        headTrimmedRows: grid.headTrimmedRows,
        tailTrimmedRows: grid.tailTrimmedRows,
        edgeTrimmedRows: grid.edgeTrimmedRows,
        rawMaxSpanNs: grid.rawMaxSpanNs,
        gravityMaxSpanNs: grid.gravityMaxSpanNs,
        degenerateSpanCount: grid.degenerateSpanCount,
      ),
      baselineSource: window.source,
      baselineStartRow: from,
      baselineRows: rows,
      baselineXMg: baselineX,
      baselineYMg: baselineY,
      baselineZMg: baselineZ,
      baselineStdXMg: stdX,
      baselineStdYMg: stdY,
      baselineStdZMg: stdZ,
    );
  }

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 수정: 2026-10-22 23:55:00 · 박건준
  /// 함수: _baselineWindow
  /// 목적: 기준선을 낼 구간을 고른다. 처음 `baselineWindowMs` 안에서 수직
  ///       가속도(저크 저역 `jerkLowpassHz` 를 양방향으로 건 값)가 처음
  ///       `baselineMinimumMs` 평균에서 `baselineMotionAccelMps2` 보다
  ///       벗어나면 움직임이다.
  ///       1. 움직임이 없으면 처음 `rows` 행(`BaselineSource.start`)
  ///       2. 움직임이 `baselineMinimumMs` 뒤면 처음 ~ 움직임 앞
  ///          (`startShortened`)
  ///       3. 더 일찍 움직였으면 마지막 `rows` 행이 정지인지(같은 판정, 끝
  ///          `baselineMinimumMs` 평균 기준) 보고 그 구간(`end`)
  ///       4. 그것도 아니면 처음 `rows` 행 그대로(`contaminated`)
  ///       진동 지표는 고역을 거치고 거리 · 속도는 움직인 구간 평균을 다시
  ///       빼므로 기준선이 지표를 거의 바꾸지 않는다(2026-10-22 개발폰 하강
  ///       0.86초로 줄여도 거리 0.0002 m 차이). 어디서 냈는지 기록해 두고
  ///       가정이 깨진 측정을 알리려는 것이다.
  /// 인자: zs — Z 열 (mg, 입력 격자)
  ///       rows — 기본 기준선 행 수 (`baselineWindowRows`). `zs` 길이 이하
  /// 반환: 구간 첫 행 · 행 수와 종류
  /// 근거: 인용 — 2026-10-22 점검 지시 "기준선 구간 안에서 움직임(1.6 Hz
  ///       가속도 |a| > 0.03 m/s²)이 잡히면, 기준선을 움직임 전까지로
  ///       줄이거나(최소 0.3초) 기록 끝 정지 구간으로 낸다"
  ({int start, int rows, BaselineSource source}) _baselineWindow(
    List<double> zs,
    int rows,
  ) {
    final fs = config.targetSampleRateHz.toDouble(); // 입력 격자 속도 (Hz)
    final minimumRows = // 줄여도 남길 최소 행 수
    (CaptureConfig.baselineMinimumMs * fs / 1000)
        .ceil();
    final threshold = // 움직임 문턱 (mg)
        CaptureConfig.baselineMotionAccelMps2 /
        Units.mgToMetersPerSecondSquared;
    // → 로직 이동: Butterworth.lowpass()
    final sections = Butterworth.lowpass(
      order: CaptureConfig.jerkLowpassOrder,
      cutoffHz: CaptureConfig.jerkLowpassHz,
      sampleRateHz: fs,
    ); // 움직임 판정 저역
    if (zs.length <= Butterworth.padLength(sections) || zs.length < rows) {
      // 격자가 덧붙임보다 짧으면 판정하지 않고 예전처럼 처음 구간을 쓴다
      return (start: 0, rows: rows, source: BaselineSource.start);
    }
    // → 로직 이동: Butterworth.filtfilt()
    final smooth = Butterworth.filtfilt(sections, zs); // 저역 Z (mg)
    // 구간 [from, to) 안에서 ref 에서 문턱 넘게 벗어난 첫 행, 없으면 null
    int? firstMotion(int from, int to, double ref) {
      for (var i = from; i < to; i++) {
        if ((smooth[i] - ref).abs() > threshold) return i;
      }
      return null;
    }

    // 구간 [from, from + count) 의 평균 (mg)
    double meanOf(int from, int count) {
      var sum = 0.0; // 합 (mg)
      for (var i = from; i < from + count; i++) {
        sum += smooth[i];
      }
      return sum / count;
    }

    final onset = // 처음 구간 안 움직임, 없으면 null
    firstMotion(
      0,
      rows,
      meanOf(0, minimumRows),
    );
    if (onset == null) {
      return (start: 0, rows: rows, source: BaselineSource.start);
    }
    if (onset >= minimumRows) {
      return (start: 0, rows: onset, source: BaselineSource.startShortened);
    }
    final n = zs.length; // 격자 행 수
    final endMotion = // 끝 구간 안 움직임, 없으면 null
    firstMotion(
      n - rows,
      n,
      meanOf(n - minimumRows, minimumRows),
    );
    if (endMotion == null) {
      return (start: n - rows, rows: rows, source: BaselineSource.end);
    }
    return (start: 0, rows: rows, source: BaselineSource.contaminated);
  }

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: _baseline
  /// 목적: 측정 첫 구간의 평균(기준선)을 구한다. 정지 상태에서 0 이어야 할
  ///       진동값이 고정 오프셋만큼 떠 있으면, 그 오프셋이 반주기 P2P 에
  ///       계속 섞여 평균 진동(A95)이 크게 틀어진다.
  /// 인자: column — 한 축의 값 (mg)
  ///       from — 기준선 구간 첫 행
  ///       rows — 평균을 낼 행 수. 1 이상, `from + rows` 가 `column` 길이
  ///       이하
  /// 반환: 구간 평균 (mg)
  /// 식: baseline = (1 / rows) x Σ column[i],  i = from … from + rows - 1
  /// 근거: 측정 — 2026-10-06 개발폰 원본 기록에서 정지 상태 가속도 센서
  ///       크기는 996~998mg 인데 중력 센서 크기는 늘 1000.0mg 이다. 진동
  ///       = 가속도 - 중력이라 그 차이가 Z 에 -2 ~ -4mg 오프셋으로 남는다.
  ///       X · Y 는 0.0~0.3mg 이고, 측정 처음과 끝 값이 같다(최종1 Z:
  ///       -4.03 / -4.09mg). 최종1 Z A95 는 보정 전 17.5mg, 보정 후 6.2mg,
  ///       오티스폰 5.1mg 이다
  static double _baseline(List<double> column, int from, int rows) {
    var sum = 0.0; // 구간 행 값의 합 (mg)
    for (var i = from; i < from + rows; i++) {
      sum += column[i];
    }
    return sum / rows;
  }

  /// 작성: 2026-10-07 02:10:57 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: _baselineStd
  /// 목적: 기준선 구간의 표준편차를 구한다. 기준선 구간은 정지 상태라고
  ///       가정하는데, 거치하며 손이 닿아 진동이 섞이면 이 값이 커진다.
  ///       나중에 집계 파일에서 확인하려는 값이고 판정 · 실패 처리는 하지
  ///       않는다.
  /// 인자: column — 한 축의 값 (mg)
  ///       from, rows — 기준선 구간 첫 행 · 행 수 (`_baseline()` 과 같다)
  ///       mean — 같은 구간의 평균 (`_baseline()`, mg)
  /// 반환: 모표준편차 (mg)
  /// 식: std = √((1 / rows) x Σ (column[i] - mean)²),
  ///     i = from … from + rows - 1
  /// 근거: 표준 — 모표준편차(나누는 수가 rows). NumPy `std()` 기본값과 같다
  static double _baselineStd(
    List<double> column,
    int from,
    int rows,
    double mean,
  ) {
    var sumSquares = 0.0; // 평균에서 벗어난 값 제곱의 합 (mg²)
    for (var i = from; i < from + rows; i++) {
      final d = column[i] - mean; // 평균에서 벗어난 값 (mg)
      sumSquares += d * d;
    }
    return math.sqrt(sumSquares / rows);
  }

  /// 작성: 2026-10-07 02:01:58 · 박건준
  /// 함수: _resampleNoise
  /// 목적: 소음 열을 새 격자 시각으로 옮긴다. 소음은 안드로이드가 RMS(제곱
  ///       평균의 제곱근, 소리 크기를 구하는 계산) 창으로 이미 구간마다
  ///       낸 값이라 거르지 않고 선형 보간만 한다. 시각은 입력
  ///       격자 첫 행을 0 초로 두고 출력 k 행을 k / `conditionedRateHz` 초로
  ///       본다. X · Y · Z 재표본 출력과 같은 정렬이다.
  ///       - 양옆 입력 중 하나라도 0(미측정)이면 0 을 쓴다. 0 과 측정값을
  ///         섞어 재지 않은 중간값을 지어내지 않는다
  ///       - 출력 시각이 입력 행 시각과 정확히 겹치면 그 행 값을 쓴다
  ///       - 마지막 입력 시각보다 뒤인 출력 행은 마지막 입력값을 쓴다. 밖으로
  ///         늘려 계산하지 않는다
  /// 인자: samples — 입력 격자 행
  ///       up, down — 재표본 배수 (`CaptureConfig.resampleUp` · `resampleDown`)
  ///       outLength — 출력 행 수. X · Y · Z 재표본 결과와 같다
  /// 반환: 새 격자 시각의 소음 (dBA). 0 이면 미측정
  /// 식: p = k x down / up            (입력 행 번호로 잰 출력 시각)
  ///     j = floor(p),  α = (k x down mod up) / up
  ///     소음 = 값_j + α x (값_(j+1) - 값_j)
  /// 근거: 표준 — 두 점 사이 선형 보간 공식
  static List<double> _resampleNoise(
    List<GridSample> samples,
    int up,
    int down,
    int outLength,
  ) {
    final n = samples.length; // 입력 행 수
    final last = samples[n - 1].noiseDba; // 마지막 입력 소음 (dBA)
    final out = Float64List(outLength); // 새 격자 시각의 소음
    for (var k = 0; k < outLength; k++) {
      final scaled = k * down; // 출력 시각 x up (입력 행 번호 기준, 정수)
      final j = scaled ~/ up; // 출력 시각 바로 앞 입력 행
      final remainder = scaled % up; // 앞 행에서 떨어진 정도 x up
      if (j >= n - 1) {
        out[k] = last;
        continue;
      }
      final before = samples[j].noiseDba; // 앞 행 소음 (dBA)
      if (remainder == 0) {
        out[k] = before;
        continue;
      }
      final after = samples[j + 1].noiseDba; // 뒤 행 소음 (dBA)
      out[k] = before == 0.0 || after == 0.0
          ? 0.0
          : before + (after - before) * remainder / up;
    }
    return out;
  }
}
