# 🎮 R-Shop

**The eShop your Retro Handheld was missing.**
A premium, console-native game manager for Android. Built for handhelds, perfected for controllers, and designed for the retro community.

<p align="center">
  <a href="https://averageconsumer.github.io/R-Shop/">
    <img src="docs/screenshots/console_list.png" width="600" alt="R-Shop Console Overview" />
  </a>
</p>

<p align="center">
  <a href="https://averageconsumer.github.io/R-Shop/">
    <img src="https://img.shields.io/badge/Website-Visit_R--Shop-blueviolet?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Website" />
  </a>
  <a href="https://github.com/averageconsumer/r-shop/releases">
    <img src="https://img.shields.io/badge/Download-Latest_APK-brightgreen?style=for-the-badge&logo=android&logoColor=white" alt="Download" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.9.8_Beta-blue?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/platform-Android-brightgreen?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/github/stars/averageconsumer/r-shop?style=flat-square&color=yellow" alt="Stars" />
</p>

---

## 🌟 What is R-Shop?

R-Shop is a Flutter-based Android application that provides a **seamless, console-like experience** for browsing, downloading, and organizing your retro game library. 

It bridges the gap between your self-hosted storage (**RomM, SMB, FTP, Web**) and your handheld device, providing a native UI that feels like it was built by a major console manufacturer. Optimized specifically for the **AYN Odin, Retroid Pocket, Anbernic** and other Android-based handhelds.

> **🛡️ Neutrality Policy:** R-Shop is a technical tool and directory browser. It does **not** host, distribute, or provide links to copyrighted content. You provide the sources; R-Shop provides the experience.

---

## ✨ Key Features

* **🎮 Console-Native UI** – 100% D-pad and analog navigation. Features haptic feedback, mechanical click sounds, and correct controller icons.
* **🌐 Multi-Protocol Mastery** – Connect to **RomM, SMB, FTP, or Web** directories. Mix and match sources for every single console in your library.
* **📚 Library Screen** – Unified cross-system browser with All/Installed/Favorites tabs, search, and adjustable grid zoom.
* **📥 Hardened Download Engine** – Background-ready downloads via Android Foreground Service. Features auto-extraction (ZIP/7z) and queue persistence.
* **🖼️ Automatic Box Art** – Metadata and covers are fetched automatically via libretro-thumbnails.
* **⚡ Quick Menu (Start Button)** – Instant access to Search, Settings, Zoom, and Downloads from any screen.
* **🔄 Background Sync** – Automatic provider sync on launch with live progress indicators.
* **🧭 Smart Onboarding** – Auto-detection of existing ROM folders and guided setup for remote sources.

---

## 📸 Screenshots

<p align="center">
  <img src="docs/screenshots/console_list.png" width="400" alt="Console Overview" />
  <img src="docs/screenshots/rom_list.png" width="400" alt="ROM List" />
</p>
<p align="center">
  <img src="docs/screenshots/smb_setup.png" width="400" alt="SMB Network Setup" />
  <img src="docs/screenshots/download_queue.png" width="400" alt="Download Queue" />
</p>

---

## 🗂️ Supported Systems (27 systems · 200+ file formats)

| Nintendo | Sony | SEGA | Other |
|----------|------|------|-------|
| NES, SNES, N64 | PlayStation (1-4) | Master System | Neo Geo Pocket Color |
| GameCube, Wii, Wii U | PSP, PS Vita | Mega Drive | Arcade (MAME) |
| Switch | | Saturn, Dreamcast | Xbox & Xbox 360 |
| GB, GBC, GBA, DS, 3DS | | | |

---

## 📲 Installation

### 🚀 The Best Way: Obtainium
Keep R-Shop updated automatically using **[Obtainium](https://github.com/ImranR98/Obtainium)**. Just add this repository URL and never miss a Beta update.

### 📦 Manual APK
Download the latest `.apk` from the [**Releases**](../../releases) page and install it manually.

---

## 🛠️ Getting Started

1. **Onboarding:** The setup wizard auto-detects existing folders or connects to your RomM, SMB, FTP, or Web sources.
2. **Library Sync:** Watch R-Shop build your local metadata cache automatically on launch.
3. **Download & Play:** Hit 'A' to queue a game. R-Shop handles the download, extraction, and organization.

*For the full walkthrough, see the **[User Guide](docs/USER_GUIDE.md)**.*

---

## 🤝 Contributing & License

Contributions make the community thrive! Check out **[CONTRIBUTING.md](CONTRIBUTING.md)**.
This project is licensed under the **MIT License**.

---

## ⚠️ Disclaimer

R-Shop is a library management tool. It does not provide ROMs. Users must legally own the content they access through their own private servers or directories.
