# Manter classes do Google Play Services Nearby Connections
-keep class com.google.android.gms.nearby.** { *; }
-dontwarn com.google.android.gms.nearby.**

# Manter classes do Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Manter classes de reflexão
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
