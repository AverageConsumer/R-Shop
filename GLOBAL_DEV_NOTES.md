# R-Shop Project Rules & Memory (GLOBAL_DEV_NOTES)

This file is the official persistent memory for all AI assistants working on the R-Shop project.

## 📦 APK Output Rules
- **Mandatory Path Reporting**: After every successful build or APK generation, you MUST provide the full absolute paths for both the directory and the specific file.
- **Verification First**: BEFORE reporting paths or building, ALWAYS check `android/app/build.gradle.kts` and `pubspec.yaml` to confirm the current output destination and version number. DO NOT rely on memory.
- **Primary Delivery Path**: `D:\test-apk\` (Automatically copied here by Gradle).
- **Gradle Output Path**: `C:\Users\Mini-PC\StudioProjects\R-Shop\build\app\outputs\flutter-apk\`
- **Naming Convention**: `R-Shop-v{version}.apk` (The script uses `R-Shop-v${defaultConfig.versionName}.apk`).

## 🛠️ Build Environment
- **JAVA_HOME**: `C:\Program Files\Android\Android Studio\jbr`
- **Flutter SDK**: `D:\flutter\bin\flutter.bat`
- **Pre-build Cleanup**: Always run `Remove-Item Env:ANDROID_PREFS_ROOT` before any `flutter build` command to prevent Gradle service instantiation conflicts.
- **Full Build Command**: 
  `Remove-Item Env:ANDROID_PREFS_ROOT; $env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; D:\flutter\bin\flutter.bat build apk --release`

## 🌐 Localization & Customization
- **Locale Strategy**: Consistently use the `zh` locale code (without region) for Traditional Chinese to avoid menu duplicates and switching bugs.
- **Application ID**: `com.retro.rshop.tw` (for the customized version, to allow co-existence with the original app).
- **Desktop Label**: `R-Shop-zh`

## 🌿 Git Branching
- **`main`**: Upstream-ready branch. Contains only clean localization and theme fixes. Suitable for PRs to the original repository.
- **`main-zh`**: Personalized branch. Contains custom App ID, version bumps, APK naming logic, and specific UI labels.

## ⌨️ Gamepad UI Rules
- **Back Button**: Must be unified at the top-left corner across all setup/settings screens (Icon size 26, 8px padding).
- **Dialogs**: Use the custom `ConsoleDialog` component for consistent gamepad support (B to cancel, white focus borders).
