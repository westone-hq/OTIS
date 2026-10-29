# GitHub에서 새 버전 준비

## 동작

`.github/workflows/prepare-release.yml`의 **새 버전 준비**를 `main`에서 수동 실행한다. 운영자는 버전 이름과 변경 내용만 입력한다. 운영자 PC에는 Git·Python·Flutter·Android Studio가 필요 없다.

1. 실행을 시작한 `main` 커밋의 `admin/설치업체.xlsx`를 읽는다.
2. `tool/import_workers.py`로 `assets/workers/workers.json`을 만든다.
3. `tool/prepare_release.py`가 버전·빌드·최소 허용 빌드 번호를 정한다.
4. Flutter 정적 분석·서식·테스트를 통과한 뒤 고정 릴리스 키로 APK를 만든다.
5. APK의 실제 패키지·버전·빌드·서명과 내부 명단을 검사한다.
6. 실제 APK 파일의 SHA-256으로 `version.json`을 만든다.
7. APK와 `version.json`을 첨부한 **Draft 릴리스**를 만든다. 제목은 입력 버전, 태그는 `v` + 입력 버전이다.
8. 운영자가 첨부 파일을 확인하고 직접 Latest로 게시한다. 자동화는 게시·Latest 전환을 하지 않는다.

엑셀 업로드 자체에는 실행되지 않는다. **Run workflow**를 누를 때 엑셀 변환부터 초안까지 진행한다. 측정 계산·로그인 판정·PDF 표현과 업데이트 서버 주소는 유지한다. 로컬 검증 중 재현된 Windows 파일 공유 위반은 아래 파일 접근 수정으로 처리했다.

## 개발 담당자 최초 설정

### 1. 파일 반영

검토한 작업 브랜치의 워크플로·도구·명단 엑셀을 `main`에 반영한다. `workflow_dispatch` 실행 버튼은 워크플로가 기본 브랜치에 있어야 나타난다.

main 반영 전 검증은 `feat/admin-release-workflow` 브랜치에 관련 파일을 push해서 실행한다. GitHub의 `push` 이벤트는 기본 브랜치에 워크플로가 없어도 해당 커밋으로 실행된다. 이 경로는 검증용 버전 `0.0.4`로 동일한 엑셀 변환·앱 검사·서명 빌드·APK 검사까지 수행하고, APK와 version.json을 Actions 아티팩트로 보관한다. 릴리스 초안 생성 단계는 main의 수동 실행에만 허용한다. 검증용 버전이 기존 배포본·초안과 겹치면 운영 준비와 같이 중단한다.

기존 루트의 `설치 업체 List_*.xlsx` 제외 규칙은 유지한다. 관리자가 올릴 입력은 **admin/설치업체.xlsx**로 고정한다. 현재 이 파일은 사용자가 수정한 엑셀에서 복사했고, 978명 중 추가한 한 명은 사번 `010613`이다.

파일 이름은 사용자 요청에 따라 `설치업체.xlsx`로 통일한다. Excel 통합 문서의 확장자는 `.xlsx`이며, `.xlxs`로 바꾸지 않는다.

### 2. GitHub Actions와 Secrets

저장소 **Settings → Actions → General**에서 Actions가 허용되어 있어야 한다. 조직 정책이 `contents: write`를 허용해야 초안을 만들 수 있다.

저장소 **Settings → Secrets and variables → Actions → New repository secret**에 다음 네 항목을 등록한다. 운영자에게 실제 값을 매뉴얼이나 화면으로 전달하지 않는다.

| Secret 이름 | 내용 |
|---|---|
| ANDROID_KEYSTORE_BASE64 | 기존 `vcheck-release.jks` 파일 전체를 Base64로 인코딩한 문자열 |
| ANDROID_STORE_PASSWORD | 키 저장소 비밀번호 |
| ANDROID_KEY_PASSWORD | 개인 키 비밀번호 |
| ANDROID_KEY_ALIAS | 키 별칭. 현재 배포 설정은 `vcheck` |

키 저장소와 개인 키 비밀번호가 같은 경우에도 두 Secret은 각각 등록한다. Base64는 인코딩이므로 평문 파일처럼 취급하고 로그·이슈·일반 저장소 파일에 넣지 않는다. Secrets의 실제 값은 소스나 매뉴얼에 적지 않는다.

키 복원과 APK 검사 모두 [release.md](release.md)에 기록된 기존 릴리스 인증서 SHA-256과 일치해야 통과한다. 다른 키로 우회 빌드하거나 새 키를 생성하지 않는다. 임시 키와 `android/key.properties`는 작업 종료 때 정리한다.

2026-10-29 기존 키와 비밀번호를 검증한 뒤 위 네 Repository Secrets를 등록했다. 실제 값은 소스나 로그에 남기지 않는다. 새 저장소로 옮길 때는 위 최초 설정을 다시 진행한다. 실제 Actions 실행 결과와 운영 릴리스 게시 여부는 별도로 확인한다.

## 버전과 빌드 번호

- 입력은 `0.0.4`처럼 세 자리 정식 버전이다. `v0.0.4`·시험판 접미사는 입력하지 않는다.
- 기존 소스·게시본·초안의 버전보다 높아야 한다. 같은 태그가 이미 있으면 중단한다.
- 빌드 번호는 소스의 `+` 뒤 번호와 기존 `version.json`들 중 최댓값에 1을 더한다. 아직 게시하지 않은 초안도 포함해 충돌을 막는다.
- `minimum`은 현재 Latest의 값을 그대로 이어받는다. 이 자동화에서 필수 업데이트로 바꾸지 않는다.
- `pubspec.yaml`은 커밋하지 않고 `flutter build apk --build-name ... --build-number ...`로 새 값을 적용한다.
- 엑셀 변환 결과 역시 빌드 작업 폴더에서만 생성한다. 후속 로컬 빌드는 `python tool/import_workers.py admin/설치업체.xlsx assets/workers/workers.json`을 먼저 실행한다.
- 여러 실행은 같은 concurrency 그룹에서 순서대로 진행한다. GitHub의 동시 실행 제한에 따라 대기 중인 이전 요청이 취소될 수 있으므로 운영자는 한 번에 한 버전만 실행하고 완료를 기다린다.

