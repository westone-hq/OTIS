package com.otis.vibration_checker

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.os.Build
import android.hardware.Sensor
import android.hardware.SensorManager
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 작성: 2026-08-17 15:43:39 · 박건준
 * 수정: 2026-10-13 14:18:51 · nada
 * 클래스: MainActivity
 * 목적: 안드로이드(네이티브, Flutter 쪽에서 부르는 안드로이드 코틀린
 *       코드) 진입점. Flutter와 채널로 연결된다.
 *       - `MethodChannel`(요청 하나 · 응답 하나짜리 통로)로 센서 확인 ·
 *         마이크 권한 · 측정 시작 · 종료 명령을 받아 처리한다
 *       - `EventChannel`(계속 흘려보내는 통로)은 `SensorStreamHandler`
 *         에게 맡겨 센서 원본 데이터를 Flutter로 흘려보낸다
 *       - 앱 안 업데이트(내려받기 · 설치)는 `UpdateInstaller` 가 따로
 *         통로를 열어 맡는다
 */
class MainActivity : FlutterActivity() {
    /**
     * 작성: 2026-07-04 12:00:10 · 박건준
     * 수정: 2026-10-04 13:50:15 · nada
     * 클래스: Companion
     * 목적: Flutter와 연결할 채널 이름, 권한 요청 코드 등 MainActivity
     *       전역에서 쓰는 상수를 모아둔다.
     */
    companion object {
        /**
         * 작성: 2026-07-04 12:00:10 · 박건준
         * 수정: 2026-10-04 13:50:15 · nada
         * 변수: METHOD_CHANNEL
         * 목적: 요청 하나 · 응답 하나를 주고받는 통로 이름. Flutter 쪽
         *       `sensor_channel.dart` 의 `_methodChannel` 과 문자열이 반드시
         *       같아야 한다. 컴파일러가 대신 검사해주는 연결이 아니라서, 둘
         *       중 하나만 바뀌면 컴파일은 되지만 요청이 반대편에 닿지 않고
         *       조용히 실패한다.
         */
        private const val METHOD_CHANNEL =
            "com.otis.vibration_checker/sensors_method"

        /**
         * 작성: 2026-07-04 12:00:10 · 박건준
         * 수정: 2026-10-04 13:50:15 · nada
         * 변수: STREAM_CHANNEL
         * 목적: 센서 값을 계속 흘려보내는 통로 이름. `METHOD_CHANNEL` 과
         *       같은 이유로 `sensor_channel.dart` 의 `_eventChannel` 과
         *       문자열이 반드시 같아야 한다.
         */
        private const val STREAM_CHANNEL =
            "com.otis.vibration_checker/sensors_stream"

        /** 마이크 권한 요청 코드. 응답을 고속 샘플링 권한과 구분하는 임의 값 */
        private const val REQ_AUDIO_PERMISSION = 1001

        /** 고속 샘플링 권한 요청 코드. 응답을 마이크 권한과 구분하는 임의 값 */
        private const val REQ_HIGH_RATE_PERMISSION = 1002

        /**
         * 작성: 2026-10-22 09:30:00 · nada
         * 변수: PLACEMENT_BEEP_MS
         * 목적: 거치 경고음 길이 (밀리초). 짧게 한 번 울린다.
         * 근거: 미정 — 엎어 둔 휴대폰에서 알아들을 만한 길이로 골랐다.
         *       경고는 수집 시작 약 1초 뒤라 지표 구간 밖이다
         */
        private const val PLACEMENT_BEEP_MS = 200

        /**
         * 작성: 2026-10-22 09:30:00 · nada
         * 변수: PLACEMENT_VIBRATE_MS
         * 목적: 거치 경고 진동 길이 (밀리초).
         * 근거: 미정 — `PLACEMENT_BEEP_MS` 와 같은 이유
         */
        private const val PLACEMENT_VIBRATE_MS = 300L
    }

