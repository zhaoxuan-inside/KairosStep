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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// onnxruntime 1.4.1 插件以 android-33 编译，其传递 androidx 依赖要求 34+——
// 根级统一降级到 33 兼容版（App 自身 compileSdk/targetSdk=36）。
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
            force("androidx.core:core-ktx:1.10.1")
            force("androidx.core:core:1.10.1")
            force("androidx.annotation:annotation-experimental:1.3.0")
            force("androidx.exifinterface:exifinterface:1.3.7")
        }
    }
}
