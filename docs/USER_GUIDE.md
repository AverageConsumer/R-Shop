# R-Shop User Guide

R-Shop is a retro game manager with a console-style UI. It organizes, downloads, and manages ROM files from your own servers and network shares, with full gamepad and keyboard support.

**R-Shop is not an emulator.** It is a file management tool for browsing, downloading, and organizing game files. To play games, use a separate emulator such as RetroArch, Dolphin, PPSSPP, or any other emulator of your choice.

> **Legal Notice:** R-Shop does not host, distribute, or link to copyrighted game files. Users are responsible for providing their own legally obtained files. Supported sources include personal backups of owned cartridges and discs, homebrew games, public domain ROMs, and legally purchased digital copies.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Home Screen](#home-screen)
3. [Browsing Games](#browsing-games)
4. [Game Detail](#game-detail)
5. [Library](#library)
6. [Provider Setup Guide](#provider-setup-guide)
7. [Downloads](#downloads)
8. [Settings Reference](#settings-reference)
9. [Controls Reference](#controls-reference)
10. [Supported Systems](#supported-systems)
11. [Troubleshooting & FAQ](#troubleshooting--faq)
12. [Legal Notice](#legal-notice)

---

## Getting Started

On first launch, R-Shop walks you through a 6-step onboarding process to configure your game sources.

### Step 1: Welcome

A greeting from the app mascot. Press A to continue.

### Step 2: Legal Notice

You must acknowledge that you are responsible for owning legal copies of any game files you manage with R-Shop.

### Step 3: RomM Setup (Optional)

If you run a [RomM](https://github.com/rommapp/romm) server on your network, you can connect it here:

1. Enter your RomM server URL (e.g. `http://192.168.1.100:8080`)
2. Provide authentication: API key or username/password
3. Press Y to test the connection
4. Select which platforms to import from the server
5. Choose a local folder where ROM files will be stored

If you don't use RomM, select "No" to skip this step and proceed to Local Setup instead.

### Step 4: Local Setup (Optional)

If you skipped RomM, this step helps you set up local ROM folders:

- **Auto-detect**: R-Shop scans for existing ROM directories on your device
- **Create folders**: Generate a standard folder structure for all supported systems
- **Pick folder**: Manually select an existing folder to scan

Detected folders are automatically matched to systems. You can toggle systems on or off, and manually assign any unmatched folders.

### Step 5: Console Setup

The main configuration screen. A grid displays all supported systems. For each console you can:

- Set a **target folder** where ROM files will be stored
- Toggle **auto-extract** for archive files
- Toggle **merge mode** to combine results from multiple providers
- **Add providers** (Web, SMB, FTP, or RomM) with connection details

Press Y to add a new provider, then fill in the type-specific fields and test the connection. You can add multiple providers per console and reorder their priority.

At least one console must be configured before you can proceed.

### Step 6: Complete

A summary of your configured consoles. Press Select to export your configuration as a JSON backup file, then press A to enter the app.

**You can always reconfigure consoles and providers later from Settings.**

---

## Home Screen

The home screen displays your configured systems.

### Carousel Mode (Default)

Swipe or use the D-pad to scroll through system cards. Each card shows the console name, manufacturer, and release year. Press A to enter a system.

### Grid Mode

Toggle via Settings. Systems display in a grid layout. Adjust columns with L1 (more columns) and R1 (fewer columns).

### Library Card

A special card appears between your systems, providing access to the cross-system Library browser.

### Download Badge

A pulsing indicator in the top-left corner appears when downloads are active.

### Quick Menu

Press Start to open the quick menu with options for:

- **Search** — jump to game search
- **Settings** — open app settings
- **Zoom** — adjust grid columns
- **Downloads** — view download queue (shown when queue has items)

### Exiting

Press B on the home screen to show an exit confirmation dialog.

---

## Browsing Games

Selecting a system from the home screen opens the game list.

### Layout

Games display as a grid of cover art. Adjust columns with L1 (more, 3-8 range) and R1 (fewer). The header shows the system logo, total game count, a local-only indicator (if no remote providers), and the target folder path.

The background dynamically shows the selected game's cover art, tinted with the system's color.

### Search

Press Y to open the search overlay. Type to filter games in real time by name. Press Down or B to exit search and return to the grid.

### Filters

Press X to cycle through filter options:

- **Region** — show only games from selected regions (OR logic)
- **Language** — show only games in selected languages (OR logic)
- **Favorites Only** — show only games you have favorited
- **Local Only** — show only games installed on your device

Games with no region or language metadata pass through those filters. Your filter choices are saved per system.

### Game Grouping

Games with the same name but different versions (e.g. USA, Europe, Japan) are grouped together. Selecting a group opens the Game Detail screen where you can pick a specific variant.

---

## Game Detail

The detail screen shows a game's cover art, title, and metadata including region, language, genre, and year.

### Variants

If multiple versions of a game exist (different regions, languages, or releases), they appear in a carousel. Use left/right on the D-pad to switch between variants.

### Actions

| Action | Button | Condition |
|--------|--------|-----------|
| Download | A | Game not installed |
| Delete | A | Game installed |
| Favorite | Select | Toggle anytime |
| Tag Info | Y | Show region/language metadata |
| Full Filename | X | Toggle between clean title and raw filename |

### Download

Pressing A on an uninstalled game adds it to the download queue. The game begins downloading based on queue availability.

### Delete

Pressing A on an installed game opens a confirmation dialog. The dialog defaults to **Cancel** to prevent accidental deletion. Navigate to Delete and press A to confirm.

---

## Library

The Library provides a cross-system view of all your games. Access it from the Library card on the home screen.

### Tabs

Switch tabs with L2 (left) and R2 (right):

| Tab | Contents |
|-----|----------|
| All | Every game in your database |
| Installed | Only games with local files |
| Favorites | Games you have favorited |

### Sorting

Press X to cycle between sort modes:

- **Alphabetical** — A to Z by display name
- **By System** — grouped by console, then alphabetical

### Search

Press Y to open the search bar. Type to filter by game name in real time.

### Grid

Navigate the game grid with the D-pad. Adjust columns with L1/R1 (range: 3-8). Press A to open a game's detail screen.

---

## Provider Setup Guide

Providers are the sources R-Shop fetches game files from. Each console can have multiple providers. Configure them during onboarding or later via Settings > Edit Consoles.

### Web Provider

An HTTP server with directory listing enabled.

**Configuration:**

| Field | Required | Description |
|-------|----------|-------------|
| URL | Yes | Base URL of the server |
| Path | No | Subdirectory within the URL |
| Username | No | HTTP Basic Auth username |
| Password | No | HTTP Basic Auth password |

**Example:** `http://192.168.1.100/roms/nes/`

**Requirements:** The server must serve an HTML page with directory listing (clickable file links). Works with nginx autoindex, Apache directory listing, and simple HTTP file servers.

### SMB Provider (Network Share)

A Windows or Samba file share on your local network.

**Configuration:**

| Field | Required | Description |
|-------|----------|-------------|
| Host | Yes | Server IP or hostname |
| Share | Yes | Share name |
| Path | No | Subdirectory within the share |
| Username | No | Defaults to `guest` |
| Password | No | Defaults to empty |
| Domain | No | Windows domain |

**Example:** Host `192.168.1.50`, Share `games`, Path `NES`

**Note:** SMB always uses port 445. If no credentials are provided, guest access is attempted.

### FTP Provider

A standard FTP server.

**Configuration:**

| Field | Required | Description |
|-------|----------|-------------|
| Host | Yes | Server IP or hostname |
| Port | No | Defaults to 21 |
| Path | No | Remote directory (defaults to `/`) |
| Username | No | Defaults to `anonymous` |
| Password | No | Defaults to empty |

**Example:** Host `192.168.1.100`, Port `21`, Path `/roms/snes`

**Note:** Anonymous login is used when no credentials are provided. Connection timeout is 30 seconds.

### RomM Provider

Integration with a self-hosted RomM game library server.

**Configuration:**

| Field | Required | Description |
|-------|----------|-------------|
| Server URL | Yes | Your RomM instance URL |
| API Key | No* | Bearer token for API access |
| Username | No* | Basic auth username |
| Password | No* | Basic auth password |

*Provide either an API key or username/password for authentication.

**Example:** URL `https://192.168.1.100:8080`, API key `your-api-key`

**Benefits:** RomM provides organized metadata, cover art, and a structured library. Requires a running RomM instance on your network.

### Multi-Provider and Merge Mode

Each console can have multiple providers with a priority order (lower number = tried first).

**Failover (default):** Providers are tried in priority order. The first successful connection provides the game list.

**Merge Mode:** Results from all providers are combined and deduplicated by filename. Useful when different servers host different regions or versions.

---

## Downloads

R-Shop uses a queue system for managing file downloads.

### Queue Behavior

| Property | Value |
|----------|-------|
| Concurrent downloads | Up to 3 (default: 2, configurable in Settings) |
| Auto-retry | Up to 3 attempts per file |
| Retry backoff | 5s, 15s, 45s (with random jitter up to 3s) |
| Non-retryable errors | 404 Not Found, SSL errors |
| Progress updates | Every 500ms with speed (KB/s) and percentage |
| Inactivity timeout | 60 seconds of no data received |
| HTTP timeouts | 30s connection, 5 min idle |

### Persistence

The download queue survives app restarts. Active downloads resume from the queue on next launch.

### Archive Extraction

ZIP files are extracted automatically when the system has auto-extract enabled. Multi-file games (e.g. PlayStation .bin/.cue pairs) are extracted into subfolders, preserving the file structure.

7z archives are moved directly without extraction.

### Limitations

There is no pause/resume for individual downloads. Cancelling a download means it must restart from the beginning.

### Download Badge

A pulsing badge on the home screen indicates active downloads. The quick menu (Start) shows a Downloads option when the queue has items.

---

## Settings Reference

Open Settings from the quick menu (Start) on the home screen.

### Preferences

| Setting | Values | Default | Description |
|---------|--------|---------|-------------|
| Home Screen Layout | Carousel / Grid | Carousel | Display mode for the home screen |
| Controller Layout | Nintendo / Xbox / PlayStation | Nintendo | Button label and mapping scheme |
| Haptic Feedback | On / Off | On | Vibration on button presses |
| Sound Effects | On / Off | On | Audio feedback for UI actions |

### Audio

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Background Music | 0–100% | 30% | Ambient BGM volume |
| SFX Volume | 0–100% | 70% | Interface sound effects volume |

Adjust audio sliders with left/right on the D-pad (steps of 5%).

### Downloads

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Max Concurrent Downloads | 1–3 | 2 | Number of simultaneous downloads |

### Connections

| Setting | Description |
|---------|-------------|
| RomM Server | Configure global RomM server URL and authentication |

### System

| Setting | Description |
|---------|-------------|
| Edit Consoles | Add, remove, or reconfigure console systems and providers |
| Scan Library | Rescan all console folders to discover games |
| Reset Application | Factory reset: clears all settings, database, and cache |

### About

| Element | Description |
|---------|-------------|
| GitHub | Opens the R-Shop GitHub repository in the browser |
| Issues | Opens the GitHub issues page to report bugs or request features |

---

## Controls Reference

R-Shop supports gamepad controllers and keyboard input. The controller layout can be changed in Settings.

### Nintendo Layout (Default)

| Button | Action |
|--------|--------|
| A | Confirm / Select |
| B | Back / Cancel |
| X | Info / Filters / Toggle |
| Y | Search / Tags |
| D-pad | Navigate |
| L / L1 | Zoom out (more columns) |
| R / R1 | Zoom in (fewer columns) |
| ZL / L2 | Tab left (Library) |
| ZR / R2 | Favorite (alternate) |
| Start / + | Quick Menu |
| Select / - | Favorite / Export config |

### Xbox Layout

The Xbox layout swaps confirm/back and info/search compared to Nintendo:

| Button | Action |
|--------|--------|
| B (bottom) | Confirm / Select |
| A (right) | Back / Cancel |
| Y (top) | Info / Filters / Toggle |
| X (left) | Search / Tags |
| D-pad | Navigate |
| LB / RB | Zoom / Tab |
| LT / RT | Tab / Favorite |
| Start / + | Quick Menu |
| Select / - | Favorite / Export config |

### PlayStation Layout

The PlayStation layout uses symbol buttons:

| Button | Action |
|--------|--------|
| Circle | Confirm / Select |
| Cross | Back / Cancel |
| Triangle | Info / Filters / Toggle |
| Square | Search / Tags |
| D-pad | Navigate |
| L1 / R1 | Zoom / Tab |
| L2 / R2 | Tab / Favorite |
| Start / + | Quick Menu |
| Select / - | Favorite / Export config |

### Keyboard

| Key | Action |
|-----|--------|
| Arrow Keys | Navigate |
| Enter / Space | Confirm / Select |
| Escape / Backspace | Back / Cancel |
| PageUp | Zoom out (more columns) |
| PageDown | Zoom in (fewer columns) |
| I | Search |
| F | Favorite |
| [ | Tab left |
| ] | Tab right |

### Screen-Specific Controls

**Home Screen:** L1/R1 adjust grid columns. Y opens Library. X opens Settings. B shows exit dialog.

**Game List:** Y opens search. X toggles filters. L1/R1 adjust columns.

**Game Detail:** A downloads or deletes. Y shows tag info. X toggles filename display. Select favorites. Left/right switches variants.

**Library:** L2/R2 switch tabs. X cycles sort mode. Y opens search. L1/R1 adjust columns.

**Settings:** Left/right adjusts sliders and toggles. A confirms selections.

---

## Supported Systems

R-Shop supports 27 systems across 6 manufacturers. All systems support archive formats (`.zip`, `.7z`, `.rar`) in addition to their native ROM extensions.

### Nintendo

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| Nintendo Entertainment System | `nes` | 1983 | `.nes` |
| Game Boy | `gb` | 1989 | `.gb` |
| Super Nintendo | `snes` | 1990 | `.sfc`, `.smc` |
| Nintendo 64 | `n64` | 1996 | `.z64`, `.n64`, `.v64` |
| Game Boy Color | `gbc` | 1998 | `.gbc`, `.gb` |
| Game Boy Advance | `gba` | 2001 | `.gba` |
| Nintendo GameCube | `gc` | 2001 | `.rvz`, `.iso`, `.gcm`, `.ciso` |
| Nintendo DS | `nds` | 2004 | `.nds` |
| Nintendo Wii | `wii` | 2006 | `.rvz`, `.wbfs`, `.iso`, `.wia`, `.ciso` |
| Nintendo 3DS | `n3ds` | 2011 | `.3ds`, `.cia` |
| Nintendo Wii U | `wiiu` | 2012 | `.wua`, `.wud`, `.wux`, `.rpx` |
| Nintendo Switch | `switch` | 2017 | `.nsp`, `.xci` |

### Sony

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| PlayStation | `psx` | 1994 | `.chd`, `.pbp`, `.cue`, `.iso`, `.img` |
| PlayStation 2 | `ps2` | 2000 | `.iso`, `.chd`, `.cso` |
| PlayStation Portable | `psp` | 2004 | `.iso`, `.cso`, `.pbp` |
| PlayStation 3 | `ps3` | 2006 | `.iso`, `.pkg` |
| PlayStation Vita | `psvita` | 2011 | `.vpk` |
| PlayStation 4 | `ps4` | 2013 | `.pkg` |

Multi-file systems: PlayStation and PlayStation 2 support `.bin` + `.cue` pairs. When downloading archives containing multiple `.bin` files, R-Shop extracts them into a subfolder preserving the file structure.

### Sega

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| Master System | `mastersystem` | 1985 | `.sms` |
| Mega Drive | `megadrive` | 1988 | `.md`, `.gen`, `.bin`, `.smd` |
| Game Gear | `gamegear` | 1990 | `.gg` |
| Saturn | `saturn` | 1994 | `.chd`, `.cue`, `.iso` |
| Dreamcast | `dreamcast` | 1998 | `.chd`, `.cdi`, `.gdi` |

Saturn also supports `.bin` + `.cue` multi-file pairs.

### SNK

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| Neo Geo Pocket Color | `ngpc` | 1999 | `.ngc`, `.ngp` |

### Arcade

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| Arcade | `arcade` | 1978 | `.zip`, `.7z` |

### Microsoft

| System | ID | Year | ROM Extensions |
|--------|----|------|----------------|
| Xbox | `xbox` | 2001 | `.iso` |
| Xbox 360 | `xbox360` | 2005 | `.iso`, `.xex` |

---

## Troubleshooting & FAQ

### No games found

- Verify the provider URL or path is correct and accessible
- Check that the server has directory listing enabled (Web provider)
- Confirm the files have extensions matching the system (see [Supported Systems](#supported-systems))
- Check your target folder path is set correctly

### Download stuck or failing

- Check your network connection
- Downloads retry up to 3 times with increasing delays (5s, 15s, 45s)
- Failed URLs are cached for 5 minutes before retrying — wait or restart the app
- A download stalls after 60 seconds of no data received

### Can't connect to SMB share

- Verify the host IP, share name, and credentials
- Ensure port 445 is open and not blocked by a firewall
- Try with explicit username/password instead of guest access

### RomM shows no platforms

- Verify the server URL is correct and reachable
- Test the connection in the provider setup (press Y)
- Check that your API key or credentials are valid
- Ensure the RomM server has platforms configured

### Games missing after scan

- Check that file extensions match the system's supported formats
- Verify the target folder path is correct
- For archive files, ensure they contain files with valid ROM extensions

### Audio not working

- Check that Sound Effects is enabled in Settings
- Verify BGM Volume and SFX Volume sliders are above 0%
- Audio initialization may fail silently on some devices — try restarting the app

### How to reset the app

Go to Settings, then select Reset Application from the System section. This clears all settings, database entries, and cached data.

### How to export or import configuration

During onboarding (Step 6: Complete), press Select to export your configuration as a JSON file. This backup can be used to restore settings on another device.

## Legal Notice

R-Shop does not host, distribute, or link to copyrighted game files. The application is a file management tool that connects to user-configured servers and network shares.

Users must provide their own legally obtained game files. Supported sources include:

- Personal backups of cartridges and discs you own
- Homebrew games created by independent developers
- Public domain ROMs
- Legally purchased digital copies

The developers of R-Shop are not responsible for how users choose to use this software.
