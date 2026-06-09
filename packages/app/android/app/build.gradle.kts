import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")

    // Google Services
    id("com.google.gms.google-services")

    // Flutter plugin
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {

    namespace = "com.notesnet.app"

    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {

        applicationId = "com.notesnet.app"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    signingConfigs {

        create("release") {

            keyAlias = keystoreProperties["keyAlias"] as String

            keyPassword = keystoreProperties["keyPassword"] as String

            storeFile = file(
                keystoreProperties["storeFile"] as String
            )

            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {

        release {

            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile(
                    "proguard-android-optimize.txt"
                ),
                "proguard-rules.pro"
            )
        }

        debug {

            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {

    // Java 17 desugaring
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    // Firebase BOM
    implementation(
        platform(
            "com.google.firebase:firebase-bom:34.12.0"
        )
    )

    // Firebase Analytics
    implementation(
        "com.google.firebase:firebase-analytics"
    )
}

flutter {
    source = "../.."
}