# UI ↔ 기능부(domain) 의존 계약

이 문서는 `lib/features/` 및 `lib/core/` 전 파일을 실제로 읽고, UI가 `lib/domain/` 이하에서
가져다 쓰는 모든 심볼과 데이터 모델 필드를 조사한 결과다. 기능부(센서 수집·신호 처리·지표 산출) 전면
재작성 시 이 문서에 기재된 시그니처를 유지하면 UI(재작성 대상 아님)는 수정 없이 계속 동작해야 한다.

조사 대상: `lib/core/router.dart`, `lib/core/theme.dart`, `lib/core/widgets/app_dialog.dart`,
`lib/features/auth/login_screen.dart`, `lib/features/history/history_screen.dart`,
`lib/features/home/home_screen.dart`, `lib/features/measure/measuring_screen.dart`,
`lib/features/measure/placement_sheet.dart`, `lib/features/measure/start_screen.dart`,
`lib/features/result/metric_card.dart`, `lib/features/result/result_screen.dart`,
`lib/features/settings/settings_screen.dart`, `lib/features/shared/measurement_session.dart`,
`lib/features/shared/send_email_sheet.dart` (총 14개, `lib/features/`·`lib/core/` 전체).

`lib/main.dart`는 지시된 조사 범위(`lib/features/`, `lib/core/`) 밖이지만 앱 진입점이 domain을
직접 호출하므로(§5 참고) 참고용으로 함께 확인했다. 표 대상에는 포함하지 않았다.

---

## 1. 요약

UI가 의존하는 기능부 파일과 파일당 사용 심볼(클래스/함수/상수/getter) 개수:

| 기능부 파일 | 사용 심볼 수 | 비고 |
|---|---|---|
| `lib/domain/auth_repository.dart` | 5 | instance, currentUserId, getAutoLoginId, login, logout |
| `lib/domain/prefs_store.dart` | 5 | instance, loadLastSite, saveLastSite, loadEmail, saveEmail |
| `lib/domain/measure/metrics_config.dart` | 5 | defaultConfig + 필드 4개 |
| `lib/domain/measure/measurement_engine.dart` | 4 | 생성자, sampleCount, addSamples, analyze |
| `lib/domain/sensor_channel.dart` | 7 | 생성자, useMock, sensorStream, checkSensorsAvailable, requestAudioPermission, startCapture, stopCapture |
| `lib/domain/measure/sensor_sample.dart` | 4 | 생성자(간접), tsUs, z, mgToMetersPerSecondSquared (+ 타입으로 광범위 사용, §3.2) |
| `lib/domain/repository/measurement_repository.dart` | 7 | instance, save, list, delete, load, getBaseDirectory, ensureReportPdf, ensureRawExcelFiles(8개, instance 포함) |
| `lib/domain/models/measurement_result.dart` | 6 (+필드 다수) | copyWith, mock, mockList, xExceeded, yExceeded, zExceeded, noiseExceeded (+ §3.1 필드 목록) |
| `lib/domain/measure/raw_sensor_diagnostics.dart` | 4 | RawSensorDiagnostics.fromSamples, ChannelStats(타입), selectRawPreviewSamples, formatRawSampleLine |
| `lib/domain/parse_raw.dart` | 1 | RawDataParser.parseEvimp1 |
| `lib/domain/report_generator.dart` | 1 | ReportGenerator.generateSummaryText |

**총 도메인 파일 11개, 콜러블 심볼 53개** (§2), **MeasurementResult 데이터 필드 약 30개** (§3.1) 별도.

---

## 2. 심볼별 계약

### 2.1 `lib/domain/auth_repository.dart`

#### `AuthRepository.instance`
- 구분: static 필드 (상수 아님, 런타임 할당)
- 정의 위치: `lib/domain/auth_repository.dart:8`
- 현재 시그니처: `static AuthRepository instance = LocalAuthRepository();`
- 호출 UI 파일: `lib/core/router.dart:23`, `lib/features/auth/login_screen.dart:48`, `lib/features/settings/settings_screen.dart:33,56,115,122`, `lib/features/shared/send_email_sheet.dart:63`
- 전달 인자: 없음 (정적 접근)
- 반환값 사용: 아래 개별 멤버 호출의 리시버로 사용

#### `AuthRepository.currentUserId` (getter)
- 구분: getter (추상 선언 `auth_repository.dart:10`, 구현 `auth_repository.dart:31`)
- 정의 위치: `lib/domain/auth_repository.dart:10` (abstract), `:31` (LocalAuthRepository 구현)
- 현재 시그니처: `String? get currentUserId;`
- 호출 UI 파일:
  - `lib/core/router.dart:23` — `final loggedIn = AuthRepository.instance.currentUserId != null;`
  - `lib/features/settings/settings_screen.dart:33` (`_loadEmail`)
  - `lib/features/settings/settings_screen.dart:56` (`_save`)
  - `lib/features/settings/settings_screen.dart:122` (`_buildProfileCard`)
  - `lib/features/shared/send_email_sheet.dart:63` (`_loadRecipient`)
- 전달 인자: 없음
- 반환값 사용:
  - router.dart: `null` 여부로 로그인 리다이렉트 분기(`/login` ↔ `/home`)
  - settings_screen.dart:33 — `PrefsStore.loadEmail(id)` 호출의 인자로 전달 (null이면 조기 return)
  - settings_screen.dart:56 — `PrefsStore.saveEmail(id, email)` 호출 조건부 인자
  - settings_screen.dart:122 — `userId ?? '미로그인'` 형태로 화면에 직접 표시
  - send_email_sheet.dart:63 — `PrefsStore.loadEmail(id)` 호출 조건부 인자

#### `AuthRepository.getAutoLoginId()`
- 구분: 인스턴스 메서드 (추상)
- 정의 위치: `lib/domain/auth_repository.dart:13` (abstract), `:34` (구현)
- 현재 시그니처: `Future<String?> getAutoLoginId();`
- 호출 UI 파일: `lib/main.dart:9` (범위 밖, 참고). **`lib/features/`·`lib/core/` 내에서는 호출하는 곳 없음.**
- 전달 인자: 없음
- 반환값 사용: main.dart에서 `await`만 하고 반환값 미사용(내부적으로 `AuthRepository.instance._currentUserId` 부수효과만 활용)

