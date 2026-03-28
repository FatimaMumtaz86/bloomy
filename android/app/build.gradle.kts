import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(key: String, envKey: String): String {
    val fromProperties = keystoreProperties.getProperty(key)
    if (!fromProperties.isNullOrBlank()) {
        return fromProperties
    }

    val fromEnv = System.getenv(envKey)
    if (!fromEnv.isNullOrBlank()) {
        return fromEnv
    }

    return ""
}

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")

val isReleaseTask = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true) ||
        taskName.contains("bundle", ignoreCase = true)
}

android {
    namespace = "com.bloomy.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bloomy.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (
                releaseStoreFile.isNotEmpty() &&
                    releaseStorePassword.isNotEmpty() &&
                    releaseKeyAlias.isNotEmpty() &&
                    releaseKeyPassword.isNotEmpty()
            ) {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (
                releaseStoreFile.isEmpty() ||
                    releaseStorePassword.isEmpty() ||
                    releaseKeyAlias.isEmpty() ||
                    releaseKeyPassword.isEmpty()
            ) {
                if (isReleaseTask) {
                    throw GradleException(
                        "Missing Android release signing config. Provide android/keystore.properties or env vars: ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD."
                    )
                }
                signingConfig = signingConfigs.getByName("debug")
            } else {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
