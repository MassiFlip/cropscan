import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(",")
    ?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    .orEmpty()
val prototype = "CROPSCAN_PROTOTYPE=true" in dartDefines
val experimental = "CROPSCAN_EXPERIMENTAL=true" in dartDefines
require(!experimental || (!prototype && "CROPSCAN_DEMO=true" !in dartDefines)) {
    "Build CropScan Experimental separately from the prototype and demo."
}
if (experimental) {
    val target = providers.gradleProperty("target").orNull.orEmpty().replace('\\', '/')
    require(target == "lib/main_experimental.dart" || target.endsWith("/lib/main_experimental.dart")) {
        "CROPSCAN_EXPERIMENTAL requires --target lib/main_experimental.dart"
    }
}

abstract class PreparePrototypeAssets : DefaultTask() {
    @get:InputFile abstract val modelFile: RegularFileProperty
    @get:OutputDirectory abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun prepare() {
        val model = modelFile.get().asFile
        model.copyTo(outputDirectory.get().asFile.resolve(model.name), overwrite = true)
    }
}

android {
    namespace = "pe.edu.cropscan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = when {
            experimental -> "pe.edu.cropscan.experimental"
            prototype -> "pe.edu.cropscan.prototype"
            else -> "pe.edu.cropscan"
        }
        manifestPlaceholders["appLabel"] = when {
            experimental -> "CropScan Experimental"
            prototype -> "CropScan Prototipo"
            else -> "CropScan"
        }
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Local demo artifact. Configure a private signing key for publication.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

if (prototype) {
    androidComponents.onVariants { variant ->
        val suffix = variant.name.replaceFirstChar { it.uppercaseChar() }
        val prepareAssets = tasks.register<PreparePrototypeAssets>("prepare${suffix}PrototypeAssets") {
            modelFile.set(rootProject.layout.projectDirectory.file("../model/prototype/crop-visual-prototype.tflite"))
            outputDirectory.set(layout.buildDirectory.dir("generated/prototypeAssets/${variant.name}"))
        }
        variant.sources.assets?.addGeneratedSourceDirectory(prepareAssets, PreparePrototypeAssets::outputDirectory)
    }
}

if (experimental) {
    androidComponents.onVariants { variant ->
        val suffix = variant.name.replaceFirstChar { it.uppercaseChar() }
        val prepareAssets = tasks.register<PreparePrototypeAssets>("prepare${suffix}ExperimentalAssets") {
            modelFile.set(rootProject.layout.projectDirectory.file(
                "../model/experiments/cnn_900_run_01/cropscan_experimental.tflite"
            ))
            outputDirectory.set(layout.buildDirectory.dir("generated/experimentalAssets/${variant.name}"))
        }
        variant.sources.assets?.addGeneratedSourceDirectory(prepareAssets, PreparePrototypeAssets::outputDirectory)
    }
}

dependencies {
    implementation("com.google.ai.edge.litert:litert:1.4.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
