# OTIS V-Check — 승강기 진동·소음 측정 앱 (vibration_checker)

일반 안드로이드 폰으로 승강기 진동(3축)·소음을 측정하고 OTIS TUNE 규격 PDF
리포트를 만들어 메일로 보내는 Flutter 앱. 앱 이름(홈 화면 아이콘 아래 ·
`MaterialApp` title)은 "OTIS V-Check"(2026-10-13). 패키지 이름
`com.otis.vibration_checker` 는 바꾸지 않는다 — 바꾸면 다른 앱으로 취급돼
업데이트가 이어지지 않는다. Android 우선, iOS 는 나중.

## 명령

```bash
flutter analyze                                   # 경고 0 유지
dart format --output=none --set-exit-if-changed lib test
flutter test                                      # 전부 통과 유지
# 화면 · 리포트 캡처(screenshot 태그, 평소 건너뜀). SHOT_DIR 에 PNG · PDF 를 쓴다
flutter test --tags screenshot --run-skipped test/screenshots
```

## 구조

| 경로 | 역할 |
|---|---|
| `lib/model/` | 순수 자료형 (`MeasurementResult` · `Worker`) |
| `lib/domain/auth/` | 작업자 명단 읽기 · 로그인 판정 (`WorkerDirectory`) |
| `lib/domain/capture/` | 네이티브 이벤트 → 256Hz 격자 환산 (`GridResampler`), 지표 계산 전 신호 처리 (`SignalConditioner`), ISO 8041 주파수 가중 (`RideWeighting`). 수집 · 처리 수치는 `CaptureConfig` |
| `lib/domain/report/` | 리포트 좌표·임계값·지표 계산. 운행 구간(`TravelWindow`) · 반주기 P2P(`HalfCycle`)도 여기. 숫자는 여기에만 둔다 |
| `lib/domain/session/` | 화면 사이에 넘기는 이번 측정 상태 (`MeasurementSession`), 지금 로그인한 작업자 (`LoginSession`) |
| `lib/domain/time/` | 사람이 읽는 시각을 한국 시간(UTC+9)으로 맞추는 `KoreaTime` |
| `lib/domain/update/` | 앱 안 업데이트 — version.json 읽기(`UpdateInfo`) · 판정(`UpdateDecision`) · 배포 주소와 시간 값(`UpdateConfig`) |
| `lib/adapter/` | 플랫폼 경계 — 센서 채널, 파일·저장소, PDF 렌더링, 환경설정. 측정 한 번의 수집 절차는 `capture_session.dart`, 저장 절차는 `measurement_recorder.dart`. 업데이트 확인은 `update_checker.dart`, 내려받기 · 설치 통로는 `update_installer.dart` |
| `lib/ui/core/` | 라우터, 디자인 토큰(`theme.dart`), 공용 위젯(`widgets/`) |
| `lib/ui/features/` | 화면별 폴더 (home · measure · history · result · settings · shared · update) |
| `android/app/src/main/kotlin/` | `MainActivity` · `SensorStreamHandler` · `NoiseCaptureHandler` · `NoiseAudioEncoder`(현장 소음 M4A 녹음) · `UpdateInstaller`(APK 내려받기 · SHA-256 확인 · `PackageInstaller` 설치) |
| `pdf_report_dev/` | 리포트 좌표를 확정할 때 쓴 파이썬 프로토타입 (앱 빌드와 무관) |
| `docs/comment_rules.md` | 주석 규칙. **코드 작업 전 매번 다시 읽는다** |
| `docs/report_layout.json` | 리포트 좌표 정본. `report_layout_test` 가 Dart 상수와 대조한다 |
| `docs/reference/sample_evimp.pdf` | 원본 TUNE 리포트. 코드 주석의 `근거:` 가 가리킨다 |
| `docs/reference/H6N1AP65.pdf` | 원본 TUNE 리포트(실제 현장). 머리말 표기(하중 · 제품 · 주소)의 근거. **H6N1AP65.pdf 는 저장소 밖 보관**(`.gitignore`) — 실제 엔지니어명 · 현장명이 들어 있다. 시험 픽스처로 쓰지 않는다 |
| `docs/noise_otis_offset_notes.md` | 소음 dBA 오프셋 · OTIS 차이 · 남은 과제 |
| `docs/release.md` | 릴리스 서명 키 보관 · `android/key.properties` · 서명 확인(인증서 지문). 키가 없으면 릴리스 빌드가 멈춘다 |
| `assets/workers/workers.json` | 로그인 작업자 명단(사번 · 성명 · 업체명 · 관리팀). OTIS 명단 엑셀(`설치 업체 List_*.xlsx`, 저장소 밖 · `.gitignore`)에서 `tool/import_workers.py` 로 만든다(아나콘다 파이썬, openpyxl). 실명이 평문으로 공개 저장소 · APK 에 들어간다(2026-10-18 사용자 결정) |
| `assets/icon/` | 앱 아이콘 원본 · OTIS 시안. `dart run flutter_launcher_icons` 로 `mipmap-*` 를 만든다. 앱 자산 목록에는 넣지 않는다 |

## 화면 흐름

```
로그인(사번 · 비밀번호, 한 번 하면 기기에 남음) ─▶ 홈
홈(현장 정보, 입력 즉시 저장) ─▶ 시작(대기 시간 · 거치 안내)
  ─[마이크 권한 확인]─▶ 측정(카운트다운 → 수집, 볼륨키로 종료)
  ─▶ 결과(/result/:id: 지표 · 결과 비교 · 메일 · 테스트 재실행)
홈 ─▶ 저장 결과 목록(history) ─▶ 결과
홈 ─▶ 설정(작업자 · 로그아웃 · 수신 이메일 목록 · 앱 버전 · 업데이트 확인)
```

- 로그인(2026-10-18): 사번 + 비밀번호, 비밀번호 = 사번(대소문자 · 앞뒤
  공백 무시, 사용자 결정 "보안은 일단 신경쓰지 말고"). 서버가 없어 명단은
  앱 자산 하나이고 바꿀 비밀번호도 없다. 로그인 사번을 기기에 남겨 앱을
  다시 켜면 `LoginStore.restore()` 가 되살리고, 새 명단에서 빠진 사번이면
  로그아웃시킨다. 로그인 전에는 라우터 `redirect` 가 모든 경로를 `/login`
  으로 돌린다. 명단이 바뀌면 `tool/import_workers.py` 로 JSON 을 다시
  만들고 앱을 새로 배포한다. 사번 · 비밀번호 입력은 `normalizeId()` 가
  대문자 · 공백 제거 · 전각 → 반각 · 한글 자판 낱자 → 영문(두벌식, "ㅅ" →
  "T")으로 맞춰 비교하고, 입력칸은 영문 · 숫자 키보드를 띄운다(2026-10-20).
  실제 명단 전원 로그인은 `worker_roster_test` 가, 실제 라우터의 로그인 전
  차단은 `app_router_login_test` 가 본다.

