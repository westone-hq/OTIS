# 리팩토링·주석 전략 진단 리포트

> 대상: 최신 코드베이스(커밋 d6b4d2f, 8스텝 완주 시점) · lib/ 27파일 6,208줄
> 범위: **중간** (중복 제거·구조 정리, 검증된 로직은 보존)
> 주석: **표준** (공개 API 문서주석 + 복잡한 곳 설명)
> 원칙: 어렵게 안정화한 측정 엔진·안전장치의 **동작은 절대 바꾸지 않는다**.
> 구조/이름/중복만 손대고, 스텝처럼 잘게 쪼개 커밋한다.

---

## 0. 총평 — 도메인은 이미 훌륭, 문제는 UI 계층에 집중

스캔 결과 이 코드베이스는 **두 얼굴**이다.

- **도메인 계층(lib/domain/measure/)**: 이미 상태가 매우 좋다. 공개 API마다 `///`
  문서주석이 달려 있고(엔진·필터·검출기·적분기·지표 전부), MetricsConfig는 파라미터
  단위로 설명이 붙어 있다. 순수 Dart 유지(measure/ 하위는 Flutter import 0건).
  → **여기는 거의 손대지 않는다.** 주석 몇 개 보강 정도.

- **UI 계층(lib/features/)**: 여기에 부채가 몰려 있다. measuring_screen 718줄,
  home 513, result 503. 다이얼로그·버튼·스낵바 패턴이 통째로 복붙되어 있고,
  `_finishMeasurement` 한 함수가 180줄이다.
  → **리팩토링의 90%는 여기.**

정량 근거: 반복된 `Semantics+SizedBox(touchMin)+Button` 패턴 18곳,
measuring_screen에만 showDialog 7개·SnackBar 2개, SharedPreferences 직접 호출이
5개 파일에 흩어짐.

---

## 1. 구조 문제 (중복 제거·정리 대상)

### 1-A. 🔴 `_finishMeasurement` 180줄 God-function (measuring_screen)
한 함수 안에 검증 4종(현장정보 null / 샘플부족 / 타당성게이트 / 저장실패)과
다이얼로그 4개가 인라인으로 박혀 있다. 안전장치를 스텝으로 하나씩 넣다 보니
자연히 쌓인 결과. **로직은 정확하지만 읽기·수정이 어렵다.**

정리 방향(동작 보존):
- 검증 단계를 순수 함수로 분리: `_ValidationResult _validateBeforeSave()` 가
  {ok / siteInvalid / noSamples / lowMotion} 중 하나를 반환. `_finishMeasurement`는
  그 결과에 따라 분기만.
- 각 다이얼로그를 별도 메서드로: `_showFailDialog(msg)`, `_showLowMotionDialog()`,
  `_showSaveRetryDialog()`. 이미 `_showAbortedDialog`·`_showExitDialog`는 분리돼
  있으니 같은 패턴으로 통일.
- 결과: 180줄 → 약 30줄 흐름 + 분리된 메서드들. **테스트는 그대로 통과해야 함**
  (외부 동작 불변).

### 1-B. 🟠 다이얼로그 버튼 패턴 18곳 복붙
`Semantics(button, label) > SizedBox(height: touchMin) > ElevatedButton/TextButton`
이 조합이 파일마다 반복된다. 어르신 UX 규칙(터치 56dp) 때문에 필수인데 매번 손으로
씀.

정리 방향:
- `lib/core/widgets/` 신설 → `AppDialogButton`(주/보조 variant), 필요시
  `AppConfirmDialog(title, content, confirmLabel, cancelLabel)` 헬퍼.
- 18곳을 이걸로 치환. 디자인 토큰 일관성도 자동 확보.
- ⚠️ 단, 이건 위젯 트리를 바꾸므로 **위젯 테스트가 find.text/find.byType로 뭘
  찾는지 확인 후** 치환. 테스트가 깨지면 셀렉터를 새 구조에 맞춰 갱신(동작 검증은 유지).

### 1-C. 🟠 SharedPreferences 직접 호출이 5개 파일에 분산
home·start·settings·send_email·auth_repository가 각자 prefs를 열고 키 문자열
(`email_{id}` 등)을 직접 만짐. 키 오타·중복 위험, 저장 로직 파악이 흩어짐.

정리 방향:
- `lib/domain/prefs_store.dart`(또는 local_store) 신설 → 키를 상수로 모으고
  `saveEmail(id, email)`, `loadEmail(id)`, `saveLastSite(map)` 등 메서드로 캡슐화.
- 각 화면은 이 store만 호출. auth_repository의 prefs는 이미 캡슐화돼 있으니 스타일
  통일 수준.

### 1-D. 🟡 report_generator가 도메인에 있으나 Flutter 의존
`lib/domain/report_generator.dart`가 `package:flutter`(pdf 렌더링 위해)를 import.
순수 도메인 규칙상 애매하지만 pdf 패키지 특성상 불가피. **이동까지는 불필요**,
다만 "이건 순수 도메인이 아니라 출력 어댑터"라는 주석 한 줄로 의도를 명시.
sensor_channel도 동일(Platform Channel이라 Flutter 필요) — 정상.

### 1-E. 🟡 router.dart의 `_Todo` 죽은 클래스
`// ignore: unused_element`로 억눌러둔 미사용 위젯. 화면 다 구현됐으니 삭제.

---

## 2. 코드 위생 (일괄 정리)

