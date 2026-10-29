import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

from import_workers import main as import_workers


# 작성: 2026-10-29 15:17:49 · Codex
# 변수: EXPECTED_SIGNER_SHA256
# 목적: 기존 설치본과 이어지는 릴리스 인증서만 허용한다.
# 근거: 인용 — docs/release.md의 2026-10-27 릴리스 인증서 지문
EXPECTED_SIGNER_SHA256 = '985405947be9a646338c11815a441df9ec7d47a451e8dd504b1b173d35a704bf'
VERSION_PATTERN = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')
MAX_BUILD = 2_100_000_000
PACKAGE_NAME = 'com.otis.vibration_checker'
APK_WORKERS_PATH = 'assets/flutter_assets/assets/workers/workers.json'


def version_parts(value):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: version_parts
    목적: 정식 버전 이름만 받아 태그와 파일 경로에 입력값이 섞이지 않게 한다.
    인자: value — v 접두사 없는 세 자리 버전 이름
    반환: 숫자 세 개. 형식이 틀리면 ValueError
    """
    if not isinstance(value, str) or not VERSION_PATTERN.fullmatch(value):
        raise ValueError('버전은 0.0.4처럼 숫자 세 자리로 입력한다(v 제외).')
    return tuple(map(int, value.split('.')))


def validate_manifest(value):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: validate_manifest
    목적: 기존 배포 정보의 빌드 번호와 최소 허용 번호를 검증한다.
    인자: value — 기존 version.json
    반환: 검증한 사전. 형식이 틀리면 ValueError
    """
    if not isinstance(value, dict):
        raise ValueError('기존 version.json이 객체가 아니다.')
    latest, minimum = value.get('latest'), value.get('minimum')
    if type(latest) is not int or type(minimum) is not int:
        raise ValueError('기존 version.json의 빌드 번호가 정수가 아니다.')
    if not 1 <= minimum <= latest <= MAX_BUILD:
        raise ValueError('기존 version.json의 빌드 번호 범위가 잘못되었다.')
    version_parts(value.get('latestName'))
    return value


def release_plan(version, pubspec, releases, manifests, latest_manifest):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: release_plan
    목적: 게시본과 초안의 번호를 함께 비교해 새 버전과 빌드 번호를 정한다.
    인자: version — 요청 버전, pubspec — pubspec.yaml 내용,
          releases — 기존 릴리스, manifests — 그 릴리스의 버전 안내,
          latest_manifest — 현재 Latest의 버전 안내 또는 None
    반환: 새 버전·태그·빌드·최소 허용 번호
    """
    requested = version_parts(version)
    match = re.search(r'^version:\s*([0-9.]+)\+([0-9]+)\s*$', pubspec, re.MULTILINE)
    if not match:
        raise ValueError('pubspec.yaml에서 버전과 빌드 번호를 찾지 못했다.')
    versions = [version_parts(match[1])]
    builds = [int(match[2])]
    tag = 'v' + version
    for release in releases:
        existing_tag = release.get('tag_name', '')
        if existing_tag == tag:
            raise ValueError(f'{tag} 릴리스 또는 초안이 이미 있다. 새 버전을 입력한다.')
        candidate = existing_tag.removeprefix('v')
        if VERSION_PATTERN.fullmatch(candidate):
            versions.append(version_parts(candidate))
    for manifest in manifests:
        checked = validate_manifest(manifest)
        versions.append(version_parts(checked['latestName']))
        builds.append(checked['latest'])
    if latest_manifest is not None:
        checked = validate_manifest(latest_manifest)
        versions.append(version_parts(checked['latestName']))
        builds.append(checked['latest'])
    if requested <= max(versions):
        raise ValueError('소스·기존 릴리스·초안보다 높은 버전을 입력한다.')
    build = max(builds) + 1
    if build > MAX_BUILD:
        raise ValueError('Android 빌드 번호 상한을 넘었다.')
    return {
        'version': version,
        'tag': tag,
        'build': build,
        'minimum': latest_manifest['minimum'] if latest_manifest is not None else 1,
        'apk_name': f'vcheck-{version}.apk',
    }


def command(arguments, *, binary=False):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: command
    목적: 외부 도구 실패를 숨기지 않고 중단한다. 비밀번호 인자는 사용하지 않는다.
    인자: arguments — 셸을 거치지 않는 인자 목록, binary — 바이너리 출력 여부
    반환: 표준 출력
    """
    result = subprocess.run(arguments, capture_output=True, text=not binary, check=False)
    if result.returncode:
        detail = result.stderr.decode(errors='replace') if binary else result.stderr
        raise ValueError(f'{Path(arguments[0]).name} 실행 실패: {detail.strip()}')
    return result.stdout