- 앱 안 업데이트(2026-10-13, 절차는 `docs/release.md`): 홈이 앱 실행마다
  한 번, 설정이 "업데이트 확인" 으로 배포 저장소(GitHub Releases)의
  version.json 을 3초 안에 받아 본다. 못 받으면 조용히 넘어간다 —
  인터넷이 없는 기계실에서도 측정은 막지 않는다. 선택 업데이트는 "나중에"
  를 누르면 같은 번호를 하루 동안 다시 묻지 않고, 필수(빌드 < minimum)는
  닫을 수 없다. 측정 · 결과 화면에서는 확인 · 설치하지 않는다. 설치는
  `PackageInstaller` 세션이고 FileProvider 를 쓰지 않는다.

- 홈 현장 정보(2026-10-08 · 10-11): 제번 · 현장명 · 우편번호(숫자 5자리) ·
  주소 · 최하층 / 최상층 · 운전 방향 · 기종 · 하중(kg 고정, 2026-10-13 —
  `SiteInfo.loadUnit`. 단위를 고를 수 있던 빌드의 lb 결과는 리포트에
  "파운드" 로 찍고, 재실행 때는 하중을 빈 칸으로 되살린다) · 해석
  종류(분석 내용, 5가지) · 추가 참고사항. 참고사항만 선택이고
  나머지는 `SiteInfo.validate()` 가 필수로 본다. 하중 판정은
  `SiteInfo.parseLoad()` 한 곳에서 하고 저장 변환도 같은 함수를 쓴다.
  입력은 바뀔 때마다 기기에 저장하되 참고사항은 저장하지 않아 측정마다 빈
  칸에서 시작한다. 해석 종류는 기록 · 리포트 표시만 하고 계산은 같다.
- 결과 화면 "테스트 재실행"은 되살린 현장 정보가 `validate()` 에 걸리면
  (하중 · 우편번호를 받기 전 예전 결과, lb 결과) 홈에서 채우라고 안내만
  하고 재지 않는다.
- 엔지니어 이름 = 로그인 작업자 성명(2026-10-18, 설정의 수동 입력칸은
  뺐다). 측정을 저장하는 시점 작업자의 성명 · 사번 · 업체명 · 관리팀을
  결과(`engineerName` · `employeeId` · `company` · `team`)에 싣는다. 나중에
  다른 사람이 로그인해도 예전 리포트 이름은 그대로다. 그 전 결과는 설정에
  손으로 적은 이름(또는 null)이고 사번 · 업체 · 팀은 null 이다. OTIS 직원
  (명단에 업체 · 팀 빈 칸)은 업체 · 팀이 null 이다.
- 리포트 1쪽 머리말: 하중 "2000 킬로그램", 측정 = 해석 종류, 주소 "주소,
  우편번호", 제품 "엘리베이터, 기종"(기종 쉼표는 리포트에서만 공백),
  엔지니어 = 저장 시점 이름(2 · 3쪽 엔지니어 칸도 같다), 층 정보
  "Start Floor : 1, Stop Floor : 8"(하강이면 "Start Floor : 8, Stop Floor :
  1" — 홈은 최하층 · 최상층을 받고 출발 · 도착은 운전 방향이 정한다,
  `SiteInfo.startStopFloors()` — 결과 화면 머리 카드 "하강 · 8층 → 1층" 도
  같은 함수, 2026-10-21). 값이 없는 칸은
  "미입력"(`ReportPage1.placeholder`).
  넘칠 수 있는 칸은 오른쪽 여백을 넘으면 글자를 줄여 한 줄을 지킨다.
- 리포트 1쪽 Performance Metrics(2026-10-15): 진동 값 단위는 "milli-G"
  (`ReportMetric.vibrationUnit`, 저장 값 · 앱 화면은 mg 그대로). 수평 두
  행은 X · Y 중 큰 값 하나만 적고 내역을 붙이지 않는다. 황색 · 적색 칸은
  위에서부터 57/60 · 72/75 · 14/21 · 20/30 · 9/13.5 · 17/25.5 · 0/0 · 0/0
  (`ReportThresholds`). 맨 왼쪽 원은 황색 기준 이하 초록, 넘으면 노랑, 적색
  기준을 넘으면 빨강, 값이 없으면 회색이고 최대 속도 · 운행 거리는 원이
  없다. 분석 자료 표의 "Machine으로 부터 진동" · "Belts" 는 서식 글자를
  덮고 "권상기 머신으로 부터 진동" · "로우프" 로 찍는다.
- 수직 최대 · Jptp(2026-10-21, OTIS 리포트와 같은 정의): `MotionZones.of()`
  가 운행(|v| > 0.05 m/s)을 1.6Hz 저역 가속도로 정속 · 가감속 구간으로
  나눈다(가속도 최대 50% 를 넘는 처음 · 마지막이 가속 · 감속 봉우리, 그 사이
  |a| < 0.03 m/s² 인 처음 · 마지막이 정속 시작 · 끝, 정속 1초 미만이면 실패
  → 수직 최대 · Jptp "—"). 1쪽 수직 최대(`zPtp`)는 정속 구간 안 최대 반주기
  P2P, `zJptp` 는 가감속 구간 최대로 2쪽 수직 차트에만 "Jptp 값milli-G" 로
  적는다(두 글자 상자는 겹치지 않게 비킨다). 수직 평균(A95)은 운행 구간
  (0.5 m 제외) 그대로다. 1쪽 수직 두 행이 황색 · 적색이면 서식 라벨 · 값을
  덮고 OTIS 문구 두 줄을 다른 행 설명 글자와 같은 크기(28px, 2026-10-22)로
  쓴다 — 평균 "진동측정결과가 {값} 로 / 일관되게 높게
  측정되었습니다", 최대 "최대의 진동 {값} 가 하부층 정지레벨로부터 / {위치}m
  에서 측정되었습니다."(`ReportMetric.remarkLines`). 다른 행은 문구가 없다.
  OTIS 대비 개발폰 3건: ptp −6 · +12 · +33%(하강, 오티스폰 원시데이터도
  +11%), Jptp +15 · −3 · −12%.
- 저장 결과 목록은 결과 파일을 읽지 못한 측정(측정 일시가 없거나 깨짐 등)을
  그 한 건만 "읽을 수 없는 결과" 로 보여 주고 지울 수 있게 한다
  (`MeasurementRepository.listEntries()`, 2026-10-15). 측정 일시를 "지금"
  으로 채워 읽지 않는다(`MeasurementResult.fromMap` 은 `FormatException`).
- 리포트 값 칸 소수 자리: 최대 속도 둘째 자리(1.74m/s), 나머지 첫째 자리,
  100 이상은 정수(`ReportMetric._decimalsByUnit`, 결과 화면도
  `ReportMetric.decimalsFor()` 로 같은 자리). 최대 속도는 반올림 단위 없이
  둘째 자리다 — 2026-10-22 에 넣은 0.05 m/s 반올림을 같은 날 되돌렸다.
  2026-10-21 비교 7건 가운데 5건만 OTIS 표시값과 같았다(1.529 · 1.532 →
  1.55, OTIS 1.50). 정속 구간 평균 속도를 0.05 로 반올림하면 7건 모두
  맞지만 OTIS 값이 1.50 · 1.75 두 가지뿐이고 경계 여유가 0.003 이라 근거가
  약하다 — result.json `steadySpeedMps`(표시 안 함)에 남겨 다른 정격 속도
  현장에서 확인한다(`docs/pending_checks.md`).
