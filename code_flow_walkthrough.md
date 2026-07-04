# OTIS 진동 측정 앱 — 전체 코드 흐름 정리본

> 앱이 켜지는 순간부터 리포트 발송까지, **어느 파일의 어떤 코드가 어떤 순서로
> 이어지는지**를 처음부터 끝까지 정리한 문서. 파일 경로와 핵심 함수명을 그대로
> 표기하여 코드를 열었을 때 바로 찾을 수 있게 했다.
> 기준: 커밋 d6b4d2f (8스텝 완주 시점)

---

## 0. 큰 그림 (한눈에)

```
[앱 시작] main.dart
   │  자동로그인 확인
   ▼
[라우터] core/router.dart ── 로그인 안 됨 → /login 강제
   │
   ├─ S1 /login      로그인 (사번 검증)
   ├─ S2 /home       현장정보 입력 ──┐
   ├─ S3 /start      지연 선택+거치 안내+센서 체크
   ├─ S4 /measuring  측정 중 (센서 수집 → 엔진)
   ├─ S5 /result/:id 결과 (카드+차트)
   ├─ /history       저장 목록
   └─ S6 /settings   설정(이메일)

[데이터 보관소] features/shared/measurement_session.dart (전역 싱글턴)
   └ 화면들이 여기에 현장정보·설정·결과를 넣고 뺀다

[측정 엔진] domain/measure/ (순수 Dart, 계산 담당)
[저장소]   domain/repository/measurement_repository.dart (파일 저장)
[리포트]   domain/report_generator.dart (PDF 생성)
```

핵심 원리 하나: **화면끼리 직접 데이터를 주고받지 않는다.** 모두
`MeasurementSession`이라는 공용 보관소를 거친다(홈이 여기 넣으면 → 측정이 꺼냄).

---

## 1. 앱 시작 — `main.dart`

```
main()
 ├ WidgetsFlutterBinding.ensureInitialized()   // Flutter 준비
 ├ AuthRepository.instance.getAutoLoginId()     // 저장된 로그인 복원
 └ runApp(VibrationCheckerApp)
       └ MaterialApp.router(routerConfig: appRouter, theme: buildAppTheme())
```

- 자동로그인 ID를 먼저 읽어서, 이미 로그인한 사람은 바로 홈으로 가게 준비.
- 테마는 `core/theme.dart`의 `buildAppTheme()` — 색·글꼴·치수 토큰(AppColors,
  AppText, AppDims)이 여기 한 곳에 정의됨.

---

## 2. 관문 — `core/router.dart`

모든 화면 이동은 여기를 거친다. GoRouter의 `redirect`가 **로그인 가드** 역할:

```
redirect(context, state):
   loggedIn = AuthRepository.currentUserId != null
   ├ 로그인 안 됨 + 로그인화면 아님  → '/login' 강제
   ├ 로그인 됨   + 로그인화면임      → '/home'
   └ 그 외                          → 통과
```

라우트 7개: `/login /home /start /measuring /result/:id /history /settings`.
결과 화면만 `:id` 파라미터를 받아 "어느 측정 결과인지"를 구분.

---

## 3. S1 로그인 — `features/auth/login_screen.dart` + `domain/auth_repository.dart`

```
[화면] login_screen.dart
   사번 입력 → 로그인 버튼
        │
        ▼
[로직] auth_repository.dart
   login(id, pw):
     ├ 형식 검증: 사번 6자리(\d{6}) 또는 T+5자리([Tt]\d{5})
     ├ 규칙: pw == id 여야 승인
     ├ isEnabled(id): 관리자 활성화 여부 (현재 항상 true, OI-2 서버 대기)
     └ 성공 시 SharedPreferences에 id 저장(자동로그인) + currentUserId 세팅
        │
        ▼
   context.go('/home')
```

---

## 4. S2 홈 — `features/home/home_screen.dart`

현장정보를 입력받아 **보관소에 넣는** 곳.

```
[입력] 제번, 현장명, 최하층, 최상층, 방향, 기종
   │  (SharedPreferences로 지난 입력 자동 복원)
   ▼
[검증] 층수 논리 체크(최하 ≥ 최상 이면 에러) 등
   │
   ▼
MeasurementSession.instance.currentSite = SiteInfo(...)  ← 보관소에 저장
   │
   ▼
context.push('/start')
```

- 여기서 `SiteInfo`(session 파일에 정의)에 담아 보관소에 넣는 게 핵심.
  이후 측정·결과·리포트가 전부 이 SiteInfo를 꺼내 쓴다.
- 우측 상단에서 /settings, /history 로도 갈 수 있음.

---

## 5. S3 측정 시작 — `features/measure/start_screen.dart` + `placement_sheet.dart`

측정 전 마지막 관문. **센서 지원 여부를 여기서 미리 체크**(안전장치 A1).

