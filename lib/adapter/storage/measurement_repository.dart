import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: UnreadableMeasurement
/// 목적: 결과 파일은 있는데 읽지 못한 측정 한 건. 저장 결과 목록이 이 건만
///       "읽을 수 없는 결과" 로 보여 주고 나머지는 그대로 보여 준다 — 한
///       건이 깨졌다고 목록에서 조용히 사라지면 지울 수도 없다.
class UnreadableMeasurement {
  /// 측정 ID (폴더 이름)
  final String id;

  /// 읽지 못한 사유 (예외 문구). 기록 · 진단용이다
  final String reason;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: UnreadableMeasurement
  /// 목적: 값을 담는다.
  /// 인자: id, reason — 위 필드
  const UnreadableMeasurement(this.id, this.reason);
}

/// 작성: 2026-08-18 23:29:46 · 박건준
/// 수정: 2026-10-05 10:03:35 · nada
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
///         - `raw.txt` — 격자에 맞춘 측정값. EVIMP1(회사 EVA 진동측정
///           장비가 쓰는 데이터 형식)로 X Y Z 소음 네 열
///         - `report.pdf` — 만들어 둔 리포트. 없으면 그때 만든다
///         - `meta.txt` · `native_raw.txt` — 집계와 안드로이드 원본 사본
///
///       어디에 무엇을 두는지는 이 클래스만 안다. 폴더는 `jobDirectory()`
///       가, 파일 이름은 위 상수들이 정한다. 쓰는 쪽이 경로를 짜 맞추면
///       배치가 바뀔 때 그쪽이 조용히 어긋난다.
///
///       목록용 파일을 따로 두는 까닭
///         `result.json` 한 건이 시계열 때문에 1MB 를 넘는다. 목록 화면은
///         날짜와 판정만 있으면 되는데 그걸 보려고 전부 읽으면, 측정이
///         쌓일수록 화면 여는 데 시간이 걸린다. 그래서 목록이 읽을 몫만
///         `summary.json` 으로 따로 떼어 둔다.
///
///       두 파일의 관계
///         `result.json` 이 정본이고 `summary.json` 은 거기서 시계열만
///         덜어낸 파생 캐시다. 둘이 어긋나면 언제나 정본이 옳다. 저장
///         도중에 앱이 죽어 한쪽만 남는 일이 있으므로, 목록을 읽을 때
///         캐시가 없거나 깨져 있으면 정본에서 다시 만들어 둔다 — 그
///         측정을 목록에서 조용히 빠뜨리면 있는 기록을 없는 것처럼
///         보여 주게 된다.
class MeasurementRepository {
  /// 작성: 2026-10-15 22:22:45 · nada
  /// 변수: maxStoredMeasurements
  /// 목적: 기기에 남겨 두는 측정 결과 수. 새 측정을 저장한 뒤 이보다
  ///       많으면 오래된 것부터 지운다(`pruneOldest()`).
  /// 근거: 인용 — 2026-10-15 사용자 지시 "30개 쌓이면 지우는걸로"
  static const int maxStoredMeasurements = 30;

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

  /// 작성: 2026-09-27 11:00:00 · nada
  /// 변수: rawFileName
  /// 목적: 격자에 맞춘 측정값 파일 이름 (EVIMP1, X Y Z 소음 네 열).
  static const String rawFileName = 'raw.txt';

  /// 작성: 2026-09-27 11:00:00 · nada
  /// 변수: metaFileName
  /// 목적: 격자 환산 집계 파일 이름. 사람이 읽어 보는 진단용이다.
  static const String metaFileName = 'meta.txt';

  /// 작성: 2026-09-27 11:00:00 · nada
  /// 변수: nativeRawFileName
  /// 목적: 안드로이드가 따로 남긴 원본 기록을 이 폴더로 옮겨 온 사본의
  ///       이름.
  static const String nativeRawFileName = 'native_raw.txt';