- 사람이 읽는 시각(리포트 머리말 · 측정 ID · 저장 결과 목록 · 결과 화면 ·
  메일 제목)은 기기 시간대와 상관없이 한국 시간이다(`KoreaTime.of()`,
  2026-10-15). 저장 값(`dateTime`)은 그대로 둔다.

- 측정 화면은 끝나면 결과 화면으로 바뀐다(`pushReplacement`). 실패 · 중단이면
  측정을 시작한 화면으로 돌아간다(`pop`).
- 마이크 권한은 측정 화면에 들어가기 전에 `ensureMicPermission()` 이 받는다.
  측정 중에는 휴대폰이 뒤집혀 있어 권한 창을 누를 수 없다.
- 거치 방향(2026-10-22, 막지 않고 알림 + 기록): 수집 시작 뒤 첫 중력
  이벤트부터 1초의 중력 Z 평균으로 판정한다(`PlacementMonitor`,
  `CaptureConfig.placementWindowMs` · `placementFaceDownMaxMg` −940 ·
  `placementFaceUpMinMg` +940 — 화면 아래 / 화면 위 / 기울어짐). 화면 아래가
  아니면 측정 중에 경고음 200ms + 진동 300ms 를 한 번 울린다
  (`MainActivity.playPlacementAlert`, `VIBRATE` 권한, 측정은 계속). result.json
  `placement` · `placementGravityZMg`, meta.txt `placement` ·
  `placementGravityZmg`(판정 전에 끝나면 `placement: unknown`)에 남기고,
  결과 화면은 화면 위 · 기울어진 결과에 재측정 권고 경고를, 메일 본문은
  "거치: 화면 아래" 한 줄을 넣는다. 리포트 PDF 에는 넣지 않는다. 경고음 ·
  진동은 수집 시작 약 1 ~ 1.3초(격자 0.5 ~ 0.8초, 신호 처리 기준선 창 안)라
  지표 구간(운행 · 정속) 밖이다. 진동 모터(약 150 ~ 250Hz)는 40Hz 저역에서
  빠지고 raw.txt · native_raw.txt · noise.m4a 에는 남는다. 이 판정이
  생기기 전에는 거치 검사가 없었다(2026-10-04 에 계획한 notFaceDown 저장
  실패는 저장소에 들어간 적이 없다).
- 바텀 시트는 `showAppSheet()` 로만 띄운다. 아래쪽 시스템 막대를 비켜 준다.
- 소음 진단 기능(new/dB 의 마이크 원본 PCM · 계산 CSV 기록
  `NoiseDiagnostics`, 오프라인 재계산 도구 `tool/compare_noise_pcm.py`,
  `docs/noise_pcm_diagnostics.md`)은 2026-10-15 에 통째로 뺐다(2026-10-14
  "늘 남긴다" 결정을 바꿈). 소음 계산(`latestDba`)과 상관없는 기록 전용이고,
  1분에 5.3MB 씩 지우는 곳 없이 쌓이며 대화가 녹음될 수 있어서다. 소음
  오프셋 · A 가중을 다시 맞출 때는 커밋 b06d417 · a32df62 에서 되살린다.
  예전 빌드가 기기에 남긴 `noise_diagnostics/` 폴더는 앱이 지우지 않는다.
- 현장 소음 녹음(2026-10-18 사용자 지시 "최종 메일 산출물에 현장 소음
  포함", 형식은 MP3 대신 M4A): `NoiseCaptureHandler` 가 dBA 를 재는 같은
  마이크 PCM(48kHz 모노, 못 열면 44.1kHz — 2026-10-22)을 `NoiseAudioEncoder`(안드로이드 내장
  `MediaCodec` AAC-LC 64 kbps + `MediaMuxer`)로 앱 저장 공간 맨 위
  `noise_native_*.m4a` 에 쓰고, `stopCapture` 가 원본 기록 경로와 함께
  돌려준다(`{recordPath, audioPath}`). 저장 절차가 측정 폴더의
  `noise.m4a` 로 옮기고, 중단이면 `CaptureSession.discard()` 가 지운다.
  녹음이 실패해도 dBA 는 계속 잰다(녹음만 포기, 메일에 "누락:"). 2026-10-15
  에 진단 PCM 을 뺀 까닭 중 "대화가 녹음될 수 있다" 는 이 녹음에도
  해당한다 — 사용자가 알고 넣기로 했다. 크기는 1분에 약 0.48MB 이고 30건
  보관 정리가 측정 폴더째 지운다. 실기기 확인 전(`docs/pending_checks.md`).
- 측정 결과는 기기에 최근 30건만 남긴다(2026-10-15,
  `MeasurementRepository.maxStoredMeasurements`). 저장 절차가 새 측정을
  저장한 뒤 `pruneOldest()` 로 측정 ID(한국 시간) 순서상 오래된 폴더부터
  지운다 — 결과 없이 멈춘 측정 폴더도 30건 밖이면 함께 지운다. 방금 저장한
  측정은 지우지 않는다. 정리에 실패해도 저장은 성공으로 둔다.
- 측정 화면은 수집 중에 경과 시간 아래 "현재 속도"(m/s, 소수 첫째 자리)를
  보여 준다(2026-10-15). `CaptureSession` 이 이벤트마다
  `LiveSpeedEstimator`(기준선 1초 → 1차 저역 250ms → 적분 → 정지 되돌림:
  거른 가속도 < 3 mg 이고 속도 < 0.2 m/s 가 0.5초)에 넣고, 이벤트 시각으로
  250ms 마다 `liveSpeedMps` 로 내보낸다. 기준선을 모으는 첫 1초는 "—".
  표시 전용이라 저장하는 최대 속도(측정 뒤 움직인 구간만 적분)와 다를 수
  있다(2026-10-15 로우 데이터 2건: 어림 최대 1.48 · 1.58, 저장 1.53 · 1.51).
  측정 중 휴대폰은 화면을 아래로 두므로 보이는 것은 화면을 볼 수 있을 때다
- 메일은 PDF 리포트, 로우 데이터(`raw.txt`, 256Hz 격자 · 필터 · 기준선
  보정 전, 축별 전체 평균만 뺌 — 2026-10-21), 현장 소음(`noise.m4a`, 첨부 이름 `NOISE_제번_측정ID.m4a`)을
  고른 만큼 붙인다. 셋 다 기본 체크이고, `raw.txt` · `noise.m4a` 가 없는
  측정은 본문에 "누락:" 줄로 밝힌다. 소음 진단 산출물 항목("데시벨 산출물" ·
  "마이크 원본")은 기능과 함께 뺐다(2026-10-15). 본문 첫 줄 아래에 결과에
  실린 작업자를 "작업자: 성명 (사번) · 업체 · 팀" 으로 적는다(없는 값은
  뺀다, 성명이 없으면 줄째 뺀다). 그 아래 거치 방향 "거치: 화면 아래"
  (판정 전 예전 결과는 뺀다). raw.txt 첨부 설명은 "256Hz 원시값(EVIMP1,
  축별 평균 제거 · 필터 없음)" 이다. 추가 참고사항이 있으면 본문 첨부 목록 앞에
  "[참고사항]" 머리줄과 함께 넣는다. 안드로이드 원본(`native_raw.txt`)은 기기의
  측정 폴더에만 남기고 보내지 않는다(2026-10-08). 안드로이드 원본은
  측정이 실패해도 그 측정 폴더로 옮기고, 저장하지 않는 중단(뒤로가기 · 앱
  전환 · 센서 무응답)이면 바로 지운다(`CaptureSession.discard()`).
