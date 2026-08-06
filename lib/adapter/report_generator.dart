import 'package:vibration_checker/model/measurement_result.dart';

/// [연결] 리포트 생성 어댑터. UI 계약 시그니처만 유지한다.
/// 리포트 계층 리빌딩에서 구현한다. 기존 구현: main 브랜치 git 이력 참조.
class ReportGenerator {
  /// 목적: 이메일 본문용 요약 글 — 리포트 계층 리빌딩에서 구현.
  static String generateSummaryText(MeasurementResult result) {
    throw UnimplementedError('리포트 계층 리빌딩에서 구현');
  }
}
