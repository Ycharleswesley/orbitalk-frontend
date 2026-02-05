# Zego SDK rules
-keep class im.zego.** { *; }
-keep class com.zegocloud.** { *; }

# Jackson databinding - required for JSON serialization
-keep class com.fasterxml.jackson.databind.ext.Java7SupportImpl { *; }
-keep class com.fasterxml.jackson.databind.ext.DOMSerializer { *; }
-keep class java.beans.** { *; }
-keep class org.w3c.dom.bootstrap.** { *; }
-keep class com.fasterxml.jackson.databind.** { *; }
-keep class com.fasterxml.jackson.annotation.** { *; }

# Don't warn about optional dependencies
-dontwarn java.beans.**
-dontwarn org.w3c.dom.bootstrap.**
-dontwarn com.fasterxml.jackson.databind.ext.Java7SupportImpl
-dontwarn com.fasterxml.jackson.databind.ext.DOMSerializer

# Google Play Core library - required for deferred components
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter/Dart rules
-keep class io.flutter.** { *; }

# Kotlin rules
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Generic rules
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile
-keepattributes LineNumberTable
-keepattributes LocalVariableTable
-keepattributes LocalVariableTypeTable
-keepattributes Signature
-keepattributes Exceptions
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations

# Additional rules for reflection and serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Don't obfuscate classes with native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep View constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Preserve the line number information for debugging stack traces
-renamesourcefileattribute SourceFile

# Remove logging (optional - comment out if you need logs)
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
# }