#### `AuthRepository.login(String id, String pw)`
- 구분: 인스턴스 메서드 (추상, `FormatException` 던질 수 있음)
- 정의 위치: `lib/domain/auth_repository.dart:16` (abstract), `:44` (구현)
- 현재 시그니처: `Future<bool> login(String id, String pw);`
- 호출 UI 파일: `lib/features/auth/login_screen.dart:48`
- 전달 인자: `_idCtl.text`(변수 `id`), `_pwCtl.text`(변수 `pw`) — 사용자 입력 원문 그대로, trim 없이 전달
- 반환값 사용: `await` 후 성공 시 `context.go('/home')`. `bool` 반환값 자체는 읽지 않음(무시) — 성공/실패는 예외 발생 여부로만 판단. `on FormatException catch (e)` → `e.message`를 `_error`에 담아 화면 표시. 그 외 예외는 고정 문자열 `'로그인 중 오류가 발생했습니다.'`로 대체 표시(원본 예외 내용은 버림)

#### `AuthRepository.logout()`
- 구분: 인스턴스 메서드 (추상)
- 정의 위치: `lib/domain/auth_repository.dart:22` (abstract), `:73` (구현)
- 현재 시그니처: `Future<void> logout();`
- 호출 UI 파일: `lib/features/settings/settings_screen.dart:115`
- 전달 인자: 없음
- 반환값 사용: `await` 후 `mounted` 체크, `context.go('/login')`으로 이동. 반환값(void) 없음

---

### 2.2 `lib/domain/prefs_store.dart`

#### `PrefsStore.instance`
- 구분: static 필드
- 정의 위치: `lib/domain/prefs_store.dart:7`
- 현재 시그니처: `static final PrefsStore instance = PrefsStore._();`
- 호출 UI 파일: `home_screen.dart:51,158`, `settings_screen.dart:35,58`, `send_email_sheet.dart:67`

#### `PrefsStore.loadLastSite()`
- 구분: 인스턴스 메서드
- 정의 위치: `lib/domain/prefs_store.dart:64`
- 현재 시그니처: `Future<Map<String, String?>> loadLastSite();` (반환 키: `jobNo`,`siteName`,`bottomFloor`,`topFloor`,`direction`,`model`)
- 호출 UI 파일: `lib/features/home/home_screen.dart:51` (`_loadSavedInputs`)
- 전달 인자: 없음
- 반환값 사용: 6개 키를 각각 `saved['jobNo']` 등으로 꺼내 null이 아니면 `setState`로 해당 `TextEditingController.text` 또는 `_direction`/`_model` 상태에 대입 (home_screen.dart:53-67). **키 이름이 바뀌면 이 6개 필드가 조용히 복원되지 않음.**

#### `PrefsStore.saveLastSite(Map<String, String?> siteMap)`
- 구분: 인스턴스 메서드
- 정의 위치: `lib/domain/prefs_store.dart:77`
- 현재 시그니처: `Future<void> saveLastSite(Map<String, String?> siteMap);`
- 호출 UI 파일: `lib/features/home/home_screen.dart:158`
- 전달 인자: 리터럴 Map `{'jobNo': jobNo, 'siteName': siteName, 'bottomFloor': bottomFloorStr, 'topFloor': topFloorStr, 'direction': _direction, 'model': _model}` (모두 지역 변수, 검증 통과 후 값)
- 반환값 사용: **`await` 없이 호출**(§5 발견사항 F1). Future 완료를 기다리지 않고 바로 다음 줄 `context.push('/start')` 실행

#### `PrefsStore.loadEmail(String id)`
- 구분: 인스턴스 메서드
- 정의 위치: `lib/domain/prefs_store.dart:50`
- 현재 시그니처: `Future<String?> loadEmail(String id);`
- 호출 UI 파일: `lib/features/settings/settings_screen.dart:35`, `lib/features/shared/send_email_sheet.dart:67`
- 전달 인자: `id` = `AuthRepository.instance.currentUserId` (non-null 확인된 변수)
- 반환값 사용:
  - settings_screen.dart: non-null이면 `_emailCtl.text`에 대입
  - send_email_sheet.dart: non-null·non-empty면 `_recipientEmail`에 대입하고 `_isEmailSet = true`

#### `PrefsStore.saveEmail(String id, String email)`
- 구분: 인스턴스 메서드
- 정의 위치: `lib/domain/prefs_store.dart:56`
- 현재 시그니처: `Future<void> saveEmail(String id, String email);`
- 호출 UI 파일: `lib/features/settings/settings_screen.dart:58`
- 전달 인자: `id`(currentUserId), `email` = `_emailCtl.text.trim()`(정규식 검증 통과 후)
- 반환값 사용: `await` 후 성공 스낵바 표시. 반환값(void) 없음

---

### 2.3 `lib/domain/measure/metrics_config.dart`

#### `MetricsConfig.defaultConfig`
- 구분: static const
- 정의 위치: `lib/domain/measure/metrics_config.dart:163`
- 현재 시그니처: `static const MetricsConfig defaultConfig = MetricsConfig();`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:155,326,327,328`
- 반환값 사용: 아래 4개 필드 접근의 리시버로만 사용됨 (그 외 필드는 UI 미접근, §4)

#### `MetricsConfig.micDbfsToDbaOffset`
- 구분: getter (final 필드)
- 정의 위치: `lib/domain/measure/metrics_config.dart:102`
- 현재 시그니처: `final double micDbfsToDbaOffset;` (기본값 85.0)
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:155`
- 전달 인자: 해당 없음 (getter)
- 반환값 사용: `_sensorManager.startCapture(...)` 호출 시 `micDbfsToDbaOffset:` named 인자로 그대로 전달

