# 📄 결과 보고서 생성 (Report Generator)

수집 및 분석이 완료된 진동 데이터를 현장 소장님이나 본사로 전달하기 위한 최종 문서(PDF, CSV 등)로 변환하는 기능을 갖춘 스크립트입니다.

## 📄 관련 스크립트
*   **[report_generator.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/report_generator.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 리포트 포맷 변환
- `MeasurementResult` 객체와 측정된 시계열 진동 데이터를 넘겨받아 보고서 레이아웃에 맞춰 데이터를 배치하고 PDF 또는 Excel용 CSV 파일로 렌더링합니다.

### 2. 외부 공유 연결
- 변환이 끝난 파일의 로컬 경로를 반환하여, 이메일 첨부 파일(`send_email_sheet.dart`)로 손쉽게 연동될 수 있도록 돕습니다.
