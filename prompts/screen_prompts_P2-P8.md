# Antigravity 화면별 프롬프트 세트 (Flutter, 통합 구조 v2)

사용법: 아래 프롬프트를 순서대로 하나씩 실행. AGENTS.md 규칙이 자동 적용되지만,
각 프롬프트 첫 줄의 "AGENTS.md 규칙과 login_screen.dart 스타일을 따라" 문구는 유지할 것.
S1 로그인은 이미 구현되어 있음 (lib/features/auth/login_screen.dart).

---

## P2 · S2 홈 / 현장정보 입력

```
AGENTS.md 규칙과 lib/features/auth/login_screen.dart 스타일을 따라
lib/features/home/home_screen.dart 를 구현하고 router.dart의 /home 라우트에 연결해줘.

목적: 이번 측정의 현장 정보를 입력하고 측정을 시작하는 홈 화면.

구성(위→아래):
- AppBar: 제목 "진동 측정", actions에 설정 아이콘 버튼(Icons.settings_outlined + "설정" 라벨,
  탭 → context.push('/settings')), 그 옆에 목록 아이콘 버튼(Icons.folder_open_outlined + "저장 결과",
  탭 → context.push('/history')). 두 버튼 모두 터치 영역 56dp 이상.
- 스크롤 영역, 섹션 제목 "현장 정보" (AppText.subhead)
- 입력 필드(각 높이 AppDims.fieldH, 라벨은 필드 위 AppText.bodyBold):
  1) 제번 — hint "예: 2024F 1447R01"
  2) 현장명 — hint "예: 럭키종합건설/송정동근생"
  3) 최하층 / 최상층 — Row로 좌우 2개 숫자 입력 (hint "1" / "8")
  4) 운전 방향 — SegmentedButton 2개: "하부 → 상부"(기본 선택) / "상부 → 하부".
     세그먼트 높이 56dp 이상, 선택 시 AppColors.blue 배경 + 흰 텍스트.
  5) 기종 — DropdownButtonFormField, 항목 ["Gen2", "기타"], 기본 Gen2
- 하단 고정(bottomNavigationBar 영역에 SafeArea + Padding):
  ElevatedButton "측정 시작" → 필수값(제번, 현장명, 층) 검증 후 context.push('/start').
  누락 시 해당 필드에 오류 표시(색+아이콘+텍스트)하고 그 위치로 스크롤.

상태: 입력값은 화면 상태로 유지. 마지막 입력값을 다음 진입 시 복원하는 TODO 주석 남길 것.
```

---

## P3 · S3 측정 시작 (시간 선택 + 거치 안내 시트)

```
AGENTS.md 규칙과 기존 화면 스타일을 따라 lib/features/measure/start_screen.dart 와
lib/features/measure/placement_sheet.dart 를 구현하고 /start 라우트에 연결해줘.

[start_screen.dart]
목적: 카운트다운 대기 시간을 고르고 측정을 시작. 거치 안내는 시트로 분리.

구성(위→아래):
- AppBar "측정 시작" + 뒤로가기
- 리마인더 카드(AppColors.surface 배경, radius 12):
  Icons.smartphone 아이콘 + "휴대폰을 카 바닥 중앙에 놓으세요" (AppText.body)
  + 오른쪽에 TextButton "거치 방법 보기" → showModalBottomSheet로 placement_sheet 표시
- 질문 텍스트 "언제 측정을 시작할까요?" (AppText.subhead)
- 대기 시간 선택: 2x2 GridView 고정 높이 카드 4개 "0초" "5초" "10초" "15초".
  각 카드 높이 72dp, 기본 5초 선택. 선택 = AppColors.blue 배경 + 흰 텍스트 + 체크 아이콘,
  비선택 = surface 배경 + 테두리. (색+아이콘 병행)
- 선택 요약 텍스트: "버튼을 누르면 {n}초 후 측정이 시작됩니다" (AppText.caption)
- 하단 고정 ElevatedButton "카운트다운 시작" → context.push('/measuring')

최초 1회 자동 안내: SharedPreferences 없이 우선 앱 세션 전역 bool(간단한 static)으로
"이번 실행에서 시트를 본 적 없으면 화면 진입 직후 자동으로 시트 표시".
SharedPreferences 영구 저장은 TODO 주석.

[placement_sheet.dart]
- DraggableScrollableSheet 아님. 고정 높이(화면의 ~75%) showModalBottomSheet 콘텐츠.
- 제목 "휴대폰 거치 방법" (AppText.subhead) + 닫기 X 버튼(56dp)
- 도식: CustomPaint 또는 단순 위젯 조합으로 카 평면도 — 위쪽에 "출입구" 라벨 박스,
  중앙에 폰 모양 rect, 세로 방향 Y축 화살표. 색은 AppColors.navy/blue만 사용.
  ※ 방향 정의는 OI-1 미확정 — 도식 위젯에 "// TODO: OI-1 확정 후 방향 검증" 주석 필수.
- 번호 단계 4개(원형 번호 뱃지 40dp + AppText.body):
  1 카운트다운이 끝나기 전에 휴대폰을 바닥에 놓으세요
  2 휴대폰을 Y축 방향으로 맞추세요
  3 테스트가 시작되면 엘리베이터를 움직이세요
  4 완전히 멈추면 '테스트 완료'를 누르세요
- 경고 배너(gold 배경 8% + 테두리): Icons.volume_off_outlined + "측정 중에는 조용히 해주세요"
- 하단 ElevatedButton "확인했습니다" → 시트 닫기
```