#### `MetricsConfig.minMeasureDurationSec`
- 구분: getter (final 필드)
- 정의 위치: `lib/domain/measure/metrics_config.dart:105`
- 현재 시그니처: `final double minMeasureDurationSec;` (기본값 8.0)
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:326`
- 반환값 사용: `_elapsedSeconds < MetricsConfig.defaultConfig.minMeasureDurationSec` — `_evaluateSaveGate`의 저동작(lowMotion) 판정 분기 조건 중 하나

#### `MetricsConfig.minValidMaxSpeed`
- 구분: getter (final 필드)
- 정의 위치: `lib/domain/measure/metrics_config.dart:106`
- 현재 시그니처: `final double minValidMaxSpeed;` (기본값 0.1)
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:327`
- 반환값 사용: `result.maxSpeed < MetricsConfig.defaultConfig.minValidMaxSpeed` — 동일 분기 조건

#### `MetricsConfig.minValidDistance`
- 구분: getter (final 필드)
- 정의 위치: `lib/domain/measure/metrics_config.dart:107`
- 현재 시그니처: `final double minValidDistance;` (기본값 0.5)
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:328`
- 반환값 사용: `result.distance < MetricsConfig.defaultConfig.minValidDistance` — 동일 분기 조건

---

### 2.4 `lib/domain/measure/measurement_engine.dart` — `MeasurementEngine`

#### 생성자 `MeasurementEngine({MetricsConfig config = MetricsConfig.defaultConfig})`
- 정의 위치: `lib/domain/measure/measurement_engine.dart:18`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:68` — `final MeasurementEngine _engine = MeasurementEngine();`
- 전달 인자: 없음 (기본 `config` 사용)

#### `MeasurementEngine.sampleCount` (getter)
- 정의 위치: `lib/domain/measure/measurement_engine.dart:21`
- 현재 시그니처: `int get sampleCount;`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:320`
- 반환값 사용: `_engine.sampleCount < 2` — `_evaluateSaveGate`에서 `noSamples` 판정

#### `MeasurementEngine.addSamples(List<SensorSample> samples)`
- 정의 위치: `lib/domain/measure/measurement_engine.dart:48`
- 현재 시그니처: `void addSamples(List<SensorSample> samples);`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:160`
- 전달 인자: `[sample]` — 센서 스트림 콜백에서 수신한 단일 `SensorSample`을 매번 1개짜리 리스트로 감싸 전달 (배치 아님, 콜백마다 호출)
- 반환값 사용: void, 없음

#### `MeasurementEngine.analyze({...})`
- 정의 위치: `lib/domain/measure/measurement_engine.dart:53`
- 현재 시그니처:
  ```dart
  MeasurementResult analyze({
    String? id,
    String jobNo = 'MOCK-JOB',
    String siteName = 'MOCK-SITE',
    int bottomFloor = 1,
    int topFloor = 10,
    String direction = '하부 → 상부',
    DateTime? dateTime,
  })
  ```
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:442-449`
- 전달 인자: `jobNo: siteData.site.jobNo`, `siteName: siteData.site.siteName`, `bottomFloor: siteData.bottomFloor`(int, 파싱됨), `topFloor: siteData.topFloor`(int), `direction: siteData.site.direction`, `dateTime: DateTime.now()`. **`id`는 UI가 전달하지 않음** — 엔진이 자동 생성한 id를 그대로 사용
- 반환값 사용: `MeasurementResult` 반환값을 `result` 지역 변수에 저장. 이후 `_evaluateSaveGate(result)`로 lowMotion 재판정 → `result.copyWith(lowMotionWarning: true)` 가능 → `MeasurementSession.instance.lastResult/lastResultId` 저장 → `MeasuringScreen.attemptSave()`로 저장 → `context.pushReplacement('/result/${finalResult.id}')`로 화면 전환

---

### 2.5 `lib/domain/sensor_channel.dart` — `SensorChannelManager`

#### 생성자 `SensorChannelManager({bool useMock = false})`
- 정의 위치: `lib/domain/sensor_channel.dart:29`
- 호출 UI 파일:
  - `lib/features/measure/measuring_screen.dart:22-23,50-51` — `final SensorChannelManager? sensorManager;`(위젯 주입 필드) / `widget.sensorManager ?? SensorChannelManager()`(인자 없이 기본 생성)
  - `lib/features/measure/start_screen.dart:15-16,29-30` — 동일 패턴
- 전달 인자: 두 화면 모두 위젯 생성자를 통해 테스트용으로 주입 가능하되, 실사용 시에는 인자 없이(`useMock` 기본값 `false`) 생성

#### `SensorChannelManager.useMock` (필드)
- 정의 위치: `lib/domain/sensor_channel.dart:27`
- 현재 시그니처: `final bool useMock;`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:152`
- 반환값 사용: `if (available && !_sensorManager.useMock)` — true면 mock 스트림 전환 없이 실제 캡처 진행 여부 분기

#### `SensorChannelManager.sensorStream` (getter)
- 정의 위치: `lib/domain/sensor_channel.dart:34`
- 현재 시그니처: `Stream<SensorSample> get sensorStream;`
- 호출 UI 파일: `lib/features/measure/measuring_screen.dart:157`
- 반환값 사용: `.listen((sample) { ... })` — 각 `SensorSample`을 받아 `_engine.addSamples([sample])` 호출 및 베이스라인/속도 적산(§2.6 SensorSample 참고)

#### `SensorChannelManager.checkSensorsAvailable()`
- 정의 위치: `lib/domain/sensor_channel.dart:53`
- 현재 시그니처: `Future<bool> checkSensorsAvailable();`
- 호출 UI 파일: `measuring_screen.dart:151`, `start_screen.dart:54`
- 반환값 사용:
  - measuring_screen.dart: `available && !useMock`이면 실제 캡처 시작, 아니면(디버그 한정) mock 스트림 구독
  - start_screen.dart: `_sensorsAvailable` state에 저장 → `StartScreen.canStartMeasure(available:, isDebug:)` 판정에 사용되어 측정 시작 버튼 활성화/경고 배너 표시 좌우

