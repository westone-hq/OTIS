import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';
import 'package:vibration_checker/domain/update/update_info.dart';

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 변수: _sha
/// 목적: 형식이 맞는 SHA-256 자리 값(16진수 소문자 64자).
final String _sha = 'ab' * 32;

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 함수: _json
/// 목적: 정상 version.json 표에서 몇 항목만 바꾸거나 지운 본문을 만든다.
/// 인자: override — 바꿀 항목. 값이 null 이면 그 항목을 지운다
/// 반환: JSON 문자열
String _json([Map<String, Object?> override = const {}]) {
  final map = <String, Object?>{
    'latest': 13,
    'latestName': '0.1.3',
    'minimum': 12,
    'apkUrl':
        'https://github.com/o/r/releases/download/v0.1.3/vcheck-0.1.3.apk',
    'sha256': _sha,
    'notes': ' 소음 표시를 고쳤습니다 ',
  }; // 정상 표
  override.forEach((key, value) {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  });
  return jsonEncode(map);
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 함수: _info
/// 목적: 판정 시험에 쓸 버전 정보(minimum 12, latest 13)를 만든다.
/// 반환: 버전 정보
UpdateInfo _info() => UpdateInfo.parse(_json()).info!;

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 함수: main
/// 목적: version.json 읽기(정상 · 필드 누락 · 자료형 · http 주소 ·
///       sha256 형식 · minimum > latest · JSON 아님)와 업데이트 판정
///       (빌드 11 · 12 · 13 · 14 × minimum 12, latest 13)을 시험한다.
void main() {
  group('UpdateInfo.parse', () {
    test('정상 파일은 모든 항목을 읽고 notes 앞뒤 공백을 지운다', () {
      final result = UpdateInfo.parse(_json()); // 읽은 결과

      expect(result.error, isNull);
      final info = result.info!; // 버전 정보
      expect(info.latest, 13);
      expect(info.latestName, '0.1.3');
      expect(info.minimum, 12);
      expect(info.apkUrl.host, 'github.com');
      expect(info.sha256, _sha);
      expect(info.notes, '소음 표시를 고쳤습니다');
    });

    test('필드가 빠지면 missingField 와 그 항목 이름', () {
      for (final key in <String>[
        'latest',
        'latestName',
        'minimum',
        'apkUrl',
        'sha256',
        'notes',
      ]) {
        final result = UpdateInfo.parse(_json({key: null})); // 읽은 결과
        expect(result.info, isNull, reason: key);
        expect(result.error, UpdateInfoError.missingField, reason: key);
        expect(result.detail, key);
      }
    });

    test('번호가 정수가 아니면 wrongType', () {
      expect(
        UpdateInfo.parse(_json({'latest': '13'})).error,
        UpdateInfoError.wrongType,
      );
      expect(
        UpdateInfo.parse(_json({'minimum': 12.5})).error,
        UpdateInfoError.wrongType,
      );
    });

    test('http 이거나 주소가 깨진 apkUrl 은 notHttps', () {
      for (final url in <String>[
        'http://github.com/o/r/a.apk',
        'ftp://github.com/a.apk',
        'https:///a.apk',
        'vcheck.apk',
      ]) {
        expect(
          UpdateInfo.parse(_json({'apkUrl': url})).error,
          UpdateInfoError.notHttps,
          reason: url,
        );
      }
    });

    test('sha256 이 소문자 16진수 64자가 아니면 badSha256', () {
      for (final sha in <String>['ab' * 31, 'AB' * 32, 'zz' * 32, '']) {
        expect(
          UpdateInfo.parse(_json({'sha256': sha})).error,
          UpdateInfoError.badSha256,
          reason: sha,
        );
      }
    });

    test('minimum 이 latest 보다 크면 minimumAboveLatest', () {
      final result = UpdateInfo.parse(_json({'minimum': 14})); // 읽은 결과
      expect(result.error, UpdateInfoError.minimumAboveLatest);
    });

    test('빌드 번호가 1 보다 작으면 notPositive', () {
      expect(
        UpdateInfo.parse(_json({'latest': 0, 'minimum': 0})).error,
        UpdateInfoError.notPositive,
      );
    });

    test('JSON 이 아니거나 맨 바깥이 표가 아니면 notJson', () {
      expect(UpdateInfo.parse('<html>').error, UpdateInfoError.notJson);
      expect(UpdateInfo.parse('[1, 2]').error, UpdateInfoError.notJson);
    });
  });

  group('UpdateDecision.decide (minimum 12, latest 13)', () {
    final cases = <int, UpdateDecision>{
      11: UpdateDecision.required,
      12: UpdateDecision.optional,
      13: UpdateDecision.none,
      14: UpdateDecision.none,
    }; // 내 빌드 번호 → 기대 판정
    for (final entry in cases.entries) {
      test('빌드 ${entry.key} → ${entry.value.name}', () {
        expect(UpdateDecision.decide(entry.key, _info()), entry.value);
      });
    }
  });
}
