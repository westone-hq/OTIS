# OTIS 진동 측정 앱 — 도메인 지식 및 규격 (Knowledge & Specs)

> [!IMPORTANT]
> 이 문서는 저장소 통합 및 개발 전 과정(Phase 0~7) 및 세션 간 유지되어야 하는 불변의 도메인 기준과 골든 픽스처 사양을 기록합니다.

---

## 1. 골든 기대값 (Golden Expectations)
- **픽스처 파일**: `assets/sample/2024F1447R01.txt` (절대 수정·삭제·재생성 금지)
- **출처**: EVA메일 첨부 (제번 2024F 1447R01, 럭키종합건설/송정동근생, 1→8층, Floor To Floor Run)
- **지표 기대값**:
  - **X Aptp (A95 peak-to-peak)**: 8.2 mg
  - **Y Aptp (A95 peak-to-peak)**: 12.9 mg
  - **Z Aptp (A95 peak-to-peak)**: 22.2 mg
  - **소음 최대 (Noise Max)**: 71.7 dBA (정속구간 v>1.4m/s, 11.6~22.0s 기준)
  - **운행 거리 (Distance)**: 20.0 m (Z축 수직 가속도 이중적분 기준, 실측 적분치 21.0m)
  - **최대 속도 (Max Velocity)**: 1.50 m/s (Z축 수직 가속도 적분 기준, 실측 적분치 1.509 m/s)
- **주의사항**: 현 mock 및 AGENTS.md에 X↔Y가 스왑된 경우가 있으나 문서 및 EVA 리포트 기준으로 X=8.2, Y=12.9 가 정답임.

---

## 2. EVIMP1 포맷 규격 (Raw Data Format)
- **헤더 형식**:
  ```text
  EVIMP1
  {sampleRate}
  ```
  (예: 256Hz인 경우 첫 줄 `EVIMP1`, 둘째 줄 `256`)
- **데이터 컬럼 (4열 공백 분리)**:
  ```text
  x y z noise
  ```
  - `x`, `y`, `z`: 각 축 진동 가속도 (단위: **mg**)
  - `noise`: 소음 (단위: **dBA**)
- **샘플 규격**: `2024F1447R01.txt` 기준 256Hz, 6,988샘플 (27.3초).

---

## 3. MetricsConfig 파라미터의 결정 근거와 변경 이력
- **단일 정의 원칙**: 모든 지표, 필터, 윈도우, 임계 파라미터 수치는 `lib/domain/measure/metrics_config.dart` 한 곳에만 존재해야 하며 리터럴 복제 금지.
- **주요 초기 파라미터 및 결정 근거**:
  - `baselineSec = 1.0`: 측정 시작 직후(카운트다운 종료 후 정지 상태) 기준선 보정(평균 차감)을 위한 정지 구간 시간.
  - `motionLowpassCutoffHz = 0.8`: 모션 성분(저주파 주행/가감속 가속도)과 진동 성분(고역)을 분리하기 위한 저역통과 필터 컷오프 주파수.
  - `rideSpeedThreshold = 0.05`: 주행 구간 검출 속도 임계치 (m/s).
  - `constantSpeedRatio = 0.9`: 정속 구간 판단 비율 (최고 속도의 90% 이상 유지 구간).
  - `aptpWindowSec = 0.5`: Aptp(A95 P2P) 산출을 위한 텀블링 윈도우 시간 (초). 축별 오버라이드 가능.
  - `aptpPercentile = 0.95`: 95번째 백분위수 (A95) 선택.
  - **임계 판정 (D3 불변 규칙)**:
    - `thresholdX = 10.0` mg (초과 시 붉은색)
    - `thresholdY = 10.0` mg (초과 시 붉은색)
    - `thresholdZ = 15.0` mg (초과 시 붉은색)
    - `thresholdNoise = 50.0` dBA (초과 시 붉은색)
- **변경 이력 (Change Log)**:
  - 2026-07-04: 초기 설정 (integration_plan.md D2~D8 및 Phase 1 기반 정의 확정)
  - 2026-07-04: Aptp 경로는 baseline 보정 미적용(P2P는 DC 불변, LPF edge effect와의 상호작용으로 Z 진동 과소산출 방지). 적분 경로만 baseline 보정 적용. cutoffHz 0.8→0.1 (Z 저주파 진동 보존).
  - (향후 Phase 7 현장 캘리브레이션 OI-1, OI-4 진행 시 피팅 결과 및 변경 이력 기록 예정)

---

## 4. 기기별 실측 샘플레이트 (Device Sample Rate Matrix)
- **목표 샘플레이트**: 256Hz (네이티브 Android `SensorStreamHandler`에서 256Hz 선형 보간 리샘플 적용)
- **기종별 실측 메모 (테이블)**:
  | 기종 | OS / SDK | 센서 콜백 주기 (Raw) | 리샘플 후 유효 샘플레이트 | 마이크 편차 / 오프셋 (OI-4) | 비고 |
  |---|---|---|---|---|---|
  | 에뮬레이터 / 모의 | Android | - (Mock) | 256 Hz (고정) | 0.0 dBA | Mock 스트림 |
  | (대기중: OI-3 법인폰/협력업체폰) | - | - | - | - | Phase 7 실기기 측정 시 업데이트 |
