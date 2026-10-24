plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google Services plugin so google-services.json is processed and
    // res/values/values.xml (with google_app_id) is generated for Firebase.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.delicia"
    // firebase_auth + androidx libs require compileSdk >= 34 (35+ recommended).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.delicia"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // firebase_auth requires minSdk = 21 (Android 5.0).
        minSdk = maxOf(flutter.minSdkVersion, 21)
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
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM (Bill of Materials) - quản lý version tự động
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    // Firebase products cần dùng
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-database")
    // UC-06: avatar upload (firebase_storage Dart plugin -> native SDK).
    // The Flutter plugin already pulls the BoM, but declaring it here keeps
    // the Storage SDK version aligned with the rest of the Firebase stack.
    implementation("com.google.firebase:firebase-storage")
    // firebase_messaging sẽ thêm ở UC-12 (push notifications)
}
