import argparse
import base64
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import openpyxl

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import import_workers
import prepare_release as release


def manifest(build=3, version='0.0.2', minimum=1):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: manifest
    목적: 번호 판정용 기존 배포 안내를 만든다.
    반환: 빌드·버전·최소 허용 번호
    """
    return {'latest': build, 'latestName': version, 'minimum': minimum}


class VersionPlanTest(unittest.TestCase):
    """작성: 2026-10-29 15:17:49 · Codex
    클래스: VersionPlanTest
    목적: 잘못된 버전 입력과 초안 사이의 빌드 번호 충돌을 막는지 확인한다.
    """

    def test_invalid_names_are_rejected(self):
        for value in ['v0.0.4', '0.04.0', '0.0.4-rc1', '0.0.4\n', '$(echo x)', '../x', None]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.version_parts(value)

    def test_published_build_and_minimum_are_preserved(self):
        latest = manifest(20, '0.0.3', 7)
        plan = release.release_plan('0.0.4', 'version: 0.0.2+3\n', [], [latest], latest)
        self.assertEqual((plan['build'], plan['minimum'], plan['tag']), (21, 7, 'v0.0.4'))

    def test_unpublished_draft_reserves_build_number(self):
        releases = [{'tag_name': 'v0.0.3', 'draft': True}]
        plan = release.release_plan('0.0.4', 'version: 0.0.2+3', releases, [manifest(10, '0.0.3')], manifest())
        self.assertEqual(plan['build'], 11)

    def test_existing_version_cannot_be_overwritten(self):
        with self.assertRaisesRegex(ValueError, '이미'):
            release.release_plan('0.0.4', 'version: 0.0.2+3', [{'tag_name': 'v0.0.4'}], [], manifest())

    def test_version_must_advance_past_source_and_drafts(self):
        for version in ['0.0.2', '0.0.3']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.release_plan(version, 'version: 0.0.2+3', [{'tag_name': 'v0.0.3'}], [], manifest())

    def test_bad_minimum_and_boolean_build_are_rejected(self):
        for bad in [manifest(3, minimum=4), manifest(True), manifest(3, minimum=0)]:
            with self.subTest(value=bad), self.assertRaises(ValueError):
                release.validate_manifest(bad)

    def test_build_limit_is_checked(self):
        with self.assertRaises(ValueError):
            release.release_plan('0.0.4', f'version: 0.0.2+{release.MAX_BUILD}', [], [], None)


class ExcelPreparationTest(unittest.TestCase):
    """작성: 2026-10-29 15:17:49 · Codex
    클래스: ExcelPreparationTest
    목적: 실제 변환기로 사번의 앞 0과 네 열을 유지하고 오류 때 원본을 지키는지 확인한다.
    """

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'admin').mkdir()
        (self.root / 'assets/workers').mkdir(parents=True)
        (self.root / 'pubspec.yaml').write_text('version: 0.0.2+3\n', encoding='utf-8')
        self.target = self.root / 'assets/workers/workers.json'
        self.target.write_text('{"unchanged": true}', encoding='utf-8')

    def workbook(self, rows):
        book = openpyxl.Workbook()
        book.active.append(import_workers.EXPECTED_HEADER)
        for row in rows:
            book.active.append(row)
        book.save(self.root / 'admin/workers.xlsx')
        book.close()

    def args(self):
        return argparse.Namespace(root=self.root, repository='westone-hq/OTIS', version='0.0.4', source_sha='a' * 40, plan=self.root / 'plan.json')

    def api(self, endpoint, **kwargs):
        if '/releases?' in endpoint:
            return [[{'id': 1, 'tag_name': 'v0.0.2', 'draft': False, 'prerelease': False, 'assets': [{'id': 10, 'name': 'version.json'}]}]]
        if '/releases/assets/10' in endpoint:
            return manifest()
        if endpoint.endswith('/releases/latest'):
            return {'id': 1}
        if '/matching-refs/' in endpoint:
            return []
        raise AssertionError(endpoint)

    def test_workbook_conversion_keeps_zero_and_four_fields(self):
        self.workbook([['010613', '작업자', '업체', '관리팀']])
        before = (self.root / 'admin/workers.xlsx').read_bytes()
        with patch.object(release, 'github_api', side_effect=self.api), patch.dict(os.environ, {'RELEASE_NOTES': '명단 갱신'}), contextlib.redirect_stdout(io.StringIO()):
            release.prepare(self.args())
        worker = json.loads(self.target.read_text(encoding='utf-8'))['workers'][0]
        self.assertEqual(worker, {'id': '010613', 'name': '작업자', 'company': '업체', 'team': '관리팀'})
        plan = json.loads(self.args().plan.read_text(encoding='utf-8'))
        self.assertEqual((plan['build'], plan['worker_count']), (4, 1))
        self.assertEqual(before, (self.root / 'admin/workers.xlsx').read_bytes())

    def test_duplicate_ids_fail_before_replacing_old_json(self):
        self.workbook([['t00001', '갑', None, None], ['T00001', '을', None, None]])
        before = self.target.read_bytes()
        with patch.object(release, 'github_api', side_effect=self.api), self.assertRaises(SystemExit):
            release.prepare(self.args())
        self.assertEqual(before, self.target.read_bytes())
        self.assertFalse(self.args().plan.exists())

    def test_missing_name_fails(self):
        self.workbook([['010613', None, None, None]])
        with patch.object(release, 'github_api', side_effect=self.api), self.assertRaises(SystemExit):
            release.prepare(self.args())

    def test_incomplete_draft_does_not_allow_build_number_reuse(self):
        self.workbook([['010613', '작업자', None, None]])
        incomplete = [[{'id': 2, 'tag_name': 'v0.0.3', 'draft': True, 'prerelease': False, 'assets': [{'id': 10, 'name': 'vcheck-0.0.3.apk'}]}]]
        with patch.object(release, 'github_api', return_value=incomplete), self.assertRaisesRegex(ValueError, 'APK만'):
            release.prepare(self.args())
        self.assertFalse(self.args().plan.exists())

    def test_existing_tag_without_release_is_rejected(self):
        self.workbook([['010613', '작업자', None, None]])
        def api(endpoint, **kwargs):
            if '/matching-refs/' in endpoint:
                return [{'ref': 'refs/tags/v0.0.4'}]
            return self.api(endpoint, **kwargs)
        with patch.object(release, 'github_api', side_effect=api), self.assertRaisesRegex(ValueError, '태그'):
            release.prepare(self.args())
        self.assertFalse(self.args().plan.exists())

    def test_empty_roster_is_not_released(self):
        self.workbook([])
        before = self.target.read_bytes()
        with patch.object(release, 'github_api', side_effect=self.api), contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(SystemExit, '0명'):
            release.prepare(self.args())
        self.assertFalse(self.args().plan.exists())
        self.assertEqual(before, self.target.read_bytes())


class SigningTest(unittest.TestCase):
    """작성: 2026-10-29 15:17:49 · Codex
    클래스: SigningTest
    목적: Secrets 누락·다른 키·속성값 손상으로 잘못 서명하는 일을 막는지 확인한다.
    """

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        (root / 'android').mkdir()
        self.args = argparse.Namespace(root=root, keystore=root / 'private/temporary.jks')
        self.values = {
            'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'key-test-only').decode(),
            'ANDROID_STORE_PASSWORD': ' pass\\한글\n',
            'ANDROID_KEY_PASSWORD': 'different-password',
            'ANDROID_KEY_ALIAS': 'vcheck',
        }

    def test_missing_secret_fails_without_creating_key(self):
        with patch.dict(os.environ, {}, clear=True), self.assertRaisesRegex(ValueError, 'Secrets'):
            release.configure_signing(self.args)
        self.assertFalse(self.args.keystore.exists())

    def test_wrong_certificate_is_rejected_and_key_removed(self):
        with patch.dict(os.environ, self.values), patch.object(release, 'command', return_value=b'wrong-certificate'), self.assertRaisesRegex(ValueError, '인증서'):
            release.configure_signing(self.args)
        self.assertFalse(self.args.keystore.exists())
        self.assertFalse((self.args.root / 'android/key.properties').exists())

    def test_valid_key_properties_preserve_special_characters(self):
        certificate = b'test-certificate'
        capture = io.StringIO()
        with patch.dict(os.environ, self.values), patch.object(release, 'command', return_value=certificate) as run, patch.object(release, 'EXPECTED_SIGNER_SHA256', hashlib.sha256(certificate).hexdigest()), contextlib.redirect_stdout(capture):
            release.configure_signing(self.args)
        properties = (self.args.root / 'android/key.properties').read_text(encoding='ascii')
        self.assertIn('storePassword=\\ pass\\\\\\ud55c\\uae00\\n\n', properties)
        self.assertNotIn(self.values['ANDROID_STORE_PASSWORD'], capture.getvalue())
        self.assertIn('-storepass:env', run.call_args.args[0])
        self.assertNotIn(self.values['ANDROID_STORE_PASSWORD'], run.call_args.args[0])

    def test_properties_escape_non_bmp_unicode(self):
        self.assertEqual(release.java_property('😀'), '\\ud83d\\ude00')


class ApkValidationTest(unittest.TestCase):
    """작성: 2026-10-29 15:17:49 · Codex
    클래스: ApkValidationTest
    목적: 생성된 APK의 서명·버전·패키지·실제 내장 명단을 함께 검증한다.
    """

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.workers = json.dumps({'workers': [{'id': '010613', 'name': '작업자'}]}).encode()
        self.plan = {'version': '0.0.4', 'build': 4, 'minimum': 1, 'worker_count': 1, 'workers_sha256': hashlib.sha256(self.workers).hexdigest(), 'repository': 'westone-hq/OTIS', 'tag': 'v0.0.4', 'apk_name': 'vcheck-0.0.4.apk', 'notes': '명단 갱신', 'source_sha': 'a' * 40, 'workbook_sha256': 'b' * 64}
        self.apk = self.root / 'app.apk'
        with zipfile.ZipFile(self.apk, 'w') as archive:
            archive.writestr(release.APK_WORKERS_PATH, self.workers)
        self.signature = 'Signer #1 certificate SHA-256 digest: ' + release.EXPECTED_SIGNER_SHA256 + '\n'

    def validate(self, **overrides):
        values = {'apk': self.apk, 'plan': self.plan, 'signature': self.signature, 'application_id': release.PACKAGE_NAME, 'version_name': '0.0.4', 'version_code': '4'}
        values.update(overrides)
        release.validate_apk(**values)

    def test_valid_apk_matches_plan(self):
        self.validate()

    def test_old_roster_or_wrong_signer_is_rejected(self):
        with self.assertRaises(ValueError):
            self.validate(signature=self.signature.replace(release.EXPECTED_SIGNER_SHA256, '0' * 64))
        with self.assertRaises(ValueError):
            self.validate(plan={**self.plan, 'workers_sha256': '0' * 64})

    def test_wrong_package_or_version_is_rejected(self):
        for field, value in [('application_id', 'other.app'), ('version_name', '0.0.3'), ('version_code', '3')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.validate(**{field: value})

    def test_finalize_hashes_actual_apk_and_preserves_minimum(self):
        plan_path = self.root / 'plan.json'
        release.write_json(plan_path, {**self.plan, 'minimum': 2})
        args = argparse.Namespace(plan=plan_path, apk=self.apk, apksigner=Path('apksigner'), apkanalyzer=Path('apkanalyzer'), output=self.root / 'out', notes=self.root / 'notes.md')
        responses = [self.signature, release.PACKAGE_NAME, '0.0.4', '4']
        with patch.object(release, 'command', side_effect=responses), contextlib.redirect_stdout(io.StringIO()):
            release.finalize(args)
        value = json.loads((args.output / 'version.json').read_text(encoding='utf-8'))
        self.assertEqual(set(value), {'latest', 'latestName', 'minimum', 'apkUrl', 'sha256', 'notes'})
        self.assertEqual(value['minimum'], 2)
        self.assertEqual(value['sha256'], hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(value['apkUrl'], 'https://github.com/westone-hq/OTIS/releases/download/v0.0.4/vcheck-0.0.4.apk')
        self.assertEqual({p.name for p in args.output.iterdir()}, {'vcheck-0.0.4.apk', 'version.json'})


if __name__ == '__main__':
    unittest.main()
