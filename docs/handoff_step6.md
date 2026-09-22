# 인수인계 — TUNE 리포트 계층 (STEP 1~5 완료, STEP 6 착수용)

이 문서 전체를 새 채팅 세션에 그대로 붙여 넣으면 이어서 작업할 수 있다.
아래 "새 세션에 붙여 넣을 프롬프트" 절이 그 본문이다.

---

## 현재 상태 (사실)

- 브랜치 `rebuild/report` (main 에서 분기, **아직 커밋 없음** — 전부 작업 트리에만 있다)
- `flutter test` **83/83 통과**
- `flutter analyze` 경고 1건 — `measuring_screen.dart:668` 의
  `use_build_context_synchronously`. 이번 작업들 이전부터 있던 것이고 범위 밖이다
- `dart format` 기준으로는 저장소 전반이 미정리 상태다(29개 중 16개). 기존 상태라
  건드리지 않았다

### 만든 파일

| 파일 | 줄 | 역할 |
|---|---|---|
| `lib/domain/report/report_layout.dart` | 685 | 서식 좌표 · 색 · 정렬 전부. 좌표 숫자는 여기에만 있다 |
| `lib/domain/report/report_thresholds.dart` | 104 | 적색 기준 4개와 판정. 임계값 숫자는 여기에만 있다 |
| `lib/domain/report/report_metrics.dart` | 341 | 측정 결과 → 표 8행 |
| `lib/domain/report/measurement_assembler.dart` | 375 | 격자 환산 결과 → `MeasurementResult` |
| `lib/adapter/report/report_page1.dart` | 477 | 1쪽 PDF 렌더링 |
| `lib/domain/session/measurement_session.dart` | 95 | `ui/features/shared/` 에서 옮겨옴 |
| 위 각각의 테스트 5개 | 1,422 | |

### 자산과 데이터

| 경로 | 내용 |
|---|---|
| `assets/report/tem_1.jpg`, `tem_2.jpg` | 서식 배경 (1쪽, 차트쪽) |
| `assets/report/NanumGothic-Regular.ttf`, `-Bold.ttf` | 한글 글꼴. `pubspec.yaml` 의 `assets:` 로 선언 (`fonts:` 아님 — pdf 패키지가 파일째 읽는다) |
| `docs/report_layout.json` | 좌표 정본. md5 `85f531f97400d6bd9b77be7ed043b870` |
| `docs/reference/sample_evimp.pdf` | 원본 리포트 3쪽. 좌표 비교 기준 |
| `test/fixtures/ride_reference.txt` | 회귀 기준 측정 데이터 11,388행 (원래 이름 `H6N1AP65.txt`) |
| `test/fixtures/app_measurement.xlsx` | 소음 0 구간 확인용 |
| `pdf_report_dev/` | 파이썬 프로토타입. `tune_report/` 패키지 + `assets/` 중첩 구조 |

`pubspec.yaml` 에 `pdf: ^3.13.0` (dependencies), `crypto: ^3.0.7` (dev). `printing` 은
**넣지 않았다** — 파일 생성만 필요하다.

---

## 관통하는 원칙 (이걸 어기는 제안은 거절할 것)

1. **재지 않은 값을 0 이나 빈 문자열로 채우지 않는다.** `GridResampleResult` 가
   격자에서 세운 규칙을 전 계층에 적용했다. 그래서 `MeasurementResult` 의
   `xPtp` · `yPtp` · `zPtp` · `noiseMax` · `distance` · `maxSpeed` 가 전부 `double?` 이고,
   판정 게터 넷은 `bool?` 이다. 미측정은 `false` 가 아니라 `null` 이다.
2. **숫자는 한 곳에만 둔다.** 좌표는 `report_layout.dart`, 임계값은
   `report_thresholds.dart`. 주석에도 숫자를 되풀이하지 않는다.
3. **도달 불가 방어 분기 대신 `assert`.** `_minimumRows`(격자 3행),
   수평 행 적색 기준 단일화 두 곳에 걸려 있다. 이유를 주석에 적는다.
4. **실패를 삼키지 않는다.** 변환 실패는 빈 결과가 아니라 사유를 올린다.
5. **주석은 `docs/comment_rules.md`(v4) 를 따른다.** 작업 시작 전 반드시 읽는다.

---

## 계층별로 결정된 것

### 좌표계 — `report_layout.dart`

서식 이미지 픽셀(2256 × 3190, 좌상단 원점) → PDF 포인트(좌하단 원점).
**축별 계수**를 쓴다. 서식 비율 1.414007 이 A4 1.414285 와 달라 단일 계수로는
두 축을 못 맞춘다.

```
ptPerPxX = pageWidthPt / pageWidthPx   = 595.276 / 2256
ptPerPxY = pageHeightPt / pageHeightPx = 841.89 / 3190
xToPoints(x)      = x * ptPerPxX
yToPoints(y)      = pageHeightPt - y * ptPerPxY
lengthToPoints(l) = l * ptPerPxX        // 길이는 뒤집지 않는다
```

