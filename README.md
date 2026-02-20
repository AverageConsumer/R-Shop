# R-Shop

**Your retro game collection, one tap away.**
A premium console-style game manager for Android — built for handhelds, controllers, and anyone who loves retro gaming.

<p align="center">
  <img src="screenshots/console_list.png" width="600" alt="R-Shop Console Overview" />
</p>

![Version](https://img.shields.io/badge/version-0.9.4_Beta-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Android-brightgreen)
![Status](https://img.shields.io/badge/status-Public_Beta-orange)

---

## What is R-Shop?

R-Shop is a Flutter-based Android app that gives you a **console-like experience** for browsing, downloading, and organizing retro game ROMs from your own sources. Think of it as your personal eShop — but for every retro system you love.

It's built with love for **Android gaming handhelds** (Retroid, Odin, AYN, Anbernic…) but works beautifully on any Android device with touch or controller input.

> **Important:** R-Shop is a neutral browser. It does **not** host, distribute, or link to any copyrighted content. Users must provide their own source URLs.

---

## Features

**Controller-first UI** — Full D-pad and analog stick navigation with auto-scroll, haptic feedback, and click sounds. Every interaction feels like a real console interface, not a phone app. Touch and gamepad input work side by side; both feel native.

**Multi-source providers** — Each console can pull from Web directories, SMB shares, FTP servers, or a RomM instance. Mix and match per system, configure once globally or per console.

**RomM integration** — Connect to your RomM server and let R-Shop automatically match platforms via IGDB. Configure the connection once in settings and auto-fill credentials for every console.

**Smart download queue** — Queue up your entire library. Downloads run with live progress, auto-extraction (ZIP/7z), and the queue persists across app restarts. Adjust concurrent downloads (1–3) in settings.

**Automatic box art** — Every game gets its cover art fetched and cached automatically via [libretro-thumbnails](https://github.com/libretro-thumbnails). An installed indicator (glowing LED strip) on each game card tells you at a glance what you've already downloaded.

**Aggressive caching** — Optimized for huge libraries (5000+ items). After the first load, the app feels instant even without internet.

**Global search** — Find any game across all cached systems instantly from the home screen.

**Region and language filters** — Filter game lists by region or language, with per-system persistence.

**Config import/export** — Save your entire setup as JSON and restore it on any device.

---

## Screenshots

<p align="center">
  <img src="screenshots/console_list.png" width="250" alt="Console Overview" />
  <img src="screenshots/rom_list.png" width="250" alt="ROM List" />
  <img src="screenshots/download_queue.png" width="250" alt="Download Queue" />
</p>

---

## Supported Systems (27)

| Nintendo | Sony | SEGA | Other |
|----------|------|------|-------|
| NES | PlayStation | Master System | Neo Geo Pocket Color |
| Super Nintendo | PlayStation 2 | Mega Drive | Arcade |
| Nintendo 64 | PlayStation 3 | Game Gear | Xbox |
| GameCube | PlayStation 4 | Saturn | Xbox 360 |
| Wii | PSP | Dreamcast | |
| Wii U | PS Vita | | |
| Switch | | | |
| Game Boy | | | |
| Game Boy Color | | | |
| Game Boy Advance | | | |
| Nintendo DS | | | |
| Nintendo 3DS | | | |

---

## Installation & Updates

### Recommended: Obtainium
The best way to install and keep R-Shop updated is via **[Obtainium](https://github.com/ImranR98/Obtainium)**.
1. Install Obtainium.
2. Add this repository URL.
3. Enjoy automatic updates for every new Beta release.

### Manual APK
1. Go to the [**Releases**](../../releases) page.
2. Download the latest `.apk` file.
3. Install it on your Android device.

---

## Getting Started

1. **Launch R-Shop.** On first start, the onboarding wizard walks you through setup.
2. **Configure your consoles.** For each system you want, pick a source type (Web directory, SMB share, FTP server, or RomM) and enter the connection details.
3. **Choose a download folder.** Select where games should be stored per console (e.g., your ROMs folder).
4. **Browse and download.** The app handles the rest — box art, caching, and organization are automatic.

You can edit your console configuration at any time in **Settings > Config Editor**.

---

## Building from Source

```bash
git clone https://github.com/AverageConsumer/R-Shop.git
cd R-Shop
flutter pub get
flutter build apk --release
```

The built APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Known Issues (Beta)

* **Initial cache:** Scrolling through a list of 2000+ games for the very first time might show placeholders briefly while the cache builds up.

---

## Contributing

Contributions are welcome! See **[CONTRIBUTING.md](CONTRIBUTING.md)** for details.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **[libretro-thumbnails](https://github.com/libretro-thumbnails)** — Game cover database
- **viik4 / iisu** — Platform icons
- **The SBCGaming Community** — Inspiration

---

## Disclaimer

R-Shop is a tool for managing your personal game library. It does **not** include, distribute, or endorse piracy of any kind. Users are solely responsible for the content they access. Always respect copyright laws in your jurisdiction.