---

## P4 · S4 측정 중 (라이브)

```
AGENTS.md 규칙을 따라 lib/features/measure/measuring_screen.dart 를 구현하고
/measuring 라우트에 연결해줘.

목적: 측정 진행 중 실시간 속도·경과 시간 표시. 멀리서도 읽히게 초대형.

구성:
- 배경 AppColors.navy (이 화면만 어두운 배경 허용 — 대비 목적), 텍스트는 흰색 기반.
- 상단: "테스트 진행 중..." (AppText.subhead, 흰색)
- 중앙: "현재 속도" 라벨(흰색 70%) + 초대형 숫자 "4.38" (fontSize 72, w800, 흰색)
  + 단위 "미터/초" (AppText.subhead, AppColors.gold)
- 그 아래: "걸린 시간" 라벨 + "0:06" (AppText.bigNumber 흰색). Timer.periodic으로 실제 카운트.
- 경고 배너(AppColors.red 배경, radius 12): Icons.front_hand_outlined 흰색 +
  "테스트가 진행되는 동안 휴대폰을 들어 올리지 마세요" (흰색 AppText.bodyBold)
- 하단 고정 ElevatedButton "테스트 완료" → context.pushReplacement('/result/demo')
- 속도 값은 지금은 mock: 0에서 1.50까지 가속했다가 유지하는 가짜 스트림
  (Stream.periodic). "// TODO: 센서 채널 연결" 주석.
- 뒤로가기(pop) 시 "측정을 중단할까요?" 확인 다이얼로그(버튼 2개, 각 56dp+).
```

---

## P5 · 결과 통합 화면 (요약 카드 + 차트 스크롤)

```
AGENTS.md 규칙을 따라 lib/features/result/result_screen.dart 와
lib/features/result/metric_card.dart 를 구현하고 /result/:id 라우트에 연결해줘.
차트는 fl_chart 패키지를 pubspec에 추가해서 사용.

목적: 측정 결과를 한 화면에서 - 위쪽 6지표 카드, 아래로 스크롤하면 차트 8종.
신규 측정 결과와 저장된 결과 열람에 같은 화면을 재사용.

데이터 모델: lib/domain/models/measurement_result.dart 에
MeasurementResult(id, 제번, 현장명, 최하층, 최상층, 방향, 일시,
xPtp, yPtp, zPtp, noiseMax, distance, maxSpeed, 시계열 List들) 순수 Dart로 정의.
임계 판정은 모델의 getter로: xExceeded(>10), yExceeded(>10), zExceeded(>15), noiseExceeded(>50).
mock 인스턴스 1개를 실제 값으로 제공 (12.9 / 8.2 / 22.2 / 71.7 / 21.0 / 1.50).

구성:
- AppBar "측정 결과" + 뒤로가기
- 현장 요약 한 줄 (AppText.caption): "2024F 1447R01 · 럭키종합건설/송정동근생 · 1층 → 8층"
- 6지표 카드: GridView 2열, childAspectRatio로 카드 높이 ~120dp.
  metric_card.dart 의 MetricCard 위젯: 라벨(AppText.body) + 값(fontSize 30 w700) + 단위.
  기준 초과 시: 카드 왼쪽 8dp red bar + 값/아이콘 red + 상단 우측 "기준 초과" 태그(red 배경 10%).
  정상 시: green "정상" 태그. 운행거리/최대속도는 태그 없음.
  카드 탭 → 아래 해당 차트 위치로 Scrollable.ensureVisible 스크롤.
- 차트 섹션 제목 "데이터 차트" (AppText.subhead)
- 차트 8개 세로 나열(각각 카드 안 LineChart, 높이 180dp):
  X축 진동 / Y축 진동 / Z축 진동 / 소음 / 위치 / 속도 / 가속도 / 저크.
  초과 지표 차트에는 임계선(빨강 점선 HorizontalLine) 표시.
  데이터는 mock 시계열(수십 포인트면 충분). 성능 위해 ListView 안에서 lazy 빌드.
  "// TODO: assets/sample/2024F1447R01.txt 파싱 연결" 주석.
- 하단 고정 ElevatedButton "이메일로 보내기" → 이메일 발송 시트(P7에서 구현 예정,
  지금은 SnackBar "발송 시트 구현 예정" 표시).
```

