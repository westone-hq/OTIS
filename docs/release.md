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

- 릴리스 키 인증서 SHA-256 (2026-10-13 생성, 별칭 `vcheck`):
  `309a7739c3b18f46a01dd5b442cafa7f0cc89a2efaf41da14dc213e07d1f3534`

지문 · 인증서 이름은 비밀이 아니다(APK 를 받은 누구나 볼 수 있다). 비밀은
키 파일과 비밀번호다.
