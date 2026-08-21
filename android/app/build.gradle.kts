import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties. That file is git-ignored and a
// fresh clone will not have it, so a missing file is a normal state and must not
// break the build. When it is absent the release build signs with debug keys and
// prints a line saying so, because an APK signed with a throwaway key that looks
// like a real release is the failure worth being loud about.
//
// A file that is present but incomplete is a different case and fails the build.
// Someone who wrote a key.properties meant to sign for real, so quietly handing
// them debug keys would waste the release.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// Paths in key.properties resolve against the folder that declares them, meaning
// android/, so a keystore kept outside the repository can be reached with `../`.
// An absolute path is used as written.
val releaseStoreFile = if (hasReleaseKeystore) {
    val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missing = required.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing ${missing.joinToString(", ")}. " +
                "Add the missing values, or delete the file to sign with debug keys."
        )
    }
    val declared = keystoreProperties.getProperty("storeFile")
    val resolved = rootProject.file(declared)
    if (!resolved.exists()) {
        throw GradleException(
            "The keystore android/key.properties points at does not exist: ${resolved.absolutePath}"
        )
    }
    resolved
} else {
    null
}

// `flutter build` runs Gradle with -q, which drops everything below the QUIET log
// level, so lifecycle and warn messages never reach the terminal. quiet() does.
if (!hasReleaseKeystore) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") }) {
            logger.quiet(
                "Cairn: no android/key.properties, so this release build is signing with " +
                    "debug keys. The APK will install and run, and it is not fit to hand to " +
                    "anybody. See the signing section of the README."
            )
        }
    }
}

android {
    namespace = "com.cynnlabs.cairn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cynnlabs.cairn"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
