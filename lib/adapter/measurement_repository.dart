import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-08-18 23:29:46 · 박건준
/// 클래스: MeasurementRepository
/// 목적: 완성된 측정 결과를 기기에 파일 형태로 저장하거나, 목록을
///       불러오고, 삭제하는 저장소 역할을 한다.
///
///       파일 배치
///         측정 한 건이 폴더 하나다. `captures/<측정 ID>/` 안에 그 측정의
///         산출물을 모아 둔다. 측정 ID 는 `yyyyMMdd-HHmmss` 형태라 폴더
///         이름만 봐도 언제 잰 것인지 알 수 있고, 한 건을 통째로 지우거나
///         옮기기도 쉽다.
///         - `result.json` — 측정 결과 전부. 시계열 여덟 개가 들어 있어
///           크다. `load()` 만 읽는다
///         - `summary.json` — 시계열을 뺀 나머지. 목록 화면이 읽는다
///         - `raw.txt` — 격자에 맞춘 측정값 (EVIMP1, X Y Z 소음)
///         - `report.pdf` — 만들어 둔 리포트. 없으면 그때 만든다
///         - `meta.txt` · `native_raw.txt` — 집계와 안드로이드 원본 사본
///
///       목록용 파일을 따로 두는 까닭
///         `result.json` 한 건이 시계열 때문에 1MB 를 넘는다. 목록 화면은
///         날짜와 판정만 있으면 되는데 그걸 보려고 전부 읽으면, 측정이
///         쌓일수록 화면 여는 데 시간이 걸린다. 그래서 목록이 읽을 몫만
///         `summary.json` 으로 따로 떼어 둔다. 두 파일은 `save()` 가 같이
///         쓰므로 어긋나지 않는다.
class MeasurementRepository {
  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: resultFileName
  /// 목적: 측정 결과 전부를 담는 파일 이름.
  static const String resultFileName = 'result.json';

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: summaryFileName
  /// 목적: 목록 화면이 읽는, 시계열을 뺀 파일 이름.
  static const String summaryFileName = 'summary.json';

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: reportFileName
  /// 목적: 만들어 둔 리포트 파일 이름.
  static const String reportFileName = 'report.pdf';

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: seriesKeys
  /// 목적: `summary.json` 에서 뺄 시계열 항목의 이름들. `toMap()` 이 쓰는
  ///       이름과 같아야 한다.
  static const List<String> seriesKeys = <String>[
    'xSeries',
    'ySeries',
    'zSeries',
    'noiseSeries',
    'positionSeries',
    'speedSeries',
    'accelSeries',
    'jerkSeries',
  ];

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 저장소 인스턴스.
  static final MeasurementRepository instance = MeasurementRepository._();

