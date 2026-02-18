# R-Shop

**Your retro game collection, one tap away.**
A premium console-style game manager for Android — built for handhelds, controllers, and anyone who loves retro gaming.

<p align="center">
  <img src="screenshots/console_list.png" width="600" alt="R-Shop Console Overview" />
</p>

![Version](https://img.shields.io/badge/version-0.9.3_Beta-blue)
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

- 🎮 **Built for Controllers** — Full D-pad/analog navigation with auto-scroll, haptic feedback on every interaction, satisfying click sounds. Feels like a real console UI, not a phone app.
- 🌐 **Multi-Source Providers** — Each console can pull from Web directories, SMB shares, FTP servers, or a RomM instance. Mix and match per system.
- 🔗 **RomM Integration** — Connect to your RomM server and let R-Shop automatically match platforms via IGDB.
- 📥 **Smart Download Queue** — Queue up your entire library. Downloads run with live progress and auto-extraction (ZIP/7z).
- ✅ **Installed Indicator** — Already downloaded? A glowing LED strip on each game card tells you at a glance.
- 🖼️ **Automatic Box Art** — Every game gets its cover art fetched and cached automatically via [libretro-thumbnails](https://github.com/libretro-thumbnails).
- ⚡ **Aggressive Caching** — Optimized for huge libraries (5000+ items). After the first load, the app feels instant even without internet.
- 🔍 **Instant Search** — Find any game across all systems in milliseconds.
- 🗂️ **27 Systems Supported** — Nintendo (NES to 3DS), Sony (PS1–PSP), SEGA (Master System to Dreamcast), and more.
- 🔍 **Global Search** — Find any game across all cached systems instantly from the home screen.
- 🎚️ **Region & Language Filters** — Filter game lists by region or language, with per-system persistence.
- 📡 **Global RomM Connection** — Configure your RomM server once in settings and auto-fill credentials for every console.
- ⚙️ **Configurable Downloads** — Adjust max concurrent downloads (1–3) and queue is persisted across app restarts.
- 📱 **Hybrid Input** — Seamlessly switch between touchscreen and gamepad. Both feel native.
- 💾 **Config Import/Export** — Save your entire setup as JSON and restore it on any device.

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/console_list.png" width="250" alt="Console Overview" />
  <img src="screenshots/rom_list.png" width="250" alt="ROM List" />
  <img src="screenshots/download_queue.png" width="250" alt="Download Queue" />
</p>

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
2. **Onboarding Wizard:** On first launch, the setup wizard walks you through configuring each console. For every system you want, pick a source type (Web directory, SMB share, FTP server, or RomM) and enter the connection details.
3. **Pick a Folder:** Choose where games should be stored per console (e.g., your ROMs folder).
4. **Browse & Download:** The app handles the rest. You can edit your console configuration later in **Settings > Config Editor**.

---

## 🐛 Known Issues (Beta)

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
