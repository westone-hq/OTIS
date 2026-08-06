import 'package:vibration_checker/domain/models/measurement_result.dart';

/// [연결] EVIMP1 파서 어댑터. UI 계약 시그니처만 유지한다.
/// 파서 계층 리빌딩에서 구현한다. 기존 구현: main 브랜치 git 이력 참조.
class RawDataParser {
  /// 목적: EVIMP1 텍스트를 측정 결과로 판독 — 파서 계층 리빌딩에서 구현.
  static MeasurementResult parseEvimp1({
    required String rawContent,
    required String id,
    required String jobNo,
    required String siteName,
    required int bottomFloor,
    required int topFloor,
    required String direction,
    required DateTime dateTime,
  }) {
    throw UnimplementedError('파서 계층 리빌딩에서 구현');
  }
}