- 거치는 화면을 아래로, 출입구를 바라보고 섰을 때 휴대폰 위쪽이 왼쪽이다
  (2026-10-07, 오티스폰도 같이 바꿈). 격자 환산의 Y 부호 뒤집기는 예전
  (위쪽 오른쪽) 때 정한 그대로 쓴다 — 두 기기가 함께 돌아 부호 관계가 같다.
  수직(Z)은 중력을 뺀 가속도를 중력 방향("위")에 투영한다
  (`GridResampler.motionOf()`, 2026-10-21) — 화면을 아래로 바르게 놓으면
  예전 식 −(raw_z − gravity_z) 와 같고, 화면을 위로 놓거나 기울여도 위로
  가속 = 양수다. 예전 식은 화면을 위로 놓으면 부호가 뒤집혔다(2026-10-21
  개발폰 하강 기록). 가속도계 영점 · 배율 오차(화면 위 개발폰 약 13.6 mg)는
  raw 에 남고 기준선 0 맞춤에서 빠진다(raw.txt 는 2026-10-21 2차부터 축별
  평균을 빼 내보낸다). 거치 방향은 2026-10-22 부터 판정 · 경고 · 기록한다
  (위 "거치 방향" 항목).

## 진동 신호 처리

저장 절차(`MeasurementRecorder.record()`)는 이 순서로 진행한다.

```
GridResampler.resample()        256Hz 격자, 두 센서가 겹친 구간 앞뒤 0.5초 버림
  ├─▶ raw.txt (EVIMP1, 256Hz)    필터 · 기준선 보정 없음, 축별 전체 평균만 뺌(OTIS 관례). 원본은 native_raw.txt
  └─▶ SignalConditioner.condition()
        1. 기준선 0 맞춤          첫 1초 평균을 X · Y · Z 마다 뺀다
        2. 40Hz 저역              4차 버터워스, 양방향(영위상)
        3. 256Hz → 100Hz 재표본   25/64 다상 FIR, 카이저 창 β 5.0
        소음 열은 거르지 않고 100Hz 시각에 선형 보간한다
      ─▶ MeasurementAssembler.assemble()   지표 · 리포트 · result.json
            4. 운동 · 최대 속도 · 운행 거리   가중 전 Z 의 움직인 구간만 적분 (`_deriveKinematics`)
               저크                           가속도 → 1.6Hz 4차 버터워스 양방향 → 중앙 차분
               가속도 차트(표시용)             가속도 → 10Hz 4차 버터워스 양방향
            5. 주파수 가중 (RideWeighting)   X·Y Wd, Z 1Hz 고역(2차, 양방향) + Wk
               수직 저역                       Z 만 가중 뒤 20Hz 4차 버터워스 양방향 (`_verticalLowpass`)
            6. 운행 구간 (TravelWindow)      출발 · 정지 0.5 m 제외, 운행 1 m 이하면 실패
            7. 반주기 P2P (HalfCycle)        구간 안 최대 P2P · A95, 구간 안 소음 최대 · 평균
            8. 정속 · 가감속 (MotionZones)   수직 최대 = 정속 구간 최대, Jptp = 가감속 구간 최대
```

- **설정 상수**: `CaptureConfig` 의 `conditionedRateHz`(100) ·
  `lowpassCutoffHz`(40) · `lowpassOrder`(4) · `baselineWindowMs`(1000).
  재표본 비 · 기준선 행 수 · 최소 측정 길이(`minimumRecordMs`, 2초)는 같은
  클래스의 게터가 유도한다. SciPy 정의를 따르는 알고리즘 상수(`halfLenPerRate`
  10, `kaiserBeta` 5.0)는 `signal_conditioner.dart` 의 `PolyphaseResampler` 에
  있다. 차수가 홀수이거나 차단 주파수가 100Hz 의 절반 이상이면 `ArgumentError`.
- **실패**: `RecordFailure.conditioningFailed`. 원인은
  `RecordOutcome.conditioningCause` 로 가른다 — 격자가 기준선 구간보다 짧으면
  `ConditioningFailure.gridTooShort`(측정 화면이 "N초 이상 측정" 안내),
  설정 오류면 `invalidConfig`. 실패해도 `raw.txt` 는 이미 써 두어 남는다.
- **meta.txt**: 기존 집계 뒤에 `conditioning` · `baselineX/Y/Zmg` ·
  `baselineStdX/Y/Zmg`(기준선 구간 모표준편차, 판정에 안 씀) ·
  `conditionedRateHz` · `conditionedRowCount` 줄을 덧붙인다. 실패면
  `conditioningFailureReason` 한 줄만. 그 뒤에 `weighting` 과
  `travelWindowStart/EndSec` · `travelWindowStart/EndM`(구간을 못 정하면
  `travelWindowFailureReason`) 줄을, 그 뒤에 `kinematics` 와
  `motionWindowStart/EndSec`(정지 측정이면 `motionWindow: none`, 여유가 기록
  앞 · 끝에서 잘렸으면 `motionWindowClippedAtStart/End: true`) 줄을 덧붙인다.
  운행 구간 줄 뒤에는 `zones` 와 `steadyStart/EndSec`(못 정하면
  `zonesFailureReason`) 줄이 붙는다.