Performance Metrics 행 간격은 `106 109 110 109 109 110 95` 로 고르지 않다.
**계산하지 말고 상수를 그대로 쓴다.** 균등 피치로 넘겨짚으면 마지막 행이 12픽셀 밀린다.

차트 슬롯: x 283, w 1458, h 198, y = `415 / 896 / 1377 / 1858`.
여백은 left 220 / right 60 / top 40 / bottom 150.

### 판정 — `report_thresholds.dart`

X 10mg · Y 10mg · Z 15mg · 소음 50dBA 초과 시 적색. 운행 거리 · 최대 속도 ·
평균값은 기준 없음. 황색 단계는 없다.

`ReportVerdict` 는 `green` / `red` / `unknown`(값 없음) / `none`(기준 없음).
`none` 이면 신호등 원을 아예 그리지 않고, `unknown` 이면 회색 원을 그린다.

수평 행은 X·Y 를 각각 판정해 합친다 — 하나라도 넘으면 적색, 못 잰 축이 있고
넘은 축이 없으면 미확정.

### 지표 — `report_metrics.dart`

지금 값이 나오는 것: **최대 속도, 운행 거리**.
비는 것과 이유가 서로 다르다.
- 소음 평균 · 최대 — 수집 경로가 아직 없다
- 수직 · 수평 진동 4개 — 진동 필터 미확정

**소음 두 값의 계약**: 소음은 약 8Hz 로 진동 256Hz 보다 느려 격자 시계열이 표본
사이 봉우리를 잃는다.
- `noiseSeries` 는 차트용
- `noiseMax` 가 소음 최대 지표의 정본. 수집 계층이 센서 최대를 실으면 그 값,
  안 실으면 어셈블러가 시계열 최대로 채운다
- 평균만 시계열에서 낸다. 0 인 표본을 걸러내고 낸다(실측에서 앞 38개가 0)

### 파생 물리량 — `measurement_assembler.dart`

`zSeries`(mg) 에서 만든다. 파이썬 프로토타입 `derive_kinematics()` 와 같은 경로다.

```
accel    = zSeries * 9.80665e-3, 전체 평균 뺌        (m/s²)
speed    = 누적합(accel) * dt, 양 끝 잇는 직선 뺌      (m/s)
position = 누적합(|speed|) * dt                      (m)
jerk     = accel 중앙차분                            (m/s³)
maxSpeed = max(|speed|),  distance = max(pos) - min(pos)
```

실측 회귀 고정값 (`ride_reference.txt`, 11,388행, 256Hz):
**maxSpeed 1.743390961 m/s, distance 57.093948064 m** (허용 오차 1e-6).
원본 리포트 값 1.75 / 57.3 과는 0.4% 이내 — 소수점까지 맞추지 않는다.

### 1쪽 렌더링 — `report_page1.dart`

`PdfGraphics` 저수준 API 로 직접 그린다. 위젯 계층을 쓰지 않는다.

- 텍스트 baseline = `yToPoints(y) - size * 0.36` (프로토타입이 원본과 맞춰 찾은 값)
- 정렬은 `font.stringMetrics(text).advanceWidth * size` 로 폭을 구해 좌/중앙/우
- 서식에 인쇄된 옛 값(적색 칸 전체, 마지막 두 행 황색 `0`, 1행의 지워지다 만 원)을
  **그 행의 줄무늬 색**으로 덮은 뒤 다시 찍는다. 흰색으로 덮으면 자국이 남는다
- 줄무늬: 홀수행 `#E6E9EE`, 짝수행 `#FAF6ED`
- 분석 자료 7개는 **전부 회색**. 확정 사항이니 바꾸지 말 것
- `debug: true` 면 모든 자리에 자홍색 십자와 키 이름. 기본은 꺼짐

**검증 결과**: `PyMuPDF` 로 참조 PDF 1쪽과 대조해 텍스트 19개 전부 같은 자리
(가로 차이 0.00pt, 크기 차이 0.00pt), 신호등 원 10개도 일치.

---

## 알려진 미해결 사항

1. **참조 PDF 가 옛 계수로 그려져 있다.** `docs/reference/sample_evimp.pdf` 는 축별
   분리 이전의 단일 계수 `0.263865` 로 만들어졌다. 신호등 원 중심을 역산해 확정했다
   (행 y=1101 → 참조 290.520, 옛 계수 290.515, 현재 ky 290.571). 내 렌더링이 현재
   정본 기준으로 정확하고, 참조가 옛 산출물이다. 차이는 페이지 맨 아래에서
   0.14pt(0.05mm). **좌표를 고치지 말고 참조 PDF 를 재생성하는 쪽이 맞다.**
