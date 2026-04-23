import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.Project

group = "io.flutter.plugins.sharedpreferences"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// TODO(stuartmorgan): See if this can be removed.
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:deprecation")
    options.compilerArgs.add("-Xlint:unchecked")
}

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

fun resolveFlutterCompileSdkVersion(project: Project): Int {
    val standaloneFallback = 35
    val flutterExtension = project.extensions.findByName("flutter") ?: return standaloneFallback
    val rawValue =
        runCatching {
            flutterExtension.javaClass.methods
                .firstOrNull { it.name == "getCompileSdkVersion" }
                ?.invoke(flutterExtension)
        }.getOrNull() ?: return standaloneFallback

    return when (rawValue) {
        is Int -> rawValue
        is Number -> rawValue.toInt()
        is String -> rawValue.toIntOrNull() ?: standaloneFallback
        else -> standaloneFallback
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget(JavaVersion.VERSION_17.toString())
    }
}

android {
    namespace = "io.flutter.plugins.sharedpreferences"
    // When this plugin is loaded by the Flutter app, the Flutter Gradle plugin
    // injects the "flutter" extension. When IDE tooling opens the plugin as an
    // isolated Gradle project, that extension does not exist, so we fall back
    // to a standalone compileSdk to keep sync/import stable.
    compileSdk = resolveFlutterCompileSdkVersion(project)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    lint {
        checkAllWarnings = true
        warningsAsErrors = true
        disable.addAll(setOf("AndroidGradlePluginVersion", "InvalidPackage", "GradleDependency", "NewerVersionAvailable"))
        baseline = file("lint-baseline.xml")
    }

    dependencies {
        implementation("androidx.datastore:datastore:1.1.7")
        implementation("androidx.datastore:datastore-preferences:1.1.7")
        implementation("androidx.preference:preference:1.2.1")
        testImplementation("junit:junit:4.13.2")
        testImplementation("androidx.test:core-ktx:1.7.0")
        testImplementation("androidx.test.ext:junit-ktx:1.3.0")
        testImplementation("org.robolectric:robolectric:4.16")
        testImplementation("org.mockito:mockito-inline:5.2.0")
        testImplementation("io.mockk:mockk:1.14.9")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            isReturnDefaultValues = true
            all {
                it.outputs.upToDateWhen { false }
                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}
