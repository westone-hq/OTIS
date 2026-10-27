# 릴리스 빌드와 서명 키

릴리스 APK 는 고정 릴리스 키 하나로만 서명한다(2026-10-13). 안드로이드는
설치된 앱과 서명 키가 같아야 덮어쓰기 업데이트를 받아 준다. 디버그 키는
컴퓨터마다 따로 만들어져, 빌드한 컴퓨터가 바뀌면 키도 바뀐다.

## 키 보관

- **키 파일(`.jks`)과 비밀번호는 저장소 밖 두 곳에 보관한다**(예: 암호화된
  USB + 비밀번호 관리자). 저장소 · 메일 · 메신저 · 클라우드 공유 폴더에
  올리지 않는다.
- **잃어버리면 같은 키를 다시 만들 수 없다.** 그때는 새 키로 서명할 수밖에
  없고, 기존 사용자는 앱을 지우고 다시 설치해야 한다. 지우면 기기에 저장한
  측정 결과도 함께 지워진다.
- 키 파일 위치는 이 문서에 적지 않는다. 빌드하는 컴퓨터의
  `android/key.properties` 에만 적는다.

## `android/key.properties`

빌드하는 컴퓨터마다 한 번 만든다. 저장소에 올리지 않는다(`.gitignore`,
`android/.gitignore`).

```properties
storeFile=<키 파일의 절대 경로, 슬래시 / 로 구분>
storePassword=<비밀번호>
keyAlias=vcheck
keyPassword=<비밀번호>
```

- 경로의 역슬래시(`\`)는 이 형식에서 이스케이프 문자라 쓰지 않는다.
  비밀번호에 역슬래시가 있으면 `\\` 로 두 번 쓴다.
- 이 파일이 없으면 `flutter build apk --release` 가 "android/key.properties
  가 없다" 로 멈춘다. 디버그 키로 조용히 넘어가지 않게 하려는 것이다.
  디버그 빌드(`flutter run`)는 이 파일 없이 된다.

## 키를 처음 만들 때 (한 번만)

이미 키가 있으면 만들지 않는다. 새 키는 기존 설치본과 이어지지 않는다.

```bash
keytool -genkeypair -v -keystore <저장소 밖 경로>/vcheck-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias vcheck
```

`keytool` 은 Android Studio 의 `jbr/bin/` 에 있다. 비밀번호는 직접 입력하고
명령줄 · 기록 파일에 남기지 않는다.

## 빌드와 서명 확인

```bash
flutter build apk --release
<Android SDK>/build-tools/<버전>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

`apksigner` 는 자바가 필요하다. PATH 에 자바가 없으면 Android Studio 의
`jbr` 폴더를 `JAVA_HOME` 으로 잡고 실행한다.

`apksigner` 가 보여 주는 인증서 SHA-256 지문이 아래 값과 같아야 한다.
다르면(특히 `CN=Android Debug`) 배포하지 않는다.

- 릴리스 키 인증서 SHA-256 (2026-10-27 생성, 별칭 `vcheck`, `CN=OTIS V-Check`):
  `985405947be9a646338c11815a441df9ec7d47a451e8dd504b1b173d35a704bf`
- 2026-10-13 키(`309a7739…3534`)는 쓰지 않는다(`docs/decisions.md`
  2026-10-27). 이 지문으로 서명된 APK 는 배포하지 않는다.

지문 · 인증서 이름은 비밀이 아니다(APK 를 받은 누구나 볼 수 있다). 비밀은
키 파일과 비밀번호다.

## 배포 (앱 안 업데이트, GitHub Releases)

구글 플레이 없이 배포 전용 공개 저장소의 릴리스로 배포한다. 앱은 켜질 때
그 저장소의 최신 릴리스 `version.json` 을 받아 새 버전이 있으면
"업데이트하세요" 창을 띄우고, 누르면 APK 를 받아 안드로이드 설치 화면을
연다(`UpdatePrompt` · `UpdateChecker` · `UpdateInstaller.kt`).

- 저장소: 소스 저장소 `westone-hq/OTIS`(공개)의 Releases 를 그대로 쓴다
  (2026-10-16). 주소는 `lib/domain/update/update_config.dart` 의
  `releaseRepository` 하나다. 앱은 로그인 없이 받으므로 저장소가 공개여야
  한다 — 비공개로 바꾸면 업데이트 확인이 조용히 실패한다. 이 저장소의
  "최신" 릴리스는 늘 앱 배포용이어야 한다(다른 용도의 릴리스를 최신으로
  올리면 앱이 그 릴리스에서 version.json 을 찾다 실패한다).
- 앱이 읽는 주소:
  `https://github.com/<주인>/<저장소>/releases/latest/download/version.json`
  — GitHub 가 가장 최근 릴리스로 넘겨 준다. 그래서 "최신" 으로 표시되는
  릴리스(Pre-release · Draft 아님)에 올려야 앱이 본다.
- 릴리스마다 자산 두 개: `vcheck-<버전>.apk`, `version.json`.

### version.json

```json
{
  "latest": 2,
  "latestName": "0.0.1",
  "minimum": 1,
  "apkUrl": "https://github.com/<주인>/<저장소>/releases/download/v0.0.1/vcheck-0.0.1.apk",
  "sha256": "<apk 의 SHA-256, 16진수 소문자 64자>",
  "notes": "사용자에게 보여 줄 한두 줄"
}
```

- `latest` · `minimum` 은 **빌드 번호**(pubspec `version:` 의 `+` 뒤)다.
  버전 이름(`+` 앞)이 아니다.
- `minimum` 보다 낮은 빌드는 업데이트하기 전까지 쓸 수 없다(닫을 수 없는
  창). 보통은 올리지 않는다. 예전 빌드에 측정을 틀리게 하는 문제가 있을
  때만 올린다.
- 앱은 아래 중 하나라도 걸리면 이 파일을 버리고 안내하지 않는다: 항목
  누락 · 자료형 다름 · `apkUrl` 이 https 가 아님 · `sha256` 형식 ·
  `minimum` > `latest`.
- 앱은 받은 APK 의 SHA-256 이 이 값과 다르면 설치하지 않는다.

### 절차

1. `pubspec.yaml` 의 `version:` 을 올린다. **빌드 번호(`+` 뒤)는 반드시
   올린다** — 안드로이드는 같거나 낮은 번호로 덮어쓰지 않는다.
2. `flutter build apk --release`, 위 "빌드와 서명 확인" 으로 릴리스 키
   지문을 확인한다.
3. `build/app/outputs/flutter-apk/app-release.apk` 를
   `vcheck-<버전>.apk` 로 이름을 바꾸고 `sha256sum vcheck-<버전>.apk` 로
   지문을 구한다.
4. `version.json` 을 쓴다(`apkUrl` 의 태그 · 파일 이름이 5 와 같아야 한다).
5. 배포 저장소에 태그 `v<버전>` 으로 릴리스를 만들고 두 파일을 올린다.
   예: `gh release create v0.0.1 vcheck-0.0.1.apk version.json -R <주인>/<저장소> --title 0.0.1 --notes "..."`
6. 실기기 한 대로 확인한다: 이전 빌드를 켜면 창이 뜨고, "업데이트" →
   (처음이면 설치 허용) → 받기 → 설치 → 다시 켰을 때 창이 없어야 한다.
