# Keep smbj and its dependencies intact — R8 minification breaks SMB auth/connection.
-keep class com.hierynomus.** { *; }
-keep class net.engio.** { *; }
-keep class com.hierynomus.smbj.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class org.asn1s.** { *; }

# smbj references javax.el and org.ietf.jgss classes that are not available on Android.
# These are optional features (EL expression filtering, Kerberos/SPNEGO auth) not used by R-Shop.
-dontwarn javax.el.**
-dontwarn org.ietf.jgss.**
-dontwarn org.bouncycastle.**
