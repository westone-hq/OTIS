# XYZ 센서값 — 발표 대본

> PPT: `docs/회의자료_XYZ_raw값_코드_v2.pptx`  
> 대상: Galaxy S22 · 256Hz · 원초 센서 데이터 설명  
> 말투: 회의/설명용 · 최대한 쉽게

---

## 1페이지 — 표지

안녕하세요.  
오늘은 OTIS 앱에서 **X/Y/Z 센서 값이 어디서 오고, 코드에서 어떻게 쓰이는지**만 간단히 설명드리겠습니다.

핵심만 말씀드리면,

- **Raw, Gravity, Linear** → **폰(Android)이 줍니다**
- **Motion** → **우리 앱 코드가 `Raw − Gravity`로 계산합니다**

저장, 메일, 적분 같은 건 오늘은 빼고, **원초 데이터만** 보겠습니다.

---

## 2페이지 — Raw XYZ 코드

### 한 줄 요약
> **Raw = 가속도계가 찍은 “그대로” 값. 중력이 섞여 있습니다.**

### 대본

첫 번째는 **Raw**입니다.

코드 파일은 `SensorStreamHandler.kt`이고,  
폰 안에 있는 **가속도계 센서**를 읽습니다.

센서 이름은 `TYPE_ACCELEROMETER`입니다.

엘리베이터가 **가만히 있어도** Z축 Raw는 대략 **1000mg(1g)** 근처가 나옵니다.  
이건 엘리베이터가 미친 듯이 움직인다는 뜻이 **아니라**, **중력**이 같이 잡히기 때문입니다.

코드가 하는 일은 **세 단계**입니다. 슬라이드에도 [1][2][3]으로 나뉘어 있습니다.

1. **[1] 버퍼 저장** — 센서 이벤트가 올 때마다 X, Y, Z와 `timestamp`를 `rawSample.push(...)`로 쌓습니다  
2. **[2] 256Hz 시각에 꺼내기** — Linear 이벤트의 `while` 루프 안에서  
   `val (rawX, rawY, rawZ) = rawSample.interpolateAt(nextTargetNs)`  
   이때 **rawX 변수가 생깁니다.** `event.values[0]`을 그 시각으로 **보간**한 값입니다  
3. **[3] mg 변환** — `"rawX" to (rawX * MPS2_TO_MG)` 로 Flutter Map에 넣습니다  

단위는 **mg**입니다.

**raw.txt** 파일에도 `rawX`, `rawY`, `rawZ` 열로 저장됩니다.

**우리가 만든 값이 아닙니다. 폰이 측정한 원본입니다.**

---

## 3페이지 — Gravity XYZ 코드

### 한 줄 요약
> **Gravity = 폰이 “지금 중력이 이만큼이다”라고 추정한 값.**

### 대본

두 번째는 **Gravity**입니다.

같은 Kotlin 파일에서, 이번엔 `TYPE_GRAVITY` 센서를 읽습니다.

이것도 **폰(Android)이 계산해서 주는 값**입니다.  
**우리가 14.88mg 같은 숫자를 정해 넣는 게 아닙니다.**

폰이 “지금 휴대폰 기준으로 중력이 X/Y/Z 방향으로 이만큼 걸린다”고 **추정**한 겁니다.

코드 흐름은 Raw와 **똑같은 3단계**입니다.

1. **[1]** `gravitySample.push(...)` — 이벤트 올 때 X, Y, Z 쌓기  
2. **[2]** `val (gravX, gravY, gravZ) = gravitySample.interpolateAt(nextTargetNs)` — 256Hz 시각에 보간  
3. **[3]** `"gravityX" to (gravX * MPS2_TO_MG)` — mg 변환 후 Flutter로 전달  

휴대폰을 세워 두면 **gravityZ ≈ 1000mg** 정도가 흔합니다.

나중에 **Motion**을 만들 때, **이 Gravity를 Raw에서 빼게 됩니다.**

---

## 4페이지 — Linear XYZ 코드

### 한 줄 요약
> **Linear = 폰이 “중력 뺀 가속도”로 **따로** 만들어 준 값. 진동 분석에 씁니다.**

### 대본

세 번째는 **Linear**입니다.

센서 타입은 `TYPE_LINEAR_ACCELERATION`입니다.

이것도 **폰이 줍니다.**  
목적은 **“중력 빼고, 실제 흔들림/가속만 보고 싶다”** 입니다.

Raw랑 비슷해 보이지만, **만드는 방식이 다릅니다.**

- Raw, Gravity → 각각 센서에서 **따로** 읽음  
- Linear → Android **안에서** 필터·센서 융합 등을 거쳐 **별도 채널**로 제공  

Android가 **내부 계산식을 공개하지는 않습니다.**  
그래서 “Linear = Raw − Gravity **만** 한다”고 **단정할 수 없습니다.**

코드도 **3단계**입니다. Raw/Gravity와 같은 루프 안에서 같이 나갑니다.

1. **[1] 버퍼 저장** — `linearSample.push(currNs, currX, currY, currZ)`  
   (`currX/Y/Z` = Linear 이벤트의 `event.values`)  
