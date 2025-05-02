# Keep Razorpay classes
-keep class com.razorpay.** {*;}
-keepclassmembers class com.razorpay.** {*;}

# Add ProGuard for Razorpay dependencies
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-dontwarn com.google.android.material.**
-keep class com.google.android.material.** { *; }