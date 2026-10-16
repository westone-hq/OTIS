@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';

import 'shot_harness.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _result
/// 목적: 변경 전 · 후 코드 모두에 있는 항목만으로 결과를 만든다. 측정
///       시각은 UTC 로 줘, 한국 시간 표시 전 · 후가 갈리는 것을 보이게 한다
///       (UTC 02:03 = 한국 11:03).
/// 인자: id — 측정 ID
///       z — 수직 최대 P2P (mg)
/// 반환: 측정 결과
MeasurementResult _result(String id, double z) => MeasurementResult(
  id: id,
  jobNo: '2025F 1234R01',
  siteName: '시험 현장',
  address: '경기도 고양시 덕양구 오금동',
  bottomFloor: 1,
  topFloor: 8,
  direction: '상승',
  model: 'Gen2',
  dateTime: DateTime.utc(2026, 1, 14, 2, 3, 59),
  xPtp: 12.0,
  yPtp: 9.0,
  zPtp: z,
  noiseMax: 55.0,
  distance: 57.1,
  maxSpeed: 1.74,
  xSeries: const <double>[],
  ySeries: const <double>[],
  zSeries: const <double>[],
  noiseSeries: const <double>[],
  positionSeries: const <double>[],
  speedSeries: const <double>[],
  accelSeries: const <double>[],
  jerkSeries: const <double>[],
);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 2026-10-15 변경(초과 기준 · 한국 시간)이 닿는 화면 — 결과 화면과
///       저장 결과 목록 — 을 같은 자료로 찍는다. 예전 커밋에서도 이 파일을
///       돌려 변경 전 그림을 얻는다. 파일 이름 머리는 `SHOT_PREFIX`.
void main() {
  late Directory temp; // 임시 저장소
  final prefix = Platform.environment['SHOT_PREFIX'] ?? '후'; // 전 · 후 표시

  setUpAll(loadShotFonts);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otis_before_after');
    PathProviderPlatform.instance = TempPathProvider(temp.path);
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in shotSizes) {
    testWidgets('결과 · 목록 ${size.width.toInt()}', (tester) async {
      setShotSize(tester, size);
      await tester.runAsync(() async {
        await MeasurementRepository.instance.save(_result('A', 20.0));
        await MeasurementRepository.instance.save(_result('B', 8.0));
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            theme: shotTheme(),
            home: const ResultScreen(id: 'A'),
          ),
        ),
      );
      await settle(tester, rounds: 60);
      await capture(tester, shotName('${prefix}_결과_Z20mg', size));

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