2. **[2] 256Hz 보간** — `while (nextTargetNs <= currNs)` 안에서  
   `alpha` 계산 후 `interpX = prevX + alpha * (currX - prevX)` (Y, Z 동일)  
   ※ Raw/Gravity는 `interpolateAt`, Linear는 **인라인 보간**  
3. **[3] mg 변환** — `"x" to (interpX * MPS2_TO_MG)` → raw.txt의 linearX/Y/Z  

실측 예를 들면, 같은 0.1초 구간에서  
**Linear X 평균 ≈ 0.79mg** 가 나올 수 있습니다.

**진동 P-P, Aptp** 같은 **진동 지표**는 이 Linear를 기반으로 계산합니다.  
(오늘은 진동 코드까지는 안 들어갑니다.)

---

## 5페이지 — Motion XYZ 코드 (우리 공식)

### 한 줄 요약
> **Motion = 우리 코드가 `Raw − Gravity`로 직접 계산한 값.**

### 대본

네 번째부터는 **우리 앱 코드**입니다.

파일은 `sensor_sample.dart`입니다.

**입력:** Kotlin [3]단계에서 이미 mg 단위로 넘어온 `rawX`, `gravityX` (SensorSample.fromMap)

공식은 아주 단순합니다.

```
motionX = rawX − gravityX
motionY = rawY − gravityY
motionZ = rawZ − gravityZ
```

**매 샘플, 매 축**마다 이렇게 뺍니다.

Raw와 Gravity가 **둘 다 있을 때만** 위 공식을 씁니다.  
없으면 **Linear 값(x, y, z)으로 대체**합니다. (fallback)

중요한 점:

- **Motion은 폰이 주는 값이 아닙니다**
- **Linear와도 다른 값입니다**
- 우리가 Raw·Gravity(둘 다 폰 값)를 받아서 **코드로 빼 만든 것**입니다

같은 구간 예시:

- Raw 평균 16.27  
- Gravity 평균 14.88  
- **Motion = 1.39**

한편 폰 Linear는 **0.79**일 수 있습니다.

**목적은 비슷(중력 제거)** 해도, **숫자가 다른 건 정상**입니다.

---

## 6페이지 — Motion 계산 예시 (X축)

### 한 줄 요약
> **코드가 실제로 하는 일 = 초등학교 뺄셈 한 번.**

### 대본

마지막 슬라이드는 **숫자 예시**입니다. X축 기준입니다.

**폰이 준 값:**

| 항목 | 값 |
|------|-----|
| rawX | 16.27 mg |
| gravityX | 14.88 mg |

**우리 코드:**

```
motionX = rawX − gravityX
        = 16.27 − 14.88
        =  1.39 mg
```

이게 전부입니다. **0.00980665 같은 곱셈은 아직 없습니다.**  
mg 단위 **원초 데이터**만 보는 단계니까요.

**비교:**

| | 값 | 누가 |
|---|-----|------|
| Linear X 평균 | 0.79 mg | 폰 |
| Motion X 평균 | 1.39 mg | 우리 (Raw−Gravity) |

둘 다 “중력 뺀 가속도”를 보려는 값이지만,  
**계산 경로가 달라서 숫자가 다를 수 있습니다.**

Y축, Z축도 **완전히 같은 방식**입니다.

```
motionY = rawY − gravityY
motionZ = rawZ − gravityZ
```

Z축은 Raw가 1000mg대, Gravity도 1000mg대라  
빼면 **작은 Motion(예: 10~30mg)** 이 나오는 경우가 많습니다.

---

## 마무리 (말로만 — 슬라이드 없음)

정리하면,

| 값 | 출처 |
|----|------|
| Raw | 폰 |
| Gravity | 폰 |
| Linear | 폰 |
| **Motion** | **우리 코드 (Raw − Gravity)** |

오늘 범위는 **여기까지**입니다.

속도·거리로 **적분**할 때는 mg → m/s² 변환(×0.00980665)이 들어가지만,  
**원초 데이터만 볼 때는 필요 없습니다.**

질문 있으시면 말씀해 주세요. 감사합니다.

---

## Q&A 예상 질문 · 짧은 답

**Q. Linear 쓰면 되지 않나요?**  
A. 앱은 진동은 Linear, 거리/속도는 Motion을 씁니다. 어느 쪽이 더 정확한지 코드·문서에 비교 근거는 없습니다.

**Q. Motion 1.39랑 Linear 0.79 중 뭐가 맞나요?**  
A. 둘 다 “중력 제거” 목적이지만 알고리즘이 달라서 숫자가 다릅니다. 단순 뺄셈 결과는 Motion 쪽입니다.

**Q. Gravity 숫자는 우리가 정하나요?**  
A. 아닙니다. Android TYPE_GRAVITY 센서 값입니다.

**Q. 0.00980665는 언제 쓰나요?**  
A. mg를 m/s²로 바꿔서 **속도·거리 적분**할 때입니다. 원초 mg만 볼 때는 불필요합니다.
