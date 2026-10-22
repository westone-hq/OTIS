import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/adapter/vibration_file_writer.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/noise_offset.dart';
import 'package:vibration_checker/domain/capture/device_response.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/capture/ride_weighting.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/report/motion_zones.dart';
import 'package:vibration_checker/domain/session/login_session.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';

/// 작성: 2026-10-04 13:29:41 · nada
/// 클래스: RecordFailure
/// 목적: 측정을 저장하지 못한 사유의 종류. 화면이 종류마다 다른 안내
///       문구를 고른다.
///       - `siteMissing` — 현장 정보가 없거나 층수가 숫자가 아니다
///       - `noSamples` — 가속도 또는 중력 값이 2개 미만이다
///       - `gridFailed` — 격자 환산이 사유를 올리며 실패했다
///       - `conditioningFailed` — 지표 계산 전 신호 처리가 실패했다. 격자가
///         기준선 구간보다 짧거나 처리 설정이 잘못된 경우다. 값 파일
///         (`raw.txt`)은 이미 써 두어 남는다
///       - `assembleFailed` — 측정 결과 모델로 바꾸지 못했다
///       - `ioError` — 파일을 쓰는 중 예외가 났다
enum RecordFailure {
  siteMissing,
  noSamples,
  gridFailed,
  conditioningFailed,
  assembleFailed,
  ioError,
}

/// 작성: 2026-10-04 13:29:41 · nada
/// 클래스: RecordOutcome
/// 목적: `MeasurementRecorder.record()` 의 결과. 성공이면 측정 ID 와
///       저장한 파일 목록을, 실패면 사유를 담는다. 성공과 실패를 같은 형태로
///       돌려줘 화면이 예외를 잡지 않고 갈래만 나누게 한다. 신호 처리
///       실패는 원인 종류(`conditioningCause`)까지 담아, 화면이 사유
///       문자열을 비교하지 않고 문구를 고르게 한다.
class RecordOutcome {
  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: RecordOutcome.success
  /// 목적: 저장에 성공한 결과를 만든다.
  /// 인자: id — 저장한 측정 ID. 결과 화면이 이 ID 로 측정 결과를 읽는다
  ///       savedPaths — 저장한 파일 경로. 메일 첨부 순서 그대로다
  const RecordOutcome.success({
    required String this.id,
    required this.savedPaths,
  }) : failure = null,
       conditioningCause = null,
       detail = null;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: RecordOutcome.failure
  /// 목적: 저장에 실패한 결과를 만든다.
  /// 인자: failure — 실패 종류
  ///       detail — 화면에 덧붙일 원인 문구. 없으면 null
  const RecordOutcome.failure(RecordFailure this.failure, [this.detail])
    : conditioningCause = null,
      id = null,
      savedPaths = const <String>[];

  /// 작성: 2026-10-07 02:22:28 · nada
  /// 함수: RecordOutcome.conditioningFailed
  /// 목적: 지표 계산 전 신호 처리에 실패한 결과를 만든다. 실패 종류는
  ///       `RecordFailure.conditioningFailed` 이고 원인 종류를 함께 담는다.
  /// 인자: cause — 처리 실패 원인 종류
  ///       detail — 화면에 덧붙일 원인 문구. 없으면 null
  const RecordOutcome.conditioningFailed(
    ConditioningFailure this.conditioningCause, [
    this.detail,
  ]) : failure = RecordFailure.conditioningFailed,
       id = null,
       savedPaths = const <String>[];

  /// 실패 종류. 성공이면 null
  final RecordFailure? failure;

  /// 신호 처리 실패의 원인 종류. 실패 종류가
  /// `RecordFailure.conditioningFailed` 일 때만 있고, 그 밖에는 null
  final ConditioningFailure? conditioningCause;

  /// 실패 원인 문구 (환산 · 변환 실패 사유, 예외 문구). 성공이거나 덧붙일
  /// 원인이 없으면 null
  final String? detail;

  /// 저장한 측정 ID (`yyyyMMdd-HHmmss`). 실패면 null
  final String? id;

  /// 저장한 파일 경로 목록. 리포트를 맨 앞에 둬 메일 첨부 목록에서 먼저
  /// 보이게 한다. 리포트 · 안드로이드 원본 사본 · 현장 소음 녹음은 못
  /// 만들었으면 빠진다. 실패면 빈 목록
  final List<String> savedPaths;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: isSuccess
  /// 목적: 저장에 성공했는지 알려준다.
  bool get isSuccess => failure == null;
}