2. **요구사항서 `Vibration_Checking_App_Development_20260630.pdf` 가 저장소에 없다.**
   임계값 `근거:` 를 `pdf_report_dev/README.md` 경유로 적어 두었다.
3. **`pdf_report_dev/README.md` 가 `ref/README.md` 보다 옛 내용**이다(행 간격 ·
   좌표 변환식). 교체 여부 미정.
4. **커밋 정책 미정.** `.gitignore` 는 적용했지만 아직 아무것도 커밋하지 않았다.
   `test/fixtures/ride_reference.txt` 는 실제 현장 측정 기록이다.
5. **파이썬 프로토타입을 끝까지 실행하지 못했다** — `matplotlib` · `reportlab` ·
   `pypdf` 가 환경에 없다. `tune_report.metrics` 경로는 돌려서 확인했다.

---

# 새 세션에 붙여 넣을 프롬프트

아래 선 사이를 통째로 복사해 새 채팅에 넣는다.

---

프로젝트: `C:\Users\User\Desktop\OTIS` (Flutter, 브랜치 `rebuild/report`)

`docs/comment_rules.md` 를 먼저 읽어라. 이번 작업부터 끝까지 이 규칙을 따른다.
그 다음 `docs/handoff_step6.md` 를 읽어 STEP 1~5 에서 결정된 것을 파악해라.
특히 "관통하는 원칙" 다섯 가지는 이후 작업에도 그대로 적용된다.

읽어야 할 코드:
- `lib/domain/report/report_layout.dart` — 차트 슬롯 좌표와 색이 여기 있다
- `lib/adapter/report/report_page1.dart` — 같은 저수준 PdfGraphics 사용법의 본보기
- `lib/model/measurement_result.dart` — 그릴 시계열 8개가 여기 있다

## STEP 6 — 차트 그리기

새 파일: `lib/adapter/report/report_chart.dart`

파형 차트를 PDF 캔버스에 직접 그린다. matplotlib 같은 라이브러리는 없다.
`report_page1.dart` 과 같은 저수준 `PdfGraphics` 를 쓴다.

1. 축 사양을 상수로 둔다. 좌표와 마찬가지로 이 파일 밖에 숫자가 새면 안 된다.

   ```
   X 진동   ±10   (원본은 ±4. 아래 주의 참고)
   Y 진동   ±15   (원본은 ±10)
   수직 진동 ±20
   소음     40 ~ 54, 눈금 40 42 44 46 48 50 52 54
   위치     단계형: 0~10 / 25 / 50 / 100 / 150
   속도     단계형: 0~1 / 2 / 4
   가속도    단계형: ±0.6 / ±1 / ±2
   jerk    단계형: ±0.5 / ±1.5 / ±3
   ```

   단계형은 데이터가 들어가는 가장 작은 단계를 고른다. 적분 잔차로 0 근처가
   살짝 음수가 될 수 있으니 비교에 여유를 둔다(범위의 2% 정도).

   X/Y 축을 원본보다 넓힌 이유를 `근거:` 에 적어라 — 원본 차트는 저역통과
   필터를 거친 파형 기준이고, 필터 미적용 원시 데이터를 ±4 에 그리면 8% 이상이
   잘려 파형이 뭉개진다. 필터 확정 시 원본 값으로 되돌린다.

2. 그릴 요소: 축 프레임, 점선 격자, 눈금과 눈금 라벨, y축 라벨(세로),
   x축 라벨 `Time (s)`, 데이터 폴리라인(파란색, 얇게).

3. 데이터가 비면 축 프레임·격자·라벨까지는 그리고 폴리라인만 뺀다. 소음 차트가
   지금 그 상태다. 슬롯을 통째로 비우면 자리가 사라져서, 나중에 소음이 붙었을 때
   레이아웃이 바뀐 것처럼 보인다.

4. 표본이 1만 개를 넘는다. 가로 1458px 폭에 전부 찍으면 파일이 무거워지고 그릴
   필요도 없다. 픽셀 열당 최소/최대만 남기는 방식으로 줄여라.
   봉우리와 골이 사라지면 안 되니 평균을 내지 마라. 줄이기 전후로 최대·최소가
   보존되는지 테스트로 확인해라.

5. 세로 라벨은 저수준 캔버스에서 회전이 필요하다. pdf 패키지의 좌표 변환을
   쓰되, 변환을 걸고 되돌리는 범위를 좁게 잡아 다음 그리기에 새지 않게 해라.

완료 기준: 축 범위를 바꿔도 이 파일 밖을 고칠 필요가 없다.
테스트는 축 단계 선택(경계값 포함)과 표본 줄이기 두 가지를 덮는다.

작업이 끝나면 `flutter analyze` 에 새 경고가 없고 기존 테스트가 전부 통과하는지
확인하고, 매 단계 "추가로 발견한 것"을 보고해라. 범위 밖 파일은 고치지 마라.

---