#### `SensorChannelManager.requestAudioPermission()`
- 정의 위치: `lib/domain/sensor_channel.dart:69`
- 현재 시그니처: `Future<bool> requestAudioPermission();`
- 호출 UI 파일: `measuring_screen.dart:119`
- 반환값 사용: `false`면 스낵바로 "소음 제외 측정" 안내 표시(빨간 배경, 4초)

#### `SensorChannelManager.startCapture({int targetSampleRate = 256, double calibrationOffsetDba = 0.0, double micDbfsToDbaOffset = 85.0})`
- 정의 위치: `lib/domain/sensor_channel.dart:82`
- 호출 UI 파일: `measuring_screen.dart:153-156`
- 전달 인자: `targetSampleRate: 256`(리터럴), `micDbfsToDbaOffset: MetricsConfig.defaultConfig.micDbfsToDbaOffset`(설정값). **`calibrationOffsetDba`는 UI가 전달하지 않음**(기본값 0.0 사용)
- 반환값 사용: `await`만 함, 반환값(void) 없음

#### `SensorChannelManager.stopCapture()`
- 정의 위치: `lib/domain/sensor_channel.dart:99`
- 호출 UI 파일: `measuring_screen.dart:248`
- 반환값 사용: `Future.wait` 내에서 `await`, 반환값(void) 없음

---

### 2.6 `lib/domain/measure/sensor_sample.dart` — `SensorSample`

#### `SensorSample.tsUs` (필드)
- 정의 위치: `lib/domain/measure/sensor_sample.dart:6`
- 현재 시그니처: `final int tsUs;`
- 호출 UI 파일: `measuring_screen.dart:158,178`
- 반환값 사용: `sample.tsUs > 0` 유효성 체크, `dt` 계산(`(sample.tsUs - _lastTsUs) / 1000000.0`)에 사용 — **UI가 직접 시간축 미분(속도 적분)을 수행**함, 도메인 엔진의 결과와 별개의 라이브 화면용 계산

#### `SensorSample.z` (필드)
- 정의 위치: `lib/domain/measure/sensor_sample.dart:9`
- 현재 시그니처: `final double z;`
- 호출 UI 파일: `measuring_screen.dart:163,174`
- 반환값 사용: 첫 1초 baseline 평균(`_baselineSumZ`) 누적, 이후 `(sample.z - _baselineZ) * SensorSample.mgToMetersPerSecondSquared`로 라이브 속도 표시용 가속도 산출 (UI 자체 로직)

#### `SensorSample.mgToMetersPerSecondSquared` (static const)
- 정의 위치: `lib/domain/measure/sensor_sample.dart:35`
- 현재 시그니처: `static const double mgToMetersPerSecondSquared = 0.00980665;`
- 호출 UI 파일: `measuring_screen.dart:175`
- 반환값 사용: mg → m/s² 단위 환산 상수로 곱셈에 직접 사용

#### `SensorSample` 타입 자체 (파라미터/필드 타입으로 사용)
- 호출 UI 파일:
  - `measuring_screen.dart:57` — `StreamSubscription<SensorSample>? _sensorSub;`
  - `result_screen.dart:9,499` — `List<SensorSample> samples` 파라미터로 받아 `selectRawPreviewSamples`/`formatRawSampleLine`에 그대로 전달(개별 필드 직접 접근 없음)
  - `models/measurement_result.dart`의 `rawSamples` 필드 타입(`List<SensorSample>?`)으로 `MeasurementResult`를 거쳐 UI에 전파(§3.1)

---

### 2.7 `lib/domain/repository/measurement_repository.dart` — `MeasurementRepository`

#### `MeasurementRepository.instance`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:18`
- 호출 UI 파일: `history_screen.dart:35,76,296,297,304`, `measuring_screen.dart:32`(정적 메서드 내부), `result_screen.dart:56`, `send_email_sheet.dart:110,113,122,123,128,144`

#### `MeasurementRepository.save(MeasurementResult result)`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:43`
- 현재 시그니처: `Future<Directory> save(MeasurementResult result);`
- 호출 UI 파일:
  - `measuring_screen.dart:32` (`MeasuringScreen.attemptSave` 내부) — `result`는 상위에서 전달받은 파라미터
  - `history_screen.dart:296` (디버그 전용 "샘플 복원" 버튼) — `MeasurementResult.mock` 전달
- 반환값 사용: `Directory` 반환 → `onSuccess?.call(dir)` 콜백으로 전파, 최종적으로 `measuring_screen.dart:481`에서 `'저장되었습니다 (경로: ${savedDir!.path})'` 스낵바에 경로 표시. 예외 발생 시 `attemptSave`는 `false` 반환(try/catch로 흡수)

#### `MeasurementRepository.list()`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:249`
- 현재 시그니처: `Future<List<MeasurementResult>> list();`
- 호출 UI 파일: `history_screen.dart:35`, `history_screen.dart:297`(디버그 전용)
- 반환값 사용: `list.isNotEmpty ? list : (kDebugMode ? MeasurementResult.mockList : [])` — `_items` state에 저장되어 `ListView.separated`로 렌더링

#### `MeasurementRepository.delete(String id)`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:304`
- 현재 시그니처: `Future<bool> delete(String id);`
- 호출 UI 파일: `history_screen.dart:76`(개별 삭제 확인 후), `history_screen.dart:304`(디버그 전용 "목록 비우기" 루프)
- 전달 인자: `item.id`
- 반환값 사용: **`bool` 반환값을 읽지 않음** — `try { await ... } catch (_) {}`로 감싸고, 성공 여부와 무관하게 `_items.removeWhere(...)`로 로컬 목록에서 항상 제거

