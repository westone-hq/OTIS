import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 키 설정. 키 파일과 비밀번호는 저장소 밖에 두고, 이 파일은
// 그 자리와 비밀번호만 적는다(.gitignore). 만드는 법은 docs/release.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties() // key.properties 내용, 없으면 빈 표
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

/** key.properties 의 항목 하나. 빠졌으면 어느 항목인지 밝히고 멈춘다 */
fun keystoreValue(key: String): String =
    keystoreProperties.getProperty(key)
        ?: throw GradleException("android/key.properties 에 $key 가 없다")

android {
    namespace = "com.otis.vibration_checker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.otis.vibration_checker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreValue("storeFile"))
                storePassword = keystoreValue("storePassword")
                keyAlias = keystoreValue("keyAlias")
                keyPassword = keystoreValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 디버그 키는 컴퓨터마다 달라 덮어쓰기 업데이트가 끊긴다. 고정
            // 릴리스 키로만 서명하고, 키 설정이 없으면 아래에서 빌드를 멈춘다
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// 릴리스 빌드인데 키 설정이 없으면 디버그 키나 서명 없는 APK 로 조용히
// 넘어가지 않고 멈춘다. 디버그 빌드는 키 설정 없이 그대로 된다
gradle.taskGraph.whenReady {
    val buildsRelease = // 이번 빌드에 이 앱의 릴리스 작업이 들어 있는가
        allTasks.any { it.project == project && it.name.contains("Release") }
    if (buildsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties 가 없다 — 릴리스 서명 키를 설정한 뒤 " +
                "빌드한다 (docs/release.md)",
        )
    }
}
