import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../measure/raw_excel_export.dart';
import '../measure/sensor_sample.dart';
import '../models/measurement_result.dart';
import '../parse_raw.dart';
import '../report_generator.dart';

/// P13 · 측정 결과 파일 저장소 Repository (Phase 4-A)
/// - 로컬 디스크 문서 디렉토리 내 `measurements/{id}/` 폴더 관리
/// - `raw.txt` (EVIMP1 형식 RAW 샘플)
/// - `EVIMP1_전체N초_초별분리_센서값_{256|128|64}.xlsx` (초당 샘플 수별)
/// - `meta.json` (SiteInfo + 지표 + 판정 메타데이터)
/// - `report.pdf` (TUNE 리포트 PDF 바이트)
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
  /// - `raw.txt`, 초별 xlsx, `meta.json`, `report.pdf` 동기화 생성
  Future<Directory> save(MeasurementResult result) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/${result.id}');
    if (overrideBaseDir != null) {
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final metaFile = File('${targetDir.path}/meta.json');
      metaFile.writeAsStringSync(result.toJson(), flush: true);

      _writeRawFilesSync(targetDir, result);

      final pdfFile = File('${targetDir.path}/report.pdf');
      final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
      pdfFile.writeAsBytesSync(pdfBytes, flush: true);

      return targetDir;
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 1. meta.json 저장
    final metaFile = File('${targetDir.path}/meta.json');
    await metaFile.writeAsString(result.toJson(), flush: true);

    // 2. raw.txt + 초별 분리 xlsx
    await _writeRawFiles(targetDir, result);

    // 3. report.pdf 저장
    final pdfFile = File('${targetDir.path}/report.pdf');
    final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);

    return targetDir;
  }

  void _writeRawFilesSync(Directory targetDir, MeasurementResult result) {
    final rawSamples = result.rawSamples ?? [];
    final rawFile = File('${targetDir.path}/raw.txt');
    rawFile.writeAsStringSync(
      RawDataParser.writeEvimp1(
        rawSamples,
        sampleRate: result.sampleRate.round(),
      ),
      flush: true,
    );
    _removeLegacyRawSidecarsSync(targetDir);
    _writeExcelFilesSync(targetDir, rawSamples, result.sampleRate);
  }

  Future<void> _writeRawFiles(
    Directory targetDir,
    MeasurementResult result,
  ) async {
    final rawSamples = result.rawSamples ?? [];
    final rawFile = File('${targetDir.path}/raw.txt');
    await rawFile.writeAsString(
      RawDataParser.writeEvimp1(
        rawSamples,
        sampleRate: result.sampleRate.round(),
      ),
      flush: true,
    );
    await _removeLegacyRawSidecars(targetDir);
    await _writeExcelFiles(targetDir, rawSamples, result.sampleRate);
  }

  void _writeExcelFilesSync(
    Directory targetDir,
    List<SensorSample> samples,
    double sampleRateHz,
  ) {
    for (final rate in kRawExcelExportRatesHz) {
      final excelName = rawBySecondExcelFileName(
        samples,
        sampleRateHz: sampleRateHz,
        exportRateHz: rate,
      );
      File('${targetDir.path}/$excelName').writeAsBytesSync(
        buildRawBySecondExcelBytes(
          samples,
          sampleRateHz: sampleRateHz,
          exportRateHz: rate,
        ),
        flush: true,
      );
    }
  }

  Future<void> _writeExcelFiles(
    Directory targetDir,
    List<SensorSample> samples,
    double sampleRateHz,
  ) async {
    for (final rate in kRawExcelExportRatesHz) {
      final excelName = rawBySecondExcelFileName(
        samples,
        sampleRateHz: sampleRateHz,
        exportRateHz: rate,
      );
      await File('${targetDir.path}/$excelName').writeAsBytes(
        buildRawBySecondExcelBytes(
          samples,
          sampleRateHz: sampleRateHz,
          exportRateHz: rate,
        ),
        flush: true,
      );
    }
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
    ]) {
      final f = File('${targetDir.path}/$name');
      if (f.existsSync()) f.deleteSync();
    }
    if (!targetDir.existsSync()) return;
    for (final entity in targetDir.listSync()) {
      if (entity is File && isRawBySecondExcelPath(entity.path)) {
        entity.deleteSync();
      }
    }
  }

  Future<void> _removeLegacyRawSidecars(Directory targetDir) async {
    for (final name in const [
      'raw_summary.txt',
      'raw_readable.txt',
    ]) {
      final f = File('${targetDir.path}/$name');
      if (await f.exists()) await f.delete();
    }
    if (!await targetDir.exists()) return;
    await for (final entity in targetDir.list()) {
      if (entity is File && isRawBySecondExcelPath(entity.path)) {
        await entity.delete();
      }
    }
  }

  /// 메일 첨부용: 256/128/64Hz 초별 xlsx가 없으면 생성 후 경로 목록 반환
  Future<List<File>> ensureRawExcelFiles(String id) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/$id');

    final existing = await _findRawExcelFiles(targetDir);
    final hasAllRates = kRawExcelExportRatesHz.every(
      (rate) => existing.any((f) => f.path.endsWith('_$rate.xlsx')),
    );
    if (hasAllRates) return existing;

    final result = await load(id);
    final samples = result?.rawSamples;
    if (result == null || samples == null || samples.isEmpty) {
      return existing;
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 이전 단일/부분 xlsx 정리 후 256·128·64 재생성
    for (final f in existing) {
      if (await f.exists()) await f.delete();
    }
    await _writeExcelFiles(targetDir, samples, result.sampleRate);
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
