// 작성: 2026-08-18 23:29:46
// 작성자: 박건준

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:vibration_checker/model/measurement_result.dart';

/// 클래스: MeasurementRepository
/// 목적: 완성된 측정 결과를 기기에 파일 형태로 저장하거나, 목록을
///       불러오고, 삭제하는 저장소 역할을 한다.
/// 현재 상태: `getBaseDirectory()`만 구현되어 있다. 나머지 6개
/// 메서드(save, list, load, delete, ensureReportPdf,
/// ensureRawExcelFiles)는 추후 구현할 내용이라, 지금 부르면
/// `UnimplementedError`(아직 못 만든 기능을 호출했을 때 Dart가 대신
/// 던져주는 오류)가 발생한다.
class MeasurementRepository {
  static final MeasurementRepository instance = MeasurementRepository._();
  MeasurementRepository._();

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
