pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// Evita la advertencia de KGP en plugins que aún declaran kotlin-android
// explícitamente. Flutter lo aplica automáticamente cuando no está en el build.gradle.
fun patchFlutterPluginsUsingExplicitKgp() {
    val pubCache = System.getenv("PUB_CACHE")
        ?: "${System.getenv("LOCALAPPDATA")}\\Pub\\Cache"
    val pubDevDir = java.io.File(pubCache, "hosted/pub.dev")
    if (!pubDevDir.isDirectory) return

    val kgpApplyPatterns = listOf(
        Regex("(?m)^apply plugin: 'kotlin-android'\\r?\\n"),
        Regex("(?m)^apply plugin: \"kotlin-android\"\\r?\\n"),
        Regex("(?m)^\\s*id\\(\"kotlin-android\"\\)\\r?\\n"),
        Regex("(?m)^\\s*id\\('kotlin-android'\\)\\r?\\n"),
    )

    pubDevDir.listFiles { file ->
        file.isDirectory && file.name.startsWith("share_plus-")
    }?.forEach { pluginDir ->
        val buildGradle = java.io.File(pluginDir, "android/build.gradle")
        if (!buildGradle.isFile) return@forEach
        val text = buildGradle.readText()
        if (text.contains("// patched-by-app: implicit-kgp")) return@forEach

        var patched = text
        kgpApplyPatterns.forEach { patched = patched.replace(it, "") }
        if (patched != text) {
            buildGradle.writeText("// patched-by-app: implicit-kgp\n$patched")
        }
    }
}

patchFlutterPluginsUsingExplicitKgp()

include(":app")
