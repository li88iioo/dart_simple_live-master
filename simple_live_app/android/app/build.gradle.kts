import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val requiredReleaseSigningProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningProperties =
    requiredReleaseSigningProperties.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFile =
    keystoreProperties
        .getProperty("storeFile")
        ?.takeIf { it.isNotBlank() }
        ?.let { file(it) }
val hasReleaseSigningConfig =
    keystorePropertiesFile.isFile &&
        missingReleaseSigningProperties.isEmpty() &&
        releaseStoreFile?.isFile == true

android {
    namespace = "com.slotsun.slive"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.slotsun.slive"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

val validateReleaseSigning by tasks.registering {
    group = "verification"
    description = "Fails release packaging when a complete release signing configuration is unavailable."

    doLast {
        if (hasReleaseSigningConfig) return@doLast

        val reasons = buildList {
            if (!keystorePropertiesFile.isFile) {
                add("missing ${keystorePropertiesFile.path}")
            }
            if (missingReleaseSigningProperties.isNotEmpty()) {
                add("missing properties: ${missingReleaseSigningProperties.joinToString()}")
            }
            if (releaseStoreFile != null && !releaseStoreFile.isFile) {
                add("keystore file does not exist: ${releaseStoreFile.path}")
            }
        }
        throw GradleException(
            "Release signing is required; refusing to build a release artifact with a debug or unsigned key " +
                "(${reasons.joinToString("; ")})."
        )
    }
}

val releasePackagingTaskPattern =
    Regex("^(assemble|bundle|package|install).*Release.*$", RegexOption.IGNORE_CASE)

tasks.configureEach {
    if (releasePackagingTaskPattern.matches(name)) {
        dependsOn(validateReleaseSigning)
    }
}
