import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/measurement_result.dart';
import '../parse_raw.dart';
import '../report_generator.dart';

/// P13 · 측정 결과 파일 저장소 Repository (Phase 4-A)
/// - 로컬 디스크 문서 디렉토리 내 `measurements/{id}/` 폴더 관리
/// - `raw.txt` (EVIMP1 형식 RAW 샘플)
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
      if (!await dir.exists()) {
        await dir.create(recursive: true);
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
  /// - `raw.txt`, `meta.json`, `report.pdf` 3종 파일 동기화 생성
  Future<Directory> save(MeasurementResult result) async {
    final baseDir = await getBaseDirectory();
    final targetDir = Directory('${baseDir.path}/${result.id}');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 1. meta.json 저장
    final metaFile = File('${targetDir.path}/meta.json');
    await metaFile.writeAsString(result.toJson(), flush: true);

    // 2. raw.txt (EVIMP1) 저장
    final rawFile = File('${targetDir.path}/raw.txt');
    final rawSamples = result.rawSamples ?? [];
    final rawContent = RawDataParser.writeEvimp1(
      rawSamples,
      sampleRate: result.sampleRate.round(),
    );
    await rawFile.writeAsString(rawContent, flush: true);

    // 3. report.pdf 저장
    final pdfFile = File('${targetDir.path}/report.pdf');
    final pdfBytes = await ReportGenerator.generateTuneReportPdf(result);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);

    return targetDir;
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
