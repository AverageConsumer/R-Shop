# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

---

## [0.9.1] Beta — 2026-02-17

### Added
- Multi-source provider system — each console can use Web, SMB, FTP, or RomM sources
- RomM server integration with automatic platform matching via IGDB
- JSON-based configuration system with import/export support
- Config editor in settings to add/remove/edit consoles after onboarding
- Unified Game Service with merge and failover strategies across multiple sources
- Interactive onboarding wizard with per-console setup

### Improved
- Mouse/touch support for all focusable widgets (click to focus and activate)
- Volume sliders now respond to drag and tap input
- Home screen only shows configured consoles
- Input debouncing for all HUD buttons and action classes (prevents double-tap actions and duplicate sounds)

### Fixed
- Renamed `romPath` to `targetFolder` to resolve path confusion in the download system
- Download queue backward-compatible with legacy JSON format
- Simplified app launch logic (no more null checks for romPath/repoUrl)
- "Reset App" now fully clears all preferences, SQLite cache, and image cache

### Internal
- New dependencies: `smb_connect`, `ftpconnect`, `share_plus`
- Provider reorganization: `config_providers.dart`, `game_providers.dart`
- `GameItem` now carries `providerConfig` for authenticated downloads

---

## [0.9.0] Beta — Initial Release

- Console-style UI with full controller support
- Download queue with live progress and auto-extraction (ZIP/7z)
- Automatic box art via libretro-thumbnails
- Aggressive caching for large libraries (5000+ items)
- Instant search across all systems
- 17 supported systems (Nintendo, Sony, SEGA)
