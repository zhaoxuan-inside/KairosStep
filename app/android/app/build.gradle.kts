plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.kairostep.kairo_step"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.kairostep.kairo_step"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // 只保留现代手机所需的 arm64，避免打包时合并另外两套原生库（ONNX/Flutter 引擎）。
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // 业务代码都在 libapp.so，R8 只处理少量插件代码，却要多花 ~30s。
            // 日常出包默认关闭；需要混淆/瘦身时用 `tools/build_apk_remote.sh --minify`。
            val wantMinify = (project.findProperty("kairosMinify") as String?)?.toBoolean() ?: false
            isMinifyEnabled = wantMinify
            isShrinkResources = wantMinify
            ndk {
                // 内部出包不需要提取原生调试符号，省掉符号表相关任务。
                debugSymbolLevel = "none"
            }
        }
    }

    lint {
        // 打包流程不走 lintVital（另有 flutter analyze / 测试把关），每次省 ~10s。
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

