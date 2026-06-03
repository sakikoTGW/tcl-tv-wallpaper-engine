plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.tclsystemfinder.wallpaper"
    compileSdk = 28

    defaultConfig {
        applicationId = "com.tclsystemfinder.wallpaper"
        minSdk = 28
        targetSdk = 28
        versionCode = 1
        versionName = "1.0.0-tcl"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
            ndk {
                abiFilters.clear()
                abiFilters += listOf("armeabi-v7a")
            }
        }
        debug {
            isMinifyEnabled = false
            // x86 模拟器 + 真机 v7a 共用 debug 包
            ndk {
                abiFilters.clear()
                abiFilters += listOf("x86", "armeabi-v7a")
            }
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.6.0")
    implementation("androidx.appcompat:appcompat:1.3.1")
    implementation("androidx.recyclerview:recyclerview:1.2.1")
}