  /// 작성: 2026-10-18 10:12:30 · nada
  /// 변수: noiseAudioFileName
  /// 목적: 측정 중 마이크로 녹음한 현장 소음(AAC, M4A 틀) 파일 이름.
  ///       안드로이드(`NoiseAudioEncoder`)가 남긴 것을 저장 절차가 이 폴더로
  ///       옮겨 온다. 메일에 "현장 소음" 으로 붙는다.
  static const String noiseAudioFileName = 'noise.m4a';

  /// 작성: 2026-09-27 11:00:00 · nada
  /// 변수: jobFileNames
  /// 목적: 측정 폴더에 놓이는 파일 이름을 모두 모아 둔 것. 낱개 상수와
  ///       같은 값이며, 폴더에 무엇이 들어가는지 한눈에 보거나 전부
  ///       훑어야 할 때 쓴다.
  static const List<String> jobFileNames = <String>[
    resultFileName,
    summaryFileName,
    reportFileName,
    rawFileName,
    metaFileName,
    nativeRawFileName,
    noiseAudioFileName,
  ];

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

  /// 저장 · 삭제 · 정리로 측정 폴더가 바뀔 때마다 1씩 오르는 번호. 저장 결과
  /// 목록이 듣고 다시 읽는다. 목록이 연 결과 화면이 "테스트 재실행" 으로 측정
  /// 화면과 바뀌어 끼워지면(`pushReplacement`) 목록 쪽 `push` 가 새 결과를
  /// 저장하기 전에 끝나, 돌아와도 다시 읽을 때가 없었다(2026-10-22 에뮬레이터
  /// 확인).
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-09-27 09:30:00 · nada
  /// 함수: getBaseDirectory
  /// 목적: 측정 산출물을 저장할 기준 폴더를 확보한다. 기기의 외장
  ///       저장소가 있으면 그 안에, 없으면 앱 전용 문서 폴더 안에
  ///       `captures` 폴더를 두고, 없으면 만든다.
  /// 반환: 생성이 보장된 `captures` 폴더
  /// 미구현: 안드로이드에서만 돈다. `getExternalStorageDirectory()` 가
  ///       안드로이드가 아닌 곳에서는 null 을 돌려주지 않고
  ///       `UnsupportedError` 를 던져서, 뒤의 앱 문서 폴더로 넘어가지
  ///       못하고 이 함수 첫 줄에서 끊긴다. 저장 · 목록 · 리포트가 모두
  ///       이 폴더를 거치므로 그 계층 전체가 함께 멈춘다. 요구사항서
  ///       2쪽이 iOS 확장 가능성을 적어 두었으므로, 그때는 플랫폼을 보고
  ///       외장 저장소를 건너뛰도록 고쳐야 한다
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
  /// 수정: 2026-10-22 12:20:00 · nada
  /// 함수: save
  /// 목적: 새롭게 계산된 측정 결과를 기기에 저장한다. 결과 전부를 담은
  ///       파일과, 목록이 읽을 요약 파일을 함께 쓴다. 같은 식별자로 다시
  ///       저장하면 덮어쓴다. 다 쓰면 `changes` 를 올린다.
  /// 인자: result — 저장할 측정 결과
  /// 반환: 저장된 파일이 위치한 디렉터리
  Future<Directory> save(MeasurementResult result) async {
    // → 로직 이동: jobDirectory()
    final dir = await jobDirectory(result.id); // 이 측정의 폴더
    final map = result.toMap(); // 저장할 항목 표

    await File('${dir.path}/$resultFileName').writeAsString(jsonEncode(map));
    // → 로직 이동: _writeSummary()
    await _writeSummary(dir, map);
    changes.value++;
    return dir;
  }

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 함수: _writeSummary
  /// 목적: 정본에서 시계열만 덜어내 목록용 캐시를 쓴다. 저장할 때와 캐시를
  ///       고쳐 쓸 때가 같은 코드를 타야 두 자리의 결과가 갈라지지 않는다.
  /// 인자: dir — 그 측정의 폴더
  ///       full — 정본에 담은 항목 표
  /// 반환: 시계열을 덜어낸 항목 표. 방금 쓴 캐시와 같은 내용이다
  Future<Map<String, dynamic>> _writeSummary(
    Directory dir,
    Map<String, dynamic> full,
  ) async {
    final summary = Map<String, dynamic>.from(full); // 시계열을 덜어낼 사본
    summary.removeWhere((key, _) => seriesKeys.contains(key));
    await File(
      '${dir.path}/$summaryFileName',
    ).writeAsString(jsonEncode(summary));
    return summary;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 함수: list
  /// 목적: 기기에 저장되어 있는 읽을 수 있는 측정 결과 목록을 불러온다.
  ///       결과 화면의 비교 대상 고르기가 쓴다. 읽지 못한 건까지 보여야 하는
  ///       목록 화면은 `listEntries()` 를 쓴다.
  /// 반환: 저장된 측정 결과 목록. 최근 것부터
  Future<List<MeasurementResult>> list() async =>
      // → 로직 이동: listEntries()
      (await listEntries()).results;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: listEntries
  /// 목적: 기기에 저장되어 있는 모든 과거 측정 결과 목록을 불러온다.
  ///       요약 파일만 읽으므로 시계열은 비어 있다 — 목록 화면이 쓰는
  ///       날짜와 판정은 요약에 다 들어 있다. 최근 측정이 앞에 온다.
  ///       폴더마다 이렇게 읽는다.
  ///       1. 요약 파일이 멀쩡하면 그것을 읽는다
  ///       2. 없거나 깨졌으면 정본에서 다시 읽고, 요약을 고쳐 쓴다.
  ///          다음부터는 1 로 끝난다
  ///       3. 정본마저 못 읽으면(측정 일시가 깨진 결과 등) 그 폴더를 읽지
  ///          못한 건으로 따로 모으고 기록을 남긴다. 한 건이 깨졌다고 목록
  ///          전체를 못 보게 되면 나머지 측정까지 손을 못 대게 된다
  ///       결과 파일이 아예 없는 폴더(신호 처리 전에 멈춘 측정)는 결과가
  ///       아니라 건너뛴다.
  /// 반환: (읽은 결과 — 최근 것부터, 읽지 못한 건 — ID 차례)
  Future<
    ({List<MeasurementResult> results, List<UnreadableMeasurement> unreadable})
  >
  listEntries() async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final items = <MeasurementResult>[]; // 모아 갈 측정 결과
    final broken = <UnreadableMeasurement>[]; // 읽지 못한 건

    await for (final entry in base.list()) {
      if (entry is! Directory) continue;
      // → 로직 이동: _readListEntry()
      final read = await _readListEntry(entry); // 이 폴더를 읽은 결과
      final item = read.result; // 읽은 측정 결과, 없으면 null
      final reason = read.unreadableReason; // 읽지 못한 사유, 없으면 null
      if (item != null) items.add(item);
      if (reason != null) {
        broken.add(
          UnreadableMeasurement(
            entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
            reason,
          ),
        );
      }
    }

    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    broken.sort((a, b) => a.id.compareTo(b.id));
    return (results: items, unreadable: broken);
  }

