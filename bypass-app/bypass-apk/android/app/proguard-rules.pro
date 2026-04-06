# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep audio player classes
-keep class com.ryanheise.just_audio.** { *; }

# Keep notification classes
-keep class com.dexterous.** { *; }

# Ignore missing Play Core classes (not using dynamic feature modules)
-dontwarn com.google.android.play.core.**
-ignorewarnings
