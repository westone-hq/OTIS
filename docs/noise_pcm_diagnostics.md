# MIC PCM 동시 측정 진단 (new/dB)

Android 측정 시작 시 기존 MIC 계산과 별도로 다음 경로에 기록한다.

`Android/data/com.otis.vibration_checker/files/noise_diagnostics/<측정시각>_<부팅시각>/`

- `audio.pcm`: 44,100 Hz, mono, signed 16-bit little-endian. MIC가 제공한
  PCM이며 OS 음향 처리 전 신호라고 보장하지 않는다.
- `metadata.json`: 표본률, 실제 정수 창/홉 길이, 기존 총 오프셋, 시작 시각.
- `calculations.csv`: 누적 표본 끝 위치, 실제 읽은 수, 읽기 반환 시각,
  계산 완료 시각, 기록 호출 시각, dBFS와 기존 결과.
  초기 미측정 창은 계산값을 비워 둔다.
- `sensor_noise.csv`: 센서 원본 시각, 기록 호출 시각, 실제 붙인 소음의
  계산 시각·표본 끝 위치·값. 값이 같아도 frame_end가 다르면 새 계산이다.

모든 ns 시각은 BOOTTIME/elapsedRealtimeNanos 기준이다. API 24 이상에서
AudioRecord 하드웨어 timestamp가 성공하면 frame position과 BOOTTIME도
남긴다. 이를 통해 표본 시각을 추정할 수 있다. 미지원은 빈 칸으로 남기며,
read 반환 시각을 마이크 취득 시각으로 오해하면 안 된다.
write/saved 시각은 버퍼에 쓰는 호출 시각이며 디스크 flush 시각이나 Dart
수신 시각이 아니다. 기존 최종 raw 격자 값에는 보간이 추가로 적용된다.

실험 브랜치에서는 매 측정에 자동 기록한다. 일반 저장 결과와 별도이며,
중단한 측정도 진단 폴더를 남긴다. 진단 파일은 메일에 자동 첨부하지 않는다.
PCM 용량은 약 5.3 MB/분이며 CSV가 추가된다. 분석 후 해당 진단 폴더는
수동 정리한다. 녹음에는 대화도 포함될 수 있으므로 공유 전에 확인한다.
파일 I/O는 수집에 부하를 줄 수 있으므로 계산 지연도 함께 확인한다.
쓰기 오류는 Logcat `NoiseDiagnostics`에 남기고 해당 진단 기록을 중단한다.

## 가져오기와 재계산

USB 디버깅 연결 후:

```sh
adb pull /sdcard/Android/data/com.otis.vibration_checker/files/noise_diagnostics ./noise_diagnostics
python -m pip install -r tool/requirements-noise.txt
python tool/compare_noise_pcm.py noise_diagnostics/<측정폴더>
```

`analysis/comparison.csv`, `summary.json`, matplotlib 설치 시 `comparison.png`가
생긴다. 동일 PCM을 현재 창, A 가중 동일 창, A 가중 Fast(125 ms 지수 평균),
A 가중 Slow(1초 지수 평균)로 비교한다. 전체 A 가중 에너지 평균도 계산한다.
현재 오프셋은 현재 방식 재현에만 사용한다. A 가중 결과는 기본적으로 dBFS다.
별도로 검증된 보정값이 있을 때만 `--a-offset <값>`을 지정한다.

A 필터는 bilinear IIR 근사이며 1 kHz를 0 dB로 정규화했다. IEC 적합성을
보장하지 않으며 높은 주파수의 warping을 포함한 응답 검증이 필요하다.
필터/지수 평균은 0 상태로 시작하므로 초기 과도 응답을 포함한다.
이 도구의 A 가중 계산은 실시간 리포트 값을 변경하지 않는다.

`current_replay_max_dbfs_error`로 기존 계산 재현을 먼저 확인한다.
`sensor_snapshot_repeat_percent`는 숫자가 같은 비율이 아니라 같은 계산 결과를
재사용한 비율이다. snapshot age는 센서 처리 시점 기준이므로 센서 배달 지연과
오디오 계산 지연이 함께 반영된다. 하드웨어 앵커 편차가 크면 표본 누락·드리프트를
점검하며, 다른 폰과의 시작 시각은 별도로 정렬해야 한다.
