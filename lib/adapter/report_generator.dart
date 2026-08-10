import 'package:vibration_checker/model/measurement_result.dart';

/// 현재 상태: 1개 메서드(generateSummaryText) 전부 미구현이며 호출하면
/// UnimplementedError 가 발생한다. 리포트 계층 리빌딩에서 구현한다.
/// 호출하는 곳: 메일 시트. 이 화면에서 해당 동작을 실행하면 실패한다.
///
/// 목적: 측정 결과를 바탕으로 이메일 본문에 들어갈 텍스트나 PDF 보고서를 예쁘게 만들어주는 역할을 한다.
class ReportGenerator {
  /// 목적: 측정 결과(성적표) 객체를 받아, 현장 엔지니어가 메일을 보낼 때 본문에 바로 붙여넣을 수 있는 깔끔한 한국어 요약 텍스트를 생성한다.
  /// 인자: result — 측정 결과 객체
  /// 반환: 이메일 본문용 요약 텍스트
  /// 근거: 미정 — 리포트 모듈 개발 시 구체적인 양식 확정 필요
  static String generateSummaryText(MeasurementResult result) {
    throw UnimplementedError('리포트 계층 리빌딩에서 구현');
  }
}