---

## P6 · S5 저장 결과 목록

```
AGENTS.md 규칙을 따라 lib/features/history/history_screen.dart 를 구현하고
/history 라우트에 연결해줘.

목적: 폰에 저장된 과거 측정 결과 목록. 행에서 결과 열람과 발송 진입.

구성:
- AppBar "저장된 결과" + 뒤로가기
- ListView. 각 행 높이 88dp 이상, InkWell 전체 탭 → context.push('/result/{id}'):
  - 왼쪽 상태 점 16dp: 초과 항목 있으면 AppColors.red, 없으면 green
    (+ 점 옆 작은 텍스트 "초과"/"정상" — 색+텍스트 병행)
  - 중앙: 제번+현장명 (AppText.bodyBold, 1줄 ellipsis)
           아래 줄: 일시 + 요약 (AppText.caption, 예: "2026-03-02 · Z 22.2mg 초과")
  - 뱃지: "PDF" "RAW" 작은 Chip 2개
  - 오른쪽: 공유 아이콘 버튼(Icons.mail_outline, 56dp, 탭 → 발송 시트 자리 SnackBar)
    + chevron
- mock 데이터 3건 (하나는 실제 값 결과, 둘은 변형).
- 빈 상태: Icons.inbox_outlined 64dp + "저장된 결과가 없습니다" (AppText.body)
  + OutlinedButton "측정하러 가기" → /home.
```

---

## P7 · 이메일 발송 bottom sheet (공용 컴포넌트)

```
AGENTS.md 규칙을 따라 lib/features/shared/send_email_sheet.dart 를 구현하고,
result_screen.dart 하단 버튼과 history_screen.dart 행의 메일 아이콘에서
이 시트를 호출하도록 연결해줘.

목적: 결과를 등록된 이메일로 발송. 보낼 항목 선택. 화면이 아니라 시트.

구성 (showModalBottomSheet, 높이 ~70%, radius 상단 12):
- 제목 "이메일 발송" (AppText.subhead) + 닫기 X (56dp)
- 수신자 카드(surface 배경): "받는 사람" 라벨 + "soonkyu.lee@otis.com" (AppText.bodyBold)
  + TextButton "변경" → 시트 닫고 context.push('/settings')
- 발송 항목 CheckboxListTile 4개 (각 행 높이 64dp, 체크박스 scale 1.4, 텍스트 AppText.body):
  [v] PDF 리포트 / [v] RAW 데이터 파일 / [ ] 음향 녹음 파일 / [ ] 지표 요약(메일 본문)
- 하단 ElevatedButton "보내기": 탭 → 로딩(버튼 내 스피너) 800ms mock
  → 시트 닫고 SnackBar "이메일이 발송되었습니다" (Icons.check_circle_outline 포함).
  "// TODO: 실제 발송 API 연결" 주석.
- 항목 0개 선택 시 버튼 비활성 + 안내 텍스트 "보낼 항목을 선택하세요".
```

---

## P8 · S6 설정

```
AGENTS.md 규칙을 따라 lib/features/settings/settings_screen.dart 를 구현하고
/settings 라우트에 연결해줘.

구성:
- AppBar "설정" + 뒤로가기
- 프로필 카드(surface): Icons.person_outline 40dp + "123456" (AppText.bodyBold)
  + "Otis 직원" (AppText.caption)
- 섹션 "결과 수신 이메일" (AppText.bodyBold):
  TextField(height fieldH, 초기값 "soonkyu.lee@otis.com", 이메일 keyboardType)
  + ElevatedButton "저장" (이 화면의 주 행동). 저장 시 간단 이메일 형식 검증 →
  통과: SnackBar "저장되었습니다" / 실패: 필드 오류(색+아이콘+텍스트).
- ListTile 2개 (높이 64dp): "앱 버전  0.1.0" / "문의하기" (탭 → SnackBar "준비 중").
- 맨 아래 OutlinedButton "로그아웃" (텍스트/테두리 AppColors.red) →
  확인 다이얼로그 → context.go('/login').
```

---

## 이후 단계 (UI 완료 후)

- P9: assets/sample 파싱 유틸 (`lib/domain/parse_raw.dart`) + 차트 실데이터 연결
- P10: A95 산출·임계 판정 모듈 (`lib/domain/metrics.dart`) + 유닛테스트
- P11: Kotlin 센서 채널 (256Hz 가속도 + 마이크 dBA) — S22에서 검증
- P12: PDF 리포트 생성 (pdf 패키지) — 기존 TUNE 리포트 레이아웃 재현
