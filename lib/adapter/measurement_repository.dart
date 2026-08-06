import 'dart:io';

import 'package:vibration_checker/model/measurement_result.dart';

/// [연결] 측정 저장소 어댑터. UI 계약 시그니처만 유지한다.
/// 저장·출력 계층 리빌딩에서 구현한다. 기존 구현: main 브랜치 git 이력 참조.
class MeasurementRepository {
  static final MeasurementRepository instance = MeasurementRepository._();
  MeasurementRepository._();

  Future<Directory> getBaseDirectory() async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<Directory> save(MeasurementResult result) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<List<MeasurementResult>> list() async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<MeasurementResult?> load(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<bool> delete(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<File?> ensureReportPdf(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  Future<List<File>> ensureRawExcelFiles(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }
}
