# 💾 현장 정보 저장소 (Prefs Store)

이 문서는 기사님이 마지막으로 측정한 현장 정보(예: 아파트 이름, 동, 호수)를 기억하여 반복 입력을 줄여주는 스크립트를 설명합니다.

## 📄 관련 스크립트
*   **[prefs_store.dart](file:///c:/Users/User/Desktop/OTIS/lib/adapter/prefs_store.dart)**

## ⚙️ 주요 기능 및 구현 위치

### 1. 현장 정보 캐싱
- 측정 시작 전 입력한 현장 정보(Job No, 현장명, 층수 등)를 로컬 디바이스(SharedPreferences 등)에 안전하게 임시 저장합니다.
- 다음 번 앱 실행 시 `PrefsStore`에서 이전 기록을 불러와 UI에 자동으로 채워줍니다.
