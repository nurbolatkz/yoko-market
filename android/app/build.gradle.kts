import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")

android {
    namespace = "kz.yokosun.yokomarket"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "kz.yokosun.yokomarket"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            check(keystorePropertiesFile.exists()) {
                "Release signing requires android/key.properties. " +
                "Copy the file (and android/app/release.keystore) from the secure backup " +
                "before building a release APK."
            }
            val props = Properties().apply { load(FileInputStream(keystorePropertiesFile)) }
            keyAlias     = props["keyAlias"]     as String
            keyPassword  = props["keyPassword"]  as String
            storeFile    = file(props["storeFile"] as String)
            storePassword = props["storePassword"] as String
        }
    }

    buildTypes {
        debug {
            // Debug builds use the default debug keystore — no key.properties needed.
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
}

flutter {
    source = "../.."
}