    /** 소음(마이크) 원본 캡처 담당. startCapture/stopCapture·onDestroy에서 시작·정지한다 */
    private lateinit var noiseCaptureHandler: NoiseCaptureHandler

    /** 가속도 · 중력 센서 원본 캡처 담당. 시작 · 종료 요청을 그대로 넘긴다 */
    private lateinit var sensorStreamHandler: SensorStreamHandler

    /** 앱 안 업데이트의 내려받기 · 설치 담당. 엔진이 뜰 때 만든다 */
    private lateinit var updateInstaller: UpdateInstaller

    /** 측정 중 볼륨키를 "측정 종료" 입력으로 쓸지 여부. 측정 화면에서만 true로 켠다 */
    private var volumeKeyCaptureEnabled = false

    /** Flutter 쪽으로 볼륨키 종료 요청을 보낼 통로 */
    private var methodChannel: MethodChannel? = null

    /** 마이크 권한 요청 결과를 알려줄 콜백. 요청을 보낸 동안에만 값이 있고,
     *  onRequestPermissionsResult 에서 쓰고 나면 다시 null 로 비운다 */
    private var permissionCallback: MethodChannel.Result? = null

    /**
     * 고속 샘플링 권한 승인을 기다리는 동안 미뤄둔, 승인 후 이어서 실행할
     * 수집 시작 동작. 권한 요청 중이 아니면 null
     */
    private var pendingStartCapture: (() -> Unit)? = null

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-10-13 14:18:51 · nada
     * 함수: configureFlutterEngine
     * 목적: Flutter 엔진이 뜰 때 소음·센서·소음테스트 핸들러를 만들고,
     *       MethodChannel·EventChannel을 등록해 Flutter와 안드로이드를
     *       연결한다. 업데이트 담당(`UpdateInstaller`)도 만들어 자기 통로를
     *       등록하게 한다. 측정 중인지는 볼륨키 가로채기가 켜져 있는지로
     *       알려 준다 — 측정 화면에서만 켜진다.
     * 인자: flutterEngine — Flutter 쪽에서 넘겨주는 엔진 인스턴스
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        noiseCaptureHandler = NoiseCaptureHandler(this)
        sensorStreamHandler = SensorStreamHandler(this, noiseCaptureHandler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            // → 로직 이동: SensorStreamHandler.onListen()
            .setStreamHandler(sensorStreamHandler)

        updateInstaller = UpdateInstaller(this) { volumeKeyCaptureEnabled }
        // → 로직 이동: UpdateInstaller.register()
        updateInstaller.register(flutterEngine.dartExecutor.binaryMessenger)


        methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-08-19 13:25:00 · 박희정
                     * 함수: checkAvailable
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "checkAvailable" 요청에 응답한다. 이 기기에
                     *       가속도 · 중력 센서가 실제로 달려있는지 확인한다.
                     * 반환: result.success(Boolean) 으로 응답. 가속도계와
                     *       중력 센서가 둘 다 있으면 true
                     */
                    "checkAvailable" -> {
                        val sensorManager = // 센서 목록 조회 서비스. 못 가져오면 null
                            getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        val accel = // 가속도 센서, 없으면 null
                            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                        val gravity = // 중력 센서, 없으면 null
                            sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        result.success(accel != null && gravity != null)
                    }
                    /**
                     * 작성: 2026-09-15 13:30:00 · 박희정
                     * 수정: 2026-10-05 10:03:35 · nada
                     * 함수: requestAudioPermission
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "requestAudioPermission" 요청에 응답한다.
                     *       마이크 권한이 이미 있으면 곧바로 성공을
                     *       알려주고, 없으면 시스템 권한 대화상자를 띄운
                     *       뒤 사용자 응답을 기다린다.
                     *       권한 창이 이미 떠 있는 동안 들어온 요청은 바로
                     *       false 로 거절한다.
                     * 반환: result.success(Boolean) 으로 응답. 이미
                     *       승인된 상태면 즉시 true, 아니면 사용자가
                     *       응답할 때까지 기다렸다가 아래
                     *       onRequestPermissionsResult 가 이어서 응답한다
                     */
                    "requestAudioPermission" -> {
                        if (ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else if (permissionCallback != null) {
                            // 권한 창이 이미 떠 있다. 앞 요청의 응답 자리를
                            // 덮어쓰면 앞 요청은 끝내 응답을 못 받으므로,
                            // 겹친 요청은 바로 거절한다
                            result.success(false)
                        } else {
                            permissionCallback = result
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_AUDIO_PERMISSION
                            )
                        }
                    }
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-10-04 13:50:15 · nada
                     * 함수: startCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "startCapture" 요청에 응답한다. 소음(마이크)과
                     *       가속도 · 중력 센서 캡처를 함께 시작한다.
                     *       - Android 12(S) 이상은 고속 샘플링 권한이
                     *         없으면 먼저 요청하고, 응답이 온 뒤 시작한다
                     *         (`pendingStartCapture`에 맡겨둔다)
                     *       - 이미 권한이 있거나 Android 12 미만이면
                     *         곧바로 시작한다
                     * 인자: calibrationOffset — 현장·기기 보정(dBA), 기본 0.0
                     *       micDbfsToDbaOffset — dBFS→dBA 오프셋. 넘어오지
                     *       않으면 `NoiseCaptureHandler` 의 기본값
                     * 반환: result.success(null) 로 즉시 응답한다. 실제로
                     *       캡처가 시작됐는지는 기다리지 않는다
                     * 근거: 측정 — SENSOR_DELAY_FASTEST 로 요청해도 실제 수신
                     *       속도는 단말 하드웨어 주기라 200Hz 를 넘는다
                     */
                    "startCapture" -> {
                        val calibrationOffset = // 현장 · 기기 보정(dBA)
                            call.argument<Double>("calibrationOffset") ?: 0.0
                        val micDbfsToDbaOffset = // dBFS→dBA 기본 오프셋
                            call.argument<Double>("micDbfsToDbaOffset")
                                ?: NoiseCaptureHandler.DEFAULT_MIC_DBFS_TO_DBA_OFFSET
                        val begin = { // 소음 · 센서 수집을 함께 켜는 동작
                            // → 로직 이동: NoiseCaptureHandler.start()
                            noiseCaptureHandler.start(
                                calibrationOffset,
                                micDbfsToDbaOffset,
                            )
                            // → 로직 이동: SensorStreamHandler.start()
                            sensorStreamHandler.start()
                        }

                        val needsHighRate = // 고속 샘플링 권한이 필요한 버전인지
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        val permName = // 고속 샘플링 권한 이름
                            "android.permission.HIGH_SAMPLING_RATE_SENSORS"
                        if (needsHighRate &&
                            ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                permName
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingStartCapture = begin
                            // → 로직 이동: onRequestPermissionsResult()
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(permName),
                                REQ_HIGH_RATE_PERMISSION
                            )
                        } else {
                            begin()
                        }
                        result.success(null)
                    }
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-10-22 12:00:00 · nada
                     * 함수: stopCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "stopCapture" 요청에 응답한다. 센서·소음
                     *       캡처를 멈추고 원본 기록 · 현장 소음 녹음 파일
                     *       경로를 돌려준다.
                     * 반환: result.success(Map) 로 응답.
                     *       - "recordPath" — 원본 기록 경로, 못 했으면 null
                     *       - "audioPath" — 현장 소음 녹음(M4A) 경로,
                     *         녹음하지 않았거나 실패했으면 null
                     *       - "noiseSampleRate" — 소음 마이크를 연 표본
                     *         속도(Hz, 48000 또는 44100). 열지 못했으면 null
                     */
                    "stopCapture" -> {
                        // → 로직 이동: SensorStreamHandler.stop()
                        val recordPath = // 저장한 원본 기록 경로, 못 했으면 null
                            sensorStreamHandler.stop()
                        // → 로직 이동: NoiseCaptureHandler.stop()
                        val audioPath = // 닫은 소음 녹음 경로, 없으면 null
                            noiseCaptureHandler.stop()
                        val noiseRate = // 소음 마이크를 연 표본 속도, 못 열었으면 0
                            noiseCaptureHandler.activeSampleRate
                        result.success(
                            mapOf(
                                "recordPath" to recordPath,
                                "audioPath" to audioPath,
                                "noiseSampleRate" to noiseRate.takeIf { it > 0 },
                            ),
                        )
                    }
                    /**
                     * 작성: 2026-10-01 13:04:31 · 박희정
                     * 수정: 2026-10-04 13:50:15 · nada
                     * 함수: setVolumeKeyCaptureEnabled
                     * 목적: 측정 중에만 볼륨키를 측정 종료 입력으로 바꾼다.
                     *       false 일 때는 시스템 볼륨키 동작에 손대지 않는다.
                     *       실제 가로채기는 `dispatchKeyEvent()` 가 한다.
                     */
                    "setVolumeKeyCaptureEnabled" -> {
                        volumeKeyCaptureEnabled =
                            call.argument<Boolean>("enabled") ?: false
                        result.success(null)
                    }
                    /**
                     * 작성: 2026-10-22 09:30:00 · nada
                     * 함수: playPlacementAlert
                     * 목적: 거치가 화면 아래가 아닐 때 경고음 한 번과 진동을
                     *       울린다(`playPlacementAlert()`). 측정은 계속한다.
                     */
                    "playPlacementAlert" -> {
                        // → 로직 이동: playPlacementAlert()
                        playPlacementAlert()
                        result.success(null)
                    }
                    /**
                     * 작성: 2026-07-04 12:00:10 · 박건준
                     * 함수: else
                     * 목적: 정의되지 않은 메서드 이름의 요청에 미구현으로
                     *       응답한다.
                     */
                    else -> {
                        result.notImplemented()
                    }
            }
        }
    }

    /**
     * 작성: 2026-10-01 13:04:31 · 박희정
     * 수정: 2026-10-05 10:03:35 · nada
     * 함수: dispatchKeyEvent
     * 목적: 측정 중 볼륨 올림 · 내림 키를 소리 크기 변경 대신 측정 종료
     *       요청으로 쓴다. 가로채는 동안에는 누름 · 뗌 · 길게 눌러 반복되는
     *       키를 모두 소비해 시스템으로 넘기지 않는다 — 하나라도 넘기면
     *       소리 크기가 바뀌고 볼륨 패널이 뜬다. 종료 알림은 처음 누를
     *       때 한 번만 보낸다. 가로채기가 꺼져 있으면(측정 전 · 후) 본래
     *       동작을 그대로 둔다.
     * 인자: event — 눌린 키 정보
     * 반환: 가로챘으면 true, 아니면 상위 클래스의 처리 결과
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val isVolumeKey = // 볼륨 올림 · 내림 키인지
            event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (volumeKeyCaptureEnabled && isVolumeKey) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                // → 로직 이동: SensorChannelManager._installMethodCallHandler()
                methodChannel?.invokeMethod(
                    "volumeKeyPressed",
                    mapOf("keyCode" to event.keyCode)
                )
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-09-15 13:30:00 · 박희정
     * 함수: onRequestPermissionsResult
     * 목적: 시스템 권한 대화상자에 대한 사용자 응답을 받아, 기다리고
     *       있던 쪽에 결과를 이어준다.
     *       - 마이크 권한 응답이면 대기 중이던 `permissionCallback`에
     *         승인 여부를 알려준다
     *       - 고속 샘플링 권한 응답이면, 승인 여부와 무관하게 대기 중이던
     *         `pendingStartCapture`(캡처 시작 동작)를 실행한다. 미승인이면
     *         저속으로라도 캡처는 계속 진행하되 경고를 로그로 남긴다
     * 인자: requestCode — 어떤 권한 요청에 대한 응답인지 구분하는 값
     *       (`REQ_AUDIO_PERMISSION` 또는 `REQ_HIGH_RATE_PERMISSION`)
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
        if (requestCode == REQ_AUDIO_PERMISSION) {
            val granted = // 마이크 권한을 허용했는지
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionCallback?.success(granted)
            permissionCallback = null
        }
        if (requestCode == REQ_HIGH_RATE_PERMISSION) {
            val granted = // 고속 샘플링 권한을 허용했는지
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                android.util.Log.w(
                    "MainActivity",
                    "고속 샘플링 권한 미승인 — 200Hz 초과 콜백이 오지 않을 수 있다"
                )
            }
            // 승인 여부와 무관하게 수집은 시작한다 (미승인 시 저속만 유효)
            pendingStartCapture?.invoke()
            pendingStartCapture = null
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
     * 수정: 2026-10-18 10:12:30 · nada
     * 함수: onDestroy
     * 목적: 액티비티가 완전히 종료될 때 센서·소음·소음테스트 핸들러와
     *       업데이트 담당을 정리해, 자원을 계속 붙들고 있지 않게 한다.
     *       측정 도중 끝나면 Flutter 가 받아 갈 수 없으므로 현장 소음
     *       녹음은 닫으면서 지운다.
     */
    override fun onDestroy() {
        super.onDestroy()
        volumeKeyCaptureEnabled = false
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop()
        }
        if (::noiseCaptureHandler.isInitialized) {
            // → 로직 이동: NoiseCaptureHandler.stopAndDiscardAudio()
            noiseCaptureHandler.stopAndDiscardAudio()
        }
        if (::updateInstaller.isInitialized) {
            // → 로직 이동: UpdateInstaller.dispose()
            updateInstaller.dispose()
        }
    }

    /**
     * 작성: 2026-10-22 09:30:00 · nada
     * 함수: playPlacementAlert
     * 목적: 경고음(`ToneGenerator`, 알람 소리 통로)을 `PLACEMENT_BEEP_MS` 울리고
     *       진동을 `PLACEMENT_VIBRATE_MS` 준다. 휴대폰이 엎어져 있어 화면
     *       안내를 볼 수 없을 때 쓰는 신호다. 소리 · 진동 장치를 못 열어도
     *       기록만 남기고 넘어간다 — 경고 때문에 측정이 멈추면 안 된다.
     *       경고음은 소음 마이크와 녹음(noise.m4a)에, 진동은 가속도계에 들어
     *       가지만 수집 시작 약 1초 뒤(운행 전 정지 구간)라 지표 구간 밖이다.
     */
    private fun playPlacementAlert() {
        try {
            val tone = // 경고음 발생기. 울린 뒤 놓는다
                ToneGenerator(AudioManager.STREAM_ALARM, ToneGenerator.MAX_VOLUME)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP, PLACEMENT_BEEP_MS)
            Handler(Looper.getMainLooper()).postDelayed(
                { tone.release() },
                PLACEMENT_BEEP_MS + 100L,
            )
        } catch (e: RuntimeException) {
            android.util.Log.w("MainActivity", "거치 경고음 실패: $e")
        }
        try {
            val vibrator = // 기기 진동 장치
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(VibratorManager::class.java).defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(
                        PLACEMENT_VIBRATE_MS,
                        VibrationEffect.DEFAULT_AMPLITUDE,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(PLACEMENT_VIBRATE_MS)
            }
        } catch (e: RuntimeException) {
            android.util.Log.w("MainActivity", "거치 경고 진동 실패: $e")
        }
    }
}