/// 작성: 2026-10-04 13:29:41 · nada
/// 클래스: MeasurementRecorder
/// 목적: 수집이 끝난 측정 한 건을 파일로 남기는 절차를 한 곳에 둔다.
///       측정 화면(measuring_screen.dart)에 있던 저장 단계를 옮겨 와,
///       화면을 다시 만들어도 저장 순서가 바뀌지 않게 한다.
class MeasurementRecorder {
  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: MeasurementRecorder._
  /// 목적: 상태가 없는 절차 묶음이라 인스턴스를 만들지 않게 막는다.
  MeasurementRecorder._();

  /// 작성: 2026-10-05 10:03:35 · nada
  /// 수정: 2026-10-18 10:12:30 · nada
  /// 함수: _moveNativeFile
  /// 목적: 안드로이드가 앱 저장 공간 맨 위에 따로 남긴 파일(원본 기록,
  ///       현장 소음 녹음)을 이번 측정 폴더로 옮긴다.
  ///       - 복사에 성공하면 안드로이드 쪽 파일을 지운다. 지우지 않으면
  ///         측정할 때마다 앱 저장 공간에 쌓인다
  ///       - 파일이 없거나 복사 · 삭제가 실패하면 그 사실을 집계 파일 끝에
  ///         `label` 을 머리로 한 줄 적고 넘어간다. 두 파일 모두 확인 ·
  ///         청취용 자료라 이것 때문에 저장 전체를 실패로 알리지 않는다
  /// 인자: sourcePath — 안드로이드가 남긴 파일 경로, 없으면 null
  ///       jobDirPath — 이번 측정 폴더 경로
  ///       fileName — 측정 폴더 안에서 쓸 이름
  ///       metaPath — 사실을 덧붙일 집계 파일 경로
  ///       label — 집계 줄 머리 (`rawRecord`, `noiseAudio`)
  /// 반환: 측정 폴더 안의 사본 경로. 복사하지 못했으면 null
  static Future<String?> _moveNativeFile({
    required String? sourcePath,
    required String jobDirPath,
    required String fileName,
    required String metaPath,
    required String label,
  }) async {
    final meta = File(metaPath); // 사실을 덧붙일 집계 파일
    if (sourcePath == null) {
      await meta.writeAsString('${label}Path: null\n', mode: FileMode.append);
      return null;
    }
    final copyPath = '$jobDirPath/$fileName'; // 사본 경로
    try {
      await File(sourcePath).copy(copyPath);
    } catch (e) {
      debugPrint('$label 복사 실패: $e');
      await meta.writeAsString(
        '${label}CopyFailed: $e\n',
        mode: FileMode.append,
      );
      return null;
    }
    try {
      await File(sourcePath).delete();
    } catch (e) {
      debugPrint('$label 삭제 실패: $e');
      await meta.writeAsString(
        '${label}DeleteFailed: $sourcePath\n',
        mode: FileMode.append,
      );
    }
    return copyPath;
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 수정: 2026-10-23 10:00:00 · nada
  /// 함수: _condition
  /// 목적: 격자에 지표 계산 전 신호 처리를 하고, 그 결과를 집계 파일 끝에
  ///       덧붙인다.
  ///       - 처리 설정이 잘못돼 `ArgumentError` 가 나면 원인 종류를
  ///         `ConditioningFailure.invalidConfig` 로 둔다. 격자가 짧아 사유를
  ///         담은 실패가 오면 처리기가 정한 원인 종류를 그대로 쓴다. 파일
  ///         쓰기 예외(`RecordFailure.ioError`)와 섞지 않으려고 여기서 잡는다
  ///       - 집계 파일 덧붙이기가 실패해도 멈추지 않는다. `record()` 가
  ///         처음 집계를 쓸 때와 같은 규칙이다
  /// 인자: grid — 격자 환산에 성공한 격자
  ///       conditioner — 격자를 만든 수집 설정을 받은 처리기
  ///       metaPath — 결과를 덧붙일 집계 파일 경로
  /// 반환: 처리한 격자와 기준선 출처. 실패면 격자는 null 이고 원인 종류와
  ///       사유가 있다
  static Future<
    ({
      GridResampleResult? grid,
      ConditioningFailure? cause,
      String? failureReason,
      BaselineSource? baselineSource,
    })
  >
  _condition(
    GridResampleResult grid,
    SignalConditioner conditioner,
    String metaPath,
  ) async {
    final ConditionedGrid conditioned; // 처리 결과
    try {
      // → 로직 이동: SignalConditioner.condition()
      conditioned = conditioner.condition(grid);
    } on ArgumentError catch (e) {
      // → 로직 이동: _appendMeta()
      await _appendMeta(
        metaPath,
        VibrationFileWriter.encodeConditioningFailure('$e'),
      );
      return (
        grid: null,
        cause: ConditioningFailure.invalidConfig,
        failureReason: '$e',
        baselineSource: null,
      );
    }
    // → 로직 이동: _appendMeta()
    await _appendMeta(
      metaPath,
      VibrationFileWriter.encodeConditioningMeta(
        conditioned,
        conditioner.config,
      ),
    );
    return conditioned.isSuccess
        ? (
            grid: conditioned.grid,
            cause: null,
            failureReason: null,
            baselineSource: conditioned.baselineSource,
          )
        : (
            grid: null,
            cause: conditioned.failureCause,
            failureReason: conditioned.failureReason,
            baselineSource: null,
          );
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 함수: _appendMeta
  /// 목적: 집계 파일 끝에 문자열을 덧붙인다. 집계 파일은 진단용이라 쓰기가
  ///       실패해도 저장 절차를 멈추지 않고 기록만 남긴다.
  /// 인자: metaPath — 집계 파일 경로
  ///       text — 덧붙일 문자열
  static Future<void> _appendMeta(String metaPath, String text) async {
    try {
      // → 로직 이동: VibrationFileWriter.appendMeta()
      await VibrationFileWriter.appendMeta(metaPath, text);
    } catch (e, st) {
      debugPrint('집계 파일 덧붙이기 실패: $e\n$st');
    }
  }

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: _minimumSamples
  /// 목적: 가속도 · 중력 각각 이만큼은 모여야 저장을 시도한다.
  /// 근거: 표준 — 격자 환산은 양옆 실측값 사이를 비례로 채우므로 축마다
  ///       값이 최소 2개 있어야 계산할 수 있다
  static const int _minimumSamples = 2;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 수정: 2026-10-23 10:00:00 · nada
  /// 함수: record
  /// 목적: 측정 한 건을 저장한다. 순서대로 진행한다.
  ///       1. 현장 정보와 표본 수를 확인한다. 모자라면 파일을 만들기
  ///          전에 멈춘다
  ///       2. 격자로 환산하고, 성공 여부와 상관없이 집계 파일을 먼저
  ///          남긴다 — 환산이 실패한 이유를 나중에 집계에서 본다.
  ///          집계 파일 쓰기가 실패해도 멈추지 않는다
  ///       3. 안드로이드가 따로 저장한 원본 기록과 현장 소음 녹음을 이번
  ///          측정 폴더로 옮긴다(`_moveNativeFile()`). 뒤 단계가 실패해도
  ///          두 파일이 측정 폴더에 남도록 실패 여부를 가르기 전에 옮긴다
  ///          — 실패한 측정의 파일이 앱 저장 공간 맨 위에 쌓이지 않게
  ///          한다. 옮기지 못해도 멈추지 않는다
  ///       4. 환산이 실패했으면 멈춘다. 성공이면 측정값 파일을 쓴다.
  ///          측정값 파일은 처리 전 격자에서 축별 전체 평균만 뺀 값이다
  ///          (OTIS EVIMP1 관례, `VibrationFileWriter.encode()`)
  ///       5. 지표 계산 전 신호 처리(기준선 0 맞춤 · 저역 필터 · 재표본)를
  ///          하고 결과를 집계 파일에 덧붙인다(`_condition()`). 실패하면
  ///          멈추되 측정값 파일은 지우지 않는다
  ///       6. 처리한 격자를 측정 결과 모델로 바꾸고(가중 · 운행 구간 ·
  ///          지표, `MeasurementAssembler`), 가중 · 운행 구간을 집계 파일에
  ///          덧붙인 뒤(운동을 적분한 움직인 구간도 함께) 처리 방식
  ///          (`SignalConditioner.methodLabel` + `RideWeighting.methodLabel`
  ///          + `DeviceResponse.methodLabel()`
  ///          + `MeasurementAssembler.kinematicsMethodLabel` +
  ///          `MeasurementAssembler.jerkMethodLabel` +
  ///          `MeasurementAssembler.accelChartMethodLabel` +
  ///          `MotionZones.methodLabel` + `noiseMethodLabel()`)
  ///          과 거치 방향을 실어
  ///          저장소에 저장한다. 로그인한
  ///          작업자(성명 · 사번 · 업체명 · 관리팀)도 이 시점 값을 함께 싣는다
  ///       7. 리포트 PDF 를 미리 만든다. 메일을 보낼 때 만들면 그때
  ///          기다리게 되고, 그 자리에서 실패하면 보내지 못한다. 실패해도
  ///          측정은 이미 저장됐으므로 멈추지 않는다 — 나중에
  ///          `ensureReportPdf()` 가 다시 만든다
  ///       8. 측정 결과가 `MeasurementRepository.maxStoredMeasurements`
  ///          개를 넘으면 오래된 것부터 지운다(`pruneOldest()`). 실패해도
  ///          이번 측정은 이미 저장됐으므로 멈추지 않는다 — 다음 측정
  ///          때 다시 정리한다
  /// 인자: resampler — 수집한 이벤트가 쌓인 환산기
  ///       site — 이번 측정의 현장 정보. 없으면 null
  ///       nativeRecordPath — 안드로이드가 저장한 원본 경로, 없으면 null
  ///       noiseAudioPath — 안드로이드가 닫은 현장 소음 녹음(M4A) 경로,
  ///       녹음하지 못했으면 null
  ///       measuredAt — 측정 시각. 측정 ID 와 파일 이름의 기준이다
  ///       placement — 수집 처음 1초로 판정한 거치 방향
  ///       (`CaptureSession.placement`). 판정 전에 끝났으면 null
  ///       noiseSampleRateHz — 소음 마이크를 연 표본 속도
  ///       (`CaptureSession.noiseSampleRateHz`). 못 열었으면 null
  ///       deviceManufacturer, deviceModel — 측정한 휴대폰 제조사 · 기종
  ///       이름(`CaptureSession.deviceModel` 등). 기종 응답 보정을 고른다.
  ///       모르면 null(보정 없음)
  /// 반환: 저장 결과. 파일을 쓰다 난 예외는 `RecordFailure.ioError` 로
  ///       바꿔 돌려준다
  static Future<RecordOutcome> record({
    required GridResampler resampler,
    required SiteInfo? site,
    required String? nativeRecordPath,
    required String? noiseAudioPath,
    required DateTime measuredAt,
    PlacementReading? placement,
    int? noiseSampleRateHz,
    String? deviceManufacturer,
    String? deviceModel,
  }) async {
    if (site == null || site.validate().isNotEmpty) {
      return const RecordOutcome.failure(RecordFailure.siteMissing);
    }
    if (resampler.rawCount < _minimumSamples ||
        resampler.gravityCount < _minimumSamples) {
      return const RecordOutcome.failure(RecordFailure.noSamples);
    }

    final id = DateFormat(
      'yyyyMMdd-HHmmss',
    ).format(KoreaTime.of(measuredAt)); // 측정 ID (한국 시간)
    final grid = resampler.resample(); // → 로직 이동: GridResampler.resample()

    try {
      final repo = MeasurementRepository.instance; // 저장 배치를 아는 저장소
      // → 로직 이동: MeasurementRepository.jobDirectory()
      final jobDir = await repo.jobDirectory(id); // 이번 측정의 폴더
      final metaPath =
          '${jobDir.path}/${MeasurementRepository.metaFileName}'; // 집계 파일
      try {
        // → 로직 이동: VibrationFileWriter.writeMeta()
        await VibrationFileWriter.writeMeta(metaPath, grid);
      } catch (e, st) {
        debugPrint('집계 파일 기록 실패: $e\n$st');
      }

      // → 로직 이동: _moveNativeFile()
      final rawCopyPath = await _moveNativeFile(
        sourcePath: nativeRecordPath,
        jobDirPath: jobDir.path,
        fileName: MeasurementRepository.nativeRawFileName,
        metaPath: metaPath,
        label: 'rawRecord',
      ); // 복사해 둔 안드로이드 원본 경로, 못 했으면 null
      // → 로직 이동: _moveNativeFile()
      final audioCopyPath = await _moveNativeFile(
        sourcePath: noiseAudioPath,
        jobDirPath: jobDir.path,
        fileName: MeasurementRepository.noiseAudioFileName,
        metaPath: metaPath,
        label: 'noiseAudio',
      ); // 옮겨 둔 현장 소음 녹음 경로, 못 했으면 null

      if (!grid.isSuccess) {
        return RecordOutcome.failure(
          RecordFailure.gridFailed,
          grid.failureReason,
        );
      }
      final valuePath =
          '${jobDir.path}/${MeasurementRepository.rawFileName}'; // 측정값 파일
      // → 로직 이동: VibrationFileWriter.write()
      await VibrationFileWriter.write(valuePath, grid);

      final conditioner = SignalConditioner(
        config: resampler.config,
      ); // 격자를 만든 설정 그대로 쓰는 처리기
      // → 로직 이동: _condition()
      final conditioned = await _condition(
        grid,
        conditioner,
        metaPath,
      ); // 처리한 격자, 실패면 격자 없이 원인 종류와 사유
      final conditionedGrid = conditioned.grid; // 처리한 격자, 실패면 null
      if (conditionedGrid == null) {
        // 실패면 원인 종류가 늘 있다 — `_condition()` 이 함께 채운다
        return RecordOutcome.conditioningFailed(
          conditioned.cause!,
          conditioned.failureReason,
        );
      }

      // 작업자는 저장하는 이 시점 값을 결과에 싣는다. 나중에 다른 사람이
      // 로그인해도 이미 낸 리포트의 엔지니어 이름이 바뀌지 않게 한다.
      // 로그인 전에는 라우터가 측정 화면에 들이지 않지만, 시험처럼 화면을
      // 거치지 않고 부르면 비어 있을 수 있어 null 로 둔다
      final worker = LoginSession.instance.current; // 로그인 작업자
      // → 로직 이동: MeasurementAssembler.assemble()
      final assembled = MeasurementAssembler.assemble(
        grid: conditionedGrid,
        site: site,
        id: id,
        measuredAt: measuredAt,
        worker: worker,
        deviceManufacturer: deviceManufacturer,
        deviceModel: deviceModel,
      ); // 측정 결과 모델로 바꾼 결과. 실패했으면 사유만 들어 있다
      if (!assembled.isSuccess) {
        return RecordOutcome.failure(
          RecordFailure.assembleFailed,
          assembled.failureReason,
        );
      }
      // → 로직 이동: _appendMeta()
      await _appendMeta(
        metaPath,
        // → 로직 이동: VibrationFileWriter.encodeTravelMeta()
        VibrationFileWriter.encodeTravelMeta(assembled.result!),
      );
      // → 로직 이동: _appendMeta()
      await _appendMeta(
        metaPath,
        // → 로직 이동: VibrationFileWriter.encodeMotionMeta()
        VibrationFileWriter.encodeMotionMeta(assembled.motion),
      );
      // → 로직 이동: _appendMeta()
      await _appendMeta(
        metaPath,
        // → 로직 이동: VibrationFileWriter.encodePlacementMeta()
        VibrationFileWriter.encodePlacementMeta(placement),
      );
      // → 로직 이동: _appendMeta()
      await _appendMeta(
        metaPath,
        // → 로직 이동: VibrationFileWriter.encodeNoiseMeta()
        VibrationFileWriter.encodeNoiseMeta(noiseSampleRateHz),
      );
      // → 로직 이동: MeasurementRepository.save()
      await repo.save(
        assembled.result!.copyWith(
          placement: placement?.placement.name,
          placementGravityZMg: placement?.gravityZMg,
          baselineSource: conditioned.baselineSource?.name,
          signalConditioning:
              '${conditioner.methodLabel}+${RideWeighting.methodLabel}'
              // → 로직 이동: DeviceResponse.methodLabel()
              '+${DeviceResponse.methodLabel(deviceModel)}'
              '+${MeasurementAssembler.kinematicsMethodLabel}'
              '+${MeasurementAssembler.jerkMethodLabel}'
              '+${MeasurementAssembler.accelChartMethodLabel}'
              '+${MotionZones.methodLabel}'
              // → 로직 이동: noiseMethodLabel()
              '+${noiseMethodLabel(noiseSampleRateHz)}',
        ),
      );

      String? reportPath; // 미리 만든 리포트 경로, 못 만들었으면 null
      try {
        // → 로직 이동: MeasurementRepository.ensureReportPdf()
        reportPath = (await repo.ensureReportPdf(id))?.path;
      } catch (e, st) {
        debugPrint('리포트 PDF 생성 실패: $e\n$st');
      }

      try {
        // → 로직 이동: MeasurementRepository.pruneOldest()
        final pruned = await repo.pruneOldest(keepId: id); // 지운 측정 ID
        if (pruned.isNotEmpty) debugPrint('오래된 측정 정리: $pruned');
      } catch (e, st) {
        debugPrint('오래된 측정 정리 실패: $e\n$st');
      }

      return RecordOutcome.success(
        id: id,
        savedPaths: <String>[
          ?reportPath,
          valuePath,
          metaPath,
          ?rawCopyPath,
          ?audioCopyPath,
        ],
      );
    } catch (e, st) {
      debugPrint('측정 저장 실패: $e\n$st');
      return RecordOutcome.failure(RecordFailure.ioError, '$e');
    }
  }
}
