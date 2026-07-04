# OTIS 승강기 진동·소음 측정 앱 (vibration_checker)

일반 안드로이드 스마트폰으로 승강기의 승차감(진동·소음·속도·거리)을 측정하고,
OTIS TUNE 규격의 PDF 리포트를 생성·발송하는 앱. 기존에 전용 장비로만 하던 측정을
현장 설치 기사의 폰으로 대체하는 것이 목표다.

> 상태: 코드 통합 완료(Phase 0~5) + 안전장치 보강 완료. 실기기 검증 3건 대기 중.
> 대상 사용자: 나이가 있는 현장 설치 기사 → UI는 큰 글씨·큰 버튼·단순함 우선.

---

## 무엇을 하는가

1. 폰을 카(car) 바닥에 놓고 승강기를 한 층에서 다른 층으로 운행
2. 폰 센서로 X/Y/Z 진동, 소음, 속도, 거리를 측정
3. 기준 초과 항목을 빨간색으로 표시한 리포트 생성 (X·Y>10mg, Z>15mg, 소음>50dBA)
4. PDF + 원본 데이터를 폰에 저장하고 이메일로 발송

측정 지표: X/Y/Z 진동 Aptp(A95 peak-to-peak, mg), 소음 최대(dBA), 운행거리(m),
최대속도(m/s), 그리고 8종 차트(진동 3축·소음·위치·속도·가속도·저크).

---

## 기술 스택

- **Flutter** (Dart SDK ^3.12.0), Android 우선
- 라우팅 `go_router`, 차트 `fl_chart`, PDF `pdf`, 저장 `path_provider` +
  `shared_preferences`, 이메일 `flutter_email_sender`, 화면유지 `wakelock_plus`
- 센서·마이크는 **네이티브 Kotlin**(Platform Channel)로 직접 수집, 256Hz 리샘플
- 상태관리 패키지 없음 — 전역 싱글턴(`MeasurementSession`)으로 화면 간 데이터 전달

---

## 프로젝트 구조

```
lib/
├── main.dart                     앱 진입점 (자동로그인 복원 후 실행)
├── core/
│   ├── router.dart               화면 라우팅 + 로그인 가드
│   └── theme.dart                디자인 토큰 (AppColors/AppDims/AppText)
├── domain/                       계산·저장 로직 (측정 엔진은 순수 Dart)
│   ├── measure/                  ★ 측정 엔진 (앱의 심장)
│   │   ├── measurement_engine.dart   분석 총괄
│   │   ├── signal_filters.dart       기준선 보정·성분 분리(모션/진동)
│   │   ├── ride_detector.dart        주행·정속 구간 검출
│   │   ├── motion_integrator.dart    속도·거리·저크 적분
│   │   ├── vibration_metrics.dart    Aptp·소음·임계 판정
│   │   ├── metrics_config.dart       ★ 모든 수치 파라미터 단일 정의처
│   │   └── sensor_sample.dart        표준 샘플 모델(mg, μs)
│   ├── models/measurement_result.dart  측정 결과 모델
│   ├── repository/measurement_repository.dart  파일 저장(raw/meta/pdf)
│   ├── report_generator.dart     TUNE PDF 리포트 생성
│   ├── sensor_channel.dart       네이티브 센서 채널 연동
│   ├── parse_raw.dart            EVIMP1 raw 파서/라이터
│   └── auth_repository.dart      로그인·자동로그인
├── features/                     화면 (feature 단위)
│   ├── auth/        로그인
│   ├── home/        현장정보 입력
│   ├── measure/     측정 시작·라이브·거치안내
│   ├── result/      결과(카드+차트)
│   ├── history/     저장 목록
│   ├── settings/    설정(이메일)
│   └── shared/      세션·이메일 시트
android/app/src/main/kotlin/com/otis/vibration_checker/  네이티브 센서·소음
assets/sample/2024F1447R01.txt   ★ 골든 픽스처(검증 기준, 수정 금지)
assets/fonts/Pretendard-*.ttf    PDF 한글 폰트
```

전체 코드가 어떻게 이어지는지는 **`code_flow_walkthrough.md`** 참조.

