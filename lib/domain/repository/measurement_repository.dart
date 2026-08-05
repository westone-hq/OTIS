import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../measure/native_readable_export.dart';
import '../measure/raw_excel_export.dart';
import '../models/measurement_result.dart';
import '../parse_raw.dart';
import '../report_generator.dart';

/// P13 · 측정 결과 파일 저장소 Repository (Phase 4-A)
/// - `raw.txt` : ≈3~7ms 원본을 256Hz로 보간한 분석용
/// - `raw_3to7ms_초별.txt` : FASTEST(≈3~7ms) 원본을 초별로 보기 쉽게
/// - `raw_1to3ms_초별.txt` : 3000us(1~3ms) 원본을 초별로 보기 쉽게
/// - `meta.json` / `report.pdf`
class MeasurementRepository {
  static final MeasurementRepository instance = MeasurementRepository._();
  MeasurementRepository._();

  /// 유닛 테스트 및 사용자 정의 설정을 위한 디렉토리 경로 오버라이드
  String? overrideBaseDir;

  /// 기본 저장 디렉토리 (`getApplicationDocumentsDirectory()/measurements`)
  Future<Directory> getBaseDirectory() async {
    if (overrideBaseDir != null) {
      final dir = Directory(overrideBaseDir!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/measurements');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 측정 결과를 저장하고 생성된 디렉토리 인스턴스를 반환
  Future<Directory> save(
    MeasurementResult result, {
    Map<String, String>? nativeRawPaths,
    @Deprecated('Use nativeRawPaths') String? nativeRawPath,
  }) async {
    final paths = <String, String>{
      ...?nativeRawPaths,
      if (nativeRawPath != null && nativeRawPath.isNotEmpty)
        'native1to3': nativeRawPath,
    };
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/${result.id}');
    if (overrideBaseDir != null) {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final metaFile = File('${targetDir.path}/meta.json');
      metaFile.writeAsStringSync(result.toJson(), flush: true);

      _writeRawFilesSync(targetDir, result, nativeRawPaths: paths);

      final pdfFile = File('${targetDir.path}/report.pdf');
      final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
      pdfFile.writeAsBytesSync(pdfBytes, flush: true);

      return targetDir;
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final metaFile = File('${targetDir.path}/meta.json');
    await metaFile.writeAsString(result.toJson(), flush: true);

    await _writeRawFiles(targetDir, result, nativeRawPaths: paths);

    final pdfFile = File('${targetDir.path}/report.pdf');
    final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);

    return targetDir;
  }

  void _writeRawFilesSync(
    Directory targetDir,
    MeasurementResult result, {
    Map<String, String> nativeRawPaths = const {},
  }) {
    final rawSamples = result.rawSamples ?? [];
    File('${targetDir.path}/raw.txt').writeAsStringSync(
      RawDataParser.writeEvimp1(
        rawSamples,
        sampleRate: result.sampleRate.round(),
      ),
      flush: true,
    );
    _writeReadableNativeSync(targetDir, nativeRawPaths);
    _removeLegacyRawSidecarsSync(targetDir);
    // 분석용 256Hz 초별 엑셀만 유지 (128/64는 생략 — 메일/저장 부담 감소)
    final excelName = rawBySecondExcelFileName(
      rawSamples,
      sampleRateHz: result.sampleRate,
      exportRateHz: 256,
    );
    File('${targetDir.path}/$excelName').writeAsBytesSync(
      buildRawBySecondExcelBytes(
        rawSamples,
        sampleRateHz: result.sampleRate,
        exportRateHz: 256,
      ),
      flush: true,
    );
  }

  Future<void> _writeRawFiles(
    Directory targetDir,
    MeasurementResult result, {
    Map<String, String> nativeRawPaths = const {},
  }) async {
    final rawSamples = result.rawSamples ?? [];
    await File('${targetDir.path}/raw.txt').writeAsString(
      RawDataParser.writeEvimp1(
        rawSamples,
        sampleRate: result.sampleRate.round(),
      ),
      flush: true,
    );
    await _writeReadableNative(targetDir, nativeRawPaths);
    await _removeLegacyRawSidecars(targetDir);
    final excelName = rawBySecondExcelFileName(
      rawSamples,
      sampleRateHz: result.sampleRate,
      exportRateHz: 256,
    );
    await File('${targetDir.path}/$excelName').writeAsBytes(
      buildRawBySecondExcelBytes(
        rawSamples,
        sampleRateHz: result.sampleRate,
        exportRateHz: 256,
      ),
      flush: true,
    );
  }

  void _writeReadableNativeSync(
    Directory targetDir,
    Map<String, String> nativeRawPaths,
  ) {
    final p3 = nativeRawPaths['native3to7'];
    if (p3 != null && p3.isNotEmpty) {
      final src = File(p3);
      if (src.existsSync()) {
        File('${targetDir.path}/$kRaw3to7BySecondFileName').writeAsStringSync(
          buildNativeBySecondReadableText(
            src.readAsStringSync(),
            title: kRaw3to7BySecondFileName,
            requestLabel: 'SENSOR_DELAY_FASTEST (≈3~7ms 요청)',
          ),
          flush: true,
        );
      }
    }
    final p1 = nativeRawPaths['native1to3'];
    if (p1 != null && p1.isNotEmpty) {
      final src = File(p1);
      if (src.existsSync()) {
        File('${targetDir.path}/$kRaw1to3BySecondFileName').writeAsStringSync(
          buildNativeBySecondReadableText(
            src.readAsStringSync(),
            title: kRaw1to3BySecondFileName,
            requestLabel: 'samplingPeriodUs=3000 (1~3ms 요청)',
          ),
          flush: true,
        );
      }
    }
  }

  Future<void> _writeReadableNative(
    Directory targetDir,
    Map<String, String> nativeRawPaths,
  ) async {
    final p3 = nativeRawPaths['native3to7'];
    if (p3 != null && p3.isNotEmpty) {
      final src = File(p3);
      if (await src.exists()) {
        await File('${targetDir.path}/$kRaw3to7BySecondFileName').writeAsString(
          buildNativeBySecondReadableText(
            await src.readAsString(),
            title: kRaw3to7BySecondFileName,
            requestLabel: 'SENSOR_DELAY_FASTEST (≈3~7ms 요청)',
          ),
          flush: true,
        );
      }
    }
    final p1 = nativeRawPaths['native1to3'];
    if (p1 != null && p1.isNotEmpty) {
      final src = File(p1);
      if (await src.exists()) {
        await File('${targetDir.path}/$kRaw1to3BySecondFileName').writeAsString(
          buildNativeBySecondReadableText(
            await src.readAsString(),
            title: kRaw1to3BySecondFileName,
            requestLabel: 'samplingPeriodUs=3000 (1~3ms 요청)',
          ),
          flush: true,
        );
      }
    }
  }

  /// 메일 첨부용: 초별 원본 텍스트
  Future<List<File>> ensureNativeReadableFiles(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');
    final out = <File>[];
    for (final name in [kRaw3to7BySecondFileName, kRaw1to3BySecondFileName]) {
      final f = File('${targetDir.path}/$name');
      if (await f.exists()) out.add(f);
    }
    return out;
  }

  Future<List<File>> _findRawExcelFiles(Directory targetDir) async {
    if (!await targetDir.exists()) return [];
    final files = <File>[];
    await for (final entity in targetDir.list()) {
      if (entity is File && isRawBySecondExcelPath(entity.path)) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  void _removeLegacyRawSidecarsSync(Directory targetDir) {
    for (final name in const [
      'raw_summary.txt',
      'raw_readable.txt',
      'raw_native.txt',
      'collection_rate_summary.txt',
      'native_by_second_원본_제한없음.xlsx',
    ]) {
      final f = File('${targetDir.path}/$name');
      if (f.existsSync()) f.deleteSync();
    }
    if (!targetDir.existsSync()) return;
    for (final entity in targetDir.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      if (isRawBySecondExcelPath(entity.path) ||
          name.startsWith('dense_interpolated_')) {
        entity.deleteSync();
      }
    }
  }

  Future<void> _removeLegacyRawSidecars(Directory targetDir) async {
    for (final name in const [
      'raw_summary.txt',
      'raw_readable.txt',
      'raw_native.txt',
      'collection_rate_summary.txt',
      'native_by_second_원본_제한없음.xlsx',
    ]) {
      final f = File('${targetDir.path}/$name');
      if (await f.exists()) await f.delete();
    }
    if (!await targetDir.exists()) return;
    await for (final entity in targetDir.list()) {
      if (entity is! File) continue;
      final name = entity.path.replaceAll('\\', '/').split('/').last;
      if (isRawBySecondExcelPath(entity.path) ||
          name.startsWith('dense_interpolated_')) {
        await entity.delete();
      }
    }
  }

  /// 메일 첨부용: 256Hz 초별 xlsx
  Future<List<File>> ensureRawExcelFiles(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');
    final existing = await _findRawExcelFiles(targetDir);
    if (existing.any((f) => f.path.endsWith('_256.xlsx'))) {
      return existing.where((f) => f.path.endsWith('_256.xlsx')).toList();
    }

    final result = await load(id);
    final samples = result?.rawSamples;
    if (result == null || samples == null || samples.isEmpty) {
      return existing;
    }
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final excelName = rawBySecondExcelFileName(
      samples,
      sampleRateHz: result.sampleRate,
      exportRateHz: 256,
    );
    await File('${targetDir.path}/$excelName').writeAsBytes(
      buildRawBySecondExcelBytes(
        samples,
        sampleRateHz: result.sampleRate,
        exportRateHz: 256,
      ),
      flush: true,
    );
    return _findRawExcelFiles(targetDir);
  }

  /// 메일 첨부용: report.pdf가 없으면 생성 후 경로 반환
  Future<File?> ensureReportPdf(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');
    final pdfFile = File('${targetDir.path}/report.pdf');
    if (await pdfFile.exists()) return pdfFile;

    final result = await load(id);
    if (result == null) return null;

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);
    return pdfFile;
  }

  /// 저장된 모든 측정 결과 목록 조회 (최신 일시 순)
  Future<List<MeasurementResult>> list() async {
    final baseDir = await getBaseDirectory();
    if (!await baseDir.exists()) return [];

    final List<MeasurementResult> results = [];
    final entities = await baseDir.list().toList();

    for (final entity in entities) {
      if (entity is Directory) {
        final metaFile = File('${entity.path}/meta.json');
        if (await metaFile.exists()) {
          try {
            final jsonStr = await metaFile.readAsString();
            final result = MeasurementResult.fromJson(jsonStr);
            results.add(result);
          } catch (e) {
            // 손상된 파일은 무시하고 계속 진행
            continue;
          }
        }
      }
    }

    // 최신순 (dateTime 내림차순) 정렬
    results.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return results;
  }

  /// id로 특정 측정 결과 및 raw 데이터 로드
  Future<MeasurementResult?> load(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');
    final metaFile = File('${targetDir.path}/meta.json');
    if (!await metaFile.exists()) return null;

    try {
      final jsonStr = await metaFile.readAsString();
      var result = MeasurementResult.fromJson(jsonStr);

      final rawFile = File('${targetDir.path}/raw.txt');
      if (await rawFile.exists()) {
        final rawContent = await rawFile.readAsString();
        final parsed = RawDataParser.parseEvimp1ToSamples(rawContent);
        result = result.copyWith(
          rawSamples: parsed.samples,
          sampleRate: parsed.sampleRate.toDouble(),
        );
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  /// id에 해당하는 측정 폴더 삭제 (`raw.txt`, `meta.json`, `report.pdf` 전체 삭제)
  Future<bool> delete(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');
    if (await targetDir.exists()) {
      try {
        await targetDir.delete(recursive: true);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
}