def github_api(endpoint, *, asset=False, pages=False):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: github_api
    목적: gh가 인증과 다운로드 리다이렉트를 처리하게 하고 응답 JSON을 읽는다.
    인자: endpoint — GitHub API 경로, asset — 첨부 파일 다운로드,
          pages — 모든 페이지를 한 배열로 받는지
    반환: API 응답 자료
    """
    args = ['gh', 'api', endpoint]
    if asset:
        args += ['-H', 'Accept: application/octet-stream']
    if pages:
        args += ['--paginate', '--slurp']
    return json.loads(command(args))


def write_json(path, value):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: write_json
    목적: 한글과 줄바꿈을 유지해 배포 정보를 기록한다.
    인자: path — 출력 파일, value — JSON 자료
    반환: 없음
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def prepare(args):
    """작성: 2026-10-29 15:17:49 · Codex
    수정: 2026-10-29 17:05:27 · Codex
    함수: prepare
    목적: 선택한 커밋의 `설치업체.xlsx`를 변환하고 기존 배포 정보로 빌드 계획을 만든다.
    인자: args — 저장소·버전·원본 커밋·작업 경로
    반환: 없음. 계획 파일과 GitHub 출력값을 기록한다
    """
    version_parts(args.version)
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repository):
        raise ValueError('저장소 이름 형식이 잘못되었다.')
    root = args.root.resolve()
    base = f'repos/{args.repository}'
    pages = github_api(base + '/releases?per_page=100', pages=True)
    releases = [release for page in pages for release in page]
    manifests = []
    by_release = {}
    for release in releases:
        assets = release.get('assets', [])
        if any(asset['name'].endswith('.apk') for asset in assets) and not any(asset['name'] == 'version.json' for asset in assets):
            raise ValueError(f'{release["tag_name"]}에 APK만 있고 version.json이 없다. 미완료 릴리스를 확인한다.')
        for asset in assets:
            if asset['name'] == 'version.json':
                manifest = validate_manifest(github_api(f'{base}/releases/assets/{asset["id"]}', asset=True))
                manifests.append(manifest)
                by_release[release['id']] = manifest
    latest_manifest = None
    if any(not r['draft'] and not r['prerelease'] for r in releases):
        latest = github_api(base + '/releases/latest')
        if latest['id'] not in by_release:
            raise ValueError('현재 Latest 릴리스에 version.json이 없다.')
        latest_manifest = by_release[latest['id']]
    tag_refs = github_api(f'{base}/git/matching-refs/tags/v{args.version}')
    if any(ref['ref'] == f'refs/tags/v{args.version}' for ref in tag_refs):
        raise ValueError('같은 태그가 이미 있다. 새 버전을 입력한다.')
    plan = release_plan(args.version, (root / 'pubspec.yaml').read_text(encoding='utf-8'), releases, manifests, latest_manifest)
    source = root / 'admin/설치업체.xlsx'
    target = root / 'assets/workers/workers.json'
    import_workers(str(source), str(target))
    workers = json.loads(target.read_text(encoding='utf-8'))['workers']
    if not workers:
        raise ValueError('명단이 0명이다. 엑셀을 확인한다.')
    plan.update({
        'repository': args.repository,
        'source_sha': args.source_sha,
        'worker_count': len(workers),
        'workbook_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'workers_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'notes': os.environ.get('RELEASE_NOTES', '').strip(),
    })
    write_json(args.plan, plan)
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a', encoding='utf-8') as stream:
            for key in ['version', 'tag', 'build', 'minimum', 'apk_name', 'worker_count']:
                stream.write(f'{key}={plan[key]}\n')
    print(f'새 버전 {plan["version"]}, 빌드 {plan["build"]}, 명단 {len(workers)}명')


def java_property(value):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: java_property
    목적: 비밀번호의 공백·역슬래시·한글이 Java Properties에서 바뀌지 않게 한다.
    인자: value — 속성값 원문
    반환: ASCII 속성값
    """
    result = []
    escapes = {'\\': '\\\\', '\n': '\\n', '\r': '\\r', '\t': '\\t', '\f': '\\f', ' ': '\\ '}
    for char in value:
        if char in escapes:
            result.append(escapes[char])
        elif 32 <= ord(char) < 127:
            result.append(char)
        else:
            encoded = char.encode('utf-16-be')
            result.extend('\\u' + encoded[i:i + 2].hex() for i in range(0, len(encoded), 2))
    return ''.join(result)


