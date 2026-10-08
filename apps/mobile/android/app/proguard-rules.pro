# google_mlkit_text_recognition mentions the Chinese, Devanagari, Japanese and Korean recognizers.
# SplitUp bundles only the Latin one, so those classes are not in the app. They are never used,
# so the release shrinker (R8) is told to ignore the missing ones instead of failing the build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
