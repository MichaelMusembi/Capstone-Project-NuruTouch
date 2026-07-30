# Flutter ONNX Runtime Proguard Rules
-keep class ai.onnxruntime.** { *; }
-keep class com.example.nurutouch.** { *; }

# Protect Google ML Kit and Vision dependencies from R8 corruption
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.common.** { *; }