  /// 작성: 2026-07-04 15:52:54 · 박건준
  /// 함수: MeasurementRepository._
  /// 목적: 외부에서 직접 생성하지 못하게 막는 전용 생성자. `instance`
  ///       하나만 쓰도록 강제한다.
  MeasurementRepository._();

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 함수: getBaseDirectory
  /// 목적: 측정 산출물을 저장할 기준 폴더를 확보한다. 기기의 외장
  ///       저장소가 있으면 그 안에, 없으면 앱 전용 문서 폴더 안에
  ///       `captures` 폴더를 두고, 없으면 만든다.
  /// 반환: 생성이 보장된 `captures` 폴더
  Future<Directory> getBaseDirectory() async {
    final external = await getExternalStorageDirectory(); // 외장 저장소, 없으면 null
    final base =
        external ??
        await getApplicationDocumentsDirectory(); // 외장 없으면 앱 전용 문서 폴더
    final dir = Directory('${base.path}/captures'); // 실제 저장에 쓸 폴더
    await dir.create(recursive: true);
    return dir;
  }

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: jobDirectory
  /// 목적: 측정 한 건의 폴더를 확보한다. 어디에 무엇을 두는지 정하는 곳을
  ///       한 군데로 두어, 저장하는 쪽과 읽는 쪽이 어긋나지 않게 한다.
  /// 인자: id — 측정 결과 식별자
  /// 반환: 생성이 보장된 그 측정의 폴더
  Future<Directory> jobDirectory(String id) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final dir = Directory('${base.path}/$id'); // 이 측정의 폴더
    await dir.create(recursive: true);
    return dir;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: save
  /// 목적: 새롭게 계산된 측정 결과를 기기에 저장한다. 결과 전부를 담은
  ///       파일과, 목록이 읽을 요약 파일을 함께 쓴다. 같은 식별자로 다시
  ///       저장하면 덮어쓴다.
  /// 인자: result — 저장할 측정 결과
  /// 반환: 저장된 파일이 위치한 디렉터리
  Future<Directory> save(MeasurementResult result) async {
    // → 로직 이동: jobDirectory()
    final dir = await jobDirectory(result.id); // 이 측정의 폴더
    final map = result.toMap(); // 저장할 항목 표

    await File('${dir.path}/$resultFileName').writeAsString(jsonEncode(map));

    final summary = Map<String, dynamic>.from(map); // 시계열을 덜어낼 사본
    summary.removeWhere((key, _) => seriesKeys.contains(key));
    await File(
      '${dir.path}/$summaryFileName',
    ).writeAsString(jsonEncode(summary));
    return dir;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: list
  /// 목적: 기기에 저장되어 있는 모든 과거 측정 결과 목록을 불러온다.
  ///       요약 파일만 읽으므로 시계열은 비어 있다 — 목록 화면이 쓰는
  ///       날짜와 판정은 요약에 다 들어 있다. 최근 측정이 앞에 온다.
  ///
  ///       읽지 못한 폴더는 건너뛰고 기록만 남긴다. 한 건이 깨졌다고
  ///       목록 전체를 못 보게 되면 나머지 측정까지 손을 못 대게 된다.
  /// 반환: 저장된 측정 결과 목록. 최근 것부터
  Future<List<MeasurementResult>> list() async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final items = <MeasurementResult>[]; // 모아 갈 측정 결과

    await for (final entry in base.list()) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/$summaryFileName'); // 이 폴더의 요약 파일
      if (!await file.exists()) continue;
      try {
        // → 로직 이동: MeasurementResult.fromMap()
        items.add(
          MeasurementResult.fromMap(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (error, stack) {
        developer.log(
          '측정 요약을 읽지 못해 목록에서 건너뛴다: ${file.path}',
          name: 'MeasurementRepository',
          error: error,
          stackTrace: stack,
        );
      }
    }

    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return items;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: load
  /// 목적: 특정 ID의 측정 결과 파일 하나만 찾아서 읽어온다. 시계열까지
  ///       들어 있는 파일을 읽으므로 리포트를 그리는 데 쓸 수 있다.
  /// 인자: id — 조회할 측정 결과 식별자
  /// 반환: 조회된 측정 결과. 없으면 null
  Future<MeasurementResult?> load(String id) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final file = File('${base.path}/$id/$resultFileName'); // 그 측정의 결과 파일
    if (!await file.exists()) return null;

    // → 로직 이동: MeasurementResult.fromMap()
    return MeasurementResult.fromMap(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: delete
  /// 목적: 특정 ID의 측정 결과를 기기에서 완전히 삭제한다. 측정 한 건이
  ///       폴더 하나이므로 폴더째 지운다 — 리포트와 원본까지 함께 사라진다.
  /// 인자: id — 삭제할 측정 결과 식별자
  /// 반환: 삭제에 성공하면 true. 그런 측정이 없으면 false
  Future<bool> delete(String id) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final dir = Directory('${base.path}/$id'); // 지울 폴더
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: ensureReportPdf
  /// 목적: 측정 한 건의 리포트 PDF 를 가져온다. 이미 만들어 둔 것이 있으면
  ///       그대로 주고, 없으면 그 자리에서 만들어 남긴 뒤 준다. 측정을
  ///       마칠 때 한 번 만들어 두므로 보통은 있는 쪽이다.
  /// 인자: id — 측정 결과 식별자
  /// 반환: 만들어졌거나 이미 있던 PDF 파일. 그런 측정이 저장돼 있지
  ///       않으면 null — 만들 밑천이 없다는 뜻이다. 만들다 실패하면 null
  ///       로 감추지 않고 그 예외를 그대로 올린다
  Future<File?> ensureReportPdf(String id) async {
    // → 로직 이동: jobDirectory()
    final dir = await jobDirectory(id); // 이 측정의 폴더
    final file = File('${dir.path}/$reportFileName'); // 리포트 파일
    if (await file.exists()) return file;

    // → 로직 이동: load()
    final result = await load(id); // 저장돼 있던 측정 결과, 없으면 null
    if (result == null) return null;

    // → 로직 이동: writeTuneReport()
    return writeTuneReport(result: result, path: file.path);
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-26 09:30:00 · nada
  /// 함수: ensureRawExcelFiles
  /// 목적: 측정 결과에 딸린 엑셀 데이터 원본 파일을 가져온다.
  /// 인자: id — 측정 결과 식별자
  /// 반환: 엑셀 파일 목록. 지금은 항상 빈 목록
  /// 미구현: 엑셀을 쓰는 코드가 없다. 예외를 던지지 않고 빈 목록을
  ///       돌려주므로, 메일 시트(`send_email_sheet.dart`)의
  ///       `_buildJobEmail()` 은 첨부를 하나도 더하지 않고 그대로
  ///       넘어간다 — 메일은 정상으로 발송된다.
  ///       요구사항서 4-① 의 raw data 파일은 같은 폴더의 `raw.txt` 가
  ///       맡는다. 엑셀로도 내보내려면 표 작성 패키지를 새로 들여야 해서
  ///       이번 범위 밖으로 두었다.
  Future<List<File>> ensureRawExcelFiles(String id) async {
    return const <File>[];
  }
}
