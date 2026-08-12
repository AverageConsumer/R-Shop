import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing properties if available
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.retro.rshop.tw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        // MainActivity derives the platform-channel prefix from
        // BuildConfig.APPLICATION_ID; AGP 8 disables BuildConfig by default.
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.retro.rshop.tw"

        // Version values are pulled from pubspec.yaml automatically
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing for development builds
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val fileName = "R-Shop-v${defaultConfig.versionName}.apk"
            output.outputFileName = fileName
        }
    }
}

// 引入本地私有任務（若存在），此部分不進入 Git
val localTasksFile = file("local-tasks.gradle.kts")
if (localTasksFile.exists()) {
    apply(from = localTasksFile)
}

dependencies {
    implementation("com.hierynomus:smbj:0.13.0")
}

flutter {
    source = "../.."
}