def configure_signing(args):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: configure_signing
    목적: Secrets의 기존 키를 임시 복원하고 인증서 일치 후 빌드 설정을 만든다.
    인자: args — 프로젝트와 임시 키 파일 경로
    반환: 없음. 비밀번호와 키 내용은 출력하지 않는다
    """
    names = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD', 'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS']
    values = {name: os.environ.get(name, '') for name in names}
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise ValueError('GitHub Secrets 누락: ' + ', '.join(missing))
    if (args.root / 'android/key.properties').exists():
        raise ValueError('기존 key.properties를 덮어쓰지 않는다.')
    key = base64.b64decode(values['ANDROID_KEYSTORE_BASE64'], validate=True)
    if not key:
        raise ValueError('서명 키 파일이 비어 있다.')
    args.keystore.parent.mkdir(parents=True, exist_ok=True)
    args.keystore.write_bytes(key)
    args.keystore.chmod(0o600)
    try:
        certificate = command([
            'keytool', '-exportcert', '-alias', values['ANDROID_KEY_ALIAS'],
            '-keystore', str(args.keystore), '-storepass:env', 'ANDROID_STORE_PASSWORD',
        ], binary=True)
        if hashlib.sha256(certificate).hexdigest() != EXPECTED_SIGNER_SHA256:
            raise ValueError('기존 배포본의 릴리스 인증서와 다르다. 키 설정을 확인한다.')
        properties = {
            'storeFile': args.keystore.resolve().as_posix(),
            'storePassword': values['ANDROID_STORE_PASSWORD'],
            'keyAlias': values['ANDROID_KEY_ALIAS'],
            'keyPassword': values['ANDROID_KEY_PASSWORD'],
        }
        destination = args.root / 'android/key.properties'
        destination.write_text(''.join(f'{k}={java_property(v)}\n' for k, v in properties.items()), encoding='ascii')
        destination.chmod(0o600)
    except BaseException:
        args.keystore.unlink(missing_ok=True)
        raise
    print('기존 릴리스 인증서 일치 확인 완료')


def validate_apk(apk, plan, signature, application_id, version_name, version_code):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: validate_apk
    목적: 다른 앱·버전·서명이나 오래된 명단을 잘못 배포하지 않게 검사한다.
    인자: apk — 완성된 APK, plan — 빌드 계획, signature — apksigner 출력,
          application_id, version_name, version_code — APK 매니페스트의 실제 값
    반환: 없음. 불일치하면 ValueError
    """
    signers = re.findall(r'^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]+)\s*$', signature, re.MULTILINE)
    if not signers or {value.lower() for value in signers} != {EXPECTED_SIGNER_SHA256}:
        raise ValueError('APK 서명 인증서가 기존 배포본과 다르다.')
    if application_id.strip() != PACKAGE_NAME:
        raise ValueError('APK 패키지 이름이 다르다.')
    if version_name.strip() != plan['version'] or version_code.strip() != str(plan['build']):
        raise ValueError('APK에 적용된 버전 또는 빌드 번호가 다르다.')
    with zipfile.ZipFile(apk) as archive:
        workers = archive.read(APK_WORKERS_PATH)
    if hashlib.sha256(workers).hexdigest() != plan['workers_sha256']:
        raise ValueError('APK에 포함된 명단이 이번 엑셀 변환 결과와 다르다.')
    if len(json.loads(workers)['workers']) != plan['worker_count']:
        raise ValueError('APK 명단 인원수가 다르다.')


