package com.otis.vibration_checker

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * 작성: 2026-10-13 14:18:51 · nada
 * 클래스: UpdateInstaller
 * 목적: 앱 안 업데이트의 안드로이드 쪽. Flutter 의 `update_installer.dart`
 *       가 부른다. 구글 플레이 없이 배포 서버(GitHub Releases)의 APK 를
 *       받아 설치 화면을 연다.
 *       - 내려받기: `HttpURLConnection` 으로 `cacheDir/update/` 에 받으며
 *         진행률을 `EventChannel`(계속 흘려보내는 통로)로 보내고, 받은
 *         파일의 SHA-256 을 version.json 값과 맞춰 본다. 다르면 지운다
 *       - 설치: `FileProvider`(다른 앱에 파일을 잠깐 보여 주는 통로)를
 *         쓰지 않고 `PackageInstaller` 세션(createSession → openWrite 로
 *         APK 바이트 쓰기 → commit)으로 넘긴다. `shared_file_paths.xml`
 *         은 메일 첨부(cache/mail/)만 열어 둔 그대로 둔다
 *       - 설치 허용: 안드로이드 8 이상은 "출처를 알 수 없는 앱 설치" 를 앱
 *         마다 허용해야 한다. 꺼져 있으면 그 설정 화면을 열고, 돌아오면
 *         다시 확인해 알려 준다
 *       측정 중에는 내려받기 · 설치를 받지 않는다(`isMeasuring`).
 */
