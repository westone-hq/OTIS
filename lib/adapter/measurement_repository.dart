import 'dart:io';

import 'package:vibration_checker/model/measurement_result.dart';

/// 목적: 완성된 측정 결과(성적표)들을 기기에 파일 형태로 저장하거나, 목록을 불러오고, 삭제하는 창고(저장소) 역할을 한다.
class MeasurementRepository {
  static final MeasurementRepository instance = MeasurementRepository._();
  MeasurementRepository._();

  /// 목적: 데이터들이 저장될 기준 폴더 경로를 가져온다.
  Future<Directory> getBaseDirectory() async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 새롭게 계산된 측정 결과를 기기에 저장한다.
  Future<Directory> save(MeasurementResult result) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 기기에 저장되어 있는 모든 과거 측정 결과 목록을 불러온다.
  Future<List<MeasurementResult>> list() async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 특정 ID의 측정 결과 파일 하나만 찾아서 읽어온다.
  Future<MeasurementResult?> load(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 특정 ID의 측정 결과를 기기에서 완전히 삭제한다.
  Future<bool> delete(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 특정 측정 결과에 대한 PDF 성적서 파일을 생성하거나 이미 있으면 가져온다.
  Future<File?> ensureReportPdf(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 측정 결과에 딸린 엑셀 데이터 원본 파일을 생성하거나 이미 있으면 가져온다.
  Future<List<File>> ensureRawExcelFiles(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }
}
