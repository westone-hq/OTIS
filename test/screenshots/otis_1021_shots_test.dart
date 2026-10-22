@Tags(['screenshot'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/report/tune_report_builder.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';

import '../support/reference_records.dart';
import 'shot_harness.dart';

/// 작성: 2026-10-21 17:40:00 · nada
/// 변수: _records
/// 목적: 캡처할 2026-10-21 개발폰 기록 세 건과 운전 방향. 측정 ID 는 저장
///       결과 목록 차례가 기록 차례와 같게 시각 순으로 준다.
const List<(String, String, String)> _records = <(String, String, String)>[
  ('dev_up1', SiteInfo.directionUp, '20261021-100100'),
  ('dev_up2', SiteInfo.directionUp, '20261021-100200'),
  ('dev_down3', SiteInfo.directionDown, '20261021-100300'),
];

/// 작성: 2026-10-21 17:40:00 · nada
/// 함수: _assemble
/// 목적: 기록 한 건을 앱 저장 절차와 같은 길로 측정 결과로 바꾼다. 현장은
///       서일대 측정과 같은 4 · 11 층이고 이름은 시험용이다.
///       `SHOT_FLIP_FACE_UP` 이 `1` 이면 `faceUpRecords` 의 Z 부호를 뒤집어
///       읽는다 — 지금 격자 환산(중력 방향 투영)이 냈을 값이다. 변경 전
///       코드에서 돌릴 때는 주지 않는다.
/// 인자: name — 기록 이름 (`otis1021Records` 열쇠)
///       direction — 운전 방향
///       id — 측정 ID
/// 반환: 측정 결과
MeasurementResult _assemble(String name, String direction, String id) {
  final flip =
      Platform.environment['SHOT_FLIP_FACE_UP'] == '1' &&
      faceUpRecords.contains(name); // Z 를 뒤집어 읽을지
  final result = assembleRecord(
    otis1021Records[name]!,
    flipVertical: flip,
    site: SiteInfo(
      jobNo: 'TEST-1021',
      siteName: '시험 현장',
      address: '서울특별시 시험구',
      postalCode: '00000',
      bottomFloor: '4',
      topFloor: '11',
      direction: direction,
      model: SiteInfo.defaultModel,
      load: '1000',
    ),
  ).result!;
  return result.copyWith(
    id: id,
    engineerName: '홍길동',
    dateTime: DateTime.utc(2026, 10, 21, 1, int.parse(id.substring(11, 13))),
  );
}

/// 작성: 2026-10-21 17:40:00 · nada
/// 함수: main
/// 목적: 2026-10-21 변경(수직 최대 정속 구간 · Jptp · 하강 부호 · 3쪽 축 ·
///       서식 얼룩)이 닿는 화면과 리포트를 같은 자료로 만든다. 변경 전
///       커밋에서도 이 파일과 `test/support/reference_records.dart` 를 돌려
///       변경 전 그림을 얻는다. 파일 이름 머리는 `SHOT_PREFIX`.
///       - 결과 화면(기록마다) · 저장 결과 목록, 두 화면 크기
///       - 리포트 PDF: `SHOT_DIR/pdf/머리_기록.pdf`
///       - 결과 JSON(시계열 포함): `SHOT_DIR/json/머리_기록.json`
void main() {
  late Directory temp; // 임시 저장소
  final prefix = Platform.environment['SHOT_PREFIX'] ?? '후'; // 전 · 후 표시

  setUpAll(loadShotFonts);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otis_1021_shots');
    PathProviderPlatform.instance = TempPathProvider(temp.path);
    SharedPreferences.setMockInitialValues({});
  });

  test('리포트 PDF · 결과 JSON', () async {
    final out = shotOutputDir(); // 쓸 폴더
    Directory('${out.path}/pdf').createSync(recursive: true);
    Directory('${out.path}/json').createSync(recursive: true);
    for (final (name, direction, id) in _records) {
      final result = _assemble(name, direction, id); // 측정 결과
      final builder = await TuneReportBuilder.load(); // 리포트 만들기
      File(
        '${out.path}/pdf/${prefix}_$name.pdf',
      ).writeAsBytesSync(await builder.build(result));
      File(
        '${out.path}/json/${prefix}_$name.json',
      ).writeAsStringSync(jsonEncode(result.toMap()));
    }
  });

  for (final size in shotSizes) {
    testWidgets('결과 · 목록 ${size.width.toInt()}', (tester) async {
      setShotSize(tester, size);
      await tester.runAsync(() async {
        for (final (name, direction, id) in _records) {
          await MeasurementRepository.instance.save(
            _assemble(name, direction, id),
          );
        }
      });

      for (final (name, _, id) in _records) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: shotKey,
            child: MaterialApp(
              theme: shotTheme(),
              home: ResultScreen(id: id),
            ),
          ),
        );
        await settle(tester, rounds: 60);
        await capture(tester, shotName('${prefix}_결과_$name', size));
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: MaterialApp(theme: shotTheme(), home: const HistoryScreen()),
        ),
      );
      await settle(tester, rounds: 100);
      await capture(tester, shotName('${prefix}_목록', size));
    });
  }
}
