# R-Shop Project AGENT Settings

> [!IMPORTANT]
> **Priority Instruction**: ALWAYS read the global long-term memory file at [GLOBAL_DEV_NOTES.md](file:///C:/Users/Mini-PC/StudioProjects/GLOBAL_DEV_NOTES.md) before starting any task to ensure compliance with universal project standards and localization rules.

This file contains UI/UX specifications and technical environment settings specific to the R-Shop project.

## 🎨 UI & Visual Specifications
- **Focus Border**: Use **pure white** (`Colors.white`) for the focus border of all focusable components (`ConsoleFocusable`).
- **Selection Style**: Active buttons/tiles must show a white border, deep red background (`alpha: 0.35`), and pure white text/icons.
- **Text Rendering**: Ensure all custom dialogs (like `ConsoleDialog`) wrap content in a `Material` widget to avoid yellow underlines and inherit correct text styles.

## 🛠️ Build Environment
- **JAVA_HOME**: `C:\Program Files\Android\Android Studio\jbr`
- **Flutter SDK**: `D:\flutter\bin\flutter.bat`
- **Pre-build Cleanup**: Always run `Remove-Item Env:ANDROID_PREFS_ROOT` before building.

## ⌨️ Gamepad Interaction
- **Back Button**: Fixed at top-left corner across all setup/settings screens (Icon size 26, Padding: `fromLTRB(8, 8, 16, 8)`).
- **Dialogs**: Mandatory use of `ConsoleDialog` for any modal confirmation, ensuring 'B' button cancels and 'A' button confirms.
