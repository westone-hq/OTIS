@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

import '../adapter/report/pdf_probe.dart';
import '../support/otis_1021_records.dart';

/// 작성: 2026-10-22 21:30:00 · nada
/// 변수: _hashPath
/// 목적: 리팩토링 전 main 에서 낸 결과 해시를 담는 파일. 기록마다
///       result.json(`toMap()`, 시계열 포함)과 PDF 쪽 내용 스트림의 SHA-256
///       이다. 전체 JSON 은 수십 MB 라 저장소에 두지 않고 `_dumpDir` 에 쓴다.
const String _hashPath = 'test/regression/golden/hashes.json';

/// 작성: 2026-10-22 21:30:00 · nada
/// 변수: _dumpDir
/// 목적: 기록마다 전체 JSON 을 떨구는 폴더(빌드 폴더라 git 밖). 해시가
///       다르면 main 에서 만든 같은 파일과 나란히 놓고 비교한다.
const String _dumpDir = 'build/golden';

/// 작성: 2026-10-22 21:30:00 · nada
/// 변수: _downSite
/// 목적: 하강 기록에 넘기는 현장(8 → 1층). 상승 기록은 `assembleRecord()`
///       기본 현장을 쓴다.
const SiteInfo _downSite = SiteInfo(
  jobNo: 'J',
  siteName: 'S',
  address: 'A',
  postalCode: '00000',
  bottomFloor: '1',
  topFloor: '8',
  direction: SiteInfo.directionDown,
  model: SiteInfo.defaultModel,
  load: '1000',
);

/// 작성: 2026-10-22 21:30:00 · nada
/// 함수: main
/// 목적: 실측 기록 12건을 앱 저장 절차와 같은 길로 계산해 결과 · PDF 가
///       리팩토링 전과 비트 단위로 같은지 본다. `GOLDEN_UPDATE=1` 이면 해시
///       파일을 다시 쓴다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final records = <String, String>{
    ...otis1021Records,
    ...records1022,
    'ride_reference': rideReferencePath,
    'conditioning_input_dev': 'test/fixtures/conditioning_input_dev_256hz.txt',
  }; // 계산할 기록 이름 → 경로
  final update = Platform.environment['GOLDEN_UPDATE'] == '1'; // 갱신 여부

  test('실측 기록 결과 · PDF 가 리팩토링 전과 같다', () async {
    final actual = <String, Map<String, String>>{}; // 기록별 해시
    Directory(_dumpDir).createSync(recursive: true);
    for (final entry in records.entries) {
      final name = entry.key; // 기록 이름
      final result = assembleRecord(
        entry.value,
        site: name.contains('down') ? _downSite : null,
        flipVertical: faceUpRecords.contains(name),
        deviceModel: name == 'conditioning_input_dev'
            ? devPhoneModel
            : deviceModelOf(name),
      ).result!; // 측정 결과
      final json = jsonEncode(result.toMap()); // result.json 내용
      File('$_dumpDir/$name.json').writeAsStringSync(json);
      final pdf = await (await TuneReportBuilder.load()).build(result);
      final streams = pdfContentStreams(pdf).join('\n'); // 쪽 내용
      File('$_dumpDir/$name.pdf.txt').writeAsStringSync(streams);
      actual[name] = <String, String>{
        'result': sha256.convert(utf8.encode(json)).toString(),
        'pdf': sha256.convert(latin1.encode(streams)).toString(),
      };
    }

    final file = File(_hashPath); // 고정한 해시 파일
    if (update) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(actual)}\n',
      );
      return;
    }
    final expected = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, dynamic>(); // 리팩토링 전 해시
    expect(actual.keys.toSet(), expected.keys.toSet());
    for (final name in records.keys) {
      expect(
        actual[name],
        (expected[name] as Map).cast<String, String>(),
        reason: name,
      );
    }
  });
}