#### `MeasurementRepository.load(String id)`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:278`
- 현재 시그니처: `Future<MeasurementResult?> load(String id);`
- 호출 UI 파일: `result_screen.dart:56`(`_loadFromRepository`), `send_email_sheet.dart:110`
- 전달 인자: `id`(위젯 파라미터 `widget.id`/`widget.jobId`)
- 반환값 사용:
  - result_screen.dart: non-null이면 `_result = loaded; _isRealSample = true`로 setState
  - send_email_sheet.dart: null이면 `MeasurementResult.mock`으로 폴백 후 **레포지토리를 우회해 더미 `report.pdf`/`raw.txt` 파일을 직접 디스크에 생성**(§5 발견사항 F5)

#### `MeasurementRepository.getBaseDirectory()`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:25`
- 현재 시그니처: `Future<Directory> getBaseDirectory();`
- 호출 UI 파일: `send_email_sheet.dart:113,122`
- 반환값 사용: `Directory('${baseDir.path}/${widget.jobId}')` 형태로 파일 경로 직접 조합에 사용

#### `MeasurementRepository.ensureReportPdf(String id)`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:230`
- 현재 시그니처: `Future<File?> ensureReportPdf(String id);`
- 호출 UI 파일: `send_email_sheet.dart:128`
- 전달 인자: `widget.jobId`
- 반환값 사용: non-null & exists면 `attachments`/`attachmentDescriptions`에 추가되어 이메일 첨부

#### `MeasurementRepository.ensureRawExcelFiles(String id)`
- 정의 위치: `lib/domain/repository/measurement_repository.dart:201`
- 현재 시그니처: `Future<List<File>> ensureRawExcelFiles(String id);`
- 호출 UI 파일: `send_email_sheet.dart:144`
- 전달 인자: `widget.jobId`
- 반환값 사용: 각 파일이 존재하면 `attachments`에 경로 추가, 파일명(경로의 마지막 세그먼트)을 설명 문자열로 사용

---

### 2.8 `lib/domain/models/measurement_result.dart` — `MeasurementResult`

#### `MeasurementResult.copyWith({...})`
- 정의 위치: `lib/domain/models/measurement_result.dart:102`
- 호출 UI 파일: `measuring_screen.dart:459`
- 전달 인자: `lowMotionWarning: true` (named, 단일 인자만 사용)
- 반환값 사용: `finalResult`에 저장되어 이후 세션/저장/화면전환에 사용

#### `MeasurementResult.mock` (static getter)
- 정의 위치: `lib/domain/models/measurement_result.dart:328`
- 호출 UI 파일: `history_screen.dart:24,38,294,296`, `result_screen.dart:46,49,104`, `send_email_sheet.dart:112`
- 반환값 사용: 폴백/디버그용 단건 예시 데이터로 `_result` 또는 `_items` 초기화에 사용

#### `MeasurementResult.mockList` (static getter)
- 정의 위치: `lib/domain/models/measurement_result.dart:396`
- 호출 UI 파일: `history_screen.dart:24,38,294`
- 반환값 사용: 디버그 모드에서 저장 결과 없을 때 3건짜리 예시 목록으로 `_items` 초기화

#### `MeasurementResult.xExceeded` / `.yExceeded` / `.zExceeded` / `.noiseExceeded` (getter)
- 정의 위치: `lib/domain/models/measurement_result.dart:320-323`
- 현재 시그니처: `bool get xExceeded => xPtp > 10.0;` 등 4종(zExceeded는 `zPtp > 15.0`, noiseExceeded는 `noiseMax > 50.0`)
- 호출 UI 파일: `history_screen.dart:103-109,174`, `result_screen.dart:196,203,210,219-221,569,577,585,593`
- 반환값 사용: `MetricCard.isExceeded`(색상/배지 분기), 차트 `isOver`(빨간 테두리/선), 리스트 상태 점 색상, 초과 사유 요약 텍스트 조합에 사용. **판정 임계값(10.0/15.0/50.0)이 getter 안에 하드코딩**되어 있고 UI는 이 값을 모른 채 결과만 소비함

---

### 2.9 `lib/domain/measure/raw_sensor_diagnostics.dart`

#### `RawSensorDiagnostics.fromSamples(List<SensorSample> samples, {double sampleRateHz = 256})`
- 정의 위치: `lib/domain/measure/raw_sensor_diagnostics.dart:86`
- 호출 UI 파일: `result_screen.dart:371-374`
- 전달 인자: `samples` = `_result.rawSamples`(non-null 확인됨), `sampleRateHz: _result.sampleRate`
- 반환값 사용: `diag` 변수에 저장, 아래 필드들을 화면에 직접 표시:
  - `diag.hasExtendedRaw`(bool) — extended raw 포맷 여부로 rawX/Y/Z, gravityX/Y/Z 표시 분기(§2.9 하단)
  - `diag.sampleCount`, `diag.durationSec`, `diag.sampleRateHz` — 요약 텍스트(`'${diag.sampleCount}샘플 · ...'`, line 392)
  - `diag.linearX/Y/Z`, `diag.rawX/Y/Z`, `diag.gravityX/Y/Z` — 각각 `ChannelStats`로 `_buildXyzLine`에 전달되어 min/max/mean/P-P 표시
  - `diag.noise` — `available`이면 `min/max/mean` dBA 표시(line 422-427)

#### `ChannelStats` (타입, `available`/`min`/`max`/`mean`/`peakToPeak` 필드)
- 정의 위치: `lib/domain/measure/raw_sensor_diagnostics.dart:4`
- 호출 UI 파일: `result_screen.dart:475` — `_buildXyzLine(String axis, ChannelStats stats, {String? hint})` 파라미터 타입
- 반환값 사용: `stats.available`(false면 `'$axis: —'`만 표시), true면 `stats.min/max/mean/peakToPeak`을 소수 1자리로 포맷해 한 줄 표시

#### `selectRawPreviewSamples(List<SensorSample> samples, {int edgeCount = 3})`
- 정의 위치: `lib/domain/measure/raw_sensor_diagnostics.dart:158`
- 호출 UI 파일: `result_screen.dart:502`
- 전달 인자: `samples`(= `_result.rawSamples`), `edgeCount: 8`(리터럴, 기본값 3 대신 UI가 명시적으로 8 지정)
- 반환값 사용: 반환된 `List<SensorSample>`을 순회하며 `formatRawSampleLine` 호출해 미리보기 텍스트 조립

