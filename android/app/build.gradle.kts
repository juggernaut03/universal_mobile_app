import java.util.Properties
import java.io.FileInputStream

// Per-tenant signing. Each flavor may have its own key.<flavor>.properties in
// android/ (pagariya keeps the legacy unsuffixed key.properties) pointing at
// its own keystore. Missing file/blank storeFile = that flavor isn't signed
// yet and release builds fall back to the debug key (see productFlavors).
fun loadKeystoreProperties(fileName: String): Properties? {
    val file = rootProject.file(fileName)
    if (!file.exists()) return null
    val props = Properties()
    props.load(FileInputStream(file))
    if (props.getProperty("storeFile").isNullOrEmpty()) return null
    return props
}

val flavorKeystoreFiles = mapOf(
    "pagariya" to "key.properties",
    "myneedmart" to "key.myneedmart.properties",
    "grahakpeth" to "key.grahakpeth.properties",
    "sansarpariwar" to "key.sansarpariwar.properties",
)

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.patelrmart.app"
    compileSdk = 36
    ndkVersion = "28.0.13004108"
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.patelrmart.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Per-flavor signing configs — only created when that tenant's keystore
    // properties file exists (see flavorKeystoreFiles above).
    signingConfigs {
        flavorKeystoreFiles.forEach { (flavorName, propsFileName) ->
            val props = loadKeystoreProperties(propsFileName)
            if (props != null) {
                create(flavorName) {
                    storeFile = file(props.getProperty("storeFile"))
                    storePassword = props.getProperty("storePassword")
                    keyAlias = props.getProperty("keyAlias")
                    keyPassword = props.getProperty("keyPassword")
                }
            }
        }
    }

    // One flavor per white-label tenant. applicationId is each tenant's
    // unique install/store identity; resValue("app_name") drives the
    // launcher label via AndroidManifest's android:label="@string/app_name".
    // signingConfig here is what release builds use (buildTypes.release
    // below deliberately leaves signingConfig unset so this isn't
    // overridden) — falls back to the debug key when the tenant has no
    // keystore yet, same as the previous single-tenant behaviour.
    // `pagariya` keeps the original applicationId so the existing Play
    // Store listing/installs keep updating in place.
    flavorDimensions += "tenant"
    productFlavors {
        create("pagariya") {
            dimension = "tenant"
            applicationId = "com.patelrmart.app"
            resValue("string", "app_name", "Pagariya Mart")
            signingConfig = signingConfigs.findByName("pagariya") ?: signingConfigs.getByName("debug")
        }
        create("myneedmart") {
            dimension = "tenant"
            applicationId = "com.myneedmart.androidapp"
            resValue("string", "app_name", "My Need Mart")
            signingConfig = signingConfigs.findByName("myneedmart") ?: signingConfigs.getByName("debug")
        }
        create("grahakpeth") {
            dimension = "tenant"
            applicationId = "com.grahakpeth.androidapp"
            resValue("string", "app_name", "Grahak Peth")
            signingConfig = signingConfigs.findByName("grahakpeth") ?: signingConfigs.getByName("debug")
        }
        create("sansarpariwar") {
            dimension = "tenant"
            applicationId = "com.sansarpariwar.androidapp"
            resValue("string", "app_name", "Sansar Pariwar")
            signingConfig = signingConfigs.findByName("sansarpariwar") ?: signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
            isMinifyEnabled = false
        }

        getByName("release") {
            // No signingConfig assignment here on purpose — each flavor
            // above sets its own, and buildType would otherwise win the
            // merge and stomp every flavor's real signing key.
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
        }
    }
}

dependencies {
    // Core library desugaring dependency - Updated to required version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Multidex support for large apps
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Facebook SDK for Android
    implementation("com.facebook.android:facebook-android-sdk:latest.release")
    implementation("com.facebook.android:facebook-marketing:latest.release")
}
   
flutter {
    source = "../.."
}