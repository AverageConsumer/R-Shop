# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

---

## [0.9.4] Beta — 2026-02-20

### Added
- Global search activated (Home screen, Y button) — cross-system search with region flags and tag badges
- Local-only mode — consoles without a provider show locally scanned ROM files with a banner hint
- FTP download progress — real-time per-chunk progress reporting instead of staying at 0%
- Download inactivity watchdog — 60-second stall detection with clear error message
- Gamepad key fix — intercepts mismatched logical keys on key-up/repeat for certain gamepad drivers (AYN Thor etc.)
- Provider type badge on version cards (RomM, SMB, FTP, WEB)
- Download overlay sectioned list (Downloading / Queued / Complete headers) with ID-stable focus and auto-scroll
- Download overlay auto-close when queue empties
- SMB domain auth field
- `ProviderConfig.validate()` and `shortLabel` helpers
- `showConsoleNotification()` — themed floating SnackBar used app-wide
- `getUserFriendlyError()` — maps raw exceptions to readable messages

### Improved
- RomM Config screen reworked — focus-aware glow borders, D-pad navigable fields, connection test as toast, per-console sync status with bulk "Update stale" action
- Settings screen — RomM Server item re-enabled, concurrent downloads widget with chevrons, Reset App moved to HUD X-button
- Home view empty-state shows HUD bar with Settings/Exit actions; loading state is a black screen (no flash)
- Game detail loading shows game name + system-colored spinner
- Game list header shows target folder path and local-only banner
- Game grid context-sensitive empty states (search miss, filter miss, local-only empty, connection error)
- Platform icons compressed (~70% smaller file sizes)
- All action shortcuts use `includeRepeats: false` (no more repeated fires on button hold; D-pad retains repeats)
- `OverlayFocusScope` / `DialogFocusScope` — `_hasClaimed` flag prevents double-release of overlay priority
- RomM cover fallback chain (CDN → small → large → first screenshot)
- `UnifiedGameService` provider calls wrapped in 30s timeout
- `RommApiService` / `WebProvider` — connect 15s / receive 30s timeouts
- README updated with supported systems table and Building from Source section

### Fixed
- **Zip Slip vulnerability** — Android ZIP extraction validates canonical path before writing
- **Path traversal** — `_safePath` uses `p.basename()` in both `DownloadService` and `RomManager`
- **Atomic config write** — `ConfigStorageService.saveConfig` writes to `.tmp` then renames
- **DB init race condition** — `DatabaseService` uses single `static Future<Database>?` guard
- **AudioManager BGM reinit loop** — `_hasAttemptedReinit` flag prevents recursive retry
- **Retry timer leak** — `DownloadQueueManager` tracks `Timer` instances, cancels on dispose
- **FailedUrlsCache unbounded growth** — replaced `Set<String>` with `Map<String, DateTime>` + 5min TTL
- **Delete dialog defaults to CANCEL** (selection index 1, not 0)
- FTP download cancel now disconnects the FTP session
- `totalBytes` clamping — treats `<= 0` as unknown so progress bar works correctly
- Global search `providerConfig` propagation — results open with correct provider
- `RepoManager` Dio connection leak — `dio.close()` in `finally` block
- `GameDetailController` / `GameListController` — disposed-guard prevents post-dispose `notifyListeners()`
- Global search Escape/B from text field moves focus to results instead of closing
- Search overlay left/right arrows no longer leak to grid while editing

### Internal
- `DownloadItem` fully immutable (all fields `final`), serializes `systemId` + `providerConfig`
- `DatabaseService` schema v3 (adds `provider_config` column with migration)
- `gamepad_key_fix.dart` installed at app startup via `main()`
- Download overlay refactored into `_buildSectionedList` / `_buildCard` / `_buildSectionHeader` helpers

---

## [0.9.3] Beta — 2026-02-19

### Added
- RomM onboarding wizard — guided first-run setup with connection test, platform auto-discovery, and folder assignment
- Game list filter overlay (X button) — filter ROMs by region and language with per-console persistence
- Global search overlay infrastructure (cross-system search, wired but trigger disabled until v0.9.4)
- Android foreground service — downloads continue in background with a persistent notification
- Download queue persistence — queued and errored downloads survive app restarts
- Automatic download retry with exponential backoff (3 attempts, 5s/15s/45s)
- Configurable concurrent download limit (1–3) in Settings
- RomM config screen for editing server URL, API key, and credentials
- Local folder scanner and fuzzy system-ID matcher for onboarding folder assignment

### Improved
- RomM ROM list fetching is now paginated (pages of 500, no more timeouts on large libraries)
- RomM platform API accepts both `items` and `results` response keys (multi-version support)
- Download overlay action button is context-aware (Cancel / Retry / Clear)
- Filter and search are mutually exclusive in the game list
- Onboarding console setup no longer requires a provider (target folder only is valid)

### Fixed
- RomM ROM fetch used a malformed `platform_ids` query parameter
- Download overlay showed "Retry" for completed items
- Game grid passed unfiltered variant lists when filters were active
- Home view carousel index jumped after system list refresh

### Internal
- Added `flutter_foreground_task` dependency
- Android manifest: foreground service, notification, and battery optimization permissions
- `FilterState` / `ActiveFilters` model extracted; `RommSetupState` added to onboarding controller
- `DownloadQueueManager` now takes `StorageService`; `GameDetailController` takes `DownloadQueueManager`
- `local_folder_matcher_test.dart` unit tests

---

## [0.9.2] Beta — 2026-02-18

### Added
- Installed indicator LED strip on game cards for downloaded ROMs
- Shared `ConsoleSetupHud` widget for onboarding and config-mode screens
- `ConsoleHud` slot-based API (`a`, `b`, `x`, `y`, `start`, `select`, `dpad`) replacing raw button lists
- Auto-scroll on focus for `ConsoleFocusable` via `Scrollable.ensureVisible`

### Improved
- Onboarding rework — streamlined flow with guard checks for provider test/save actions
- Input system: global Actions now use `isEnabled()` overlay checks instead of inline guard clauses
- `NavigateAction` cooldown (100ms) prevents rapid-fire navigation on DPAD hold
- `OverlayFocusScope` claims priority and requests focus in a single operation
- Focus state restoration uses `getFocusState()` public API instead of direct `StateNotifier.state` access
- `ConfigModeScreen` simplified, shares HUD logic with onboarding

### Fixed
- DPAD hold producing duplicate navigation by removing `tick()` feedback from `ConsoleFocusable`
- `ConsoleFocusable.didUpdateWidget` correctly handles focus node swaps
- `ExitConfirmationOverlay` overlay priority lifecycle (set in `initState`, reset in `dispose`)

### Internal
- Removed `GameSourceService` (replaced by unified provider system)
- `SystemModel` restructured for multi-source provider configs
- `FocusScopeObserver` and `OverlayScope` cleanup

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