#### `formatRawSampleLine(SensorSample s, {required bool extended})`
- 정의 위치: `lib/domain/measure/raw_sensor_diagnostics.dart:171`
- 호출 UI 파일: `result_screen.dart:505`
- 전달 인자: `s`(개별 샘플), `extended: extended`(= `diag.hasExtendedRaw`)
- 반환값 사용: `buf.writeln(...)`로 `SelectableText`에 그대로 출력되는 원본 데이터 미리보기 한 줄

---

### 2.10 `lib/domain/parse_raw.dart` — `RawDataParser.parseEvimp1`

- 정의 위치: `lib/domain/parse_raw.dart:13`
- 현재 시그니처:
  ```dart
  static MeasurementResult parseEvimp1({
    required String rawContent,
    required String id,
    required String jobNo,
    required String siteName,
    required int bottomFloor,
    required int topFloor,
    required String direction,
    required DateTime dateTime,
  })
  ```
- 호출 UI 파일: `result_screen.dart:71-80` (`_loadRawSample`)
- 전달 인자: `rawContent` = `rootBundle.loadString('assets/sample/2024F1447R01.txt')`의 결과(변수), `id: widget.id`(변수), `jobNo: '2024F 1447R01'`(리터럴), `siteName: '럭키종합건설/송정동근생'`(리터럴), `bottomFloor: 1`(리터럴), `topFloor: 8`(리터럴), `direction: '상향'`(리터럴 — 참고: `MetricsConfig`/`SiteInfo`가 쓰는 `'하부 → 상부'` 표기와 다른 문자열임), `dateTime: DateTime.now()`(계산값)
- 반환값 사용: `_result = parsed`로 setState, 스낵바에 `parsed.xSeries.length` 표시(파싱된 샘플 개수 확인용)

---

### 2.11 `lib/domain/report_generator.dart` — `ReportGenerator.generateSummaryText`

- 정의 위치: `lib/domain/report_generator.dart:374`
- 현재 시그니처: `static String generateSummaryText(MeasurementResult result);`
- 호출 UI 파일: `send_email_sheet.dart:157`
- 전달 인자: `result`(레포지토리에서 로드했거나 mock 폴백된 `MeasurementResult`)
- 반환값 사용: `_sendSummary` 체크박스가 선택된 경우 이메일 본문(`body`)으로 그대로 사용

---

## 3. 데이터 모델 필드

### 3.1 `MeasurementResult` — UI가 직접 접근하는 필드

| 필드명 | 타입 | 접근하는 UI 파일 | 용도 |
|---|---|---|---|
| `id` | `String` | history_screen.dart:80,258,265,296,304; result_screen.dart:130; measuring_screen.dart:463,490 | 삭제/조회 키, 이메일 발송 대상 jobId, 라우팅(`/result/:id`) |
| `jobNo` | `String` | history_screen.dart:57,100-102,228; result_screen.dart:175; send_email_sheet.dart:155 | 목록/요약 표시, 이메일 제목 |
| `siteName` | `String` | history_screen.dart:228; result_screen.dart:175 | 목록/요약 표시 |
| `bottomFloor` | `int` | result_screen.dart:175 | 요약 헤더(`N층 → M층`) |
| `topFloor` | `int` | result_screen.dart:175 | 요약 헤더 |
| `direction` | `String` | **UI 미접근** (§3.1 하단 참고) | — |
| `dateTime` | `DateTime` | history_screen.dart:57,92-97,235; send_email_sheet.dart:154 | 목록 날짜 표시, 이메일 제목 날짜 |
| `xPtp` / `yPtp` / `zPtp` | `double` | history_screen.dart:106-108; result_screen.dart:194,201,208,570,578,586 | MetricCard 값 표시, 차트 임계 안내 텍스트 |
| `noiseMax` | `double` | history_screen.dart:109; result_screen.dart:215-221 | MetricCard 값(≤0.0이면 'N/A' 처리) |
| `distance` | `double` | result_screen.dart:226 | MetricCard 값 |
| `maxSpeed` | `double` | result_screen.dart:233; measuring_screen.dart:327(게이트 판정) | MetricCard 값, 저동작 게이트 조건 |
| `fullXPtp`/`fullYPtp`/`fullZPtp` | `double` | result_screen.dart:287,294,301 | 필터 전/후 비교 행(postFull) |
| `constantXPtp`/`constantYPtp`/`constantZPtp` | `double` | result_screen.dart:289,296,303 | 필터 전/후 비교 행(postConstant) |
| `preFilterFullXPtp`(X/Y/Z) | `double` | result_screen.dart:286,293,300 | 비교 행(preFull) |
| `preFilterConstantXPtp`(X/Y/Z) | `double` | result_screen.dart:288,295,302 | 비교 행(preConstant) |
| `xSeries`/`ySeries`/`zSeries` | `List<double>` | result_screen.dart:567,575,583 | 차트 0~2번 시계열 |
| `noiseSeries` | `List<double>` | result_screen.dart:591 | 차트 3번 시계열 |
| `positionSeries` | `List<double>` | result_screen.dart:598 | 차트 4번 시계열 |
| `speedSeries` | `List<double>` | result_screen.dart:604 | 차트 5번 시계열 |
| `accelSeries` | `List<double>` | result_screen.dart:610 | 차트 6번 시계열 |
| `jerkSeries` | `List<double>` | result_screen.dart:617 | 차트 7번 시계열 |
| `sampleRate` | `double` | result_screen.dart:373,622-624 | RawSensorDiagnostics 인자, 차트 X축(시간) 환산 |
| `usedDetectedRideSegment` | `bool` | result_screen.dart:155 | "주행 구간 자동검출 실패" 안내 배너 표시 조건 |
| `constantSpeedRange` | `String` | result_screen.dart:268 | 정속 구간 텍스트 표시 |
| `usedDetectedConstantSpeed` | `bool` | result_screen.dart:270 | "자동 검출"/"전체 구간 사용" 텍스트 분기 |
| `constantSpeedSampleCount` | `int` | result_screen.dart:274 | 샘플 수 텍스트 |
| `totalVibrationSampleCount` | `int` | result_screen.dart:274 | 샘플 수 텍스트 |
| `constantSpeedRatio` | `double` | result_screen.dart:275 | 백분율 텍스트 |
| `rawSamples` | `List<SensorSample>?` | result_screen.dart:347,371,499 | 원본 센서 데이터 박스 표시 여부 및 소스 |
| `lowMotionWarning` | `bool` | result_screen.dart:137; measuring_screen.dart:459(copyWith로 설정) | "움직임 미감지 상태로 저장" 안내 배너 |
| `debugMetrics` | `Map<String, double>` | result_screen.dart:511,516-519,535-549 | 디버그 진단값 박스(`sampleRate`,`maxAccelMs2`,`velocityMax`,`distanceRaw` 키만 사용) |
| `xExceeded`/`yExceeded`/`zExceeded`/`noiseExceeded` | `bool` (getter) | §2.8 참고 | 초과 판정 색상/배지 |