---

## 화면 흐름

```
로그인 → 홈(현장정보) → 측정시작(지연·거치안내) → 측정중(라이브)
   → 결과(카드+차트) → 이메일 발송
                          ↘ 저장 → 히스토리(과거 결과 조회)
```

화면끼리 직접 데이터를 주고받지 않고 전역 세션(`MeasurementSession`)을 거친다.

---

## 시작하기

```bash
flutter pub get
flutter run              # 실기기 연결 권장 (센서·마이크 필요)
flutter test             # 유닛·위젯 테스트
flutter analyze          # 정적 분석
flutter build apk --release
```

**실기기 필요**: 에뮬레이터는 가속도 센서·마이크가 없어 디버그 모드의 mock
스트림으로만 동작한다. 실제 측정은 선형가속도 센서(TYPE_LINEAR_ACCELERATION)가
있는 폰이 필요하며, 없는 기기는 측정 시작 화면에서 "지원 안 됨"으로 차단된다.

---

## 검증 방식 (중요)

이 앱의 정확성은 **골든 픽스처**로 검증한다. `assets/sample/2024F1447R01.txt`는
실제 OTIS 장비로 측정한 데이터이고, 정답이 알려져 있다:

| 지표 | 정답값 |
|---|---|
| 소음 최대 | 71.7 dBA |
| 최대 속도 | 1.50 m/s |
| 운행 거리 | 20.0 m |
| Z 진동 Aptp | 22.2 mg |
| X / Y 진동 Aptp | 8.2 / 12.9 mg (※ OI-1 캘리브레이션 전이라 현재 과대산출) |

엔진 결과를 이 정답과 대조하는 골든 테스트가 `test/domain/measure/`에 있다.
**측정 로직을 수정하면 반드시 골든 테스트로 회귀를 확인할 것.**

---

## 개발 규칙 (요약)

전체 규칙은 **`AGENTS.md`**, 통합 기준은 **`integration_plan.md`** 참조.

- **골든 픽스처 불변**: `assets/sample/2024F1447R01.txt` 수정·삭제 금지
- **수치 단일 정의**: 필터·윈도우·임계값은 `metrics_config.dart` 한 곳에만.
  다른 파일에 숫자 하드코딩 금지
- **임계 판정 고정**: X>10, Y>10, Z>15 mg, 소음>50 dBA
- **디자인 토큰 전용**: 색·치수·글꼴은 `theme.dart`의 AppColors/AppDims/AppText만
- **어르신 UX**: 터치 56dp↑, 주 버튼 64dp, 본문 18sp↑, 상태는 색+아이콘+텍스트 3중
- **단순 우선**: 요구사항에 없는 기능 추가 금지

---

## 현재 상태 & 남은 작업

**완료**: Phase 0~5 통합(측정 엔진·화면·저장·PDF·로그인·이메일), 안전장치 보강
(미지원 기기 차단, 가짜 결과 저장 방지, 백그라운드 중단, 타당성 게이트 등).

**실기기 대기 (코드로는 불가)**:
1. 실기기 샘플레이트 256Hz + 마이크 dBA 반응 실측 (Phase 2)
2. 실기기 이메일 첨부 실제 렌더링 확인 (Phase 5, FileProvider)
3. EVA 장비 병행측정으로 X/Y Aptp 캘리브레이션(OI-1) + 소음 오프셋(OI-4) (Phase 7)

---

## 문서 안내

| 문서 | 내용 |
|---|---|
| `integration_plan.md` | 통합 기준 문서 (모든 판단의 근거) |
| `AGENTS.md` | 코드 작성 규칙 |
| `code_flow_walkthrough.md` | 전체 코드 흐름 (파일·함수 단위) |
| `research_notes_phase0-5.md` | 연구노트 — 시도/실패/해결 과정 ("왜" 담당) |
| `refactor_diagnosis.md` | 리팩토링 진단 |
| `docs/domain_knowledge.md` | 도메인 지식·골든 규격 |
| `phase*_easy.md` | 단계별 비전문가용 설명 |
```
