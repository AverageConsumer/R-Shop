# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

---

## [1.3.0] — 2026-03-01

### Added
- **Console store-style game detail** — redesigned detail screen with structured layout, section headers, and download area inspired by digital storefronts
- **IGDB metadata** — RomM games now display genre, developer, release year, game modes, and summary via a glassmorphic "About This Game" card (fetched from RomM's IGDB data)
- **Description overlay** — full game summary accessible from the quick menu when metadata is available
- **Variant picker overlay** — pressing A on multi-version games opens a dedicated picker with all variants, install status, and per-variant download/delete actions
- **Game metadata database** — new `game_metadata` table (DB v8) stores IGDB metadata separately from game entries, surviving library re-syncs

### Improved
- **Quick menu consolidation** — Tags, Description, Filename toggle, and Achievements are now accessible from the quick menu instead of dedicated button shortcuts
- **Detail screen layout** — portrait mode uses scrollable layout with adaptive cover aspect ratio; landscape uses two-column layout with expandable info card
- **Download action button** — redesigned as a standalone widget with distinct states (download, delete, installed, adding, unavailable) and variant count badge

### Internal
- `GameMetadataInfo` model with `hasContent`, `genreList`, `averageRating` helpers
- `gameMetadataProvider` (`FutureProvider.family`) for async metadata loading
- `RommRom` extended to parse `summary`, `genres`, `companies`, `first_release_date`, `game_modes`, `average_rating`
- `RommProvider.fetchGames()` saves metadata as fire-and-forget side effect
- 194 new API service tests covering metadata parsing edge cases

---

## [1.2.0] — 2026-02-27

### Added
- **RetroAchievements integration** — connect your RA account to track achievements, verify ROMs via hash matching, and view per-game progress directly in R-Shop
- **Achievements screen** — dedicated viewer with earned/locked badges, points, progress bar, mastery status, and full D-pad navigation
- **RA onboarding step** — optional setup during first-run wizard with connection test and skip option
- **RA config screen** — manage credentials (encrypted via SecureStorage) from Settings with connection testing
- **Post-download hash verification** — downloaded ROMs are automatically hashed and matched against the RA database in the background
- **RA sync service** — 3-phase background sync (catalog fetch → name matching → hash verification) with 24h freshness cache and cancellation support
- **RA badges on game cards** — achievement count and match type (gold for name match, green for hash verified) displayed on every card; mastery outline when fully completed
- **Add-to-queue toast** — animated bottom-right notification when a game is added to the download queue
- **Hide empty consoles** — new toggle in Settings → Preferences to hide systems with no games from the home screen

### Improved
- **Sync badge** — now shows dual pills for library sync (cyan) and RA sync (gold) with independent progress tracking
- **Game detail screen** — RA info section below metadata showing match status, progress bar, and "View Achievements" button; quick menu gains "Achievements" option
- **Download overlay** — visual refinements and better state display
- **SystemModel** — 15+ systems now carry RA console IDs (NES, SNES, N64, GB, GBC, GBA, Mega Drive, SMS, Game Gear, 32X, Atari 2600/7800, Lynx, NDS)
- **Library screen** — deduplication of installed entries when same game exists in multiple formats
- **Cover preload service** — improved reliability and error handling

### Internal
- Database schema v7 — new tables: `ra_games` (catalog cache), `ra_hashes` (hash index), `ra_matches` (match results)
- Hash computation for 10+ systems: simple MD5, NES (iNES header strip), SNES (copier header), NDS (multi-section), Lynx, Atari 7800
- `RaNameMatcher` with 4-tier fallback: exact → contains → No-Intro filename → fuzzy (Levenshtein)
- New providers: `raGameProgressProvider`, `raRefreshSignalProvider`, `raMatchResultProvider`, `raSyncServiceProvider`
- 1,209 tests (up from 1,069) — new suites: RA hash service, RA models, RA name matcher, expanded database and onboarding tests

---

## [1.1.0] — 2026-02-27

### Added
- **Native SMB** — replaced smb_connect library with Kotlin MethodChannel service (`SmbService.kt`), enabling folder downloads, progress reporting, and reliable timeout handling on Android
- **Folder downloads** — games stored as multi-file directories (bin/cue, m3u) can now be downloaded as complete folders via SMB and FTP
- **Gamepad button icons** — SVG icon set (Xbox, PlayStation, Nintendo Switch) for context-aware controller hints
- **RomM config screen** — full server management (add/edit/remove) with connection test, directly accessible from settings
- **Network constants** — centralized timeout values (`NetworkTimeouts`) shared across all providers
- **File utilities** — crash-safe atomic file move (`moveFile`) with staging and cleanup

### Improved
- **Onboarding rework** — redesigned setup wizard with streamlined console configuration, local folder detection, and RomM integration
- **FTP provider** — host validation (hostname, IPv4, IPv6), injection protection, configurable timeouts
- **Web provider** — security hardened directory parsing (path traversal, control chars, oversized hrefs filtered)
- **Download service** — folder-aware downloads for SMB and FTP protocols with per-file progress
- **Friendly errors** — expanded user-facing error mapping for network, auth, and provider failures
- **Console HUD / Quick Menu / Control Button** — simplified rendering with gamepad icon integration

### Internal
- 1,069 tests (up from 970) — new suites: SMB provider (14), FTP provider (8), Web provider (12), FocusSyncManager (32), OverlayPriorityManager (14), file_utils (5), friendly_error expansions
- `smb_connect` dependency removed (replaced by native Kotlin implementation)
- `NativeSmbService` Dart wrapper for `com.retro.rshop/smb` MethodChannel
- `NativeSmbDownloadHandle` / `NativeSmbFolderDownloadHandle` download handle types

---

## [1.0.0] — 2026-02-26

### Highlights
- **Stable release** — R-Shop exits beta
- **SVG platform icons** — all 29 system icons migrated from PNG to crisp SVG format
- **Android package restructure** — migrated from `com.example.r_shop` to `com.retro.rshop`
- **Network security config** — dedicated XML configuration for local network protocols

### Improved
- **Test coverage** — 950+ tests covering controllers, services, models, and utilities
- **Code quality** — zero TODO/FIXME markers, zero silent catches, all error paths logged
- **Dependency hygiene** — all dependencies pinned to exact versions

### Internal
- New test suites: GameListController (43 tests), GameMergeHelper (12 tests), ImageHelper (19 tests)
- 8 additional test files covering app config, audio manager, config parser, onboarding, providers, and cover preload

---

## [0.9.9] Beta — 2026-02-25

### Added
- **Custom Shelves** — create personal game collections with manual curation, filter rules (by system, region, language), or hybrid mode; supports reordering, renaming, and per-shelf sort modes
- **Device Info Service** — adaptive memory tiering (low/standard/high RAM) that auto-tunes image cache sizes, grid cache extents, and cover preload pools for low-end handhelds
- **Shelf Picker Dialog** — quick-add games to shelves from library and game detail screens
- **System Selector Overlay** — filter library view by system with visual system badges

### Improved
- **Settings screen refactored** — split into Preferences, System, and About tabs with extracted `DeviceInfoCard` widget (1048→604 lines)
- **Download overlay refactored** — extracted 7 widgets to `lib/widgets/download/` (DownloadItemCard, CoverThumbnail, PulsingDot, LowSpaceWarning, StatusLabel, DownloadProgressBar, DownloadActionButton) (1477→793 lines)
- **Shelf edit screen refactored** — extracted GameListOverlay, TextInputDialog to shared library widgets (1108→631 lines)
- **RomM onboarding refactored** — extracted RommConnectView, RommSelectView, RommFolderView, RommActionButton (1405→122 lines); state classes moved to `onboarding_state.dart` (1713→1362 lines)
- **Library screen refactored** — extracted ReorderableCardWrapper, LibraryEntry to dedicated widgets (1490→1386 lines)
- **Dependency pinning** — all 16 remaining caret-range dependencies pinned to exact resolved versions for reproducible builds

### Internal
- New models: `CustomShelf`, `ShelfFilterRule` with JSON serialization
- New providers: `CustomShelvesNotifier` / `customShelvesProvider` for shelf CRUD
- `DeviceInfoService` with `MemoryTier` classification
- ~20 new test files covering download queue manager, unified game service, library sync, thumbnail service, custom shelves, database service, config storage, image cache, storage service, and widget tests

---

## [0.9.8] Beta — 2026-02-23

### Added
- **Crash log service** — local ring-buffer log file (~500KB) captures all uncaught errors with timestamps and stack traces; persists across sessions in app cache
- **Export Error Log** — new Settings entry (under System) shares the crash log via the system share sheet for easy bug reporting; only visible when log contains data
- **Disk space pre-check** — downloads are rejected with a clear error when device storage drops below 1 GB

### Improved
- **HTTP download depth guard** — the `_downloadHttp` resume-restart path now enforces a single-retry limit, preventing infinite recursion if the server keeps returning mismatched content lengths
- **FocusSyncManager index safety** — `ensureFocusNodes()` clamps `_selectedIndex` after pruning disposed nodes; `validateState()` clamps `_targetColumn` when column count changes — prevents focus jumping to invalid positions during rapid grid resizing
- **Zone alignment** — `WidgetsFlutterBinding.ensureInitialized()` and `runApp()` now execute inside the same `runZonedGuarded` zone, eliminating the "Zone mismatch" warning on startup
- **Overlay priority release** — all scope classes (`OverlayFocusScope`, `DialogFocusScope`, `SearchFocusScope`, `ExitConfirmationOverlay`) defer `release()` via `Future()` in `dispose()`, fixing the Riverpod "cannot modify provider during widget tree build" crash
- **Detail screen layout** — system name badge wrapped in `Flexible` with ellipsis overflow, fixing `RenderFlex` overflow on narrow screens with long system names (e.g. "PlayStation 2")
- **ConfigModeScreen dispose** — audio manager cached in `initState` to avoid `ref.read()` after widget is disposed
- **Download queue lookup** — `getDownloadById()` uses a simple loop instead of `firstWhere` + try/catch, eliminating noisy "Bad state: No element" log spam during queue restore

### Fixed
- **Overlay priority crash** — releasing overlay tokens during widget unmount no longer throws Riverpod state modification errors (was causing "At least listener of the StateNotifier threw an exception" crashes)
- **FocusSyncManager focus loss** — selected index could point to a disposed `FocusNode` after the item count decreased, causing silent focus failures

### Internal
- New `CrashLogService` singleton (`lib/services/crash_log_service.dart`) with `log()`, `logError()`, `getLogFile()`, `clearLog()`, `getLogContent()`
- `crashLogServiceProvider` in `app_providers.dart`, overridden in `main.dart`
- Global error handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`) now write to crash log in addition to `debugPrint`
- Removed spammy `debugPrint` in `FocusSyncManager._enforceFocus()` for deferred focus (fired on every scroll)

---

## [0.9.7] Beta — 2026-02-22

### Added
- **Thumbnail pipeline** — persistent isolate-based thumbnail generator (400px JPEG) with background migration on startup and proactive cover preloading during library scans
- **ROM status providers** — real-time ROM installation tracking via filesystem watchers and download-completion listeners, replacing manual polling
- **Installed files provider** — central isolate-scanned index of all installed ROM files across every system
- **Cover preload** — new Settings entry to batch-generate thumbnails for all games
- **About section** — app version, GitHub/Issues links, and Easter Egg tagline in Settings
- **Zip extraction limit** — increased from 2 GB to 8 GB

### Improved
- **Smart cover loading** — thumbnail-first display with magic-byte validation, JPEG re-encoding for corrupt cache entries, and scroll-suppressed loading to reduce jank during fast scrolling
- **Controller button styling** — pill-shaped shoulder/trigger buttons, per-layout face button colors (Xbox green/red/blue/yellow, PlayStation palette), and shape painters for Nintendo +/− buttons
- **Quick menu hints** — face button hints now show layout-correct color palettes
- **Game card performance** — replaced `AnimatedScale`/`AnimatedContainer` with static `Transform.scale`/`Container` for smoother grid scrolling; `SelectionAwareItem` uses `ValueNotifier` to rebuild only affected cards on selection change
- **Search overlay** — extracted `SearchableScreenMixin` (shared by GameListScreen and LibraryScreen) and moved `SearchOverlay` widget from `features/game_list/widgets/` to `widgets/` for cross-screen reuse
- **FocusSyncManager** moved from `features/game_list/logic/` to `core/input/` for use by Library and Scan screens
- **Library screen** — now uses `SearchableScreenMixin`, `SelectionAwareItem`, `FocusSyncManager`, and scroll suppression for consistent behavior with GameListScreen
- **Image cache rate limiter** — cancellable pending requests, increased concurrent fetch limit (50), and host-level rate-limit detection
- **Database schema v4** — adds `thumb_hash` and `has_thumbnail` columns; thumbnail flags preserved across game list refreshes
- **`OverlayGuardedAction`** — generic reusable guarded action replaces per-screen private action classes

### Fixed
- **Zip bomb protection** — extracted archive size capped at 2 GB; extraction aborts with clear error if limit exceeded
- **Web provider path traversal** — directory listing parser rejects absolute URLs and `../` href values
- **Overlay priority teardown** — `OverlayFocusScope`, `DialogFocusScope`, and `SearchFocusScope` use `addPostFrameCallback` with try/catch instead of raw `Future()`, preventing "disposed notifier" crashes on fast screen transitions
- **Android backup disabled** — `android:allowBackup="false"` prevents unintended data restore from breaking app state
- **Grid navigation guard** — `_GridNavigateAction` now checks `overlayPriorityProvider` in `isEnabled`, preventing D-pad navigation while an overlay is open
- **Focus restoration** — `mainFocusRequestProvider` now set centrally in `ConsoleScreenMixin.initState`

### Internal
- New dependencies: `image: ^4.3.0`, `crypto: ^3.0.6`
- `GameItem.hasThumbnail` field added; `copyWith` extended accordingly
- `adjustColumnCount()` helper extracted to `ConsoleScreenMixin`
- Deleted 4 obsolete files: `animated_background.dart`, `radial_glow.dart`, `folder_analysis_view.dart`, `search_overlay.dart` (game_list copy)

---

## [0.9.6] Beta — 2026-02-21

### Added
- **Scan Library** screen — Settings entry opens animated console grid with per-system scan progress, game count badges, and completion summary
- **Smart onboarding auto-detection** — detects existing ROM folders at common paths (`/storage/emulated/0/ROMs`, `/Roms`, `/roms`) with scan, create, pick, or skip options
- **Cache-first game list loading** — lists load instantly from SQLite cache, then silently refresh from remote providers; UI only updates if the list actually changed (filename-diffed)
- **Offline indicator** — amber "Offline — cached data" toast on failed sync; sync badge shows failure state
- **Provider reordering** — D-pad or arrow buttons to change provider priority in console configuration panel
- **Test & Save** — single button tests provider connection and auto-saves on success (replaces separate Save button)
- **User Guide** (`docs/USER_GUIDE.md`) — comprehensive guide covering all features, controls, supported systems, and troubleshooting

### Improved
- **ROM format coverage** expanded across 10+ systems — GameCube (ISO/GCM/CISO), Wii (WBFS/WIA/CISO), PS2 (CSO), PS3 (PKG), PSP (PBP), Mega Drive (BIN/SMD), Dreamcast (CDI/GDI), Saturn (ISO), Arcade (7z), N64 (V64), SNES (SMC)
- **Isolate-based local scanning** — filesystem scanning offloaded to a Dart isolate via `compute()` for smoother UI
- **Library sync freshness** — 5-minute cache prevents redundant re-syncs; `clearFreshness()` forces refresh after config changes
- **Sync covers local-only systems** — `syncAll()` now includes systems without remote providers
- **Batched install-status checks** — processes in parallel batches of 20
- **Filter passthrough** — games with no region/language metadata now pass through filters instead of being excluded
- **Console grid badges** — local-only systems show blue folder badge instead of green provider checkmark
- **Post-settings re-sync** — config reloaded and freshness cleared after returning from settings
- **Library installed detection** — correctly matches extracted ROM files (e.g., `Game.zip` → `Game.iso`)
- **Library-based search** — Y button on home navigates to Library with search open, replacing standalone global search overlay

### Fixed
- **GameDetail variant index** clamped to valid range (prevents crash on variant list changes)
- **Search overlay** focus handling improved

### Internal
- `GlobalSearchOverlay` removed (675 lines) — replaced by Library with `openSearch: true`
- `RepoManager` and `RomHeaderParser` removed
- `archive` dependency removed from `pubspec.yaml`
- `GameMergeHelper` extracted for dedup logic (remote-vs-local merge, archive expansion, multi-file detection)
- `SystemModel` gains `archiveExtensions`, `allRomExtensions`, `allGameExtensions`, and `isGameFile()`
- Unused providers cleaned up from `app_providers`, `config_providers`, `download_providers`
- `LibrarySyncService` extended with `discoverAll()`, `isFresh()`, `hadFailures` state

---

## [0.9.5] Beta — 2026-02-20

### Added
- **Library screen** — unified cross-system game browser with All/Installed/Favorites tabs, search, sort modes (A-Z / by system), and adjustable grid zoom (LB/RB)
- **Background library sync** — automatic provider sync on launch with live progress badge on home screen
- **Quick Menu** (Start/+ button) — contextual overlay with shortcuts to Search, Settings, Zoom, and Downloads
- **Home grid layout** — toggle between carousel and grid view on the home screen; grid columns adjustable via LB/RB
- **ROM header parser** — extracts internal game titles from GB, GBC, GBA, NDS, and SNES ROM headers (raw + ZIP)
- **Favorite toggle** (Select/- button) — quick-favorite from game detail screen
- **Tab switching** (LB/RB) — navigate filter tabs in Library and Filter overlay
- **Local-only filter** — new toggle in filter overlay to show only locally installed ROMs

### Improved
- **BaseGameCard** replaces old game card — unified design with system badge, installed indicator, favorite heart, variant count, and provider label
- **Version card** simplified — significant refactor removing redundant layout logic
- **ConsoleHud** refactored — cleaner slot rendering, consistent spacing, proper embedded vs positioned modes
- **Filter overlay** — improved layout with local-only toggle and multi-tier filtering
- **Global search** — results now show provider label and region flags consistently
- **Controller layout** preference persisted across sessions
- **Home layout** preference (carousel/grid) persisted across sessions

### Fixed
- **Download overlay HUD position** — button legend was stuck top-left instead of bottom-right (AnimatedOpacity wrapping Positioned broke Stack layout)
- **Quick Menu downloads option** now shows whenever queue has any items (including completed/failed), not just active+queued
- Favorite names migration cleans up legacy IDs on app start
- **Duplicate library entries for multi-file ROMs** — remote archive merge now adds extracted folder names to dedup set (bin/cue games no longer appear twice)
- **ROMs in subdirectories not detected** — `scanLocalGames`, `exists`, and `delete` now check subdirectories for all ROM extensions, not just multi-file formats

### Internal
- New `QuickMenuOverlay` widget with overlay priority and controller-aware shortcut hints
- `AdjustColumnsIntent` consolidates zoom controls across screens
- `ToggleOverlayAction` uses `onToggle` callback instead of publishing a state request
- `SyncBadge` widget for real-time sync progress display
- `LibrarySyncService` as `StateNotifier<LibrarySyncState>`
- `homeLayoutProvider`, `homeGridColumnsProvider`, `controllerLayoutProvider` in app_providers

---

## [0.9.4] Beta — 2026-02-20

> [!WARNING]
> **Migration Notice:** Upgrading from versions `<= 0.9.3` to `0.9.4` or newer requires a **fresh installation** due to significant backend database and config architecture changes. Legacy configurations will not transfer over cleanly.

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