**UI가 접근하지 않는 필드**: `direction` (`String`). `lib/features/`·`lib/core/` 전체에서
`result.direction` 또는 `_result.direction` 패턴을 검색했으나 매치 없음(측정 중 화면에서 쓰는
`siteData.site.direction`은 UI 자체 모델 `SiteInfo.direction`이며 별개). `MetricsConfig`,
`debugMetrics`의 나머지 키(`hasExtendedRaw`,`rawSampleCount`,`linearXMin/Max` 등 다수),
`fromMap`/`toMap`/`toJson`/`fromJson`도 UI가 직접 호출하지 않음(레포지토리 내부 전용).

### 3.2 `SensorSample` — UI가 직접 접근하는 필드

| 필드명 | 타입 | 접근하는 UI 파일 | 용도 |
|---|---|---|---|
| `tsUs` | `int` | measuring_screen.dart:158,178 | 유효성 체크, dt 계산 |
| `z` | `double` | measuring_screen.dart:163,174 | baseline 보정, 라이브 속도 산출 |
| `mgToMetersPerSecondSquared`(static const) | `double` | measuring_screen.dart:175 | 단위 환산 |

`x`, `y`, `noiseDba`, `rawX/Y/Z`, `gravityX/Y/Z`, `motionX/Y/Z`, `timestamp`, `timestampSec`
필드/getter는 UI가 직접 접근하지 않음(`RawSensorDiagnostics`/`formatRawSampleLine` 등 도메인 함수
내부에서만 소비되고, UI는 그 결과만 받음).

### 3.3 `ChannelStats` — UI가 직접 접근하는 필드

| 필드명 | 타입 | 접근하는 UI 파일 | 용도 |
|---|---|---|---|
| `available` | `bool` | result_screen.dart:476,499(간접) | 값 존재 여부 분기 |
| `min`/`max`/`mean`/`peakToPeak` | `double` | result_screen.dart:488-491 | 한 줄 요약 텍스트(`min .. max .. mean .. P-P ..`) |

---

## 4. 재작성 시 유지해야 할 항목

아래 항목은 시그니처(이름/파라미터/타입/반환형) 변경 시 UI가 컴파일 오류 또는 런타임 오류로
깨진다. §2/§3에서 실제 호출·접근이 확인된 것만 추렸다.

**클래스/함수 시그니처 (§2 전체가 대상, 요약):**
- `AuthRepository.instance`, `.currentUserId`(getter), `.getAutoLoginId()`, `.login(String, String)`(FormatException 계약 포함), `.logout()`
- `PrefsStore.instance`, `.loadLastSite()` → `Map<String,String?>`(키: jobNo/siteName/bottomFloor/topFloor/direction/model), `.saveLastSite(Map<String,String?>)`, `.loadEmail(String)`, `.saveEmail(String,String)`
- `MetricsConfig.defaultConfig` 및 그 필드 `micDbfsToDbaOffset`,`minMeasureDurationSec`,`minValidMaxSpeed`,`minValidDistance`
- `MeasurementEngine()` 무인자 생성자, `.sampleCount`(getter), `.addSamples(List<SensorSample>)`, `.analyze({jobNo,siteName,bottomFloor,topFloor,direction,dateTime})`(named, 이 5개 파라미터명 유지 필수)
- `SensorChannelManager({useMock=false})`, `.useMock`, `.sensorStream`(`Stream<SensorSample>`), `.checkSensorsAvailable()`, `.requestAudioPermission()`, `.startCapture({targetSampleRate,micDbfsToDbaOffset})`, `.stopCapture()`
- `SensorSample`의 `tsUs`,`z`,`mgToMetersPerSecondSquared`, 그리고 타입 자체(`List<SensorSample>` 형태로 여러 API의 파라미터/반환/필드 타입에 사용)
- `MeasurementRepository.instance`, `.save(MeasurementResult)`→`Directory`, `.list()`→`List<MeasurementResult>`, `.delete(String)`, `.load(String)`→`MeasurementResult?`, `.getBaseDirectory()`→`Directory`, `.ensureReportPdf(String)`→`File?`, `.ensureRawExcelFiles(String)`→`List<File>`
- `MeasurementResult.copyWith({...})`(적어도 `lowMotionWarning` 파라미터), `.mock`, `.mockList`, `.xExceeded`/`.yExceeded`/`.zExceeded`/`.noiseExceeded`
- `RawSensorDiagnostics.fromSamples(List<SensorSample>, {sampleRateHz})` 및 §2.9의 반환 필드 전체, `ChannelStats`의 4개 필드, `selectRawPreviewSamples(List<SensorSample>,{edgeCount})`, `formatRawSampleLine(SensorSample,{extended})`
- `RawDataParser.parseEvimp1({rawContent,id,jobNo,siteName,bottomFloor,topFloor,direction,dateTime})`→`MeasurementResult`
- `ReportGenerator.generateSummaryText(MeasurementResult)`→`String`

