allprojects {
    repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://storage.flutter-io.cn/download.flutter.io") {
            content {
                includeGroup("io.flutter")
            }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// onnxruntime 插件模板仍以 android-33 声明 AAR 元数据，但其 androidx 传递依赖
// （androidx.core 1.16.0——Flutter 输入法栈 TextInputPlugin 必需，低于该版本
// 点击输入框会抛 NoSuchMethodError 闪退）要求 compileSdk >= 35。
// 这里对该模块显式抬升 compileSdk，避免 checkDebugAarMetadata 报错。
// 注意：afterEvaluate 必须先于 evaluationDependsOn 注册，否则报
// "Cannot run Project.afterEvaluate ... already evaluated"。
subprojects {
    afterEvaluate {
        if (name == "onnxruntime") {
            extensions.findByName("android")?.let { ext ->
                if (ext is com.android.build.gradle.LibraryExtension) {
                    ext.compileSdk = 36
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// onnxruntime 1.4.1 插件以 android-33 编译，其传递 androidx 依赖要求 34+——
// 根级统一到兼容版（App 自身 compileSdk/targetSdk=36，可承载较新的 androidx）。
//
// 注意：androidx.core 必须保持 >= 1.16.0！Flutter 引擎的
// TextInputPlugin.createInputConnection 会调用
// EditorInfoCompat.setStylusHandwritingEnabled（core 1.16 才有），
// 强制降到旧版会在「点击任意输入框唤起键盘」时抛 NoSuchMethodError 直接闪退。
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.fragment:fragment:1.6.2")
            force("androidx.window:window:1.0.0")
            force("androidx.window:window-java:1.0.0")
            force("androidx.activity:activity:1.7.2")
            force("androidx.lifecycle:lifecycle-livedata-core-ktx:2.6.2")
            force("androidx.lifecycle:lifecycle-livedata:2.6.2")
            force("androidx.lifecycle:lifecycle-viewmodel:2.6.2")
            force("androidx.lifecycle:lifecycle-livedata-core:2.6.2")
            force("androidx.lifecycle:lifecycle-viewmodel-savedstate:2.6.2")
            force("androidx.lifecycle:lifecycle-runtime:2.6.2")
            force("androidx.lifecycle:lifecycle-process:2.6.2")
            force("androidx.core:core-ktx:1.16.0")
            force("androidx.core:core:1.16.0")
            force("androidx.annotation:annotation-experimental:1.4.1")
            force("androidx.exifinterface:exifinterface:1.3.7")
        }
    }
}
