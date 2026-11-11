import com.android.build.api.variant.FilterConfiguration
import com.android.build.api.variant.impl.VariantOutputImpl
import java.io.File
import java.nio.file.Files

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ownscan.scanner_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ownscan.scanner_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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
        }
    }

    // Native libraries are normally stored uncompressed so Android can map them
    // straight out of the APK. That is faster to start, but it makes the file
    // the user downloads carry ~17 MB of raw .so bytes. Storing them deflated
    // costs one extraction pass at install time and roughly halves the
    // installer, with no change to the code that runs.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// The APKs end up named `ToraScan-<version>-<abi>.apk`, so a file shared over
// WhatsApp or Drive says what it is and which build it is without having to
// install it first. The version comes from pubspec.yaml through Flutter, the
// same string the sidebar shows.
//
// `flutter build apk` copies these outputs into build/app/outputs/flutter-apk
// under its own `app-<abi>-<mode>.apk` names, because the tool looks for
// exactly those and fails when they are missing. The named files stay in
// build/app/outputs/apk/release; a small task also links them into flutter-apk
// so the folder a release is shared from shows the real names too.
androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            val abi = output.filters
                .firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }
                ?.identifier
            val suffix = if (abi == null) "" else "-$abi"
            (output as VariantOutputImpl).outputFileName.set(
                output.versionName.map { version -> "ToraScan-$version$suffix.apk" },
            )
        }
    }
}

val versionedApks = tasks.register("versionedApks") {
    val releaseDir = layout.buildDirectory.dir("outputs/apk/release")
    val apkDir = layout.buildDirectory.dir("outputs/flutter-apk")
    outputs.upToDateWhen { false }
    doLast {
        val from = releaseDir.get().asFile
        val to = apkDir.get().asFile
        to.mkdirs()
        // Drop links from an older version so two versions never sit side by
        // side and get shared by mistake.
        to.listFiles { file ->
            file.isFile && file.name.startsWith("ToraScan-") && file.extension == "apk"
        }?.forEach { it.delete() }
        from.listFiles { file ->
            file.isFile && file.name.startsWith("ToraScan-") && file.extension == "apk"
        }?.forEach { apk ->
            val target = File(to, apk.name)
            target.delete()
            try {
                // Same bytes, two names: a hard link keeps the build directory
                // from carrying every APK twice.
                Files.createLink(target.toPath(), apk.toPath())
            } catch (linkFailed: Exception) {
                apk.copyTo(target, overwrite = true)
            }
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(versionedApks)
}

flutter {
    source = "../.."
}
