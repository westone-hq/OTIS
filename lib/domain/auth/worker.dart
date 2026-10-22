/// 작성: 2026-10-18 09:09:47 · nada
/// 클래스: Worker
/// 목적: 로그인할 수 있는 작업자 한 명. OTIS 가 준 작업자 명단(엑셀,
///       `tool/import_workers.py` 가 `assets/workers/workers.json` 으로
///       바꾼다)의 한 줄이다. 로그인한 작업자의 성명이 리포트 엔지니어
///       칸에 찍히고, 사번 · 업체명 · 관리팀은 측정 결과와 메일 본문에
///       함께 남는다.
class Worker {
  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: Worker
  /// 목적: 명단 한 줄의 값을 그대로 담는다.
  /// 인자: employeeId — 사번. 대문자로 맞춘 값(`WorkerDirectory.normalizeId()`)
  ///       name — 성명
  ///       company — 업체명. OTIS 직원처럼 명단에 비어 있으면 null
  ///       team — 관리팀. 명단에 비어 있으면 null
  const Worker({
    required this.employeeId,
    required this.name,
    this.company,
    this.team,
  });

  /// 사번 (예: "T00001" — 협력 업체, "200001" — OTIS 직원). 대문자로 맞춘
  /// 값이다
  final String employeeId;

  /// 성명
  final String name;

  /// 업체명 (예: "(주)경성승강기"). 명단에 비어 있으면 null
  final String? company;

  /// 관리팀 (예: "설치2팀"). 명단에 비어 있으면 null
  final String? team;
}
