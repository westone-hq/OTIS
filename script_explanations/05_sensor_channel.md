# 🌉 하드웨어 통신망 및 센서 데이터 수집 (Sensor Channel)

앱(Flutter)과 스마트폰 안드로이드/iOS 간의 통신을 담당하며, **실제로 기기 센서의 값을 갖고 오는 핵심 스크립트**입니다.

## 📄 관련 스크립트
*   **[sensor_channel.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/sensor_channel.dart)**
*   **[native_event.dart](file:///c:/Users/User/Desktop/OTIS/lib/domain/capture/native_event.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 하드웨어 직접 제어 및 권한 요청
- `SensorChannelManager.checkSensorsAvailable()`: 기기의 가속도/중력 센서 사용 가능 여부를 검사합니다.
- `SensorChannelManager.requestAudioPermission()`: 소음 측정을 위한 마이크 접근 권한을 네이티브(Android) 쪽에 요청합니다.

### 2. 센서 데이터 측정 시작/종료 명령
- `startCapture()`: 네이티브 플랫폼에 MethodChannel을 통해 "지정된 속도로 센서 데이터 수집 시작" 명령을 보냅니다.
- `stopCapture()`: 측정을 중단하고 수집된 원본(Raw) 데이터를 파일로 저장한 경로를 반환받습니다.

### 3. 실시간 센서 스트림 수신 (센서 값 갖고오기)
- `nativeEventStream`: EventChannel을 통해 실시간으로 쏟아지는 방대한 센서 배치 데이터를 `NativeEvent` 객체로 변환하여 Dart Stream으로 앱에 공급합니다. 화면의 실시간 그래프나 데이터 처리 로직은 모두 이 스트림을 구독하여 센서값을 얻습니다.