def finalize(args):
    """작성: 2026-10-29 15:17:49 · Codex
    함수: finalize
    목적: 실제 APK를 검증해 APK와 일치하는 업데이트 안내·릴리스 설명을 만든다.
    인자: args — 계획·APK·Android 검증 도구·출력 경로
    반환: 없음. 출력 폴더에는 APK와 version.json 두 파일만 만든다
    """
    plan = json.loads(args.plan.read_text(encoding='utf-8'))
    signature = command([str(args.apksigner), 'verify', '--print-certs', str(args.apk)])
    manifest = [command([str(args.apkanalyzer), 'manifest', field, str(args.apk)]) for field in ['application-id', 'version-name', 'version-code']]
    validate_apk(args.apk, plan, signature, *manifest)
    if args.output.exists() and any(args.output.iterdir()):
        raise ValueError('배포 출력 폴더가 비어 있지 않다.')
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / plan['apk_name']
    shutil.copyfile(args.apk, destination)
    manifest = {
        'latest': plan['build'],
        'latestName': plan['version'],
        'minimum': plan['minimum'],
        'apkUrl': f'https://github.com/{plan["repository"]}/releases/download/{plan["tag"]}/{plan["apk_name"]}',
        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        'notes': plan['notes'],
    }
    write_json(args.output / 'version.json', manifest)
    notes = plan['notes'] or f'OTIS V-Check {plan["version"]}'
    notes += f'\n\n- 버전: {plan["version"]} / 빌드: {plan["build"]}\n- 명단: {plan["worker_count"]}명\n- 원본 커밋: `{plan["source_sha"]}`\n- 엑셀 SHA-256: `{plan["workbook_sha256"]}`\n\n운영자가 첨부 파일을 확인한 뒤 Latest로 게시합니다.\n'
    args.notes.write_text(notes, encoding='utf-8', newline='\n')
    print('APK 서명·버전·명단 검증 및 version.json 생성 완료')


def main():
    """작성: 2026-10-29 15:17:49 · Codex
    함수: main
    목적: GitHub Actions가 준비·서명·완료 검사를 단계별로 호출하게 한다.
    반환: 없음. 실패는 0이 아닌 종료 코드로 전달한다
    """
    parser = argparse.ArgumentParser(description='OTIS 릴리스 초안 준비')
    sub = parser.add_subparsers(dest='operation', required=True)
    prepare_parser = sub.add_parser('prepare')
    prepare_parser.add_argument('--root', type=Path, default=Path.cwd())
    prepare_parser.add_argument('--version', required=True)
    prepare_parser.add_argument('--repository', required=True)
    prepare_parser.add_argument('--source-sha', required=True)
    prepare_parser.add_argument('--plan', type=Path, required=True)
    signing_parser = sub.add_parser('signing')
    signing_parser.add_argument('--root', type=Path, default=Path.cwd())
    signing_parser.add_argument('--keystore', type=Path, required=True)
    final_parser = sub.add_parser('finalize')
    for name in ['plan', 'apk', 'apksigner', 'apkanalyzer', 'output', 'notes']:
        final_parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        {'prepare': prepare, 'signing': configure_signing, 'finalize': finalize}[args.operation](args)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
