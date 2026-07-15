# Google ML Kit Text Recognition ProGuard Rules
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Specific rules from missing_rules.txt
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# General ML Kit rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Flutter plugins & platform channel keep rules
-keep class io.flutter.plugins.localauth.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Google Play Core / Deferred components dontwarn rules to allow R8/minify compilation
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**
