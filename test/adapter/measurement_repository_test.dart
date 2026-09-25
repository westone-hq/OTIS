import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-26 09:30:00 · nada
/// 클래스: _TempPathProvider
/// 목적: 저장소가 쓰는 기준 폴더를 시험용 임시 폴더로 바꿔 끼운다. 실제
///       구현은 안드로이드 기기의 외장 저장소를 묻는데, 시험은 기기 없이
///       도므로 그 자리에 임시 폴더를 돌려준다.
class _TempPathProvider extends PathProviderPlatform {
  /// 기준 폴더로 쓸 임시 폴더 경로
  final String root;

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: _TempPathProvider
  /// 목적: 기준 폴더로 쓸 경로를 담는 생성자.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외장 저장소 자리에 임시 폴더를 돌려준다.
  /// 반환: 임시 폴더 경로
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리에 임시 폴더를 돌려준다.
  /// 반환: 임시 폴더 경로
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: _result
/// 목적: 저장했다 읽어 볼 측정 결과를 꾸민다. 시계열을 짧게 두어 파일
///       크기가 시험 시간을 잡아먹지 않게 한다.
/// 인자: id — 측정 식별자
///       measuredAt — 측정 시각
/// 반환: 저장에 넣을 측정 결과
MeasurementResult _result(String id, DateTime measuredAt) {
  return MeasurementResult(
    id: id,
    jobNo: '2025F 1234R01',
    siteName: '럭키종합건설/송정동근생',
    bottomFloor: 1,
    topFloor: 8,
    direction: '하부에서 상부로',
    dateTime: measuredAt,
    maxSpeed: 1.743390961,
    distance: 57.093948064,
    noiseMax: 65.6,
    xSeries: const <double>[1.0, 2.0, 3.0],
    ySeries: const <double>[4.0, 5.0, 6.0],
    zSeries: const <double>[7.0, 8.0, 9.0],
    noiseSeries: const <double>[45.0, 46.0, 47.0],
    positionSeries: const <double>[0.0, 1.0, 2.0],
    speedSeries: const <double>[0.0, 0.5, 1.0],
    accelSeries: const <double>[0.1, 0.2, 0.3],
    jerkSeries: const <double>[0.01, 0.02, 0.03],
  );
}

/// 작성: 2026-09-26 09:30:00 · nada
/// 함수: main
/// 목적: 저장소를 시험한다. 측정 한 건이 폴더 하나로 저장되는지, 목록이
///       요약만 읽는지, 지울 때 폴더째 사라지는지를 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp; // 이번 시험이 쓸 임시 폴더
  final repo = MeasurementRepository.instance; // 시험할 저장소

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_repo_test');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('MeasurementRepository 저장과 조회', () {
    test('측정 한 건이 폴더 하나로 저장된다', () async {
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59)),
      ); // 저장된 폴더

      expect(dir.path.endsWith('20260114-110359'), isTrue);
      expect(
        await File(
          '${dir.path}/${MeasurementRepository.resultFileName}',
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          '${dir.path}/${MeasurementRepository.summaryFileName}',
        ).exists(),
        isTrue,
      );
    });

    test('요약 파일에는 시계열이 없다', () async {
      // 목록 화면이 읽는 파일이라, 시계열이 들어가면 측정이 쌓일수록
      // 화면 여는 데 시간이 걸린다
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59)),
      ); // 저장된 폴더
      final summary =
          jsonDecode(
                await File(
                  '${dir.path}/${MeasurementRepository.summaryFileName}',
                ).readAsString(),
              )
              as Map<String, dynamic>; // 요약 파일 내용

      for (final key in MeasurementRepository.seriesKeys) {
        expect(summary.containsKey(key), isFalse, reason: key);
      }
      expect(summary['noiseMax'], 65.6, reason: '판정에 쓰는 값은 남아 있어야 한다');
    });

    test('저장한 것을 시계열까지 그대로 읽는다', () async {
      final saved = _result(
        '20260114-110359',
        DateTime(2026, 1, 14, 11, 3, 59),
      ); // 저장할 측정 결과
      await repo.save(saved);

      final loaded = await repo.load(saved.id); // 다시 읽은 측정 결과

      expect(loaded, isNotNull);
      expect(loaded!.jobNo, saved.jobNo);
      expect(loaded.zSeries, saved.zSeries);
      expect(loaded.noiseMax, saved.noiseMax);
      expect(loaded.dateTime, saved.dateTime);
    });

    test('없는 것을 읽으면 예외 대신 null 이다', () async {
      expect(await repo.load('없는측정'), isNull);
    });

    test('목록은 최근 것부터 나온다', () async {
      await repo.save(_result('20260114-110359', DateTime(2026, 1, 14)));
      await repo.save(_result('20260301-090000', DateTime(2026, 3, 1)));
      await repo.save(_result('20260210-090000', DateTime(2026, 2, 10)));

      final items = await repo.list(); // 저장된 목록

      expect(items.map((e) => e.id).toList(), <String>[
        '20260301-090000',
        '20260210-090000',
        '20260114-110359',
      ]);
    });

    test('목록은 요약만 읽으므로 시계열이 비어 있다', () async {
      await repo.save(_result('20260114-110359', DateTime(2026, 1, 14)));

      final items = await repo.list(); // 저장된 목록

      expect(items.single.zSeries, isEmpty);
      expect(items.single.noiseMax, 65.6, reason: '판정에 쓰는 값은 있어야 한다');
    });

    test('요약이 없으면 정본에서 다시 만들어 목록에 올린다', () async {
      // 저장 도중 앱이 죽어 정본만 남은 경우다. 목록에서 빠뜨리면 있는
      // 기록을 없는 것처럼 보여 주게 된다
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14)),
      ); // 저장된 폴더
      final cache = File(
        '${dir.path}/${MeasurementRepository.summaryFileName}',
      ); // 목록용 캐시
      await cache.delete();

      final items = await repo.list(); // 저장된 목록

      expect(items.single.id, '20260114-110359');
      expect(items.single.noiseMax, 65.6);
      expect(await cache.exists(), isTrue, reason: '캐시를 고쳐 써 둬야 한다');
      expect(items.single.zSeries, isEmpty, reason: '목록은 시계열을 싣지 않는다');
    });

    test('요약이 깨져 있어도 정본에서 다시 만든다', () async {
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14)),
      ); // 저장된 폴더
      final cache = File(
        '${dir.path}/${MeasurementRepository.summaryFileName}',
      ); // 목록용 캐시
      await cache.writeAsString('이건 json 이 아니다');

      final items = await repo.list(); // 저장된 목록

      expect(items.single.id, '20260114-110359');
      expect(
        jsonDecode(await cache.readAsString()),
        isA<Map<String, dynamic>>(),
        reason: '깨진 캐시를 성한 것으로 덮어써야 한다',
      );
    });

    test('정본까지 없으면 그 폴더만 건너뛴다', () async {
      // 한 건이 깨졌다고 목록 전체를 못 보게 되면 나머지 측정까지 손을
      // 못 대게 된다
      await repo.save(_result('20260114-110359', DateTime(2026, 1, 14)));
      final broken = Directory('${temp.path}/captures/망가진측정'); // 깨진 폴더
      await broken.create(recursive: true);
      await File(
        '${broken.path}/${MeasurementRepository.summaryFileName}',
      ).writeAsString('이건 json 이 아니다');
      await File(
        '${broken.path}/${MeasurementRepository.resultFileName}',
      ).writeAsString('정본도 깨졌다');

      final items = await repo.list(); // 저장된 목록

      expect(items.length, 1);
      expect(items.single.id, '20260114-110359');
    });
  });

  group('MeasurementRepository 삭제', () {
    test('폴더째 지운다', () async {
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14)),
      ); // 저장된 폴더

      expect(await repo.delete('20260114-110359'), isTrue);
      expect(await dir.exists(), isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('없는 것을 지우면 예외 대신 false 다', () async {
      expect(await repo.delete('없는측정'), isFalse);
    });
  });

  group('MeasurementRepository 리포트', () {
    test('저장된 것이 없으면 만들지 않고 null 이다', () async {
      expect(await repo.ensureReportPdf('없는측정'), isNull);
    });

    test('없으면 그 자리에서 만들어 폴더에 남긴다', () async {
      // 측정을 마칠 때 만들어 두므로 보통은 이 갈래로 오지 않지만, 그때
      // 실패했거나 옛 측정이면 여기서 만든다
      await repo.save(_result('20260114-110359', DateTime(2026, 1, 14)));

      final made = await repo.ensureReportPdf('20260114-110359'); // 만든 리포트

      expect(made, isNotNull);
      final bytes = await made!.readAsBytes(); // 만든 PDF 내용
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        made.path.endsWith(MeasurementRepository.reportFileName),
        isTrue,
        reason: '측정 폴더 안에 남아야 다음에 다시 만들지 않는다',
      );
      expect(await repo.ensureReportPdf('20260114-110359'), isNotNull);
    });

    test('이미 있으면 다시 만들지 않고 그대로 준다', () async {
      final dir = await repo.save(
        _result('20260114-110359', DateTime(2026, 1, 14)),
      ); // 저장된 폴더
      final made = File(
        '${dir.path}/${MeasurementRepository.reportFileName}',
      ); // 미리 놓아 둘 리포트 자리
      await made.writeAsString('이미 만들어 둔 리포트');

      final got = await repo.ensureReportPdf('20260114-110359'); // 받아 온 리포트

      expect(got, isNotNull);
      expect(await got!.readAsString(), '이미 만들어 둔 리포트');
    });
  });

  group('MeasurementRepository 엑셀', () {
    test('아직 만들지 않으므로 빈 목록이다', () async {
      // 예외를 던지면 메일 발송이 통째로 막힌다. 빈 목록이라야 첨부만
      // 빠지고 메일은 나간다
      expect(await repo.ensureRawExcelFiles('20260114-110359'), isEmpty);
    });
  });
}