**데이터 필드 (§3.1/§3.2/§3.3 표 전체가 대상)**: 특히 `MeasurementResult`의 29개 필드(§3.1)는
표에 열거된 UI 파일·행에서 널 안전성 가정 없이(non-nullable 대부분) 직접 보간되므로, 타입을
바꾸거나(`double`→`String` 등) 제거하면 즉시 컴파일 실패한다. `rawSamples`만 nullable(`List<SensorSample>?`)이며
UI가 이미 null 체크(`result_screen.dart:348`)를 하고 있다.

---

## 5. 발견 사항

수정하지 않고 기재만 함.

- **F1 — `await` 누락 가능성 있는 저장 호출**: `lib/features/home/home_screen.dart:158`
  `PrefsStore.instance.saveLastSite({...})`가 `await` 없이 호출된다. `_startMeasure()`가
  `async`가 아닌 동기 함수(`void _startMeasure()`, line 83)라 애초에 await 할 수 없는 구조다.
  바로 다음 줄(line 167)에서 `context.push('/start')`로 화면을 전환하므로, 저장이 실제로
  완료되기 전에 화면이 전환될 수 있다.

- **F2 — 거치 안내 시트 "확인함" 상태가 프로세스 재시작 시 초기화됨**:
  `lib/features/measure/start_screen.dart:33-34`에 `// TODO(Phase 7): PrefsStore를 통한
  SharedPreferences 영구 저장으로 변경`이라는 주석과 함께 `static bool _hasSeenPlacementSheet = false;`
  (인메모리, static)를 사용 중이다. 반면 `lib/domain/prefs_store.dart:22,96-104`에는 이미
  `kHasSeenPlacementSheet` 키와 `loadHasSeenPlacementSheet()`/`saveHasSeenPlacementSheet()`가
  구현돼 있지만 **UI 어디에서도 호출되지 않는다**(§1 요약에 미포함된 이유). 앱을 완전히 종료했다가
  다시 켜면 매번 거치 안내 바텀시트가 다시 뜬다.

- **F3 — 저장 목록 요약 텍스트가 필드 값이 아닌 ID 문자열에 하드코딩됨**:
  `lib/features/history/history_screen.dart:100-102`의 `_getSummaryText`가 `item.id`가
  `'2024F1447R01'`/`'2024F1448R02'`/`'2024F1449R03'`일 때 각각 `'Z 22.2mg 초과'` 등 고정
  문자열을 반환한다. 이는 현재 `MeasurementResult.mock`/`mockList`(models/measurement_result.dart:328-393)의
  값과 우연히 일치하지만, 실제 필드(`xPtp` 등, line 103-110)를 계산하는 대신 ID 매칭으로 분기하므로
  기능부 재작성으로 mock 수치가 조금이라도 바뀌면 목록에는 여전히 옛 수치가 표시된다.

- **F4 — 결과 화면 라우팅이 매직 스트링 3개에 의존**:
  `lib/features/result/result_screen.dart:43-45`에서 `widget.id`가 `'sample'`, `'raw'`,
  `'2024F1447R01'` 중 하나면 저장소 조회 대신 번들 자산(`assets/sample/2024F1447R01.txt`)을
  파싱해 표시한다(`_loadRawSample`, line 66-99). 이 3개 문자열은 다른 곳에 문서화돼 있지 않고
  result_screen.dart 내부에만 존재하는 암묵적 라우팅 규칙이다.

- **F5 — 레포지토리를 우회한 더미 파일 생성, 유효하지 않은 PDF 바이트**:
  `lib/features/shared/send_email_sheet.dart:110-120`에서 `MeasurementRepository.instance.load()`가
  `null`을 반환하면 `MeasurementResult.mock`으로 폴백하는데, 이때 `report.pdf`(4바이트
  `[0x25,0x50,0x44,0x46]`만 기록, line 117 — PDF 매직 넘버만 있고 나머지 구조가 없어 실제로는
  열리지 않는 파일)와 `raw.txt`(`'EVIMP1\n256\n'` 헤더만, line 119)를 `MeasurementRepository`를
  거치지 않고 `File(...).writeAsBytes/writeAsString`으로 직접 생성한다. 이후 line 128의
  `ensureReportPdf`는 이 파일이 이미 존재하므로 정상 PDF로 재생성하지 않고 그대로 첨부한다.

- **F6 — 저장 재시도 실패 시 추가 피드백 없음**:
  `lib/features/measure/measuring_screen.dart:383-415`의 `_showSaveRetryDialog`에서 "재시도"
  버튼(line 400-411)을 눌러 `MeasuringScreen.attemptSave`가 다시 실패하면(`success == false`),
  `if (success && ctx.mounted)` 조건이 거짓이 되어 다이얼로그가 닫히지 않고 그대로 남는다. 최초
  실패 메시지("측정 결과 파일 저장에 실패했습니다") 외에 재시도도 실패했다는 별도 안내는 없다.

- **F7 — 로그인 화면의 일반 예외 처리 시 원본 오류 정보 폐기**:
  `lib/features/auth/login_screen.dart:58-63`의 `catch (e)` 블록이 `e`를 전혀 사용하지 않고
  고정 문자열 `'로그인 중 오류가 발생했습니다.'`만 표시한다. `FormatException` 외의 예외(예:
  `PrefsStore`의 `SharedPreferences.getInstance()` 실패 등)가 발생하면 원인 파악에 필요한
  정보가 UI 레벨에서 사라진다.

---

## 부록: Task 1 — 사장 코드 삭제 근거

삭제한 5개 파일 각각에 대한 참조 검색 결과(원문)와 `flutter analyze` 결과는 본 대화의 별도
보고에 기재했으며, 이 문서에는 포함하지 않는다(요청된 산출물은 `docs/ui_contract.md` 단일
파일이라 했으므로, 삭제 근거는 대화 보고로만 전달함).