### 2-A. 🟠 줄바꿈 CRLF/LF 혼재 (14파일 CRLF, 나머지 LF)
브랜치 합칠 때 생긴 흔적. 지금은 무해하나 diff가 지저분해지고 나중에 "줄 전체가
바뀐 것처럼" 보이는 커밋이 생긴다.
정리: `.gitattributes`에 `*.dart text eol=lf` 추가 후 전 파일 LF 통일(1커밋).
**이건 내용 변경 0이라 가장 안전** — 리팩토링 첫 커밋으로 추천.

### 2-B. 🟡 안전장치 문자열 리터럴 산재
'측정 실패' 등 안내 문구가 코드에 흩어져 있음. 지금 규모(9곳)에선 상수화가 과할 수
있으나, 다이얼로그 헬퍼(1-B) 도입 시 자연히 파라미터로 모임. 별도 작업 불필요.

---

## 3. 주석 전략 (표준: 공개 API 문서주석 + 복잡한 곳 why)

### 원칙
1. **What이 아니라 Why**: 코드로 자명한 건 안 씀. "왜 이 값/이 순서/이 예외"인지를 씀.
   특히 이 프로젝트는 **실패에서 배운 결정**이 많아서, 그 이유를 주석으로 남기면
   가치가 크다(예: "왜 텀블링이 아니라 슬라이딩인가").
2. **공개 API엔 `///` 문서주석**: 클래스·public 메서드. 도메인은 이미 됨 → UI의
   public 위젯/메서드에 보강.
3. **OI/이월 마커 표준화**: `// OI-1:`, `// TODO(Phase 7):`, `// 실기기 PENDING:`을
   일관된 형식으로. 나중에 grep으로 미결 항목을 한 번에 수집 가능하게.

### "왜(why)" 주석을 꼭 남길 핵심 지점 (실패에서 얻은 결정들)
이건 연구노트와 코드를 잇는 다리다. 다음 자리에 1~2줄 근거 주석 권장:
- `vibration_metrics.calculateAptp`: "슬라이딩 윈도우 사용 — 텀블링은 구간 경계
  0.1초 이동에 값이 22.6→16.8로 요동(위상 민감)하여 폐기. 연구노트 Phase1 참조."
- `signal_filters` LPF 컷오프: "0.1Hz — Z축 저주파 진동 보존. 0.8Hz는 진동까지
  모션으로 흡수해 Z 과소산출."
- `motion_integrator`: "부호 유지 적분 — abs 클램프는 하강 운행에서 거리 0 버그."
  (이미 일부 있음, 보강)
- Aptp 경로가 baseline 보정을 **안 하는** 이유: "P2P는 DC 불변 + LPF edge effect로
  Z 과소산출 방지. 적분 경로만 baseline 적용."
- measuring_screen mock 폴백 `kDebugMode`: "릴리즈에서 mock 저장 시 가짜 리포트가
  실제 제출되는 사고 방지. 연구노트 전수검사 A1 참조."
- dBA `+offset`: "// OI-4: 미검증 임시값. 실기기 캘리브레이션 전 절대값 신뢰 불가."

### 하지 말 것
- 줄마다 주석(`i++ // i 증가`) 금지. 도메인 계층에 이미 좋은 밀도가 있으니 그 수준 유지.
- 주석으로 죽은 코드 남기기 금지(삭제하고 git에 맡김).

---

## 4. 권장 실행 순서 (스텝 분할, 안전한 것부터)

Phase 5 안전장치 때처럼 **한 스텝 = 한 커밋**. 앞쪽일수록 무위험.

| 스텝 | 내용 | 위험도 | 근거 |
|---|---|---|---|
| R1 | `.gitattributes` + 전 파일 LF 통일 | 무 | 내용 변경 0 |
| R2 | `_Todo` 죽은 클래스 삭제, OI/TODO 마커 형식 통일 | 무 | 미사용 제거 |
| R3 | 도메인 계층 "why" 주석 보강(4개 핵심 지점) | 무 | 주석만 |
| R4 | `prefs_store` 신설 + 5개 파일 prefs 호출 이전 | 저 | 동작 불변, 테스트로 확인 |
| R5 | `core/widgets`에 다이얼로그·버튼 헬퍼 + 18곳 치환 | 중 | 위젯 트리 변경, 테스트 셀렉터 갱신 |
| R6 | `_finishMeasurement` 검증/다이얼로그 분리(180→30줄) | 중 | 외부 동작 불변 필수, 골든·위젯 테스트 green 유지 |
| R7 | UI 공개 위젯/메서드 `///` 문서주석 보강 | 무 | 주석만 |

각 스텝 게이트: `dart analyze` 0건 + `flutter test` 전체 통과 + 별도 커밋.
R5·R6은 테스트가 깨질 수 있는데, **깨지면 셀렉터/구조를 새것에 맞추되 검증 내용은
약화 금지**(Step 8 테스트 지옥 교훈 — 통과시키려 검증을 비우지 않는다).

---

## 5. 하지 않을 것 (범위 밖 — 중간 리팩토링 선을 지킴)

- 측정 엔진 알고리즘 재작성·최적화 (검증된 로직 보존)
- 상태관리 패키지 도입(Provider/Riverpod 등) — AGENTS 규칙상 금지, 현 싱글턴으로 충분
- 화면 아키텍처 전면 재설계(MVVM 등) — 적극적 범위라 제외
- 폴더 구조 대개편 — 현 feature/domain/core 구조가 이미 합리적