- **result.json**: `signalConditioning` 에 처리 방식 문자열
  (`baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)+zlp(20.0bw4zp)+motion(v>0.05,pad500ms)
  +jerk(lp1.6bw4zp)+acc(lp10.0bw4zp)+zones(v>0.05,pk0.5,a<0.03,min1000ms)
  +noise(A,slow,+105.2,48000Hz)`,
  `SignalConditioner.methodLabel` + `RideWeighting.methodLabel` +
  `MeasurementAssembler.verticalLowpassMethodLabel` +
  `MeasurementAssembler.kinematicsMethodLabel` + `jerkMethodLabel` +
  `accelChartMethodLabel` + `MotionZones.methodLabel` +
  `noiseMethodLabel(마이크 표본 속도)`) 과
  `travelWindow`(첨자 · 초 · m) 또는 `travelWindowFailure`, `motionZones`
  (첨자 · 초) 또는 `motionZonesFailure`, `zJptp` · `zPtpPositionM`. `+zones`
  가 없는 2026-10-21 전 결과의 `zPtp` 는 운행 구간 전체 최대이고 Jptp ·
  위치가 없다. `+zlp` 가 없는 2026-10-21 2차 전 결과의 수직 시계열 · 지표는
  20Hz 저역을 걸지 않은 값이다. `+motion` 이 없는
  2026-10-20 전 결과는 기록 전체를 적분한 예전 거리 · 최대 속도다. `+jerk`
  가 없는 2026-10-21 전 결과의 저크는 40Hz 가속도를 그대로 미분해 ±10 ~ 20
  m/s³ 로 크다(그대로 읽고 그린다). `+acc` 가 없는 결과의 `accelSeries` 는
  거르지 않은 가속도다(지금은 10Hz 저역을 건 차트 표시용). `+iso18738` 이
  없는 2026-10-15 전 결과는 가중 없이 전체 구간에서 낸 지표이고(그대로 읽고
  차트 점도 그때 정의로 찍는다), `signalConditioning` 이 null 인 더 예전
  결과는 원시 256Hz 기준이다. 시계열 `x/y/zSeries` 는 지표를 낸 그 값(가중
  뒤)이라 차트도 같은 값을 그린다. 화면에는 보이지 않는다.
- **가중 · 구간 상수**: `CaptureConfig.rideVerticalHighpassHz`(1.0) ·
  `rideVerticalHighpassOrder`(2) · `rideVerticalLowpassHz`(20) ·
  `rideVerticalLowpassOrder`(4) · `travelEdgeExclusionM`(0.5) ·
  `minimumTravelM`(1.0) · `motionSpeedThresholdMps`(0.05) ·
  `motionPaddingMs`(500) · `jerkLowpassHz`(1.6) · `jerkLowpassOrder`(4) ·
  `accelChartLowpassHz`(10) · `accelChartLowpassOrder`(4, 차트 표시용) ·
  `zoneRunSpeedMps`(0.05) · `zonePeakRatio`(0.5) · `zoneSteadyAccelMps2`(0.03)
  · `zoneMinimumSteadyMs`(1000, 정속 · 가감속 구간). 저크
  저역은 OTIS 리포트 저크 차트 4개와 RMSE 0.02 ~ 0.03 m/s³ 로 맞춘 값이다
  (2026-10-21). 저크 필터의 양 끝 덧댐(15행) 때문에 조립은 16행 미만 격자를
  사유와 함께 돌려보낸다. ISO 8041 가중 상수(0.4 Hz 대역 제한, Wd 2 Hz/0.63,
  Wk 12.5 Hz/0.63 · 2.37 → 3.35 Hz/0.91)는 `ride_weighting.dart` 에 있다.
  가중 필터는 한 방향(인과), 1 Hz 고역만 양방향이다.
- **정본과 픽스처**: 처리 결과는 SciPy 1.18.1 과 같아야 한다
  (`test/domain/capture/signal_conditioner_test.dart`). 픽스처는
  `test/fixtures/` 에 있고 `pdf_report_dev/gen_conditioning_fixtures.py` 가
  만든다(저장소 루트에서 `python pdf_report_dev/gen_conditioning_fixtures.py
  test/fixtures/conditioning_input_dev_256hz.txt test/fixtures`).
  - `conditioning_input_dev_256hz.txt` — 2026-10-06 개발폰 실측
    (`RAW_1_20261006-091841`, 앱이 앞뒤 0.5초 버림) EVIMP1 9,439행. 스크립트의
    입력이며 스크립트가 만들지 않는다
  - `conditioning_expected_100hz.txt` — 위 입력의 X · Y · Z 에 아래를 적용한
    3,688행. `#` 머리말 한 줄(원래 파일은 `RAW_1_…` 에서 만들어 머리말의 입력
    파일 이름만 다르다)
  - `conditioning_unit_cases.json` — 10Hz + 60Hz 합성 신호 300표본 `input`,
    그 `filtfilt` 출력, `input` 을 바로 재표본한 `resample_25_64`, 계수 `sos`.
    값을 소수 12자리로 반올림해 저장하므로, 다시 만들거나 반올림한 `input`
    으로 다시 계산하면 1e-12 대 차이가 날 수 있다(시험 기준 1e-9)
  - `weighting_unit_cases.json` · `weighting_expected_metrics.json`
    (2026-10-15) — 가중 계수 · 출력과, ride_reference · 개발폰 기록을 앱과
    같은 길로 계산한 구간 · 지표. `--weighting` 모드로 만들고 위 세 파일은
    건드리지 않는다(`python pdf_report_dev/gen_conditioning_fixtures.py
    --weighting test/fixtures/ride_reference.txt
    test/fixtures/conditioning_input_dev_256hz.txt test/fixtures`).
    `ride_weighting_test` · `measurement_assembler_test` 가 1e-9 · 1e-6 으로
    대조한다. `weighting_expected_metrics.json` 은 2026-10-20 움직인 구간
    적분으로 다시 만들었다 — 이 PC 에 SciPy 1.18.1 이 없어 아나콘다 1.16.3
    으로 만들었고(파일의 `scipy` 값), 가중 단위 픽스처를 같이 만들어 보니
    1.18.1 판과 1e-12 안에서 같아 그 파일은 되돌렸다

  ```python
  x = x - x[:256].mean()                                  # 축마다 첫 1초 평균
  sos = scipy.signal.butter(4, 40, fs=256, output='sos')
  y = scipy.signal.sosfiltfilt(sos, x)                    # padtype='odd', padlen 기본
  y100 = scipy.signal.resample_poly(y, 25, 64)            # window=('kaiser', 5.0), padtype='constant'
  ```

## 관통 원칙

1. **재지 않은 값을 0 이나 빈 문자열로 채우지 않는다.** 미측정은 `null`.
   `MeasurementResult` 의 지표는 `double?`, 판정 게터는 `bool?` 이다.
2. **숫자는 한 곳에만 둔다.** 리포트 좌표는 `report_layout.dart`, 임계값은
   `report_thresholds.dart`, 화면 색·치수·글자는 `ui/core/theme.dart`,
   수집 · 신호 처리 수치는 `capture_config.dart`.
3. **도달 불가 방어 분기 대신 `assert`** 를 쓰고 이유를 주석에 적는다.
4. **실패를 삼키지 않는다.** 변환 실패는 빈 결과가 아니라 사유를 올린다.
5. **주석은 `docs/comment_rules.md` 를 따른다.**

## UI 작업 규칙

- 색 · 치수 · 글자 스타일은 `AppColors` · `AppDims` · `AppText` 만 쓴다.
  필요한 값이 없으면 화면에 숫자를 쓰지 말고 `theme.dart` 에 토큰을 더한다.
  그림 하나에만 쓰는 치수는 그 파일 안 상수 묶음에 둔다
  (예: `placement_sheet.dart` 의 `_DiagramSize`).
- 현장 사용자 기준: 본문 18sp 이상, 캡션 16sp 이상, 터치 영역 56dp 이상,
  주 버튼 64dp.