  /// 작성: 2026-09-26 14:10:00 · nada
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 함수: _readListEntry
  /// 목적: 폴더 하나에서 목록에 올릴 측정 결과를 읽는다. 요약 캐시를 먼저
  ///       보고, 없거나 깨졌으면 정본에서 다시 만든다.
  /// 인자: dir — 측정 한 건의 폴더
  /// 반환: (읽어 낸 측정 결과, 읽지 못한 사유). 정본이 없으면 둘 다 null,
  ///       정본을 못 읽으면 결과는 null 이고 사유가 있다
  Future<({MeasurementResult? result, String? unreadableReason})>
  _readListEntry(Directory dir) async {
    final summary = File('${dir.path}/$summaryFileName'); // 이 폴더의 요약 캐시
    if (await summary.exists()) {
      try {
        return (
          // → 로직 이동: MeasurementResult.fromMap()
          result: MeasurementResult.fromMap(
            jsonDecode(await summary.readAsString()) as Map<String, dynamic>,
          ),
          unreadableReason: null,
        );
      } catch (error) {
        developer.log(
          '요약 캐시가 깨져 정본에서 다시 만든다: ${summary.path}',
          name: 'MeasurementRepository',
          error: error,
        );
      }
    }

    final result = File('${dir.path}/$resultFileName'); // 이 폴더의 정본
    if (!await result.exists()) return (result: null, unreadableReason: null);
    try {
      final map =
          jsonDecode(await result.readAsString())
              as Map<String, dynamic>; // 정본에 담긴 항목 표
      // 고쳐 쓴 캐시와 같은 내용으로 돌려준다. 정본을 그대로 넘기면 이
      // 폴더만 시계열이 실려 나가, 목록이 폴더마다 다른 모양이 된다
      // → 로직 이동: _writeSummary()
      final summary = await _writeSummary(dir, map); // 시계열을 덜어낸 항목 표
      // → 로직 이동: MeasurementResult.fromMap()
      return (
        result: MeasurementResult.fromMap(summary),
        unreadableReason: null,
      );
    } catch (error, stack) {
      developer.log(
        '측정을 읽지 못해 읽을 수 없는 결과로 둔다: ${result.path}',
        name: 'MeasurementRepository',
        error: error,
        stackTrace: stack,
      );
      return (result: null, unreadableReason: '$error');
    }
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

  /// 작성: 2026-10-15 22:22:45 · nada
  /// 수정: 2026-10-22 12:20:00 · nada
  /// 함수: pruneOldest
  /// 목적: 측정 결과가 `maxStoredMeasurements` 개를 넘으면 오래된 것부터
  ///       폴더째 지운다. 폴더 이름(측정 ID, `yyyyMMdd-HHmmss` 한국 시간)을
  ///       최근 것부터 훑어 결과 파일이 있는 폴더를 센다. 다 찬 뒤에
  ///       나오는 폴더는 결과가 있든 없든(저장하다 멈춘 측정) 지운다.
  ///       다 차기 전에 나온 결과 없는 폴더는 세지 않고 남긴다.
  ///       방금 저장한 측정(`keepId`)은 기기 시계가 거꾸로 가 이름이 더
  ///       오래돼 보여도 지우지 않는다.
  /// 인자: keepId — 방금 저장해 지우면 안 되는 측정 ID
  /// 반환: 지운 측정 ID (오래된 것이 뒤)
  Future<List<String>> pruneOldest({required String keepId}) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final dirs = <Directory>[]; // 측정 폴더들
    await for (final entry in base.list()) {
      if (entry is Directory) dirs.add(entry);
    }
    String nameOf(Directory dir) =>
        dir.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);
    dirs.sort((a, b) => nameOf(b).compareTo(nameOf(a)));

