# ⏱️ 실시간 측정 및 제어 화면 (Measuring)

기사님이 실제로 엘리베이터 안에서 테스트를 진행할 때 표시되는 실시간 라이브 측정 화면과 상태를 관리하는 **"실제 측정이 이루어지는 곳"** 에 대한 스크립트입니다.

## 📄 관련 스크립트
*   **[measuring_screen.dart](file:///c:/Users/User/Desktop/OTIS/lib/ui/features/measure/measuring_screen.dart)**
*   **[measurement_session.dart](file:///c:/Users/User/Desktop/OTIS/lib/ui/features/shared/measurement_session.dart)**
*   **[grid_resampler.dart](file:///c:/Users/User/Desktop/OTIS/lib/domain/capture/grid_resampler.dart)**
*   **[vibration_file_writer.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/vibration_file_writer.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 측정 세션 관리
- **`MeasurementSession`**: 전역 싱글톤으로 현장 정보(`SiteInfo`)와 측정 딜레이(Delay)를 메모리에 보관하여 앱 전반의 측정 흐름을 잃지 않게 유지합니다.

### 2. 센서 데이터 수집 및 UI 갱신 (측정 로직)
- **`_MeasuringScreenState._initCaptureAndTimers()`**: 화면이 시작될 때 카운트다운이 끝나면 `sensorManager.startCapture()`를 호출하여 센서를 켭니다. 화면은 `WakelockPlus`를 통해 꺼지지 않게 유지하며 실시간 측정 경과 시간을 계산하여 노출시킵니다.
- 네이티브에서 올라오는 `nativeEventStream` 센서 값을 지속적으로 구독(listen)하여 가공 엔진인 `GridResampler`에 값을 넘깁니다 (`_resampler.onEvent`).

### 3. 측정 완료 및 데이터 물리적 저장
- **`_finishMeasurement()`**: "테스트 완료" 버튼을 누르면 센서 수집을 즉시 중지합니다.
- 이후 `_resampler.resample()`을 통해 그간 모인 수만개의 이벤트들을 정해진 격자(Grid)로 환산하여 최종 진동 배열(`GridResampleResult`)로 가공합니다.
- 가공이 완료된 데이터는 **`VibrationFileWriter.write()`** 를 통해 휴대폰 디렉토리에 텍스트와 메타데이터 파일로 안전하게 기록되고, 요약 다이얼로그를 띄워 현장 보고를 마무리합니다.