- 공용 위젯(`lib/ui/core/widgets/`)을 먼저 찾아 쓴다.
  - `AppScrollBody` · `AppBottomBar` — 화면 본문 틀과 아래 고정 버튼 자리
  - `AppCard` — 회색 표면 카드, `AppNotice` — 안내 박스(danger · caution · alert)
  - `showAppConfirmDialog` — 제목 · 문구 · 버튼 한두 개 대화상자
  - `showAppSheet` — 바텀 시트, `showSuccessSnackBar` · `showErrorSnackBar`
  - `AppDialogButton` · `AppDialogIconButton` — 56dp 터치 영역을 지키는 버튼
- 화면은 `go_router` 경로(`ui/core/router.dart`)로만 오간다.
- 측정 · 저장 · 리포트 로직을 화면 파일에 새로 넣지 않는다. 화면은
  `CaptureSession` · `MeasurementRecorder` · `SiteInfo.validate()` 의 결과를
  받아 문구와 화면 이동만 고른다.

## 작업 방식

- 작업은 함수 · 클래스 묶음 단위로 나눠 진행하고 묶음마다 리뷰를 받는다.
- 매 단계 끝에 "추가로 발견한 것"을 보고한다(없으면 "없음").
- 지시 범위 밖 파일은 읽기만 하고 고치지 않는다.
- 커밋할 때 `git add .` · `git add -A` 를 쓰지 않고 파일 경로를 하나씩
  지정하며, 커밋 전에 `git diff --cached --stat` 으로 들어가는 파일을
  확인한다(2026-10-11, 저장소 밖에 둘 파일이 섞이지 않게).

## 알려진 미해결

- 진동 지표 결정 이력
  - 2026-10-07: 기준선 0 맞춤 + 40Hz 저역(4차 버터워스, 양방향) + 100Hz
    재표본 후 값으로 낸다(2026-10-04 "진동 필터를 넣지 않는다" 결정을 바꿈).
    근거는 오티스폰 · 개발폰 동시 측정 6쌍 — 개발폰 Z 가 정지 상태에서
    −2 ~ −4mg 에 떠 있고, 오티스폰(100Hz)이 담지 못하는 50Hz 위 성분이 개발폰
    최대 P2P 를 키웠다
  - 2026-10-15: 원본 리포트(ISO 18738 방식)와 같은 길로 바꾼다 — 가중
    (X·Y Wd, Z 1Hz 고역 + Wk), 운행 구간(출발 · 정지 0.5 m 제외), 최대
    P2P = 반주기 P2P 의 최댓값(예전 "전체 최대 − 최소" 를 버림). 2026-10-07
    "전체 구간 · 가중 없음" 결정을 바꾼다. 원본 리포트를 만든 기록
    (ride_reference)에서 원본 대비 수직 5.53/3.71(원본 6.1/3.6) · 수평
    11.07/5.01(11.3/4.8) · 소음 45.3/48.7(45.5/48.7), 신호등 8행 모두 원본과
    같다. 예전 방식은 수직 127 · 수평 48.3 으로 정상 승강기가 늘 빨강이었다
  - 수직 처리는 ride_reference 비교로 골랐다(1Hz 고역만 6.97/4.23 — A95 가
    ±15% 밖, Wk 만 9.06/3.74 — 최대가 밖, 고역 + Wk 5.53/3.71). 원본
    (레퍼런스폰 앱)이 실제로 쓴 수직 처리는 미확인이다
  - 2026-10-15 두 번째 대조: 오티스 앱 리포트 BS15721003(서일대, 11→4층
    하강)과 그 로우 데이터를 앱과 같은 길로 계산하면 수직 17.4/9.3(원본
    18.2/10.3) · 수평 13.0/12.2(13.9/10.8) · 소음 47.5/41.7(47.6/42.0) · 최대
    속도 1.51(1.50) · 운행 거리 24.95(24.9) m, 신호등 6개 모두 같고 Y · 수직
    최대 점도 같은 순간(11.6 · 16.5초)이다. 오티스 수직 차트는 가감속
    경계의 느린 흔들림이 남아 있어 1Hz 고역보다 약한 처리로 보이나, 고역
    0.5Hz · Wk 만 · 1Hz 중 두 기록을 함께 ±10% 안에 드는 것은 지금(1Hz)과
    0.5Hz 뿐이라 바꾸지 않았다. 수평 A95 는 이 기록에서 +13% 높다(백분위
    방식 미확인). 운행 거리는 같은 로우 데이터에서 오티스 앱과 같으므로,
    동시 측정에서 나는 차이(0.4 m 안팎)는 보정 방식이 아니라 두 기기
    센서의 치우침 차이다
  - 2026-10-21 2차: 수직(Z)만 가중 뒤 20Hz 4차 버터워스 저역 양방향을 더
    건다(`CaptureConfig.rideVerticalLowpassHz`). 같은 운행 정속 구간
    대역별 RMS(개발폰 ÷ 오티스폰)가 1–20Hz 1.0~1.1배, 20–40Hz 1.5배,
    40–50Hz 5.8~6.6배로, 개발폰 가속도계의 20Hz 위 잡음이 수직 최대를
    키웠다. 개발폰 대 OTIS PDF 수직 ptp 가 −6 / +12 / +33% → −9 / +6 / +1%,
    Jptp −1 / −12 / −13%, A95 −6 / −2 / −1%. 대가로 오티스폰 기록
    (ride_reference)은 진짜 20~40Hz 성분이 깎여 원본 대비 최대가 −9% →
    −14%(±15% 경계)다. 25Hz 는 3회 ptp 가 +19% 로 남고, 15Hz 는
    ride_reference 가 −19% 로 밖이라 고르지 않았다. 수평은 지금도 OTIS 대비
    −2 ~ +10% 이고 저역을 걸면 3회 A95 가 +21% 로 벌어져 걸지 않는다. 2회
    ptp 차이(+6 ~ +13%)는 어느 차단에서도 줄지 않아 잡음이 아니다. 한
    현장 3회 비교로 정한 값이라 다른 현장 동시 측정으로 다시 확인한다
    (`docs/pending_checks.md`)
  - 2026-10-21 2차: `raw.txt`(EVIMP1 내보내기)는 축별로 내보내는 행 전체의
    평균을 빼고 쓴다(`VibrationFileWriter.encode()`, 뺀 값은 meta.txt
    `rawExportMeanX/Y/Zmg`). 오티스폰 EVIMP1 내보내기(otis_* · ride_reference)
    축별 평균이 X · Y 0.0000, Z −0.002 ~ −0.012 mg 라 OTIS 관례로 본다. 정지
    → 운행 → 정지 기록은 가속도 전체 평균이 물리적으로 0 이라 영점 오차만
    빠진다(개발폰 하강 기록 −13.6 mg). 지표는 격자(평균 빼기 전)에서 따로
    내므로 바뀌지 않는다. 손대지 않은 원본은 `native_raw.txt` 다. 예전
    "raw.txt = 보정 전 원시 보존" 을 바꾼다
  - `raw.txt` 와 `native_raw.txt` 는 처리 전 값이다(`raw.txt` 는 축별 평균만 뺌). 운행 구간(A95 · 수평 ·
    소음)은 거리로만 정하고, 정속 구간은 수직 최대 · Jptp 에만 쓴다
    (2026-10-21, 예전 "정속 구간 감지는 넣지 않는다" 를 바꿈). A95 백분위는
    최근접 순위다(표준의 보간 방식 미확인)
