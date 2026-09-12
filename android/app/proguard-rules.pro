# Keep Razorpay classes
-keep class com.razorpay.** {*;}
-keepclassmembers class com.razorpay.** {*;}

# Add ProGuard for Razorpay dependencies
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-dontwarn com.google.android.material.**
-keep class com.google.android.material.** { *; }

# --- Added when isMinifyEnabled/isShrinkResources were switched on for the
# release build type (was off for every flavor, which is why Play Console
# had no mapping.txt to accept crash reports against). Flutter plugin AARs
# ship their own consumer-rules.pro that R8 merges automatically, so most
# plugins need nothing extra here — these cover the parts that don't:
# Google Play Core's deferred-component classes (referenced by the Flutter
# engine even when splits aren't used, a common source of R8 "missing
# class" build failures), and Gson's reflection-based (de)serialization,
# which several Play Services/Firebase libraries depend on transitively.

-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

-keepattributes Signature
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer