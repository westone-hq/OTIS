# 수집 채널 계약 (Dart ↔ Kotlin)

Dart `sensor_channel.dart` 와 Kotlin 수집 코드가 공유하는 계약.
어느 한쪽을 바꾸면 반드시 이 문서와 상대쪽을 함께 바꾼다.

## 1. MethodChannel — com.otis.vibration_checker/sensors_method

| 명령 | 인자 | 반환 |
|---|---|---|
| checkAvailable | 없음 | bool — 가속도계와 중력 센서가 모두 존재하면 true |
| requestAudioPermission | 없음 | bool — 마이크 권한 허용 여부 |
| startCapture | sampleRate(int), calibrationOffset(double), micDbfsToDbaOffset(double) | 없음 |
| stopCapture | 없음 | String? — 이번 측정의 원본 기록 파일 절대 경로. 기록 실패 시 null |

- startCapture 의 sampleRate 로 센서 요청 주기를 도출한다:
  samplingPeriodUs = 1,000,000 / sampleRate (판독서 C2)
- stopCapture 는 배치 잔여분을 마저 전송(flush)한 뒤 파일을 닫고 경로를 돌려준다 (판독서 C3)

## 2. EventChannel — com.otis.vibration_checker/sensors_stream

배치(List<Map>)로 전송한다. Map 하나가 원본 이벤트 1건이다.

| 키 | 형 | 내용 |
|---|---|---|
| type | String | "accel" 또는 "gravity". linear 는 보내지 않는다 (RD-6) |
| tsUs | int | 센서 이벤트 시각 (마이크로초). SensorEvent.timestamp(ns)/1000 |
| xMg, yMg, zMg | double | 축별 값 (밀리지). m/s² × 101.97162129779283 |
| dtUs | int | 직전 동일 type 이벤트와의 간격 (마이크로초). 첫 이벤트는 0 |
| noiseDba | double | 해당 시점 소음값 (데시벨) |

- 보간·필터·보정 없이 콜백 도착 그대로 보낸다 (RD-1)
- Dart 는 필수 키 누락 항목을 폐기하고 집계한다. 0값 대체 금지 (RD-4)

## 3. 원본 기록 파일

- 네이티브가 콜백마다 raw_native 형식(RD-2)으로 기록한다:
  `type tsUs x_mg y_mg z_mg dtUs`
- 저장 위치는 앱 영속 저장소 (cacheDir 금지 — 판독서 C6)
- 이 파일이 주기·간격 판정의 근거 자료다. 채널 스트림은 화면 표시·엔진 입력용이다