- 리포트 차트 세로축(2026-10-10 · 10-11, `lib/domain/report/chart_scale.dart`):
  원본 리포트 범위(X ±4 · Y ±10 · Z ±20 · 소음 40~54 · 위치 0~10 · 속도
  0~1 · 가속도 ±0.6 · 저크 ±0.6(눈금 0.2, 2026-10-21))를 최소 범위로 두고(위치 ·
  속도 · 가속도 · 저크는 아래 여백 규칙이 대신한다), 데이터 양 끝에 10% 씩
  여유를 더한 범위가 그 안이면 그대로, 넘치면 1 · 2 · 2.5 · 5 × 10ⁿ 눈금
  (6칸 이하)으로 넓힌다. 진동 · 가속도 · 저크는 0 가운데, 소음은 넓힐 때 폭
  14 dB 만 지키고 0(미측정) 구간은 선을 끊는다. 개발폰 · 레퍼런스폰 · 하강
  가정 3자료 × 8차트 모두 축 밖 표본 0%. X · Y · Z 차트에는 최댓값 ·
  최솟값 자리에 흰 테를 두른 굵은 빨간 점을 찍고, 최댓값 점 옆(오른쪽,
  자리가 없으면 왼쪽)에 흰 상자 · 굵은 빨간 글자로 "ptp 값 milli-G"(1쪽
  표와 같은 지표, 원본 표기 `a_x,ptp` 를 따라 소문자, 2026-10-20)를 적는다.
  수직 차트는 정속 구간 최대 쌍에 "ptp", 가감속 구간 최대 쌍에 "Jptp" 를
  함께 적는다(2026-10-21).
  소음 최댓값도 같은 방식이다(2026-10-15). 운행 구간 점선(2026-10-20,
  원본과 같은 모양): X · Y · 수직 차트는 ±A95/2 높이에 붉은 가로 점선 두
  줄과 왼쪽 아래 "A95", 소음 차트는 평균 한 줄을 지표를 낸 운행 구간
  (`travelWindow`) 시작부터 끝까지만 긋는다. 구간이 없는 예전 결과는 진동
  점선 없음, 소음 평균선은 폭 전체. 점선 무늬는 원본을 600dpi 로 재 점 ·
  빈칸 2.3pt(`ReportChartRenderer.guideDashPattern`).
  가로축은 가장 긴 시계열의 마지막 표본까지 담는다(`timeWindow()`).
  3쪽 위치 · 속도(2026-10-21, `ChartScaleKind.padded`, 2026-10-08 "0 에서
  시작, 끝을 눈금에 맞춰 바깥으로 반올림" 을 바꿈): 데이터 최소 · 최대에서
  폭의 10% 씩 바깥을 틀 끝으로 두고 반올림하지 않는다. 눈금은 틀 안의
  1 · 2 · 5 × 10ⁿ 배수만(6칸 이하, 25 m → 5 m · 1.5 m/s → 0.5) 찍는다. 정지
  측정(한 값)만 최소 범위(0~10 · 0~1)에 여백을 둔다. 위치는 하부층 정지레벨
  기준(하강 = 운행 거리 → 0), 속도는 부호 그대로(하강 음수), 표의 최대
  속도 · 운행 거리는 크기다. 가속도 · 저크(2026-10-22,
  `ChartScaleKind.paddedSymmetric`)는 같은 규칙을 0 대칭으로 쓴다 — 틀 =
  ±(데이터 최대 절댓값 x 1.2), 반올림 없음, 눈금은 틀 안 배수(OTIS 3쪽 6개
  실측 1.20 ~ 1.22배, 예전 "±0.6 넘으면 ±0.75 · ±1 로 넓힘" 을 바꿈). 데이터가
  모두 0 이면 최소 범위 ±0.6. 2 · 3쪽 여덟 차트 모두(2026-10-22, 2쪽도) 가로축
  양쪽에 측정 길이의 4% 여백을 둔다(`ReportChartRenderer.timeWindow()` 한 함수,
  `timePaddingRatio`, 31.4초 → −1.26 ~ 32.6초, 음수 쪽에는 눈금 없음). 시간
  눈금 간격은 1 · 2 · 5 × 10ⁿ 가운데 측정 길이를 12칸 이하로 나누는 가장 작은
  값(`maxTimeTickCells`, 30 · 45초 → 5초, 60초 넘으면 10초 — 지시의 예 셋을
  맞추는 상한). 세로 눈금 숫자는 한 축 안에서 소수 자리를 맞춘다
  (`ReportChartRenderer.formatTick()`, 0.0 0.5 1.0 / 0.6 0.4 … −0.6, 정수
  간격은 정수). 모두 OTIS 2 · 3쪽에서 잰 모양이다.
  2 · 3쪽 제목은 "테이터 차트" — OTIS 원본 표기를 따른 의도된 표기다
  (`ReportChartPageRenderer.title`, 오타로 보고 되돌리지 않는다).
- 신호 처리 남은 과제
  - 26.5Hz 봉우리가 개발폰에서 1.25~2.1배 크다. 40Hz 아래라 이 처리로 줄지
    않는다.
  - 차단 주파수 40Hz 는 비교 측정을 더 모아 조정할 수 있다.
  - `pdf_report_dev` 프로토타입에는 이 처리를 넣지 않았다.
  - 이 처리 전에 저장한 결과(`signalConditioning` 이 null)는 원시 256Hz
    지표라 새 결과와 기준이 다르다.
- 격자는 두 센서가 겹친 구간의 앞뒤를 0.5초씩 버리고 만든다(2026-10-05,
  `CaptureConfig.edgeTrimMs`). 시작 · 종료 입력(볼륨키) 충격을 빼려는 것이고,
  볼륨키 충격 길이는 실기기 확인 전이다. 원본 기록(`native_raw.txt`)은 자르지
  않는다. 기준선 1초까지 남아야 하므로 측정은 2초 이상이어야 저장된다.
- `ride_reference.txt` 와 원본 TUNE 리포트는 레퍼런스폰 산출물이다(EVA 아님).
  판정 기준은 2026-10-15 사용자 지시로 원본 리포트 서식의 황색 · 적색 값을
  쓴다(요구사항서 값 Z 15 · X·Y 10 · 소음 50 에서 바꿈). 앱 화면의 초과
  표시(결과 · 저장 결과 목록)도 같은 적색 기준(Z 30, X·Y 25.5, 소음 75)을
  쓴다. 그 값이 무엇을 근거로 정해졌는지는 미확인이다.
- 운행 거리 · 최대 속도(2026-10-20 결정, 사용자 승인): 움직인 구간만
  적분한다. 기록 전체를 적분하던 예전 방식은 가만히 있어도 속도가 떠다녀
  (1분에 ±0.02 m/s) 정지 구간이 거리에 섞였다 — 1분 정지 기록이 0.68 m
  (실제 리포트에 "운행 거리 0.7m"), 같은 운행도 도착 뒤 기다린 시간(1 ~
  6초)에 따라 최대 0.57 m 달라졌다. 같은 승강기(BS15721003) 같은 구간 기록
  6건에서 거리 표준편차 0.204 → 0.067 m, 오티스폰 · 개발폰 동시 측정 차
  0.30 · 0.38 → 0.16 · 0.17 m. 자료(오티스폰 · 테스트폰 동시 기록 zip 3개)는
  분석 뒤 삭제했다(2026-10-20 사용자 지시) — 수치는 이 항목과
  `docs/noise_otis_offset_notes.md` 에만 남는다.
  배율 오차 흔적은 없었다(두 폰 최대 속도 비 0.985 · 0.99 · 1.02, 개발폰
  native_raw 정지 크기 996 mg · 기울여 둔 기록 1003 mg 로 ±0.4% 안). 같은
  기록에서 예전 방식보다 0.4 ~ 0.6 m 작다. 오티스 앱과의 관계는 엇갈린다 —
  10-15 오티스 기록(`자료/오티스꺼.txt`)은 새 방식 1.499 m/s · 25.04 m 가
  그날 오티스 리포트(1.50 m/s · 24.9 m)에 맞고 예전 방식(1.529 · 25.57)은
  어긋나며, 원본 리포트 기록(ride_reference)은 원본 57.3 m 에 예전 57.09 가
  지금 56.84 보다 가깝다. 그 10-15 오티스 리포트의 로우 데이터가 이
  파일인지는 미확인이다(위 "두 번째 대조" 의 24.95 m 는 지금 계산으로
  재현되지 않는다). 실제 거리는 층고 도면을 아는 운행으로 확인해야 한다
  (`docs/pending_checks.md`).
  운행 구간(`TravelWindow`)이 위치로 정해지므로, 도착 뒤 정지가 길던 기록은
  예전에 구간 끝이 정지 구간 안까지 들어갔다(개발폰 픽스처 0.48초) — 지금은
  들어가지 않는다.
- 소음(2026-10-20): 표본마다 A 가중(IEC 61672-1, 44.1kHz 2차 필터 3단,
  `NoiseCaptureHandler.A_WEIGHTING_SOS`)을 건 뒤 창 RMS · Fast 평활에 오프셋
  105.2(`kDefaultMicDbfsToDbaOffset`)를 더한다. 녹음(`noise.m4a`)은 가중 전
  소리다. result.json 처리 방식 끝 `+noise(A,fast,+105.2)` 가 없는 전 결과는
  A 가중 없이 +87.3 이다. 테스트폰 · 오티스폰 동시 기록 3건에서 오티스와의
  상관 0.88 ~ 0.90 → 0.96 ~ 0.98, 정면 기록은 평균 · 최대가 0.2 dB 안으로
  맞고 나머지 둘은 조용한 구간이 ±5 dB 갈린다. 오프셋은 임시값이다 — 두 폰을
  같은 자리 · 같은 방향에 두고 다시 재 확정하고, 폰마다 마이크 감도가 달라
  기기별 보정이 필요할 수 있다(`noise_otis_offset_notes.md`).
  2026-10-22: 시간가중을 Slow(1초, `kNoiseTimeWeightSec` = 코틀린
  `TIME_WEIGHT_SEC`)로, 마이크를 48000Hz(못 열면 44100Hz, A 가중 계수 두 벌)로
  바꿨다. 처리 방식 `+noise(A,slow,+105.2,48000Hz)`, meta.txt
  `noiseTimeWeighting` · `noiseSampleRateHz` · `noiseOffsetDb`. 2026-10-21 동시
  측정 3회에서 최대가 OTIS PDF 대비 +5.3 / +2.5 / +3.6 → +1.0 / −0.6 / −0.6 dB
  (저장된 Fast 열에 1초 평활을 더한 어림)이고, 대신 dB 평균이 0.7 ~ 2.6 dB
  오른다(에너지 평활). 이미 저장된 소음열은 다시 계산하지 않는다. 계수 ·
  평활은 `noise_weighting_test` 가 SciPy 픽스처(`--noise`)와 코틀린 소스
  상수를 대조한다.
- 리포트 서식 이미지의 지운 자국: 2 · 3쪽 `tem_2.jpg` 는 예전 차트를 붓으로
  지운 옅은 회색 덩어리(252 ~ 254)가 차트 둘레 그림자처럼 찍혀 2026-10-21
  흰색으로 정리했다(세 채널 246 이상만, 띠 · 로고 그대로). 1쪽 `tem_1.jpg`
  도 2026-10-22 흰 바탕과 이어진 밝은 점(246 이상, 연결 성분)만 흰색으로
  정리했다(머리말 제번 자리 · 주소 칸 등 155,694점). 표 줄무늬 안의 얼룩은
  줄무늬 색 위라 그대로 둔다(흰색으로 바꾸면 흰 점이 된다). JPEG 로 다시
  저장해 줄무늬 점이 최대 11/255(평균 0.09) 흔들린다 — PNG 면 0 이지만 PDF 가
  0.9 MB 커져 JPEG(품질 95, +0.24 MB)를 골랐다.
- `docs/reference/sample_evimp.pdf` 는 축별 계수 분리 이전의 단일 계수로
  만들어졌다. 차이는 최대 0.14pt. 좌표가 아니라 참조 PDF 를 다시 만들어야 한다.
- 요구사항서(`Vibration_Checking_App_Development_20260630.pdf`)가 저장소에 없다.
- 앱 안 업데이트(2026-10-13)는 소스 저장소 `westone-hq/OTIS`(공개)의
  Releases 로 배포한다(2026-10-16, `UpdateConfig.releaseRepository`). 저장소를
  비공개로 바꾸거나 최신 릴리스에 version.json 이 없으면 확인이 조용히
  실패한다. 실기기 설치 경로(설치 허용 · 서명 충돌 · 설치 뒤 재시작)는 확인
  전이다(`docs/pending_checks.md`).
- 릴리스 서명 키(2026-10-13)로 바꾸기 전 디버그 키로 서명해 깐 기기는 한
  번 지우고 새로 깔아야 한다. 기기의 측정 결과도 지워지므로 먼저 옮긴다.
- 서버 연동은 미구현이다. 로그인은 앱 안 명단으로만 판정한다(수신 이메일은
  기기에 목록으로 둔다). 엑셀의 동명이인 33쌍은 리포트(성명만)로는 구분되지
  않는다 — 결과 · 메일에는 사번이 남는다.
- 소음 RMS 창(`WINDOW_SEC`) · 갱신 주기(`HOP_HZ`)는 OTIS 와 맞춰 보는
  실험값이다 (`NoiseCaptureHandler.kt`). 2026-10-12 부터 평균 제곱값을
  지수평활해 낸다 — 2026-10-22 부터 IEC 61672-1 "Slow" 시정수
  (`TIME_WEIGHT_SEC`, 1초), 그 전은 "Fast"(0.125초).
