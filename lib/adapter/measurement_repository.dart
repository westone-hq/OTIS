import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:vibration_checker/model/measurement_result.dart';

/// 현재 상태: 7개 메서드 전부 미구현이며 호출하면 UnimplementedError 가
/// 발생한다. 저장·출력 계층 리빌딩에서 구현한다.
/// 호출하는 곳: 이력 화면, 결과 화면, 메일 시트(jobId 경로).
/// 이 화면들에서 해당 동작을 실행하면 실패한다.
/// 계측 경로는 이 클래스를 쓰지 않는다. 측정 화면은 저장 위치를 직접 확보한다.
///
/// 목적: 완성된 측정 결과를 기기에 파일 형태로 저장하거나, 목록을 불러오고, 삭제하는 저장소 역할을 한다.
class MeasurementRepository {
  static final MeasurementRepository instance = MeasurementRepository._();
  MeasurementRepository._();

  /// 목적: 데이터들이 저장될 기준 폴더 경로를 가져온다.
  Future<Directory> getBaseDirectory() async {
    final external = await getExternalStorageDirectory();
    final base = external ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/captures');
    await dir.create(recursive: true);
    return dir;
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

  /// 목적: 특정 측정 결과에 대한 PDF 보고서 파일을 생성하거나 이미 있으면 가져온다.
  Future<File?> ensureReportPdf(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }

  /// 목적: 측정 결과에 딸린 엑셀 데이터 원본 파일을 생성하거나 이미 있으면 가져온다.
  Future<List<File>> ensureRawExcelFiles(String id) async {
    throw UnimplementedError('저장·출력 계층 리빌딩에서 구현');
  }
}