```
[진입] initState:
   checkSensorsAvailable() 비동기 호출 → _sensorsAvailable 보관
   │
   ▼
[게이트] canStartMeasure(available, isDebug) = available || isDebug
   ├ false(미지원 기기) → 빨간 경고카드 "센서 없어 지원 안 함" + 시작버튼 비활성
   └ true → 정상 진행
   │
[지연 선택] 0 / 5 / 10 / 15초 → MeasurementSession.delaySec 에 저장
[거치 안내] placement_sheet.dart (폰을 Y축 방향으로 바닥에 놓는 도식)
   │
   ▼
context.push('/measuring')
```

---

## 6. S4 측정 중 — `features/measure/measuring_screen.dart` (가장 복잡, 718줄)

**앱의 심장부.** 센서를 수집해 엔진에 넣고, 완료 시 검증·저장까지.

### 6-1. 진입 → 카운트다운 → 수집 시작
```
initState:
   ├ WidgetsBindingObserver 등록 (백그라운드 감지용, 안전장치 A3)
   └ delaySec > 0 이면 _startCountdown() (대형 숫자 카운트다운)
        │ 끝나면
        ▼
_initCaptureAndTimers():
   ├ 마이크 권한 요청
   ├ wakelock 켜기 (화면 안 꺼지게)
   ├ 센서 스트림 구독:
   │    ├ 실기기: SensorChannelManager(네이티브 256Hz) → _engine.start(stream)
   │    └ [kDebugMode 한정] 미지원/무수신 시 _subscribeMockStream() (테스트용)
   └ [릴리즈] 3초 무수신 시 "센서 응답 없음" → 중단 (안전장치 A1)
```

### 6-2. 실시간 표시
```
센서 샘플 도착 → _engine 버퍼에 쌓임(엔진이 보관)
   + 라이브 속도 표시: _signedVelocity 부호유지 적분 → 화면엔 .abs() (안전장치 B1)
   + UI 갱신은 150ms 타이머로 스로틀 (초당 7회, 버벅임 방지)
```

### 6-3. 백그라운드 전환 감지 (안전장치 A3)
```
didChangeAppLifecycleState(paused):   // 전화 수신·홈버튼
   _cleanup() (센서·마이크·wakelock 정지) + _measurementAborted = true
didChangeAppLifecycleState(resumed):
   중단됐으면 → "측정 중단됨" 안내 → /start (저장 안 함)
```

### 6-4. 완료 버튼 → `_finishMeasurement()` (검증 4단 → 저장)
이 함수가 안전장치의 집약점. 순서대로 통과해야 저장된다:
```
_finishMeasurement():
   _cleanup()
   │
   ① 현장정보 검증: site == null 또는 층수 파싱 실패 → "측정 실패" → /start
   │
   ② 샘플 검증: _engine.sampleCount < 2 → "센서 데이터 없음" → /start (안전장치 A1)
   │           (가짜 mock 저장 경로는 여기서 원천 차단)
   │
   ▼
   result = _engine.analyze(현장정보 주입)   ← 여기서 도메인 엔진 호출 (7절)
   │
   ③ 타당성 게이트: 측정<8초 or 속도<0.1 or 거리<0.5 → "움직임 미감지" (안전장치 A4)
   │      ├ [다시 측정] → /start
   │      └ [그래도 저장] → lowMotionWarning=true 플래그
   │
   ▼
   MeasurementSession.lastResult = finalResult  ← 보관소에 결과 저장
   │
   ④ 저장: MeasuringScreen.attemptSave() → repository.save()  (8절)
   │      실패 시 "저장 실패" 다이얼로그 [재시도]/[확인] (안전장치 B2)
   │
   ▼
   context.pushReplacement('/result/{id}')
```

---

## 7. 측정 엔진 — `domain/measure/` (순수 Dart, 계산 담당)

`_finishMeasurement`이 부르는 `_engine.analyze()`의 내부. **여기가 흔들림 데이터를
숫자로 바꾸는 계산기.** 파일별 역할:

```
measurement_engine.dart  analyze() ── 아래 순서로 다른 모듈을 호출하는 총괄
   │
   ├ 1. signal_filters.dart
   │     ├ applyBaselineCorrection()  첫 1초 평균을 0점으로 (적분 경로용)
   │     ├ estimateSampleRate()       타임스탬프 중앙값으로 실제 Hz 산출
   │     └ separateMotionAndVibration()  LPF 0.1Hz로 모션/진동 분리
   │            motion=저주파(적분용), vibration=진동(지표용)
   │
   ├ 2. motion_integrator.dart  (motion 성분을 적분)
   │     └ 부호유지 적분 → 속도 v(t), 거리 s(t), 가속도, 저크
   │        maxSpeed, distance 산출 (안전장치 B1의 근원 로직)
   │
   ├ 3. ride_detector.dart
   │     ├ detectRideSegment()      속도>0.05 구간 = 주행 구간
   │     └ detectConstantSpeed()    최대속도 90%↑ 연속구간 = 정속 구간
   │        (지표는 정속 구간에서만 산출 — 소음 71.7 재현의 핵심)
   │
   ├ 4. vibration_metrics.dart  (vibration 성분에서 지표)
   │     ├ calculateAptp()   정속구간을 1.0초 슬라이딩 윈도우 → P2P 95%
   │     │                   (텀블링 아님 — 위상 민감 버그 때문, 연구노트 P1)
   │     ├ calculateNoiseMax()  정속구간 소음 최대
   │     └ ThresholdEvaluation.evaluate()  X/Y>10, Z>15, 소음>50 판정
   │
   └ 5. 결과 조립 → MeasurementResult 반환
         (지표 6종 + 시계열 8종 + 판정 + 원본샘플 + 플래그)

   ※ metrics_config.dart: 위 모든 수치(0.1Hz, 1.0초, 임계 10/15/50 등)의
      단일 정의처. 다른 파일에 숫자 하드코딩 금지 원칙.
   ※ sensor_sample.dart: 표준 샘플 모델(mg 단위, us 타임스탬프).
```

