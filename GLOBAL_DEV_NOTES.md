# R-Shop Project Technical Memory

This file contains technical details and UI specifications specific to the R-Shop project. General development and localization rules are maintained in the global [StudioProjects/GLOBAL_DEV_NOTES.md](file:///C:/Users/Mini-PC/StudioProjects/GLOBAL_DEV_NOTES.md).

## 🛠️ Build Environment
- **JAVA_HOME**: `C:\Program Files\Android\Android Studio\jbr`
- **Flutter SDK**: `D:\flutter\bin\flutter.bat`
- **Pre-build Cleanup**: Always run `Remove-Item Env:ANDROID_PREFS_ROOT` before any `flutter build` command to prevent Gradle service instantiation conflicts.
- **Full Build Command**: 
  `Remove-Item Env:ANDROID_PREFS_ROOT; $env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"; D:\flutter\bin\flutter.bat build apk --release`

## 📦 Project Output
- **Gradle Config**: The project is configured to automatically copy renamed APKs to `D:\test-apk\` upon a successful release build.
- **Gradle Output Path**: `C:\Users\Mini-PC\StudioProjects\R-Shop\build\app\outputs\flutter-apk\`

## ⌨️ Gamepad UI Specifications (Project Specific)
- **Focus Border**: Use **pure white** (`Colors.white`) for the focus border of all focusable components (`ConsoleFocusable`) to ensure high visibility against the dark theme.
- **Selection Style**: Active buttons must show a white border, deep red background (`alpha: 0.35`), and pure white text.
- **Dialogs**: All modal confirmations must use the custom `ConsoleDialog` component (defined in `lib/widgets/console_dialog.dart`) for consistent gamepad support.
