plugins {
    id("com.android.application")
}

android {
    namespace = "com.nativeStream.asm"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.nativeStream.asm"
        minSdk = 24
        targetSdk = 34
        versionCode = 2
        versionName = "1.3.0-alpha1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
}