class UpdateInstaller(
    /** 설정 화면 · 설치 확인 화면을 띄울 화면 */
    private val activity: Activity,
    /** 지금 측정 중인지 알려 주는 함수. 측정 중이면 요청을 거절한다 */
    private val isMeasuring: () -> Boolean,
) : EventChannel.StreamHandler {

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 클래스: Companion
     * 목적: 채널 이름 · 요청 코드 · 파일 이름 등 상수를 모아 둔다.
     */
    companion object {
        /**
         * 작성: 2026-10-13 14:18:51 · nada
         * 변수: METHOD_CHANNEL
         * 목적: 요청 하나 · 응답 하나를 주고받는 통로 이름. Flutter 쪽
         *       `update_installer.dart` 의 `_methodChannel` 과 문자열이
         *       반드시 같아야 한다 — 다르면 컴파일은 되지만 요청이 닿지
         *       않는다.
         */
        const val METHOD_CHANNEL = "com.otis.vibration_checker/update_method"

        /**
         * 작성: 2026-10-13 14:18:51 · nada
         * 변수: PROGRESS_CHANNEL
         * 목적: 내려받기 진행률을 흘려보내는 통로 이름. `METHOD_CHANNEL`
         *       과 같은 이유로 `update_installer.dart` 의 `_progressChannel`
         *       과 같아야 한다.
         */
        const val PROGRESS_CHANNEL = "com.otis.vibration_checker/update_progress"

        /** 설치 허용 설정 화면 요청 코드. 다른 화면 결과와 구분하는 임의 값 */
        const val REQ_INSTALL_PERMISSION = 2001

        /** 설치 결과 방송(broadcast)의 이름. 이 앱 안에서만 쓴다 */
        private const val ACTION_INSTALL_STATUS =
            "com.otis.vibration_checker.UPDATE_INSTALL_STATUS"

        /** 받은 APK 를 두는 `cacheDir` 아래 폴더 이름 */
        private const val UPDATE_DIR = "update"

        /** 받은 APK 파일 이름. 한 번에 하나만 받으므로 고정한다 */
        private const val APK_NAME = "vcheck-update.apk"

        /**
         * 작성: 2026-10-13 14:18:51 · nada
         * 변수: CONNECT_TIMEOUT_MS
         * 목적: 서버 연결을 기다리는 한도 (밀리초).
         * 근거: 미정 — 화면에 진행 막대와 취소가 있어 version.json 확인
         *       (3초)보다 길게 잡았다. 실기기 확인 뒤 조정한다
         */
        private const val CONNECT_TIMEOUT_MS = 15_000

        /**
         * 작성: 2026-10-13 14:18:51 · nada
         * 변수: READ_TIMEOUT_MS
         * 목적: 받는 도중 데이터가 끊긴 채 기다리는 한도 (밀리초).
         * 근거: 미정 — `CONNECT_TIMEOUT_MS` 와 같은 이유
         */
        private const val READ_TIMEOUT_MS = 30_000

        /** 읽기 한 번에 쓰는 버퍼 크기 (바이트) */
        private const val BUFFER_BYTES = 64 * 1024
    }

    /** 메인 스레드에서 Flutter 로 결과 · 진행률을 보낼 때 쓰는 연결 */
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 진행률을 받을 Flutter 쪽 통로. 듣는 쪽이 없으면 null */
    private var progressSink: EventChannel.EventSink? = null

    /** 설치 허용 설정 화면에서 돌아오기를 기다리는 응답 자리. 아니면 null */
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** 진행 중인 내려받기 스레드. 받는 중이 아니면 null */
    private var downloadThread: Thread? = null

    /** 내려받기 취소 표시. `cancelDownload` 가 켜고 받는 스레드가 본다 */
    @Volatile
    private var cancelRequested = false

    /** 설치 결과를 기다리는 응답 자리. 설치 중이 아니면 null */
    private var pendingInstallResult: MethodChannel.Result? = null

    /** 설치 결과 방송을 받는 수신기. 설치 중에만 등록한다 */
    private var installReceiver: BroadcastReceiver? = null

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: register
     * 목적: 두 통로를 Flutter 엔진에 연결한다. `MainActivity` 가 엔진을
     *       만들 때 한 번 부른다. 지난 업데이트 때 받아 둔 APK(약 55MB)를
     *       여기서 지운다 — 설치가 끝나면 앱이 바로 바뀌어 지울 틈이 없고,
     *       앱이 막 켜진 이때는 받는 중인 파일이 없다.
     * 인자: messenger — Flutter 엔진의 메시지 통로
     */
    fun register(messenger: BinaryMessenger) {
        File(activity.cacheDir, UPDATE_DIR).deleteRecursively()
        EventChannel(messenger, PROGRESS_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: canInstall
                 * 목적: 이 앱이 다른 APK 를 설치할 수 있게 허용됐는지
                 *       알려 준다. 안드로이드 8 미만은 앱별 허용이 없어
                 *       늘 true 다.
                 * 반환: result.success(Boolean)
                 */
                "canInstall" -> result.success(canInstall())
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: openInstallSettings
                 * 목적: "이 출처의 앱 설치 허용" 설정 화면을 연다. 사용자가
                 *       돌아오면 `onActivityResult()` 가 다시 확인해 답한다.
                 *       이미 연 화면을 기다리는 중이면 겹친 요청은 바로
                 *       지금 상태로 답한다.
                 * 반환: result.success(Boolean) — 돌아온 뒤 허용됐는지
                 */
                "openInstallSettings" -> {
                    if (pendingPermissionResult != null ||
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O
                    ) {
                        result.success(canInstall())
                    } else {
                        pendingPermissionResult = result
                        val intent = Intent( // 이 앱의 설치 허용 설정 화면
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}"),
                        )
                        // → 로직 이동: onActivityResult()
                        activity.startActivityForResult(intent, REQ_INSTALL_PERMISSION)
                    }
                }
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: download
                 * 목적: APK 를 내려받아 SHA-256 을 맞춰 본다. 받는 동안
                 *       진행률을 `PROGRESS_CHANNEL` 로 보낸다.
                 * 인자: url — APK https 주소
                 *       sha256 — 기대하는 SHA-256 (16진수 소문자 64자)
                 * 반환: 성공이면 result.success(받은 파일 경로). 실패면
                 *       result.error 의 코드로 사유를 가른다 —
                 *       "measuring" · "busy" · "badArgs" · "network" ·
                 *       "sha256Mismatch" · "cancelled"
                 */
                "download" -> {
                    val url = call.argument<String>("url") // APK 주소
                    val sha256 = call.argument<String>("sha256") // 기대 지문
                    when {
                        isMeasuring() ->
                            result.error("measuring", "측정 중에는 받지 않는다", null)
                        downloadThread != null ->
                            result.error("busy", "이미 받는 중이다", null)
                        url == null || sha256 == null || !url.startsWith("https://") ->
                            result.error("badArgs", "url · sha256 확인 필요", null)
                        // → 로직 이동: startDownload()
                        else -> startDownload(url, sha256, result)
                    }
                }
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: cancelDownload
                 * 목적: 받는 중인 APK 내려받기를 멈춘다. 멈춘 내려받기는
                 *       "cancelled" 로 끝나고 받던 파일은 지워진다.
                 */
                "cancelDownload" -> {
                    cancelRequested = true
                    result.success(null)
                }
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: install
                 * 목적: 받은 APK 를 `PackageInstaller` 세션으로 설치한다.
                 *       안드로이드가 확인 화면을 요구하면 그 화면을 띄우고
                 *       최종 결과를 기다린다.
                 * 인자: path — `download` 가 돌려준 파일 경로
                 * 반환: result.success(String) — "success" · "aborted"(사용자
                 *       취소) · "conflict"(서명 불일치 등 기존 앱과 충돌) ·
                 *       "failed:<사유>". 요청 자체가 틀리면 result.error
                 *       ("measuring" · "busy" · "badArgs")
                 */
                "install" -> {
                    val path = call.argument<String>("path") // 받은 APK 경로
                    when {
                        isMeasuring() ->
                            result.error("measuring", "측정 중에는 설치하지 않는다", null)
                        pendingInstallResult != null ->
                            result.error("busy", "이미 설치 중이다", null)
                        path == null || !File(path).isFile ->
                            result.error("badArgs", "APK 파일이 없다", null)
                        // → 로직 이동: startInstall()
                        else -> startInstall(File(path), result)
                    }
                }
                /**
                 * 작성: 2026-10-13 14:18:51 · nada
                 * 함수: else
                 * 목적: 정의되지 않은 요청에 미구현으로 응답한다.
                 */
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: canInstall
     * 목적: 이 앱에 다른 APK 설치가 허용됐는지 본다.
     * 반환: 허용됐으면 true. 안드로이드 8 미만은 앱별 허용이 없어 true
     */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: onActivityResult
     * 목적: 설치 허용 설정 화면에서 돌아오면 다시 확인해, 기다리던 쪽에
     *       허용 여부를 알려 준다. 설정 화면은 결과 코드를 주지 않으므로
     *       코드는 보지 않는다. `MainActivity.onActivityResult()` 가
     *       넘겨준다.
     * 인자: requestCode — 어느 화면의 결과인지 가르는 값
     * 반환: 이 클래스가 처리했으면 true
     */
    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQ_INSTALL_PERMISSION) return false
        pendingPermissionResult?.success(canInstall())
        pendingPermissionResult = null
        return true
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: startDownload
     * 목적: 별도 스레드에서 APK 를 받는다. 순서대로 진행한다.
     *       1. 예전에 받은 파일을 지우고 `cacheDir/update/` 를 만든다
     *       2. 받으면서 SHA-256 을 함께 계산하고, 진행률(받은 바이트 ·
     *          전체 바이트)을 보낸다. 전체 크기를 모르면 전체는 -1
     *       3. 취소되면 파일을 지우고 "cancelled"
     *       4. 지문이 다르면 파일을 지우고 "sha256Mismatch" — 받은 파일이
     *          깨졌거나 바뀐 것이라 설치하지 않는다
     *       5. 맞으면 파일 경로로 응답한다
     * 인자: url — APK https 주소
     *       expectedSha256 — 기대하는 SHA-256
     *       result — 끝나면 응답할 자리
     */
    private fun startDownload(
        url: String,
        expectedSha256: String,
        result: MethodChannel.Result,
    ) {
        cancelRequested = false
        val dir = File(activity.cacheDir, UPDATE_DIR) // 받은 APK 폴더
        val target = File(dir, APK_NAME) // 받을 파일
        val thread = Thread { // 내려받기 스레드
            var connection: HttpURLConnection? = null // 서버 연결, 열기 전 null
            try {
                dir.mkdirs()
                target.delete()
                connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = CONNECT_TIMEOUT_MS
                connection.readTimeout = READ_TIMEOUT_MS
                connection.instanceFollowRedirects = true
                val code = connection.responseCode // 서버 응답 코드
                if (code != HttpURLConnection.HTTP_OK) {
                    throw java.io.IOException("응답 $code")
                }
                val total = connection.contentLengthLong // 전체 바이트, 모르면 -1
                val digest = MessageDigest.getInstance("SHA-256") // 지문 계산기
                var received = 0L // 지금까지 받은 바이트
                var lastPercent = -1 // 마지막으로 보낸 백분율, 보내기 전 -1
                connection.inputStream.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(BUFFER_BYTES) // 읽기 버퍼
                        while (true) {
                            if (cancelRequested) break
                            val n = input.read(buffer) // 이번에 읽은 바이트 수
                            if (n < 0) break
                            output.write(buffer, 0, n)
                            digest.update(buffer, 0, n)
                            received += n
                            val percent = // 백분율, 전체를 모르면 -1
                                if (total > 0) (received * 100 / total).toInt() else -1
                            if (percent != lastPercent || total <= 0) {
                                lastPercent = percent
                                sendProgress(received, total)
                            }
                        }
                    }
                }
                if (cancelRequested) {
                    target.delete()
                    finishDownload { result.error("cancelled", "사용자가 취소했다", null) }
                    return@Thread
                }
                val actual = // 받은 파일의 지문 (16진수 소문자)
                    digest.digest().joinToString("") { "%02x".format(it) }
                if (actual != expectedSha256) {
                    target.delete()
                    finishDownload {
                        result.error("sha256Mismatch", "기대 $expectedSha256, 받음 $actual", null)
                    }
                    return@Thread
                }
                finishDownload { result.success(target.absolutePath) }
            } catch (e: Exception) {
                target.delete()
                finishDownload { result.error("network", e.toString(), null) }
            } finally {
                connection?.disconnect()
            }
        }
        downloadThread = thread
        thread.start()
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: finishDownload
     * 목적: 내려받기 상태를 비우고, 메인 스레드에서 응답한다. Flutter
     *       통로는 메인 스레드에서만 써야 한다.
     * 인자: respond — 응답 동작
     */
    private fun finishDownload(respond: () -> Unit) {
        mainHandler.post {
            downloadThread = null
            respond()
        }
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: sendProgress
     * 목적: 진행률 한 건을 메인 스레드에서 Flutter 로 보낸다.
     * 인자: received — 받은 바이트
     *       total — 전체 바이트. 모르면 -1
     */
    private fun sendProgress(received: Long, total: Long) {
        mainHandler.post {
            progressSink?.success(mapOf("received" to received, "total" to total))
        }
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: startInstall
     * 목적: `PackageInstaller` 세션에 APK 를 쓰고 넘긴다. 결과는 방송으로
     *       돌아오므로 수신기를 먼저 등록한다.
     * 인자: apk — 받은 APK 파일
     *       result — 설치가 끝나면 응답할 자리
     */
    private fun startInstall(apk: File, result: MethodChannel.Result) {
        val installer = activity.packageManager.packageInstaller // 설치 서비스
        val params = PackageInstaller.SessionParams( // 기존 앱을 바꾸는 설치
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        pendingInstallResult = result
        // → 로직 이동: registerInstallReceiver()
        registerInstallReceiver()
        var sessionId = -1 // 세션 번호, 만들기 전 -1
        try {
            sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                session.openWrite(APK_NAME, 0, apk.length()).use { out ->
                    apk.inputStream().use { input -> input.copyTo(out, BUFFER_BYTES) }
                    session.fsync(out)
                }
                val intent = Intent(ACTION_INSTALL_STATUS) // 결과를 받을 방송
                    .setPackage(activity.packageName)
                val flags = // 안드로이드 12 부터 PendingIntent 에 가변 여부가 필수다
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                val pending = // 설치 서비스가 결과를 채워 보낼 방송 예약
                    PendingIntent.getBroadcast(activity, sessionId, intent, flags)
                session.commit(pending.intentSender)
            }
        } catch (e: Exception) {
            // 넘기지 못한 세션은 기기에 남지 않게 버린다
            if (sessionId >= 0) installer.abandonSession(sessionId)
            finishInstall("failed:$e")
        }
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: registerInstallReceiver
     * 목적: 설치 결과 방송을 받는 수신기를 등록한다. 결과마다 이렇게
     *       처리한다.
     *       - 사용자 확인이 필요하면(STATUS_PENDING_USER_ACTION) 안드로이드가
     *         준 확인 화면을 띄우고 다음 방송을 기다린다
     *       - 성공 → "success". 자기 자신을 바꾸는 설치라 이 응답이 닿기
     *         전에 앱이 끝날 수 있다
     *       - 사용자 취소(STATUS_FAILURE_ABORTED) → "aborted"
     *       - 기존 앱과 충돌(STATUS_FAILURE_CONFLICT) → "conflict"
     *       - 그 밖 → "failed:<안드로이드 문구>"
     * 근거: 표준 — `PackageInstaller.STATUS_*` 계약
     *       미확인: 서명이 다른 APK 의 거절이 CONFLICT 로 오는지 실기기에서
     *       확인하지 않았다(docs/pending_checks.md)
     */
    private fun registerInstallReceiver() {
        unregisterInstallReceiver()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val status = intent.getIntExtra( // 설치 상태 코드
                    PackageInstaller.EXTRA_STATUS,
                    PackageInstaller.STATUS_FAILURE,
                )
                when (status) {
                    PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                        val confirm = // 안드로이드가 준 설치 확인 화면
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(Intent.EXTRA_INTENT)
                            }
                        if (confirm == null) {
                            finishInstall("failed:확인 화면 없음")
                        } else {
                            confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            activity.startActivity(confirm)
                        }
                    }
                    PackageInstaller.STATUS_SUCCESS -> finishInstall("success")
                    PackageInstaller.STATUS_FAILURE_ABORTED -> finishInstall("aborted")
                    PackageInstaller.STATUS_FAILURE_CONFLICT -> finishInstall("conflict")
                    else -> {
                        val message = // 안드로이드가 준 실패 문구
                            intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                        finishInstall("failed:$status $message")
                    }
                }
            }
        }
        ContextCompat.registerReceiver(
            activity,
            receiver,
            IntentFilter(ACTION_INSTALL_STATUS),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        installReceiver = receiver
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: finishInstall
     * 목적: 설치 결과를 기다리던 쪽에 한 번만 알려 주고 수신기를 푼다.
     * 인자: outcome — "success" · "aborted" · "conflict" · "failed:<사유>"
     */
    private fun finishInstall(outcome: String) {
        pendingInstallResult?.success(outcome)
        pendingInstallResult = null
        unregisterInstallReceiver()
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: unregisterInstallReceiver
     * 목적: 등록한 설치 결과 수신기를 푼다. 없으면 아무것도 안 한다.
     */
    private fun unregisterInstallReceiver() {
        installReceiver?.let { activity.unregisterReceiver(it) }
        installReceiver = null
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: dispose
     * 목적: 화면이 끝날 때 받는 중인 내려받기를 멈추고 수신기를 푼다.
     *       `MainActivity.onDestroy()` 가 부른다.
     */
    fun dispose() {
        cancelRequested = true
        unregisterInstallReceiver()
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: onListen
     * 목적: Flutter 가 진행률을 듣기 시작하면 보낼 통로를 잡아 둔다.
     * 인자: arguments — 쓰지 않는다
     *       events — 진행률을 보낼 통로
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        progressSink = events
    }

    /**
     * 작성: 2026-10-13 14:18:51 · nada
     * 함수: onCancel
     * 목적: Flutter 가 그만 들으면 통로를 비운다.
     * 인자: arguments — 쓰지 않는다
     */
    override fun onCancel(arguments: Any?) {
        progressSink = null
    }
}
