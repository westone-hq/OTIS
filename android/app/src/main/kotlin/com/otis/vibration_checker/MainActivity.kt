package com.otis.vibration_checker

import android.content.Intent
import android.view.KeyEvent
import com.otis.vibration_checker.sensor.SensorMethodHandler
import com.otis.vibration_checker.update.UpdateInstaller
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 작성: 2026-08-17 15:43:39 · 박건준
 * 수정: 2026-10-22 23:30:00 · nada
 * 클래스: MainActivity
 * 목적: 안드로이드(네이티브, Flutter 쪽에서 부르는 안드로이드 코틀린
 *       코드) 진입점. Flutter와 채널로 연결된다.
 *       - 측정 통로(센서 확인 · 마이크 권한 · 측정 시작 · 종료 · 볼륨키 ·
 *         거치 경고)는 `SensorMethodHandler` 가 맡는다
 *       - 앱 안 업데이트(내려받기 · 설치)는 `UpdateInstaller` 가 따로
 *         통로를 열어 맡는다
 *       이 클래스는 화면 단위로 오는 신호(키 입력 · 권한 응답 · 다른 화면
 *       결과 · 종료)를 두 담당에게 넘긴다.
 */
class MainActivity : FlutterActivity() {
    /** 측정 통로 담당. 엔진이 뜰 때 만든다 */
    private lateinit var sensorMethodHandler: SensorMethodHandler

    /** 앱 안 업데이트의 내려받기 · 설치 담당. 엔진이 뜰 때 만든다 */
    private lateinit var updateInstaller: UpdateInstaller

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-10-22 23:30:00 · nada
     * 함수: configureFlutterEngine
     * 목적: Flutter 엔진이 뜰 때 측정 통로 담당(`SensorMethodHandler`)과
     *       업데이트 담당(`UpdateInstaller`)을 만들어 각자 통로를 등록하게
     *       한다. 측정 중인지는 볼륨키 가로채기가 켜져 있는지로 알려 준다
     *       — 측정 화면에서만 켜진다.
     * 인자: flutterEngine — Flutter 쪽에서 넘겨주는 엔진 인스턴스
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorMethodHandler = SensorMethodHandler(this)
        // → 로직 이동: SensorMethodHandler.register()
        sensorMethodHandler.register(flutterEngine.dartExecutor.binaryMessenger)

        updateInstaller =
            UpdateInstaller(this) { sensorMethodHandler.volumeKeyCaptureEnabled }
        // → 로직 이동: UpdateInstaller.register()
        updateInstaller.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    /**
     * 작성: 2026-10-01 13:04:31 · 박희정
     * 수정: 2026-10-22 23:30:00 · nada
     * 함수: dispatchKeyEvent
     * 목적: 측정 중 볼륨키를 측정 종료 요청으로 쓰도록 측정 통로 담당에
     *       먼저 넘긴다. 가로채지 않은 키는 본래 동작을 그대로 둔다.
     * 인자: event — 눌린 키 정보
     * 반환: 가로챘으면 true, 아니면 상위 클래스의 처리 결과
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (::sensorMethodHandler.isInitialized &&
            // → 로직 이동: SensorMethodHandler.handleKeyEvent()
            sensorMethodHandler.handleKeyEvent(event)
        ) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-10-22 23:30:00 · nada
     * 함수: onRequestPermissionsResult
     * 목적: 시스템 권한 대화상자에 대한 사용자 응답을 측정 통로 담당에
     *       넘긴다. 마이크 · 고속 샘플링 권한 모두 그쪽이 요청했다.
     * 인자: requestCode — 어떤 권한 요청에 대한 응답인지 구분하는 값
     *       permissions — 요청했던 권한 이름 목록. 여기서는 안 쓴다
     *       grantResults — 각 권한에 대한 승인 결과. 인덱스가
     *       permissions 와 대응한다
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::sensorMethodHandler.isInitialized) {
            // → 로직 이동: SensorMethodHandler.onRequestPermissionsResult()
            sensorMethodHandler.onRequestPermissionsResult(requestCode, grantResults)
        }
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: onActivityResult
     * 목적: 다른 화면에서 돌아온 결과를 받는다. 앱 설치 허용 설정 화면에서
     *       돌아온 것이면 `UpdateInstaller` 가 다시 확인해 Flutter 에
     *       알린다.
     * 인자: requestCode — 어느 화면을 열었던 요청인지 가르는 값
     *       resultCode — 그 화면의 결과 코드. 설정 화면은 주지 않는다
     *       data — 돌려받은 자료. 쓰지 않는다
     */
    @Deprecated("startActivityForResult 계약을 그대로 쓴다")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (::updateInstaller.isInitialized) {
            // → 로직 이동: UpdateInstaller.onActivityResult()
            updateInstaller.onActivityResult(requestCode)
        }
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-10-22 23:30:00 · nada
     * 함수: onDestroy
     * 목적: 액티비티가 완전히 종료될 때 측정 통로 담당과 업데이트 담당을
     *       정리해, 자원을 계속 붙들고 있지 않게 한다.
     */
    override fun onDestroy() {
        super.onDestroy()
        if (::sensorMethodHandler.isInitialized) {
            // → 로직 이동: SensorMethodHandler.dispose()
            sensorMethodHandler.dispose()
        }
        if (::updateInstaller.isInitialized) {
            // → 로직 이동: UpdateInstaller.dispose()
            updateInstaller.dispose()
        }
    }
}
