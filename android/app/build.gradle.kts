import java.util.Properties
import java.io.FileInputStream
import java.net.URLDecoder

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.ginies.secure_mark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Extract TARGET_PACKAGE from dart-defines if present
        var targetPackage: String? = null
        if (project.extra.has("DART_DEFINES")) {
            val dartDefinesString = project.extra.get("DART_DEFINES") as String
            val dartDefines = dartDefinesString.split(",")
            for (define in dartDefines) {
                val pair = URLDecoder.decode(define, "UTF-8").split("=")
                if (pair.size == 2 && pair[0] == "TARGET_PACKAGE") {
                    targetPackage = pair[1]
                }
            }
        }

        if (targetPackage != null) {
            applicationId = targetPackage
        } else {
            applicationId = "org.ginies.secure_mark"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            val isSigningConfigured = keystoreProperties.getProperty("storeFile") != null
            signingConfig = if (isSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
