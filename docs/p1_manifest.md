# p1_manifest

## 1. 변경 요약
- **lib/domain/auth_repository.dart**: 로그인 우회 처리. `currentUserId`, `getAutoLoginId`, `login` 등이 실제 인증 없이 고정된 ID('T00000')와 성공(true)을 반환하도록 수정. 상단 주석을 클래스 선언 위로 이동하여 lint 해소.
- **lib/domain/sensor_channel.dart**: 골격화 적용. 메서드 본문을 `UnimplementedError`로 대체하여 껍데기만 남김.
- **lib/features/measure/measuring_screen.dart**: 측정 화면에서 기능부 계산(거리/속도 누적 계산 등) 로직을 제거하고, 관련된 라이브 속도 표시 텍스트를 "측정 중"으로 교체. 관련된 필드 모두 삭제 및 목적을 잃은 `_uiTimer` 제거.
- **lib/domain/measure/raw_readable_export.dart (삭제 시도 중단)**: test/domain/measure/raw_readable_export_test.dart:2 에서 참조 중이므로 삭제하지 않고 유지. 변경 파일은 3개.

## 2. sensor_channel 골격 시그니처
| 심볼명 | 작성된 시그니처 | docs/ui_contract.md §2.5 대응 항목 | 일치 여부 |
|---|---|---|---|
| 생성자 | `SensorChannelManager({this.useMock = false});` | `SensorChannelManager({bool useMock = false})` | 일치 |
| useMock | `final bool useMock;` | `SensorChannelManager.useMock` (필드) | 일치 |
| sensorStream | `Stream<SensorSample> get sensorStream` | `Stream<SensorSample> get sensorStream;` | 일치 |
| checkSensorsAvailable | `Future<bool> checkSensorsAvailable() async` | `Future<bool> checkSensorsAvailable();` | 일치 |
| requestAudioPermission | `Future<bool> requestAudioPermission() async` | `Future<bool> requestAudioPermission();` | 일치 |
| startCapture | `Future<void> startCapture({int targetSampleRate = 256, double calibrationOffsetDba = 0.0, double micDbfsToDbaOffset = 85.0}) async` | `Future<void> startCapture({int targetSampleRate = 256, double calibrationOffsetDba = 0.0, double micDbfsToDbaOffset = 85.0})` | 일치 |
| stopCapture | `Future<void> stopCapture() async` | `Future<void> stopCapture()` | 일치 |

## 3. auth_repository 우회 내용
- **변경 전후 동작 대조표**
  | 메서드/필드 | 변경 전 | 변경 후 (우회) |
  |---|---|---|
  | `currentUserId` | 저장된 ID 반환 | 항상 `'T00000'` 반환 |
  | `getAutoLoginId()` | PrefsStore에서 조회 후 반환 | 항상 `'T00000'` 반환 |
  | `login(id, pw)` | 정규식 및 PW 일치 검증, 비활성 여부 체크 후 저장 | 검증 없이 항상 `true` 반환 |
  | `logout()` | `currentUserId` 초기화 및 PrefsStore 값 삭제 | 아무 동작도 하지 않음 (빈 메서드) |
  | `isEnabled(id)` | `true` 반환 (변경 없음) | `true` 반환 (변경 없음) |

- **원복 시 되돌려야 할 항목 목록**
  - 삭제된 `_idPattern` 정규식 복구
  - 내부 변수 `String? _currentUserId;` 선언 복구
  - `PrefsStore`를 사용한 ID 불러오기 및 저장 로직 복구
  - 아이디 및 비밀번호 형식 검증(정규식 매치, 아이디/비밀번호 동일 확인) 로직 복구
  - 로그아웃 시 메모리 및 `PrefsStore`의 상태 삭제 로직 복구
  - 주석 원위치 및 import 재구성

## 4. measuring_screen 제거 내용
- **제거한 계산 항목과 원래 행 번호**:
  - Z축 기준선 누적 및 평균 산출 (`162-168행`)
  - 샘플 간격(dt) 산출 (`170-172행`)
  - mg -> m/s² 환산 및 속도 적분/클램프 (`173-177행`)
  - mock 스트림 구독 중 속도 갱신 setState 부분 (`211-213행`)
- **삭제한 타이머 및 필드 목록**: `_uiTimer`, `_currentSpeed`, `_signedVelocity`, `_baselineSumZ`, `_baselineCount`, `_baselineZ`, `_lastTsUs`
- **각 필드 및 타이머를 참조하던 위치 전체**:
  - `_uiTimer`: 초기화 및 setState 빈 블록 (134-138행), `_cleanup()` (200, 205행)
  - `_currentSpeed`: 초기화(60행), `_uiTimer` 내부 갱신(145행), `_subscribeMockStream` 내부 갱신(212행), UI 속도 텍스트 표시(637행)
  - `_signedVelocity`: 초기화(62행), `_uiTimer` 내부 `_currentSpeed` 계산(145행), baseline 이후 Z축 갱신 시(168행), 적분 누적(176행)
  - `_baselineSumZ`: 초기화(63행), baseline Z축 누적(163행, 166행)
  - `_baselineCount`: 초기화(64행), 카운트 증가(164행, 165행, 166행)
  - `_baselineZ`: 초기화(65행), 평균 Z축 계산 저장(165-167행), Z축 환산 시 참조(174행)
  - `_lastTsUs`: 초기화(66행), 샘플 간격 dt 계산 시 참조(170-171행), 최근 타임스탬프 갱신(178행)

## 5. 임시값을 넣은 필드
| 파일 | 필드명 | 넣은 값 | 계약상 의미 |
|---|---|---|---|
| `lib/domain/auth_repository.dart` | `currentUserId` | `'T00000'` | 앱 전체에서 참조하는 현재 로그인된 사번(우회 상태) |
| `lib/domain/auth_repository.dart` | `getAutoLoginId()` 반환값 | `'T00000'` | 스토리지 확인을 우회하기 위한 고정 자동 로그인 ID |
| `lib/domain/auth_repository.dart` | `login()` 반환값 | `true` | 로그인 무조건 성공 |
| `lib/domain/auth_repository.dart` | `isEnabled()` 반환값 | `true` | 계정 무조건 활성화 상태 |

## 6. 검증 결과
- **flutter analyze 출력**:
  - 오류 0건, `dangling_library_doc_comments` 해소됨.
  - 경고: 작업 1 기준선(raw_excel_export_test.dart 의 unnecessary_non_null_assertion 3건)만 유지됨.
- **git diff main..ui-base --stat 출력**:
```text
 lib/domain/auth_repository.dart            | 39 +++-----------
 lib/domain/sensor_channel.dart             | 86 +++---------------------------
 lib/features/measure/measuring_screen.dart | 59 +-------------------
 3 files changed, 15 insertions(+), 169 deletions(-)
```

## 7. 실행 관찰 결과
- 실행 확인은 불가했습니다 (CLI 텍스트 전용 인터페이스 환경이므로 그래픽 화면 관찰 및 인터랙션을 할 수 없습니다).
