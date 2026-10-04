import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/measurement_recorder.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

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
/// 변수: _site
/// 목적: 검사를 통과하는 현장 정보.
const _site = SiteInfo(
  jobNo: '2025F 1234R01',
  siteName: '럭키종합건설/송정동근생',
  bottomFloor: '1',
  topFloor: '8',
  direction: SiteInfo.directionUp,
  model: SiteInfo.defaultModel,
);

/// 작성: 2026-10-04 13:36:00 · nada
/// 함수: _filledResampler
/// 목적: 가속도 · 중력 이벤트를 2초 동안 256Hz 로 채운 환산기를 만든다.
///       가속도에는 1Hz 사인 진동을 얹어 격자 값이 0 으로만 차지 않게 한다.
/// 인자: count — 센서마다 넣을 이벤트 수
/// 반환: 이벤트가 쌓인 환산기
GridResampler _filledResampler({int count = 512}) {
  final resampler = GridResampler(config: const CaptureConfig()); // 채울 환산기
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
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.siteMissing);
      expect(temp.listSync(recursive: true), isEmpty);
    });

    test('층수가 오름차순이 아니면 현장 정보 오류다', () async {
      const reversed = SiteInfo(
        jobNo: '2025F 1234R01',
        siteName: '현장',
        bottomFloor: '8',
        topFloor: '1',
        direction: SiteInfo.directionUp,
        model: SiteInfo.defaultModel,
      ); // 최하층과 최상층을 거꾸로 넣은 현장 정보
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: reversed,
        nativeRecordPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.failure, RecordFailure.siteMissing);
    });

    test('표본이 2개 미만이면 파일을 만들기 전에 멈춘다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(count: 1),
        site: _site,
        nativeRecordPath: null,
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
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(outcome.isSuccess, isTrue, reason: '${outcome.detail}');
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

    test('안드로이드 원본이 없으면 그 사실을 집계 파일에 남긴다', () async {
      final outcome = await MeasurementRecorder.record(
        resampler: _filledResampler(),
        site: _site,
        nativeRecordPath: null,
        measuredAt: measuredAt,
      ); // 저장 결과

      final meta = await File(
        '${outcome.directoryPath}/${MeasurementRepository.metaFileName}',
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
        measuredAt: measuredAt,
      ); // 저장 결과

      expect(
        outcome.savedPaths.last,
        endsWith(MeasurementRepository.nativeRawFileName),
      );
      expect(
        await File(outcome.savedPaths.last).readAsString(),
        'accel 1 0 0 1000 3906\n',
      );
    });
  });
}
