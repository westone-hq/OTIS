import 'dart:io';

import 'package:vibration_checker/domain/analysis/measurement_assembler.dart';
import 'package:vibration_checker/domain/analysis/motion_zones.dart';
import 'package:vibration_checker/domain/analysis/ride_weighting.dart';
import 'package:vibration_checker/domain/analysis/signal_conditioner.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/config/noise_config.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-08-18 23:43:06 · 박건준
/// 클래스: VibrationFileWriter
/// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 환산 결과를
///       참조 파일과 같은 구조의 텍스트 파일로 기록한다.
///
///       참조한 OTIS 데이터 텍스트 파일에서 확인한 구조:
///       1줄  포맷 식별자
///       2줄  초당 행 수
///       3줄~ 값들, 공백 구분, 소수점 최대 3자리(뒤 0 제거), 줄 끝은
///       참조 파일과 같은 줄바꿈 문자(`lineEnding` 참고)로 되어 있다.
///       시간 열은 없다. 시각은 행 번호로만 결정된다.
///
///       이번 산출물은 소음 열이 붙은 4열 EVIMP1(회사 EVA 진동측정 장비가
///       쓰는 표준 데이터 포맷)이다.
class VibrationFileWriter {
  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 변수: formatId
  /// 목적: 이번 산출물의 포맷 식별자. X Y Z 소음 4열이므로 EVIMP1 을 쓴다.
  /// 근거: 인용 — 참조한 OTIS 데이터 텍스트 파일 1줄이 EVIMP1, 4열(X Y Z 소음) 구조.
  static const String formatId = 'EVIMP1';

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 변수: columnCount
  /// 목적: 이번 산출물의 열 수 (X Y Z 소음)
  static const int columnCount = 4;

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 변수: decimalDigits
  /// 목적: 값 하나의 소수점 자리 수
  /// 근거: 인용 — 참조 파일 값의 소수점 자리가 최대 3자리
  static const int decimalDigits = 3;

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 변수: lineEnding
  /// 목적: 줄바꿈 문자
  /// 근거: 인용 — 참조 파일의 줄바꿈 문자가 이 두 글자(`\r\n`)와 같다
  static const String lineEnding = '\r\n';

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-10-21 23:20:00 · nada
  /// 함수: encode
  /// 목적: 격자 환산 결과를 참조 파일과 같은 구조의 문자열로 만든다.
  ///       1줄에 포맷 식별자, 2줄에 초당 행 수를 쓰고, 그 뒤로 격자
  ///       행마다 진동·소음 값(X Y Z 소음)을 한 줄씩 이어붙인다.
  ///       진동 세 축은 축마다 내보내는 행 전체의 평균(`axisMeans()`)을 빼고
  ///       쓴다(2026-10-21). OTIS EVIMP1 내보내기와 같은 관례다. 정지 →
  ///       운행 → 정지 기록은 가속도 전체 평균이 물리적으로 0 이라, 빼는
  ///       것은 가속도계 영점 오차뿐이다. 손대지 않은 원본은 안드로이드
  ///       원본(`native_raw.txt`)에 따로 남고, 뺀 평균은 집계 파일
  ///       (`encodeMeta()`)에 적는다. 소음 열은 그대로다.
  /// 인자: result — 격자 환산 결과. `result.samples`에 격자 행마다
  ///       하나씩, 원본 가속도에서 중력 성분을 뺀 진동 값과 소음이 들어있다
  /// 반환: 머리말 2줄과 값 행들이 `lineEnding`으로 이어진 문자열
  /// 식: 값_축(i) = 격자_축(i) - 평균_축(격자_축(0..n-1))
  /// 근거: 측정 — 2026-10-21 오티스폰 EVIMP1 내보내기(otis_* 3건)와 원본
  ///       리포트 기록(ride_reference)의 축별 평균이 X · Y 0.0000, Z −0.002
  ///       ~ −0.012 mg 다. 개발폰 하강 기록은 영점 오차로 정지 Z 가
  ///       −13.6 mg 였다
  static String encode(GridResampleResult result) {
    // → 로직 이동: axisMeans()
    final mean = axisMeans(result); // 축마다 뺄 평균 (mg)
    final rateHz = 1000000000 ~/ result.gridIntervalNs; // 1초(10억 나노초)를 격자
    // 간격(나노초)으로 나눈 값 — 1초에 몇 행이 들어가는지
    final buffer = StringBuffer(); // 완성할 문자열을 쌓아갈 버퍼
    buffer.write(formatId);
    buffer.write(lineEnding);
    buffer.write('$rateHz');
    buffer.write(lineEnding);
    for (final s in result.samples) {
      // s: 격자 행 하나의 진동 값(X Y Z, mg)과 소음(dBA)
      // → 로직 이동: formatValue()
      buffer.write(formatValue(s.xMg - mean.x));
      buffer.write(' ');
      buffer.write(formatValue(s.yMg - mean.y));
      buffer.write(' ');
      buffer.write(formatValue(s.zMg - mean.z));
      buffer.write(' ');
      buffer.write(formatValue(s.noiseDba));
      buffer.write(lineEnding);
    }
    return buffer.toString();
  }