    // 방금 저장한 측정은 자리를 먼저 차지한다
    var kept = dirs.any((dir) => nameOf(dir) == keepId) ? 1 : 0; // 남긴 결과 수
    final deleted = <String>[]; // 지운 측정 ID
    for (final dir in dirs) {
      final id = nameOf(dir); // 이 폴더의 측정 ID
      if (id == keepId) continue;
      final hasResult = await File(
        '${dir.path}/$resultFileName',
      ).exists(); // 결과 파일이 있는지
      if (kept < maxStoredMeasurements) {
        if (hasResult) kept++;
        continue;
      }
      await dir.delete(recursive: true);
      deleted.add(id);
    }
    if (deleted.isNotEmpty) changes.value++;
    return deleted;
  }

  /// 작성: 2026-08-18 23:29:46 · 박건준
  /// 수정: 2026-10-22 12:20:00 · nada
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
    changes.value++;
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

  /// 작성: 2026-10-08 21:39:21 · nada
  /// 함수: rawFile
  /// 목적: 측정 한 건의 `raw.txt` 를 찾는다. 리포트와 달리 나중에 다시
  ///       만들 수 없는 기록이라, 없으면 없다고만 알린다. `jobDirectory()`
  ///       를 거치지 않는다 — 그 함수는 폴더가 없으면 만들어서, 찾기만
  ///       하는 데 빈 측정 폴더가 기기에 남는다.
  /// 인자: id — 측정 결과 식별자
  /// 반환: 그 측정의 `raw.txt`. 예전 측정이거나 저장 도중 실패해 파일이
  ///       없으면 null
  Future<File?> rawFile(String id) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final file = File('${base.path}/$id/$rawFileName'); // 그 측정의 raw.txt
    return await file.exists() ? file : null;
  }

  /// 작성: 2026-10-18 10:12:30 · nada
  /// 함수: noiseAudioFile
  /// 목적: 측정 한 건의 현장 소음 녹음(`noise.m4a`)을 찾는다. `rawFile()`
  ///       과 같이 폴더를 만들지 않고 찾기만 한다.
  /// 인자: id — 측정 결과 식별자
  /// 반환: 그 측정의 `noise.m4a`. 녹음 기능 전 측정이거나, 마이크 권한이
  ///       없었거나, 녹음이 실패해 파일이 없으면 null
  Future<File?> noiseAudioFile(String id) async {
    // → 로직 이동: getBaseDirectory()
    final base = await getBaseDirectory(); // 산출물 기준 폴더
    final file = File('${base.path}/$id/$noiseAudioFileName'); // 그 측정의 녹음
    return await file.exists() ? file : null;
  }

  /// 작성: 2026-10-05 10:03:35 · nada
  /// 함수: mailAttachmentName
  /// 목적: 메일에 붙일 파일 이름을 정한다. 측정 폴더 안 이름(`report.pdf`
  ///       등)은 모든 측정이 같아, 받는 쪽에서 여러 현장 메일을 모아 두면
  ///       구분할 수 없다. 제번 속 파일 이름에 쓸 수 없는 글자는 `_` 로
  ///       바꾼다.
  /// 인자: result — 첨부할 측정 결과
  ///       prefix — 자료 종류 머리말 (`TUNE`, `RAW`)
  ///       extension — 확장자 (점 없이)
  /// 반환: "머리말_제번_측정ID.확장자" 꼴 이름
  static String mailAttachmentName(
    MeasurementResult result,
    String prefix,
    String extension,
  ) {
    final safeJobNo = result.jobNo.trim().replaceAll(
      RegExp(r'[^0-9A-Za-z가-힣_-]+'),
      '_',
    ); // 파일 이름에 쓸 수 있게 다듬은 제번
    return '${prefix}_${safeJobNo}_${result.id}.$extension';
  }

  /// 작성: 2026-10-05 10:03:35 · nada
  /// 수정: 2026-10-11 17:10:57 · nada
  /// 함수: mailAttachmentCopy
  /// 목적: 측정 폴더의 파일을 메일용 이름으로 앱 임시 폴더(`mail/`)에
  ///       복사한다. 측정 폴더 안 이름은 리포트 생성 · 목록 읽기가 기대하는
  ///       이름이라 바꾸지 않는다. 같은 이름이 있으면 덮어쓴다.
  ///       메일 앱에 넘기는 FileProvider 는 이 폴더 하나만 연다
  ///       (`android/app/src/main/res/xml/shared_file_paths.xml` 의
  ///       `cache-path mail/`). 폴더 이름 `mail` 을 바꾸면 그 파일도 같이
  ///       바꿔야 한다 — 어긋나면 첨부가 "Failed to find configured root"
  ///       로 실패한다.
  /// 인자: source — 복사할 원래 파일
  ///       name — 붙일 이름 (`mailAttachmentName()` 이 만든 것)
  /// 반환: 메일에 붙일 사본
  Future<File> mailAttachmentCopy(File source, String name) async {
    final temp = await getTemporaryDirectory(); // 앱 임시 폴더
    final dir = Directory('${temp.path}/mail'); // 메일 첨부 사본 폴더
    await dir.create(recursive: true);
    return source.copy('${dir.path}/$name');
  }
}
