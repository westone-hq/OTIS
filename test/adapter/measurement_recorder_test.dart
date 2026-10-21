import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/measurement_recorder.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/domain/session/login_session.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/model/worker.dart';

/// 작성: 2026-10-04 13:36:00 · nada
/// 클래스: _TempPathProvider
/// 목적: 저장소의 기준 폴더를 시험마다 새로 만든 임시 폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-04 13:36:00 · nada
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-04 13:36:00 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-04 13:36:00 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 작성: 2026-10-04 13:36:00 · nada
/// 수정: 2026-10-11 17:28:28 · nada
/// 변수: _site
/// 목적: 검사를 통과하는 현장 정보. 2026-10-11 부터 필수인 주소 ·
///       우편번호 · 하중까지 채운다.
const _site = SiteInfo(
  jobNo: '2025F 1234R01',
  siteName: '럭키종합건설/송정동근생',
  address: '부산시 해운대구',
  bottomFloor: '1',
  topFloor: '8',
  direction: SiteInfo.directionUp,
  model: SiteInfo.defaultModel,
  load: '1000',
  postalCode: '48094',
);

/// 작성: 2026-10-04 13:36:00 · nada
/// 함수: _filledResampler
/// 목적: 가속도 · 중력 이벤트를 4초 동안 256Hz 로 채운 환산기를 만든다.
///       앞뒤 0.5초씩 버린 뒤에도 기준선 구간 1초가 남아 신호 처리까지
///       지나는 길이다.
///       가속도에는 1Hz 사인 진동을 얹어 격자 값이 0 으로만 차지 않게 한다.
/// 인자: count — 센서마다 넣을 이벤트 수
///       config — 환산기 설정. 기본은 앱과 같은 기본 설정
/// 반환: 이벤트가 쌓인 환산기
GridResampler _filledResampler({
  int count = 1024,
  CaptureConfig config = const CaptureConfig(),
}) {
  final resampler = GridResampler(config: config); // 채울 환산기
  const stepUs = 3906; // 256Hz 한 칸 간격 (마이크로초)
  for (var i = 0; i < count; i++) {
    final tsUs = 1000000 + i * stepUs; // 이 이벤트의 시각 (마이크로초)
    final wobble = 5 * math.sin(2 * math.pi * i / 256); // 얹을 진동 (mg)
    resampler.onEvent(
      NativeEvent(
        type: NativeEventType.accel,
        tsUs: tsUs,
        xMg: wobble,
        yMg: wobble,
        zMg: 1000 + wobble,
        dtUs: stepUs,
      ),
    );
    resampler.onEvent(
      NativeEvent(
        type: NativeEventType.gravity,
        tsUs: tsUs + 100,
        xMg: 0.1,
        yMg: 0.1,
        zMg: 1000,
        dtUs: stepUs,
      ),
    );
  }
  return resampler;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp; // 이번 시험이 쓸 임시 폴더
  final measuredAt = DateTime(2026, 1, 14, 11, 3, 59); // 측정 ID 의 기준 시각

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_recorder_test');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    // 저장할 때 설정의 엔지니어 이름을 읽는다. 기본은 비어 있는 설정
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('MeasurementRecorder.record 저장 전 확인', () {
    test('현장 정보가 없으면 파일을 만들기 전에 멈춘다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: null,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.siteMissing);
      expect(temp.listSync(recursive: true), isEmpty);
    });

    test('층수가 오름차순이 아니면 현장 정보 오류다', () async {
      const reversed = SiteInfo(
        jobNo: '2025F 1234R01',
        siteName: '현장',
        address: '부산시 해운대구',
        bottomFloor: '8',
        topFloor: '1',
        direction: SiteInfo.directionUp,
        model: SiteInfo.defaultModel,
        load: '1000',
        postalCode: '48094',
      ); // 층수만 거꾸로이고 나머지는 검사를 통과하는 현장 정보
      expect(reversed.validate(), [SiteFieldError.floorNotAscending]);
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: reversed,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.siteMissing);
    });

    test('표본이 2개 미만이면 파일을 만들기 전에 멈춘다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 1),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.noSamples);
      expect(temp.listSync(recursive: true), isEmpty);
    });
  });

  group('MeasurementRecorder.record 저장', () {
    test('리포트를 맨 앞에 두고 결과 파일을 모두 남긴다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');
      expect(outcome.id, '20260114-110359');
      final names = outcome.savedPaths
          .map((p) => p.split('/').last)
          .toList(); // 저장한 파일 이름
      expect(names, <String>[
        MeasurementRepository.reportFileName,
        MeasurementRepository.rawFileName,
        MeasurementRepository.metaFileName,
      ]);
      for (final path in outcome.savedPaths) {
        expect(await File(path).exists(), isTrue, reason: path);
      }
      expect(
        await MeasurementRepository.instance.load('20260114-110359'),
        isNotNull,
        reason: '목록과 메일이 읽는 측정 결과도 저장돼야 한다',
      );
    });

    test('거치 방향과 그 중력 Z 평균을 결과 · 집계 파일에 남긴다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
        placement: const PlacementReading(Placement.faceUp, 997.25),
      ); // 저장 결과
      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');
      final saved = await MeasurementRepository.instance.load(outcome.id!);
      expect(saved!.placement, 'faceUp');
      expect(saved.placementGravityZMg, 997.25);
      final meta = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.metaFileName),
        ),
      ).readAsString(); // 집계 파일 내용
      expect(meta, contains('placement: faceUp'));
      expect(meta, contains('placementGravityZmg: 997.25'));
    });

    test('소음 마이크 표본 속도 · 시간가중을 처리 방식과 집계 파일에 남긴다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
        noiseSampleRateHz: 48000,
      ); // 저장 결과
      final saved = await MeasurementRepository.instance.load(outcome.id!);
      expect(
        saved!.signalConditioning,
        endsWith('+noise(A,slow,+105.2,48000Hz)'),
      );
      final meta = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.metaFileName),
        ),
      ).readAsString(); // 집계 파일 내용
      expect(meta, contains('noiseTimeWeighting: slow (1.0s)'));
      expect(meta, contains('noiseSampleRateHz: 48000'));
      expect(meta, contains('noiseOffsetDb: 105.2'));
    });

    test('판정 전에 끝난 측정은 거치를 비우고 집계에 unknown 으로 적는다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과
      final saved = await MeasurementRepository.instance.load(outcome.id!);
      expect(saved!.placement, isNull);
      final meta = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.metaFileName),
        ),
      ).readAsString(); // 집계 파일 내용
      expect(meta, contains('placement: unknown'));
    });

    test('안드로이드 원본이 없으면 그 사실을 집계 파일에 남긴다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      final meta = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.metaFileName),
        ),
      ).readAsString(); // 집계 파일 내용
      expect(meta, contains('rawRecordPath: null'));
    });

    test('안드로이드 원본이 있으면 측정 폴더로 복사해 맨 뒤에 둔다', () async {
      final native = File('${temp.path}/native_source.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');

      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: native.path,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(
        outcome.savedPaths.last,
        endsWith(MeasurementRepository.nativeRawFileName),
      );
      expect(
        await File(outcome.savedPaths.last).readAsString(),
        'accel 1 0 0 1000 3906\n',
        reason: '안드로이드 원본은 손대지 않는다',
      );
      // raw.txt 는 OTIS EVIMP1 관례대로 축별 전체 평균을 뺀 값이다
      final raw = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.rawFileName),
        ),
      ).readAsLines(); // 값 파일 줄
      final rows = <List<double>>[
        for (final line in raw.skip(2).where((l) => l.isNotEmpty))
          line.split(' ').map(double.parse).toList(),
      ]; // 값 행
      for (var axis = 0; axis < 3; axis++) {
        final mean =
            rows.map((r) => r[axis]).reduce((a, b) => a + b) / rows.length;
        expect(mean.abs(), lessThan(0.01), reason: '축 $axis');
      }
    });

    test('원본을 옮긴 뒤 안드로이드 쪽 원본은 지운다', () async {
      final native = File('${temp.path}/native_source.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');

      await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: native.path,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      );

      expect(await native.exists(), isFalse, reason: '측정마다 쌓이면 안 된다');
    });

    test('현장 소음 녹음을 측정 폴더의 noise.m4a 로 옮겨 맨 뒤에 두고 원래 것은 지운다', () async {
      final audio = File('${temp.path}/noise_native_1.m4a'); // 녹음 자리
      await audio.writeAsBytes(const <int>[0, 0, 0, 24]);

      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: audio.path,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(
        outcome.savedPaths.last,
        endsWith(MeasurementRepository.noiseAudioFileName),
      );
      expect(await File(outcome.savedPaths.last).readAsBytes(), <int>[
        0,
        0,
        0,
        24,
      ]);
      expect(await audio.exists(), isFalse, reason: '측정마다 쌓이면 안 된다');
    });

    test('현장 소음 녹음이 없으면 저장은 성공하고 집계 파일에 적는다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.isSuccess, isTrue);
      final meta = await File(
        outcome.savedPaths.firstWhere(
          (path) => path.endsWith(MeasurementRepository.metaFileName),
        ),
      ).readAsString(); // 집계 파일 내용
      expect(meta, contains('noiseAudioPath: null'));
    });

    test('원본 복사가 실패해도 저장은 성공하고 집계 파일에 적는다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: '${temp.path}/missing_native.txt',
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.isSuccess, isTrue);
      expect(
        outcome.savedPaths.last,
        endsWith(MeasurementRepository.metaFileName),
        reason: '원본 사본은 빠진다',
      );
      final meta = await File(outcome.savedPaths.last).readAsString(); // 집계
      expect(meta, contains('rawRecordCopyFailed'));
    });

    test('앞뒤 0.5초를 버려 너무 짧은 측정은 사유와 함께 실패한다', () async {
      // 이벤트 200개 × 3.906ms ≈ 0.78초 — 앞뒤 0.5초씩 버리면 남지 않는다
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 200),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.gridFailed);
      expect(outcome.detail, contains('너무 짧다'));
    });
  });

  group('MeasurementRecorder.record 지표 계산 전 신호 처리', () {
    /// 작성: 2026-10-07 02:10:57 · nada
    /// 함수: rawFileExists
    /// 목적: 이번 측정 폴더에 값 파일(`raw.txt`)이 남아 있는지 본다.
    /// 반환: 남아 있으면 true
    Future<bool> rawFileExists() async {
      final dir = await MeasurementRepository.instance.jobDirectory(
        '20260114-110359',
      ); // 이번 측정 폴더
      return File('${dir.path}/${MeasurementRepository.rawFileName}').exists();
    }

    /// 작성: 2026-10-07 02:10:57 · nada
    /// 함수: metaText
    /// 목적: 이번 측정 폴더의 집계 파일(`meta.txt`) 내용을 읽는다.
    /// 반환: 집계 파일 내용
    Future<String> metaText() async {
      final dir = await MeasurementRepository.instance.jobDirectory(
        '20260114-110359',
      ); // 이번 측정 폴더
      return File(
        '${dir.path}/${MeasurementRepository.metaFileName}',
      ).readAsString();
    }

    test('저장할 때 로그인 작업자를 싣고, 나중에 다른 사람이 로그인해도 그대로다', () async {
      LoginSession.instance.current = const Worker(
        employeeId: 'T00001',
        name: '홍길동',
        company: '(주)시험승강기',
        team: '설치1팀',
      );
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 1024),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과
      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');

      LoginSession.instance.current = const Worker(
        employeeId: 'T00002',
        name: '김철수',
      );
      final saved = await MeasurementRepository.instance.load(
        '20260114-110359',
      ); // 다른 사람이 로그인한 뒤 다시 읽은 측정 결과
      expect(saved?.engineerName, '홍길동');
      expect(saved?.employeeId, 'T00001');
      expect(saved?.company, '(주)시험승강기');
      expect(saved?.team, '설치1팀');
      LoginSession.instance.current = null;
    });

    test('로그인 작업자가 없으면 결과의 작업자 칸은 null 이다', () async {
      LoginSession.instance.current = null;
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 1024),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과
      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');

      final saved = await MeasurementRepository.instance.load(
        '20260114-110359',
      ); // 저장한 측정 결과
      expect(saved?.engineerName, isNull);
      expect(saved?.employeeId, isNull);
    });

    test('저장한 결과의 표본 속도는 100Hz 이고 집계 파일에 처리 · 가중 · 구간 내역을 남긴다', () async {
      // 이벤트 1024개 × 3.906ms ≈ 4초 — 앞뒤 0.5초를 버려도 기준선 1초가 남는다
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 1024),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');
      final saved = await MeasurementRepository.instance.load(
        '20260114-110359',
      ); // 저장한 측정 결과
      expect(saved?.sampleRate, 100.0);
      expect(
        saved?.signalConditioning,
        'baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)+zlp(20.0bw4zp)'
        '+motion(v>0.05,pad500ms)+jerk(lp1.6bw4zp)+acc(lp10.0bw4zp)'
        '+zones(v>0.05,pk0.5,a<0.03,min1000ms)+noise(A,slow,+105.2)',
      );

      final meta = await metaText(); // 집계 파일 내용
      expect(meta, contains('gridRateHz: 256'), reason: '처리 전 격자 집계');
      expect(
        meta,
        contains(
          'conditioning: baseline + lowpass 40Hz (butterworth 4, '
          'zero-phase) + resample 256->100Hz',
        ),
      );
      for (final key in [
        'baselineXmg',
        'baselineYmg',
        'baselineZmg',
        'baselineStdXmg',
        'baselineStdYmg',
        'baselineStdZmg',
      ]) {
        expect(meta, contains('$key: '), reason: key);
      }
      expect(meta, contains('conditionedRateHz: 100'));
      expect(meta, contains('kinematics: motion(v>0.05,pad500ms)'));
      // 이 시험 격자는 움직임이 없는 무작위 값이라 정지 측정으로 적힌다
      expect(meta, contains('motionWindow: none'));
      expect(meta, contains('conditionedRowCount: ${saved!.xSeries.length}'));
      expect(
        meta,
        contains('weighting: x/y Wd, z highpass 1.0Hz (butterworth 2'),
        reason: '가중 내역',
      );
      // 시험 이벤트는 승강기가 움직이지 않아 운행 구간을 정하지 못한다.
      // 그 사유가 집계와 결과에 남고 진동 지표는 비어 있어야 한다
      expect(meta, contains('travelWindowFailureReason: '));
      expect(saved.travelWindow, isNull);
      expect(saved.travelWindowFailure, isNotNull);
      expect(saved.zPtp, isNull);
      // 정속 구간도 같은 이유로 정하지 못하고 사유를 남긴다
      expect(meta, contains('zones: zones(v>0.05,pk0.5,a<0.03,min1000ms)'));
      expect(meta, contains('zonesFailureReason: '));
      expect(saved.motionZones, isNull);
      expect(saved.motionZonesFailure, isNotNull);
      expect(saved.zJptp, isNull);
    });

    test('처리 설정이 잘못되면 컨디셔닝 실패로 돌려주고 값 파일은 남긴다', () async {
      // 차단 50Hz 는 재표본 100Hz 의 절반이라 ArgumentError 가 난다
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(
          count: 1024,
          config: const CaptureConfig(lowpassCutoffHz: 50),
        ),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.conditioningFailed);
      expect(outcome.conditioningCause, ConditioningFailure.invalidConfig);
      expect(outcome.detail, contains('lowpassCutoffHz'));
      expect(await rawFileExists(), isTrue);
      expect(await metaText(), contains('conditioningFailureReason: '));
    });

    test('격자가 기준선 구간보다 짧으면 컨디셔닝 실패로 돌려주고 값 파일은 남긴다', () async {
      // 이벤트 512개 ≈ 2초 — 앞뒤 0.5초를 버리면 255행으로 256행에 모자란다
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 512),
        site: _site,
        nativeRecordPath: null,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.conditioningFailed);
      expect(outcome.conditioningCause, ConditioningFailure.gridTooShort);
      expect(outcome.detail, contains('255행'));
      expect(await rawFileExists(), isTrue);
      expect(await metaText(), contains('conditioningFailureReason: '));
    });

    test('측정이 실패해도 안드로이드 원본은 측정 폴더로 옮기고 원래 자리에서 지운다', () async {
      final native = File('${temp.path}/native_source.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');

      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 512),
        site: _site,
        nativeRecordPath: native.path,
        noiseAudioPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과 (기준선 구간 부족으로 실패)

      expect(outcome.failure, RecordFailure.conditioningFailed);
      expect(await native.exists(), isFalse, reason: '실패한 측정도 쌓이면 안 된다');
      final dir = await MeasurementRepository.instance.jobDirectory(
        '20260114-110359',
      ); // 이번 측정 폴더
      expect(
        await File(
          '${dir.path}/${MeasurementRepository.nativeRawFileName}',
        ).readAsString(),
        'accel 1 0 0 1000 3906\n',
      );
    });
  });
}