  /// 작성: 2026-10-21 23:20:00 · nada
  /// 함수: axisMeans
  /// 목적: 값 파일에서 뺄 축별 평균을 낸다. 내보내는 격자 행 전체의
  ///       평균이다. 행이 없으면(환산 실패) 0 을 돌려준다 — 그때는 값 파일을
  ///       쓰지 않고(`write()`), 집계 파일에도 적지 않는다(`encodeMeta()`).
  /// 인자: result — 격자 환산 결과
  /// 반환: X · Y · Z 평균 (mg)
  static ({double x, double y, double z}) axisMeans(GridResampleResult result) {
    final rows = result.samples; // 격자 행
    if (rows.isEmpty) return (x: 0.0, y: 0.0, z: 0.0);
    var sx = 0.0; // X 합
    var sy = 0.0; // Y 합
    var sz = 0.0; // Z 합
    for (final s in rows) {
      sx += s.xMg;
      sy += s.yMg;
      sz += s.zMg;
    }
    final n = rows.length; // 행 수
    return (x: sx / n, y: sy / n, z: sz / n);
  }

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 함수: formatValue
  /// 목적: 값 하나(mg)를 참조 파일과 같은 표기로 바꾼다. 소수점 3자리로
  ///       자른 뒤, 뒤에 남는 0 은 떼어낸다. 표기 예시는 참조한 OTIS
  ///       데이터 텍스트 파일을 참고한다.
  /// 인자: value — 기록할 값 (mg)
  /// 반환: 표기 문자열. 숫자가 아니거나(NaN) 무한대면 '0'
  static String formatValue(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    var text = value.toStringAsFixed(decimalDigits); // 소수점 3자리로 자른 표기
    if (text.contains('.')) {
      while (text.endsWith('0')) {
        text = text.substring(0, text.length - 1);
      }
      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }
    }
    if (text == '-0') return '0';
    return text;
  }

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 함수: write
  /// 목적: 격자 환산 결과를 값 파일로 기록한다. `writeMeta()`와 달리
  ///       환산이 실패한 결과는 기록하지 않고 예외를 던진다 — 값이
  ///       없는 값 파일을 만들어도 판독 측이 쓸 수 없기 때문이다.
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과
  /// 반환: 기록한 파일
  static Future<File> write(String path, GridResampleResult result) async {
    if (!result.isSuccess) {
      throw StateError('격자 환산 실패 결과는 기록하지 않는다: ${result.failureReason}');
    }
    final file = File(path); // 기록할 파일 객체
    await file.parent.create(recursive: true);
    // → 로직 이동: encode()
    await file.writeAsString(encode(result));
    return file;
  }

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 수정: 2026-10-21 23:20:00 · nada
  /// 함수: encodeMeta
  /// 목적: 환산 과정에서 폐기되거나 특이하게 처리된 표본 수를 모아
  ///       사람이 읽을 수 있는 집계 문자열로 만든다. 값 파일(`encode()`
  ///       가 만드는 문자열)에는 이 집계를 섞지 않는다. 판독 측이 값
  ///       행만 읽기 때문이다.
  /// 인자: result — 격자 환산 결과
  /// 반환: 집계 항목이 줄바꿈으로 이어진 문자열
  static String encodeMeta(GridResampleResult result) {
    final buffer = StringBuffer(); // 집계 문자열을 쌓아갈 버퍼
    /// 작성: 2026-08-26 04:58:38 · nada
    /// 함수: line
    /// 목적: 한 줄을 쓰고 줄바꿈 문자를 붙여 버퍼에 담는다.
    /// 인자: text — 추가할 한 줄 내용
    void line(String text) {
      buffer.write(text);
      buffer.write(lineEnding);
    }

    line('# OTIS 계측 집계');
    line('format: $formatId ($columnCount열)');
    line('gridRateHz: ${1000000000 ~/ result.gridIntervalNs}');
    line('gridIntervalNs: ${result.gridIntervalNs}');
    line('t0Ns: ${result.t0Ns}');
    line('rowCount: ${result.rowCount}');
    line('durationSec: ${result.durationSec.toStringAsFixed(6)}');
    line('');
    // rawUsedCount · gravityUsedCount: 원본 가속도 · 중력 두 센서에서
    // 격자를 채우는 데 실제로 쓰인 표본 수. rawMaxSpanUs ·
    // gravityMaxSpanUs: 그 표본들 사이 시간 간격 중 가장 컸던 값(마이
    // 크로초) — 넓을수록 그만큼 성긴 원본 데이터로 비례 계산했다는 뜻
    line('rawUsedCount: ${result.rawUsedCount}');
    line('gravityUsedCount: ${result.gravityUsedCount}');
    line('rawMaxSpanUs: ${result.rawMaxSpanNs ~/ 1000}');
    line('gravityMaxSpanUs: ${result.gravityMaxSpanNs ~/ 1000}');
    line('');
    // 환산 과정에서 그대로 못 쓰고 버리거나 대체한 표본 수.
    // droppedZeroCount: 측정 시작 직후처럼 X Y Z가 전부 0으로 온
    // 표본(그대로 쓰면 없는 진동이 만들어져 버린다).
    // droppedBackwardCount: 시각이 직전 표본보다 거꾸로 온 표본.
    // droppedLinearCount: 안드로이드가 자체 계산해 보내는(쓰지 않기로
    // 한) linear 값. degenerateSpanCount: 비례 계산에 쓸 앞뒤 두
    // 실측값의 시각이 같아 계산 대신 앞 값을 그대로 쓴 횟수.
    // headTrimmedRows · tailTrimmedRows는 바로 아래 설명대로다.
    line('droppedZeroCount: ${result.droppedZeroCount}');
    line('droppedBackwardCount: ${result.droppedBackwardCount}');
    line('droppedLinearCount: ${result.droppedLinearCount}');
    line('degenerateSpanCount: ${result.degenerateSpanCount}');
    line('headTrimmedRows: ${result.headTrimmedRows}');
    line('tailTrimmedRows: ${result.tailTrimmedRows}');
    line('edgeTrimmedRows: ${result.edgeTrimmedRows}');
    line('');
    line('# headTrimmedRows / tailTrimmedRows 는 두 센서의 수신 구간이');
    line('# 어긋난 만큼 격자를 만들지 않은 행 수다. 직전 값 복사는 하지 않는다.');
    line('# edgeTrimmedRows 는 시작 · 종료 입력 충격을 빼려고 앞뒤에서 버린');
    line('# 행 수의 합이다. native_raw.txt 는 자르지 않는다.');
    if (result.samples.isNotEmpty) {
      // → 로직 이동: axisMeans()
      final mean = axisMeans(result); // raw.txt 에서 뺀 평균 (mg)
      line('');
      line('rawExportMeanXmg: ${mean.x.toStringAsFixed(decimalDigits)}');
      line('rawExportMeanYmg: ${mean.y.toStringAsFixed(decimalDigits)}');
      line('rawExportMeanZmg: ${mean.z.toStringAsFixed(decimalDigits)}');
      line('# raw.txt 는 OTIS EVIMP1 관례대로 축별 위 평균을 뺀 값이다.');
      line('# 손대지 않은 원본은 native_raw.txt 다.');
    }
    return buffer.toString();
  }

  /// 작성: 2026-08-18 23:43:06 · 박건준
  /// 함수: writeMeta
  /// 목적: 집계 파일을 기록한다. 격자 환산이 실패하면 `result`에는
  ///       표본 없이 실패 사유(`failureReason`)만 담겨 오는데, 이때도
  ///       집계 파일은 그대로 만들고 그 사유를 파일 끝에 한 줄
  ///       추가한다. 나중에 왜 실패했는지 찾아볼 수 있어야 하기
  ///       때문이다. (반면 값 파일을 쓰는 `write()`는 실패한 결과면
  ///       아예 쓰지 않고 예외를 던진다.)
  /// 인자: path — 기록할 파일 절대 경로
  ///       result — 격자 환산 결과. 실패했으면 `failureReason`에
  ///       사유가 들어있다
  /// 반환: 기록한 파일
  static Future<File> writeMeta(String path, GridResampleResult result) async {
    final file = File(path); // 기록할 파일 객체
    await file.parent.create(recursive: true);
    // → 로직 이동: encodeMeta()
    final body = StringBuffer(encodeMeta(result)); // 집계 파일 본문
    if (result.failureReason != null) {
      body.write('failureReason: ${result.failureReason}');
      body.write(lineEnding);
    }
    await file.writeAsString(body.toString());
    return file;
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 수정: 2026-10-22 19:00:00 · nada
  /// 함수: encodeConditioningMeta
  /// 목적: 지표 계산 전 신호 처리(`SignalConditioner.condition()`)를 어떻게
  ///       했는지 집계 파일 끝에 덧붙일 문자열로 만든다. 값 파일(`raw.txt`)은
  ///       처리 전 격자(축별 전체 평균만 뺌)이고 지표는 처리 후 격자로
  ///       내므로, 두 값이 왜 다른지 집계 파일만 보고 알 수 있어야 한다.
  ///       - 처리 방식 한 줄 — 수치는 실제로 쓴 설정에서 옮긴다
  ///       - 축별 기준선과 기준선 구간 표준편차 (mg). 표준편차는 기준선 구간에
  ///         손 움직임이 섞였는지 나중에 보려는 값이고 판정하지 않는다
  ///       - 처리 후 표본 속도와 행 수
  ///       처리가 실패했으면 기준선 대신 실패 사유만 적는다
  ///       (`encodeConditioningFailure()`).
  /// 인자: conditioned — 처리 결과
  ///       config — 처리에 쓴 수집 설정
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 집계 문자열
  static String encodeConditioningMeta(
    ConditionedGrid conditioned,
    CaptureConfig config,
  ) {
    if (!conditioned.isSuccess) {
      // → 로직 이동: encodeConditioningFailure()
      return encodeConditioningFailure(conditioned.failureReason!);
    }
    final buffer = StringBuffer(lineEnding); // 앞 집계와 빈 줄로 나눈다
    // 한 줄을 쓰고 줄바꿈 문자를 붙인다
    void line(String text) => buffer
      ..write(text)
      ..write(lineEnding);
    // 성공이면 세 값 모두 있다 — `ConditionedGrid` 생성자가 요구한다
    String mg(double? value) => value!.toStringAsFixed(decimalDigits);

    line(
      'conditioning: baseline + lowpass ${config.lowpassCutoffHz}Hz '
      '(butterworth ${config.lowpassOrder}, zero-phase) + resample '
      '${config.targetSampleRateHz}->${config.conditionedRateHz}Hz',
    );
    line('baselineXmg: ${mg(conditioned.baselineXMg)}');
    line('baselineYmg: ${mg(conditioned.baselineYMg)}');
    line('baselineZmg: ${mg(conditioned.baselineZMg)}');
    line('baselineStdXmg: ${mg(conditioned.baselineStdXMg)}');
    line('baselineStdYmg: ${mg(conditioned.baselineStdYMg)}');
    line('baselineStdZmg: ${mg(conditioned.baselineStdZMg)}');
    // 성공이면 기준선 구간도 늘 있다 — `ConditionedGrid` 생성자가 요구한다
    final rate = config.targetSampleRateHz; // 입력 격자 속도 (Hz)
    line('baselineSource: ${conditioned.baselineSource!.name}');
    line(
      'baselineStartSec: '
      '${(conditioned.baselineStartRow! / rate).toStringAsFixed(decimalDigits)}',
    );
    line(
      'baselineSec: '
      '${(conditioned.baselineRows! / rate).toStringAsFixed(decimalDigits)}',
    );
    line('conditionedRateHz: ${conditioned.sampleRateHz.round()}');
    line('conditionedRowCount: ${conditioned.rowCount}');
    line(
      '# raw.txt 는 필터 · 기준선 보정 전 ${config.targetSampleRateHz}Hz '
      '격자에서 축별 전체 평균만 뺀 값이다. 지표 · 리포트는 위 처리 후 '
      '값으로 낸다.',
    );
    line(
      '# baselineStd 는 기준선 구간(baselineStartSec 부터 baselineSec)의 '
      '표준편차다. 판정에는 쓰지 않는다. 기준선은 처음 '
      '${config.baselineWindowMs}ms 이고, 그 안에서 움직였으면 움직임 '
      '앞까지(startShortened) 또는 기록 끝 정지 구간(end)에서 낸다.',
    );
    return buffer.toString();
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 함수: encodeConditioningFailure
  /// 목적: 지표 계산 전 신호 처리가 실패한 사유를 집계 파일 끝에 덧붙일
  ///       문자열로 만든다. 처리가 실패해도 값 파일(`raw.txt`)은 이미 써
  ///       두었으므로, 왜 지표가 없는지 집계 파일에서 찾을 수 있어야 한다.
  /// 인자: reason — 실패 사유 (설정 오류 예외 문구 포함)
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 한 줄
  static String encodeConditioningFailure(String reason) =>
      '${lineEnding}conditioningFailureReason: $reason$lineEnding';

  /// 작성: 2026-10-20 14:05:12 · nada
  /// 함수: encodeMotionMeta
  /// 목적: 운행 거리 · 최대 속도를 적분한 움직인 구간을 집계 파일 끝에
  ///       덧붙일 문자열로 만든다. 거리가 이상할 때 어느 구간을 적분했는지
  ///       집계 파일만 보고 알 수 있게 한다.
  ///       - 적분 방식 한 줄(`MeasurementAssembler.kinematicsMethodLabel`)
  ///       - 구간 시작 · 끝 (초). 정지 측정이면 그 사실 한 줄
  ///       - 구간 여유가 기록 앞 · 끝에서 잘렸으면 그 사실. 승강기가 서기
  ///         전에 측정을 끝냈거나 움직이는 중에 시작했으면 거리가 작게 나올
  ///         수 있다
  /// 인자: motion — 움직인 구간. 정지 측정이면 null
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 집계 문자열
  static String encodeMotionMeta(MotionWindow? motion) {
    final buffer = StringBuffer(lineEnding); // 앞 집계와 빈 줄로 나눈다
    // 한 줄을 쓰고 줄바꿈 문자를 붙인다
    void line(String text) => buffer
      ..write(text)
      ..write(lineEnding);

    line('kinematics: ${MeasurementAssembler.kinematicsMethodLabel}');
    if (motion == null) {
      line('motionWindow: none');
      line('# 문턱을 넘는 움직임이 없어 운행 거리 · 최대 속도를 0 으로 둔다.');
      return buffer.toString();
    }
    line(
      'motionWindowStartSec: ${motion.startSec.toStringAsFixed(decimalDigits)}',
    );
    line('motionWindowEndSec: ${motion.endSec.toStringAsFixed(decimalDigits)}');
    if (motion.clippedAtStart) {
      line('motionWindowClippedAtStart: true');
      line('# 측정 시작 때 이미 움직이고 있었을 수 있다. 거리가 작게 나올 수 있다.');
    }
    if (motion.clippedAtEnd) {
      line('motionWindowClippedAtEnd: true');
      line('# 승강기가 서기 전에 측정을 끝냈을 수 있다. 거리가 작게 나올 수 있다.');
    }
    return buffer.toString();
  }

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: encodePlacementMeta
  /// 목적: 거치 방향 판정을 집계 파일 끝에 덧붙일 문자열로 만든다.
  /// 인자: placement — 판정 결과. 측정이 1초보다 짧아 판정하지 못했으면 null
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 집계 문자열
  static String encodePlacementMeta(PlacementReading? placement) {
    final buffer = StringBuffer(lineEnding); // 앞 집계와 빈 줄로 나눈다
    // 한 줄을 쓰고 줄바꿈 문자를 붙인다
    void line(String text) => buffer
      ..write(text)
      ..write(lineEnding);

    if (placement == null) {
      line('placement: unknown');
      line(
        '# 수집 처음 ${CaptureConfig.placementWindowMs}ms 의 중력 이벤트가 '
        '모이기 전에 끝나 판정하지 못했다.',
      );
      return buffer.toString();
    }
    line('placement: ${placement.placement.name}');
    line(
      'placementGravityZmg: '
      '${placement.gravityZMg.toStringAsFixed(decimalDigits)}',
    );
    line(
      '# 수집 처음 ${CaptureConfig.placementWindowMs}ms 중력 Z 평균으로 판정 '
      '(≤ ${CaptureConfig.placementFaceDownMaxMg} faceDown, '
      '≥ ${CaptureConfig.placementFaceUpMinMg} faceUp, 그 밖 tilted).',
    );
    return buffer.toString();
  }

  /// 작성: 2026-10-22 12:00:00 · nada
  /// 함수: encodeNoiseMeta
  /// 목적: 소음 계산 방식(시간가중 · 마이크 표본 속도)을 집계 파일 끝에
  ///       덧붙일 문자열로 만든다. 2026-10-22 에 44.1 → 48kHz 로 바꿔, 예전
  ///       측정과 견줄 때 어느 쪽인지 집계 파일만 보고 알게 한다.
  /// 인자: sampleRateHz — 소음 마이크를 연 표본 속도(Hz). 못 열었으면 null
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 집계 문자열
  static String encodeNoiseMeta(int? sampleRateHz) {
    final buffer = StringBuffer(lineEnding); // 앞 집계와 빈 줄로 나눈다
    // 한 줄을 쓰고 줄바꿈 문자를 붙인다
    void line(String text) => buffer
      ..write(text)
      ..write(lineEnding);

    line('noiseTimeWeighting: fast (${kNoiseTimeWeightSec}s)');
    line('noiseSampleRateHz: ${sampleRateHz ?? 'none'}');
    line('noiseOffsetDb: $kDefaultMicDbfsToDbaOffset');
    if (sampleRateHz == null) {
      line('# 소음 마이크를 열지 못했다(권한 없음 등). 소음 값은 0(미측정)이다.');
    }
    return buffer.toString();
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 수정: 2026-10-22 19:00:00 · nada
  /// 함수: encodeTravelMeta
  /// 목적: 주파수 가중과 운행 구간을 집계 파일 끝에 덧붙일 문자열로 만든다.
  ///       지표는 가중한 시계열의 운행 구간 안에서 내므로, 리포트 값이
  ///       어느 구간에서 나왔는지 집계 파일만 보고 알 수 있어야 한다.
  ///       - 가중 방식 한 줄 — 수치는 실제로 쓴 상수에서 옮긴다
  ///       - 휴대폰 제조사 · 기종과 기종 응답 보정(2026-10-22)
  ///       - 운행 구간 시작 · 끝 (초, m). 정하지 못했으면 그 사유 한 줄
  ///       - 정속 구간 판정 방식과 시작 · 끝 (초), Jptp 넓힘이 기록 끝에
  ///         막혔는지. 정하지 못했으면 그 사유
  ///       - 운행 끝부터 기록 끝까지 (초). 1초 미만이면 주석 한 줄
  /// 인자: result — 지표를 낸 측정 결과
  /// 반환: 빈 줄로 시작해 줄바꿈 문자로 끝나는 집계 문자열
  static String encodeTravelMeta(MeasurementResult result) {
    final buffer = StringBuffer(lineEnding); // 앞 집계와 빈 줄로 나눈다
    // 한 줄을 쓰고 줄바꿈 문자를 붙인다
    void line(String text) => buffer
      ..write(text)
      ..write(lineEnding);
    String fixed(double value) => // 소수 셋째 자리까지 적은 값
        value.toStringAsFixed(decimalDigits);

    line(
      'weighting: x/y Wd, z highpass '
      '${CaptureConfig.rideVerticalHighpassHz}Hz (butterworth '
      '${CaptureConfig.rideVerticalHighpassOrder}, zero-phase) + Wk '
      '(ISO 8041) [${RideWeighting.methodLabel}]',
    );
    line('deviceManufacturer: ${result.deviceManufacturer ?? 'unknown'}');
    line('deviceModel: ${result.deviceModel ?? 'unknown'}');
    line('deviceCompensation: ${result.deviceCompensation}');
    line(
      '# 수직은 가중 뒤 기종 응답 보정(표에 있는 기종만, 양방향 저역)을 건다. '
      'none 이면 보정하지 않았다.',
    );
    final window = result.travelWindow; // 운행 구간, 못 정했으면 null
    if (window == null) {
      line('travelWindowFailureReason: ${result.travelWindowFailure}');
    } else {
      line('travelWindowStartSec: ${fixed(window.startSec)}');
      line('travelWindowEndSec: ${fixed(window.endSec)}');
      line('travelWindowStartM: ${fixed(window.startM)}');
      line('travelWindowEndM: ${fixed(window.endM)}');
    }
    line(
      '# 진동 · 소음 지표는 위 가중 뒤 시계열의 운행 구간(출발 · 정지 '
      '${CaptureConfig.travelEdgeExclusionM}m 제외) 안에서 낸다.',
    );
    final zones = result.motionZones; // 정속 · 가감속 구간, 못 정했으면 null
    line('zones: ${MotionZones.methodLabel}');
    if (zones == null) {
      line('zonesFailureReason: ${result.motionZonesFailure}');
    } else {
      line('steadyStartSec: ${fixed(zones.steadyStartSec)}');
      line('steadyEndSec: ${fixed(zones.steadyEndSec)}');
      line('zJptpClippedAtEnd: ${result.zJptpClippedAtEnd}');
      line(
        '# 수직 최대(zPtp)는 정속 구간, 가감속 최대(zJptp)는 그 밖 운행에서 '
        '낸다.',
      );
    }
    final margin = result.stopMarginSec; // 정지 뒤 여유 (초), 없으면 null
    line('stopMarginSec: ${margin == null ? 'none' : fixed(margin)}');
    if (margin != null && margin * 1000 < CaptureConfig.minimumStopMarginMs) {
      line(
        '# 운행 끝 뒤 ${CaptureConfig.minimumStopMarginMs}ms 를 못 채우고 '
        '끝났다. 끝부분 값이 부정확할 수 있다.',
      );
    }
    return buffer.toString();
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 함수: appendMeta
  /// 목적: 이미 쓴 집계 파일 끝에 문자열을 덧붙인다. 집계는 격자 환산
  ///       직후에 먼저 쓰고, 신호 처리 결과는 그 뒤에 알 수 있기 때문이다.
  /// 인자: path — 집계 파일 절대 경로
  ///       text — 덧붙일 문자열 (`encodeConditioningMeta()` 등)
  /// 반환: 덧붙인 파일
  static Future<File> appendMeta(String path, String text) =>
      File(path).writeAsString(text, mode: FileMode.append);
}