---

## 8. 저장 — `domain/repository/measurement_repository.dart`

```
save(result):
   측정 1건당 measurements/{id}/ 폴더에 3파일 생성
   ├ raw.txt    EVIMP1 포맷 원본 (parse_raw.dart로 직렬화, OTIS 장비 호환)
   ├ meta.json  지표+현장정보+플래그(lowMotionWarning 등)
   └ report.pdf report_generator.dart로 생성 (아래 9절)
   실패 시 반쪽 파일 안 남게 롤백

list()   → 저장된 결과 목록 (History 화면이 사용)
load(id) → meta+raw 합쳐서 MeasurementResult 복원 (과거 결과 조회)
delete(id)
```

---

## 9. 리포트 — `domain/report_generator.dart`

```
generateTuneReportPdf(result):
   ├ Pretendard 한글 폰트 로드 (rootBundle) → 한글 안 깨지게
   ├ 헤더: 현장정보(제번/현장명/층수/방향/일시)
   ├ 6지표 표: X/Y/Z 진동·소음·거리·속도 (임계 초과는 빨간색)
   ├ 8종 차트: X/Y/Z진동·소음·위치·속도·가속도·저크 (실제 파형 렌더링)
   └ 참고 문구: lowMotionWarning / 주행구간 검출실패 시 표기
generateSummaryText(result): 이메일 본문용 요약 텍스트
```

---

## 10. S5 결과 — `features/result/result_screen.dart` + `metric_card.dart`

```
ResultScreen(id):
   ├ id == session.lastResultId → 방금 측정한 결과(보관소에서)
   └ 그 외 → repository.load(id) (과거 결과, History에서 진입 시)
   │
   ├ 상단: 6지표 카드 (metric_card.dart, 초과는 빨간색+아이콘)
   │       + lowMotionWarning/검출실패 시 참고 안내줄
   ├ 중단: 8종 차트 (800pt 다운샘플, 시간축)
   └ 하단: 이메일 발송 버튼 → send_email_sheet.dart
```

---

## 11. 이메일 발송 — `features/shared/send_email_sheet.dart`

```
[바텀시트]
   ├ 수신자: settings에 저장된 email_{id} (없으면 → /settings 유도)
   ├ 첨부 선택: PDF / raw / 차트 등 체크박스
   └ 발송 버튼
        │
        ▼
   flutter_email_sender로 기기 메일 앱 작성창 호출
   (FileProvider가 첨부 파일 권한 처리 — 안전장치 A2)
   ※ "발송"이 아니라 "작성창 열기"까지. 실제 전송은 사용자가 누름.
```

---

## 12. 곁가지 화면

**History `features/history/history_screen.dart`**
```
repository.list() → 저장된 측정 목록
   행 탭 → context.push('/result/{id}') (과거 결과 로드)
   개별 삭제, [kDebugMode] 샘플 복원/비우기 토글
```

**Settings `features/settings/settings_screen.dart`**
```
├ 로그인 사번 표시
├ 이메일 입력·저장 (email_{id} 키로 SharedPreferences)
└ 로그아웃 → AuthRepository 초기화 → /login
```

---

## 부록: 데이터가 흐르는 세 갈래

1. **현장정보**: home → SiteInfo → session.currentSite → measuring가 꺼내
   engine.analyze()에 주입 → result·meta.json·PDF에 박힘
2. **측정 결과**: engine.analyze() → MeasurementResult → session.lastResult +
   repository 저장(3파일) → result 화면 표시 → 이메일 첨부
3. **설정값**: settings → SharedPreferences(email_{id}) → send_email_sheet가 로드
   / auth의 로그인 id → 자동로그인·이메일 키

## 부록: "왜 이렇게 했나"가 궁금하면
이 흐름의 각 결정(왜 슬라이딩 윈도우인지, 왜 정속구간인지, 왜 mock을 릴리즈에서
막는지)의 배경은 **연구노트(research_notes)**에 실패 과정과 함께 기록돼 있다.
코드의 "무엇을"은 이 문서, "왜"는 연구노트가 담당한다.
