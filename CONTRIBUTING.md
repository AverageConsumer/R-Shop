# Contributing to R-Shop

First off — **thank you!** 🎮 Whether you're fixing a typo or building a whole new feature, every contribution helps make R-Shop better. This project is maintained by a solo developer who is learning as they go, so patience and kindness are appreciated.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](../../issues) to avoid duplicates
2. Open a new issue with:
   - A clear title
   - Steps to reproduce the bug
   - What you expected vs. what happened
   - Your device info (Android version, device model)
   - Screenshots or screen recordings if possible

### Suggesting Features

Open an issue with the **Feature Request** label. Describe what you'd like and why it would be useful.

### Submitting Code

1. **Fork** the repository
2. **Create a branch** from `main` (`git checkout -b feature/your-feature`)
3. **Make your changes** — try to keep commits focused and descriptive
4. **Test on a real device** if possible (this app is designed for Android handhelds)
5. **Open a Pull Request** with a clear description of what you changed and why

### Code Style

- Follow standard [Dart/Flutter conventions](https://dart.dev/effective-dart/style)
- Keep widgets focused — one widget, one job
- Use Riverpod for state management (the existing pattern)
- Comment any non-obvious logic

### What We Need Help With

- 🐛 Bug fixes and stability improvements
- 🎨 UI/UX polish and animations
- 🎮 Controller input improvements (D-pad navigation, gamepad support)
- 📱 Testing on different Android devices and handhelds
- 📝 Documentation and guides
- 🌍 Translations / localization

## Development Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (SDK ≥ 3.0.0)
2. Clone the repo
3. Run `flutter pub get`
4. Connect an Android device or emulator
5. Run `flutter run`

## Code of Conduct

Be kind, be respectful, have fun. We're all here because we love retro gaming. 🕹️

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
