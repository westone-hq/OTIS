import 'package:vibration_checker/model/measurement_result.dart';

/// 클래스: ReportGenerator
/// 목적: 측정 결과를 바탕으로 이메일 본문에 들어갈 요약 텍스트를 만든다.
/// 미구현: 1개 메서드(generateSummaryText) 전부 미구현이며 호출하면
///       UnimplementedError 가 발생한다. 메일 시트에서 이 동작을 실행하면
///       실패한다. 리포트 계층 리빌딩에서 구현한다.
class ReportGenerator {
  /// 함수: generateSummaryText
  /// 목적: 측정 결과 객체를 받아, 현장 엔지니어가 메일을 보낼 때 본문에 바로 붙여넣을 수 있는 한국어 요약 텍스트를 생성한다.
  /// 인자: result — 측정 결과 객체
  /// 반환: 이메일 본문용 요약 텍스트
  /// 근거: 미정 — 리포트 모듈 개발 시 구체적인 양식 확정 필요
  /// 미구현: 리포트 계층이 없어 UnimplementedError 를 던진다. 메일
  ///       발송 시트의 `_buildJobEmail()`에서 지표 요약 발송을 선택했을
  ///       때 부르는데, 그 함수는 `MeasurementRepository.load()`가 먼저
  ///       던지므로 실제로는 이 지점까지 도달하지 않는다. 도달한다면
  ///       `_send()`의 바깥 try/catch가 잡아 "저장·출력 기능은 아직
  ///       구현되지 않았습니다" 스낵바를 띄운다.
  static String generateSummaryText(MeasurementResult result) {
    throw UnimplementedError('리포트 계층 리빌딩에서 구현');
  }
}
