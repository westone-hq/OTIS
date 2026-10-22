import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 작성: 2026-10-22 21:50:00 · nada
/// 변수: _packagePrefix
/// 목적: 이 앱 파일을 가리키는 import 의 앞부분.
const String _packagePrefix = 'package:vibration_checker/';

/// 작성: 2026-10-22 21:50:00 · nada
/// 변수: _domainForbidden
/// 목적: domain 이 import 하면 안 되는 앞부분. domain 은 화면 · 파일 ·
///       플랫폼을 모르는 순수 Dart 로 두어 시험에서 그대로 돌린다.
const List<String> _domainForbidden = <String>[
  'package:flutter/',
  'dart:io',
  'dart:ui',
  '${_packagePrefix}adapter/',
  '${_packagePrefix}service/',
  '${_packagePrefix}ui/',
];

/// 작성: 2026-10-22 21:50:00 · nada
/// 함수: _importsOf
/// 목적: Dart 파일 하나의 import · export 대상을 읽는다.
/// 인자: file — 읽을 파일
/// 반환: import · export 문의 대상 문자열 목록
List<String> _importsOf(File file) {
  final directive = RegExp(
    r"""^(?:import|export)\s+'([^']+)'""",
    multiLine: true,
  ); // import · export 문 하나
  return <String>[
    for (final m in directive.allMatches(file.readAsStringSync())) m.group(1)!,
  ];
}

/// 작성: 2026-10-22 21:50:00 · nada
/// 함수: _violationsOf
/// 목적: lib 파일 하나가 층 규칙을 어긴 import 를 찾는다.
///       - domain → domain 만 (`_domainForbidden`)
///       - domain/dsp → dsp 만 (이 앱 규칙을 모르는 필터 부품)
///       - adapter → domain · adapter (service · ui 금지)
///       - service → adapter · domain · service (ui 금지)
///       - ui · main.dart → 제한 없음
/// 인자: path — lib 기준 상대 경로(`domain/analysis/kinematics.dart` 꼴)
///       imports — 그 파일의 import 대상
/// 반환: "경로 → 대상" 꼴의 위반 목록
List<String> _violationsOf(String path, List<String> imports) {
  final out = <String>[]; // 찾은 위반
  for (final target in imports) {
    final bad = switch (path) {
      _ when path.startsWith('domain/dsp/') =>
        target.startsWith(_packagePrefix) &&
                !target.startsWith('${_packagePrefix}domain/dsp/') ||
            _domainForbidden.any(target.startsWith),
      _ when path.startsWith('domain/') => _domainForbidden.any(
        target.startsWith,
      ),
      _ when path.startsWith('adapter/') =>
        target.startsWith('${_packagePrefix}service/') ||
            target.startsWith('${_packagePrefix}ui/'),
      _ when path.startsWith('service/') => target.startsWith(
        '${_packagePrefix}ui/',
      ),
      _ => false,
    }; // 이 import 가 규칙을 어기는지
    if (bad) out.add('$path → $target');
  }
  return out;
}

/// 작성: 2026-10-22 21:50:00 · nada
/// 함수: main
/// 목적: lib 의 import 가 층 규칙(CLAUDE.md "층 규칙")을 지키는지 본다.
void main() {
  test('lib 의 import 가 층 규칙을 지킨다', () {
    final violations = <String>[]; // 모든 파일의 위반
    final libDir = Directory('lib'); // 앱 소스 폴더
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path
          .replaceAll(r'\', '/')
          .substring('lib/'.length); // lib 기준 경로
      violations.addAll(_violationsOf(path, _importsOf(entity)));
    }
    expect(violations, isEmpty);
  });

  test('규칙 판정이 층마다 맞게 걸린다', () {
    expect(_violationsOf('domain/report/a.dart', ['dart:io']), isNotEmpty);
    expect(
      _violationsOf('domain/dsp/a.dart', ['${_packagePrefix}domain/x/b.dart']),
      isNotEmpty,
    );
    expect(
      _violationsOf('adapter/a.dart', ['${_packagePrefix}service/b.dart']),
      isNotEmpty,
    );
    expect(
      _violationsOf('service/a.dart', ['${_packagePrefix}ui/b.dart']),
      isNotEmpty,
    );
    expect(
      _violationsOf('service/a.dart', ['${_packagePrefix}adapter/b.dart']),
      isEmpty,
    );
    expect(_violationsOf('ui/a.dart', ['dart:io']), isEmpty);
  });
}