## 검증과 실패

Python 검사는 `python -m unittest discover -s tool/tests -p 'test_*.py' -v`로 실행한다. 중복 사번·빈 필수값·0명 명단·앞 0 보존·초안 빌드 번호 예약·서명키 불일치·APK 내장 명단 불일치를 검사한다.

2026-10-29 로컬 확인: 배포 도구 21개 검사, actionlint 워크플로 검사, Flutter 정적 분석·서식 검사, Android 디버그 빌드가 통과했다. 전체 Flutter 검사는 566개 통과, 4개 예정 건너뜀이다. 기존 키와 전달받은 비밀번호로 `0.0.4+4` 릴리스 APK 빌드에도 성공했다. APK의 실제 서명·패키지·버전·978명 명단과 앞 0을 유지한 사번 010613을 확인했고, 임시 키와 설정을 정리했다.

2026-10-29 실제 GitHub Ubuntu [브랜치 검증 실행](https://github.com/westone-hq/OTIS/actions/runs/40837836409)도 성공했다. 검사한 코드 커밋은 `641cce05020bb1011c262f208f82cc7e10d1138c`이다. 배포 도구 21개 검사, 정적 분석, 서식(160파일 변경 없음), Flutter 검사 564개 통과, 실제 서명 APK 빌드와 APK 검사, 아티팩트 업로드를 모두 확인했다. 예정 건너뜀 6개는 화면 캡처 전용 3개와 Windows 전용 공유 위반 검사 3개다. Windows 전용 검사는 위 로컬 전체 검사에서 통과했다.

성공한 실행의 [아티팩트](https://github.com/westone-hq/OTIS/actions/runs/40837836409/artifacts/12881049739)를 내려받아 APK와 version.json 두 파일만 들어 있는지, APK 서명이 기존 배포본과 같은지, 실제 APK의 SHA-256·패키지·버전 `0.0.4+4`·978명 명단·사번 `010613`이 일치하는지도 별도로 확인했다. `minimum`은 기존 값 1을 유지했다. 브랜치 검증은 운영 초안을 생성하지 않으며, main 병합이나 Latest 게시도 수행하지 않았다. 운영 초안의 실제 생성은 main 반영 후 수동 실행으로 확인해야 한다.

### Windows 파일 잠금 수정

표준 Dart 코드로 새 집계 파일 100건을 기록했을 때도 Windows 공유 위반(오류 32)이 16건 재현됐다. 파일 열기만 10·20·40·80·160ms 간격으로 제한 재시도하는 `StorageFileAccess`와 `TextFileWriter`를 추가했다. 이미 시작한 쓰기를 재시도하지 않아 덧붙인 내용이 중복되지 않는다. Android와 다른 운영체제에서는 재시도하지 않고, 다른 오류도 즉시 전달한다.

`MetaWriter`와 측정 원본 이동의 집계 기록이 이 기록기를 사용한다. 측정 폴더 삭제·보관 개수 정리와 관련 시험의 임시 폴더 정리에도 같은 공유 위반 정책을 사용한다. 계산식·판정값·집계 문자열은 유지한다. 수정 후 동일한 재현 검사는 100건 모두 통과했고, 파일 쓰기 실패 전파·핸들 닫기·재시도 상한·한글·CRLF·중복 없는 덧붙이기·폴더 삭제 회귀 검사를 추가했다.

워크플로의 Flutter는 현재 프로젝트에서 쓰는 **3.44.4 커밋**으로 고정했고, 공식 setup·checkout·artifact Actions도 확인한 커밋으로 고정했다. Android SDK 36·Build Tools 36.0.0·NDK 28.2.13676358을 준비한다.

브랜치의 실제 실행에서 확인한 환경 차이도 반영했다. Android 도구는 SDK의 설치 경로로 호출하고, Flutter는 버전 태그를 받은 뒤 고정 커밋과 일치하는지 확인한다. 기존 검사의 `DateTime(...)` 입력과 고정 파일 이름은 한국 현지 시각 기준이므로 실행 환경의 `TZ`를 `Asia/Seoul`로 명시한다. 앱의 한국 시각 환산 코드나 검사 기대값은 바꾸지 않는다.

실패하면 릴리스 초안을 만들지 않는다. 예외적으로 업로드 후 네트워크 오류가 발생하면 Draft가 남을 수 있으므로 같은 버전을 다시 실행하기 전 Releases를 확인한다. 같은 태그를 덮어쓰는 기능은 없다.

배포 파일 아티팩트에는 APK와 version.json 두 개만 넣고 14일 보관한다. 키 파일·비밀번호·엑셀은 넣지 않는다. 릴리스 초안이 만들어지기 전 작업이 실패했을 때 이 아티팩트를 배포 승인으로 간주하지 않는다.

## 확인할 화면

관리자 매뉴얼의 실제 GitHub 사진은 main 반영과 Secrets 설정 후 촬영한다. 필요한 화면은 `admin` 파일 업로드, Actions 입력(version·notes·main), 성공한 실행과 명단 인원수, APK·version.json이 첨부된 Draft, Latest 게시 결과이다. 비밀번호나 Secrets 입력값은 촬영하지 않는다.
