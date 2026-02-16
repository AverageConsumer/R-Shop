# R-Shop

**Your retro game collection, one tap away.**
A premium console-style game manager for Android — built for handhelds, controllers, and anyone who loves retro gaming.

![Version](https://img.shields.io/badge/version-0.9.0_Beta-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Android-brightgreen)
![Status](https://img.shields.io/badge/status-Public_Beta-orange)

---

## What is R-Shop?

R-Shop is a Flutter-based Android app that gives you a **console-like experience** for browsing, downloading, and organizing retro game ROMs from your own sources. Think of it as your personal eShop — but for every retro system you love.

It's built with love for **Android gaming handhelds** (Retroid, Odin, AYN, Anbernic…) but works beautifully on any Android device with touch or controller input.

> **⚠️ Important:** R-Shop is a neutral browser. It does **not** host, distribute, or link to any copyrighted content. Users must provide their own source URLs.

---

## ✨ Features

- 🎮 **Built for Controllers** — Full D-pad/analog navigation, haptic feedback on every interaction, satisfying click sounds. Feels like a real console UI, not a phone app.
- 📥 **Smart Download Queue** — Queue up your entire library. Downloads run with live progress and auto-extraction (ZIP/7z).
- 🖼️ **Automatic Box Art** — Every game gets its cover art fetched and cached automatically via [libretro-thumbnails](https://github.com/libretro-thumbnails).
- ⚡ **Aggressive Caching** — Optimized for huge libraries (5000+ items). After the first load, the app feels instant even without internet.
- 🔍 **Instant Search** — Find any game across all systems in milliseconds.
- 🗂️ **17 Systems Supported** — Nintendo (NES to 3DS), Sony (PS1, PS2, PSP), SEGA (Master System to Dreamcast).
- 📱 **Hybrid Input** — Seamlessly switch between touchscreen and gamepad. Both feel native.

---

## 📸 Screenshots

*Screenshots coming soon!*

---

## 📲 Installation & Updates

### Recommended: Obtainium
The best way to install and keep R-Shop updated is via **[Obtainium](https://github.com/ImranR98/Obtainium)**.
1. Install Obtainium.
2. Add this repository URL.
3. Enjoy automatic updates for every new Beta release!

### Manual APK
1. Go to the [**Releases**](../../releases) page.
2. Download the latest `.apk` file.
3. Install it on your Android device.

---

## 🕹️ How to Use

1. **Open the app.**
2. **Setup Source:** On first launch, you need to provide a URL. R-Shop works with any **Apache Directory Listing**.
    > *Hint: It works perfectly with standard community ROM archives. Just point it to the main files directory.*
3. **Pick a Folder:** Choose where games should be stored (e.g., your generic ROMs folder).
4. **Browse & Download:** The app handles the rest.

---

## 🐛 Known Issues (Beta)

* **Background Downloads:** In v0.9.0, downloads might pause if your device enters "Deep Sleep". Please keep the screen on for massive batch downloads. (A background service is coming in v0.9.1!).
* **Initial Cache:** Scrolling through a list of 2000+ games for the very first time might show placeholders briefly while the cache builds up.

---

## 🤝 Contributing

Contributions are welcome and **greatly appreciated**! This project is maintained by a solo dev who honestly can't even code that well — so if you're a Flutter wizard, your help would be legendary. 🧙

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for details.

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **[libretro-thumbnails](https://github.com/libretro-thumbnails)** — For the massive database of game covers.
- **viik4 / iisu** — For the clean platform icons used in the UI.
- **Flutter** — The framework powering this app.
- **The SBCGaming Community** — For the inspiration! 🕹️

---

## ⚠️ Disclaimer

R-Shop is a tool for managing your personal game library. It does **not** include, distribute, or endorse piracy of any kind. Users are solely responsible for the content they access. Always respect copyright laws in your jurisdiction.
