import 'package:vibration_checker/model/measurement_result.dart';

/// 현재 상태: 1개 메서드(parseEvimp1) 전부 미구현이며 호출하면
/// UnimplementedError 가 발생한다. 파서 계층 리빌딩에서 구현한다.
/// 호출하는 곳: 결과 화면. 이 화면에서 해당 동작을 실행하면 실패한다.
///
/// 목적: 회사 표준 데이터 포맷(EVIMP1)으로 작성된 텍스트 데이터를 읽어와서 앱에서 쓸 수 있는 측정 결과 객체로 변환해주는 역할을 한다.
class RawDataParser {
  /// 목적: 긴 문자열로 된 EVIMP1 포맷 텍스트를 분석(파싱)하여 MeasurementResult 객체로 만든다.
  ///       (현재 뼈대만 있고, 실제 문자열 분리 로직은 나중에 구현될 예정이다)
  /// 인자: rawContent — EVIMP1 포맷으로 된 원본 텍스트 전체
  ///       id — 저장 아이디
  ///       jobNo — 엘리베이터 호기 번호 (제번)
  ///       siteName — 설치 현장명
  ///       bottomFloor — 시작 층수
  ///       topFloor — 도착 층수
  ///       direction — 운행 방향 (상/하)
  ///       dateTime — 측정 시각
  /// 반환: 문자열을 해석해 수치가 채워진 MeasurementResult 객체
  /// 근거: 미정 — 파서 모듈 개발 완료 시 구현됨
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
