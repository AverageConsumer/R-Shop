# R-Shop 規格書（`main-zh`）

> **基準分支：`main-zh`**（領先 upstream `main` 26 個 commit）
> Flutter 專案名：`retro_eshop` ｜ Android 套件名：`com.retro.rshop.tw`
> 版本：`1.7.0-zh+13` ｜ Dart SDK `>=3.0.0 <4.0.0` ｜ Material 3
> 目標裝置：Android 復古掌機（Anbernic / Retroid Pocket / AYN Odin 等）與 Android TV
> 支援平台目錄：`android` / `ios` / `linux` / `macos` / `windows` / `web`（實際維護以 Android 為主）

> **相關文件**：[../ARCHITECTURE.md](../ARCHITECTURE.md)（高階概覽，1 張圖）｜[ARCHITECTURE.md](ARCHITECTURE.md)（深度架構，Mermaid 圖集）｜[../docs/USER_GUIDE.md](USER_GUIDE.md)（25KB 使用手冊）

---

## 0. 分支說明與既有文件校正

### 0.1 `main-zh` vs `main`

| 項目 | `main`（上游） | `main-zh`（本分支） |
|------|---------------|---------------------|
| `applicationId` / `namespace` | `com.retro.rshop` | `com.retro.rshop.tw` |
| Kotlin 原始碼路徑 | `.../kotlin/com/retro/rshop/` | `.../kotlin/com/retro/rshop/tw/` |
| `pubspec.yaml` version | `1.7.x` | `1.7.0-zh+13` |
| App 顯示名稱 | R-Shop | **R-Shop-zh** |
| APK 檔名 | 預設 | `R-Shop-v{versionName}.apk` |
| 語系 | 多語，繁中不完整 | `lib/l10n/app_zh.arb` 統一為 `zh` locale（原有 `zh` 與 `zh-TW` 混用問題已修正）；新增 `app_localizations_zh.dart`（1582 行） |

**`main-zh` 的實質功能增補**：

| 新增 / 變更 | 位置 | 說明 |
|-------------|------|------|
| **`ConsoleDialog`** | `lib/widgets/console_dialog.dart`（252 行，新檔） | 手把最佳化對話框元件，統一焦點高亮樣式（白框 + 紅底） |
| Onboarding 流程改版 | `lib/features/onboarding/`（5 檔大幅修改） | 歡迎選擇步驟、RA 引導、RomM 登入畫面重構 |
| B 鍵離開確認 | `onboarding_screen.dart` | 手把 B 鍵觸發離開確認對話框 |
| Select 鍵映射匯入設定 | `onboarding_screen.dart` | 手把 Select 鍵 → 匯入設定檔 |
| 焦點高亮統一 | `lib/core/widgets/console_focusable.dart` | 全 App 統一白框 + 紅底選取樣式 |
| 返回鈕與標題統一 | `pairing` / `sources` 畫面 | 返回箭頭位置與標題樣式一致化 |
| 語系切換修正 | — | 修正相似語言代碼（`zh` 與 `zh-TW`）切換失效問題 |
| APK 部署任務 | `android/` gradle | 自動複製改名後的 APK 至 `D:\test-apk` |

> **合併回上游注意**：與 ImageOverlay 相同，`.tw` 套件路徑重命名會讓 Kotlin 檔案在 `git diff` 中全檔標記變更。Dart 側沒有改名，回推較容易。

### 0.2 既有 [../ARCHITECTURE.md](../ARCHITECTURE.md) 的已知偏差

| 記載 | 實際 | 狀態 |
|------|------|------|
| `FocusSyncManager` 位於 `lib/core/focus/` | `lib/core/focus/` 不存在；實為 `lib/core/input/focus_sync_manager.dart` | ✅ **已修正**（2026-07-30） |
| 檔案連結為 `file:///c:/Users/Mini-PC/StudioProjects/...` | 實際路徑為 `D:\ThorAPK\StudioProjects\` | ✅ **已改為相對路徑** |
| 版本 v1.7.0 | `main-zh` 為 `1.7.0-zh+13` | ✅ **已更新** |
| `GlobalInputWrapper` 位於 `lib/core/input/` | 正確（`lib/core/input/global_input_wrapper.dart`） | — 無誤 |
| 「66 種主機字典」 | `system_model.dart` 實際有 **67 個 `SystemModel(` 建構** | ⚠️ **待核實**：可能含 1 個非主機項目，或已新增 1 種未更新描述 |

---

## 1. 產品定位

**控制器優先（Controller-First）**的復古遊戲庫管理器與下載前端，視覺風格模仿 Nintendo eShop。

核心命題：把散落在**本地儲存、RomM 伺服器、SMB 網路共享、FTP 伺服器、Web 目錄**的 ROM，統一成一個可用手把完整操作的遊戲庫。

**設計約束**：
| 約束 | 說明 |
|------|------|
| 無觸控可用 | 所有選單、列表、設定、對話框都必須能純靠 D-pad + 手把按鍵操作 |
| 小記憶體裝置 | 掌機記憶體有限，大量高畫質封面需防 OOM |
| 背景下載不中斷 | 下載與解壓縮須靠 Android 前台服務保活 |
| 離線可用 | 已下載的遊戲庫與元資料存於本地 SQLite |

---

## 2. 分層結構

```
lib/
├── main.dart              入口：Riverpod scope、主題、i18n、全域輸入監聽
├── core/                  基礎設施（22 檔）
│   ├── input/             ★ 手把焦點系統（11 檔，1980 行）
│   ├── widgets/           console_focusable.dart（564 行）等通用元件
│   ├── responsive/        breakpoints / spacing / typography
│   ├── theme/             app_theme.dart
│   └── util/              色彩對比、來源配色
├── features/              功能頁面（8 個模組）
│   ├── home/  game_list/  game_detail/  library/
│   ├── onboarding/  pairing/  sources/  settings/
├── models/                資料模型（11 檔）
│   ├── system_model.dart  ★ 906 行，主機字典
│   └── config/            app_config / provider_config / source / system_config
├── providers/             Riverpod 狀態（9 檔，1426 行）
├── services/              ★ 業務服務（43 檔，最大層）
├── widgets/               全域共用 UI（18 + download 9 檔）
├── utils/                 工具函式（8 檔）
└── l10n/                  7 種語言 .arb + 產生的 dart

android/app/src/main/kotlin/com/retro/rshop/tw/
├── MainActivity.kt        Platform Channels（zip / storage / smb）
└── SmbService.kt          smbj 原生 SMB 存取
```

### 2.1 各層檔案規模（找程式碼的參考）

| 層 | 檔案數 | 最大單檔 |
|----|--------|----------|
| `services/` | 43 | `download_service.dart` 1245、`database_service.dart` 1066、`download_queue_manager.dart` 694、`library_sync_service.dart` 630 |
| `features/` | 約 90 | 依模組分散 |
| `core/` | 22 | `console_focusable.dart` 564、`focus_sync_manager.dart` 393 |
| `models/` | 11 | `system_model.dart` 906、`provider_config.dart` 335、`source.dart` 313 |
| `providers/` | 9 | `app_providers.dart` 460 |
| `widgets/` | 27 | — |

---

## 3. 多來源抽象層（本專案的核心設計）

### 3.1 兩個型別系統的區別（易混淆，務必分清）

```dart
// lib/models/config/source.dart
enum SourceType { romm, smb, ftp, web, local }   // 5 種 — 使用者看到的「來源」

// lib/models/config/provider_config.dart
enum ProviderType { web, smb, ftp, romm }        // 4 種 — 可抽象化的「取得管道」
```

> ⚠️ **`local` 沒有對應的 `ProviderType`** —— 本地來源**不走 `SourceProvider` 抽象**，而是由 `rom_folder_service.dart` / `local_folder_matcher.dart` 直接掃描檔案系統。新增來源型別時要留意這個不對稱。

**`SourceTypeX.supportsAutoMap`**：只有 `romm` 為 `true`。
- RomM 能自報平台清單 → 不需逐主機設定路徑
- 其他來源（smb/ftp/web/local）**必須**為每個主機建立 `SystemSourceMapping`，系統才知道內容在哪

### 3.2 `SourceProvider` 抽象介面

```dart
abstract class SourceProvider {
  ProviderConfig get config;
  Future<List<GameItem>> fetchGames(SystemConfig system);
  Future<DownloadHandle> resolveDownload(GameItem game);
  Future<SourceConnectionResult> testConnection();
  String get displayLabel;
}
```

實作（`lib/services/providers/`）：

| 實作 | 行數 | 協定 |
|------|------|------|
| `WebProvider` | 256 | HTTP 目錄索引解析（dio） |
| `SmbProvider` | 164 | 委派給原生 `NativeSmbService`（smbj） |
| `FtpProvider` | 299 | `ftpconnect` |
| `RommProvider` | 167 | RomM REST API（委派 `RommApiService` 442 行） |

`ProviderFactory.getProvider(config)` 依 `ProviderType` 建立實例。
**注意**：`SmbProvider` 需要 `ProviderFactory.init(smbService:)` 先注入 `NativeSmbService`，否則 `_smbService!` 會拋 null assertion。

### 3.3 `SourceResolver`（全靜態工具類）

負責把「使用者設定的 `Source`」解析成「可用的 `ProviderConfig` 清單」：

| 方法 | 用途 |
|------|------|
| `providersFor(...)` | 針對某主機解析出所有可用 provider 設定 |
| `sourcesFor(...)` | 反查 provider 對應的 Source |
| `_typeMatches(SourceType, ProviderType)` | 跨兩個列舉的型別對映 |
| `_connectionMatches(Source, ProviderConfig)` | 連線參數比對（判斷是否同一台伺服器） |
| `_toProviderConfig(...)` | Source → ProviderConfig 轉換 |
| `_joinUrl(base, segment)` | URL 拼接 |

> 一個主機可能有多個來源同時提供 → 這是下載失敗時「自動切換替代來源」（§4.3）的基礎。

### 3.4 RomM 認證

`AuthConfig` 支援 `user`/`pass`/`apiKey`/`domain`。**RomM 4.8+ 的 Client API Token（Bearer）優先於帳密**。

配對方式（`lib/features/pairing/`，3 檔）：
- QR Code 掃描（`mobile_scanner` 5.2.3，支援相機與相簿圖片）
- 手動輸入（`manual_pairing_screen.dart`，`main-zh` 有 218 行修改）
- mDNS 區網自動發現（`network_discovery_service.dart` 136 行）

---

## 4. 下載系統

### 4.1 狀態機

```dart
enum DownloadStatus {
  queued, downloading, extracting, moving, completed, cancelled, error;
  bool get isTerminal => this == completed || this == cancelled || this == error;
}
```

`DownloadItem` 欄位：`id`、`game`、`system`、`targetFolder`、`autoExtract`、`addedAt`、`status`、`progress`、`receivedBytes`、`totalBytes`、`downloadSpeed`、`error`、`retryCount`。

### 4.2 佇列管理（`DownloadQueueManager`，`ChangeNotifier`）

| 常數 / 設定 | 值 |
|-------------|-----|
| `_maxRetries` | 3 |
| `_maxQueueSize` | 100 |
| `maxConcurrent` | 預設 **2**，可由設定調整（`setMaxConcurrent()`，有 clamp） |

**關鍵行為**：
- `_processQueue()` 依 `availableSlots = maxConcurrent - activeCount` 啟動新任務
- `_isRetryableError()` 判斷是否可重試；`_scheduleRetry()` 帶 **jitter**（`_jitterRandom`）避免同時重試打爆伺服器
- **`_switchToAlternativeSource()`** — 重試耗盡後，自動改用同主機的其他來源（§3.3 的價值所在）
- `_generateId(game, system)` 產生穩定 ID → 可去重
- `_persistQueue()` / `restoreQueue()` — 佇列持久化，App 重啟後可續傳
- `_throttledNotificationUpdate()` — 節流通知更新，避免高頻 UI 重繪
- `_stopForegroundServiceIfIdle()` — 佇列空閒時停止前台服務省電
- `_safeNotify()` — 包裝 `notifyListeners()` 防止 dispose 後呼叫

### 4.3 下載執行（`DownloadService`，1245 行）

支援斷點續傳與 HTTP / FTP / SMB 串流讀寫，並與 Android 前台服務（`flutter_foreground_task` 9.2.0）同步進度。
`DownloadHandle`（78 行）為各 provider 回傳的統一下載句柄。

### 4.4 解壓縮

下載完成且 `autoExtract` 為 true 時，透過 Platform Channel 交給 Android 原生解壓（見 §6）。

---

## 5. 手把焦點系統（`lib/core/input/`，11 檔 1980 行）

這是「控制器優先」的實作核心，也是本專案最需要理解才敢改的部分。

| 檔案 | 行數 | 職責 |
|------|------|------|
| `focus_sync_manager.dart` | 393 | **焦點同步管理器**，確保無觸控環境下焦點不遺失、不跳錯 |
| `overlay_scope.dart` | 307 | 對話框 / 覆蓋層的焦點範圍隔離 |
| `app_actions.dart` | 300 | 全域動作定義（Flutter `Actions`） |
| `searchable_screen_mixin.dart` | 280 | 可搜尋畫面的通用行為 |
| `console_screen_mixin.dart` | 239 | 主機風格畫面的通用行為 |
| `input_providers.dart` | 181 | 輸入相關 Riverpod provider |
| `global_input_wrapper.dart` | 90 | 攔截 D-pad / 手把 / 鍵盤事件並轉發 |
| `focus_scope_observer.dart` | 82 | 焦點範圍變化觀察 |
| `gamepad_key_fix.dart` | 52 | **手把按鍵相容性修補**（不同手把 keycode 差異） |
| `app_intents.dart` | 46 | Flutter `Intent` 定義 |
| `input.dart` | 10 | barrel export |

搭配 `lib/core/widgets/console_focusable.dart`（**564 行**）—— 可聚焦元件的視覺與行為封裝。

> **`main-zh` 統一了焦點高亮樣式為「白框 + 紅底」**，並新增 `ConsoleDialog`（`lib/widgets/console_dialog.dart` 252 行）解決對話框在手把下的焦點問題。改動焦點樣式時請同時檢查 `console_focusable.dart` 與 `console_dialog.dart`，避免兩處不一致。
>
> 已修過的坑：`ConsoleDialog` 需要包 `Material` widget，否則文字出現黃色底線（Flutter 預設 debug 樣式）。

---

## 6. Android 原生橋接

`MainActivity.kt` 註冊 5 個 channel：

| Channel | 型別 | 用途 |
|---------|------|------|
| `com.retro.rshop.tw/zip` | MethodChannel | 解壓縮 |
| `com.retro.rshop.tw/zip_progress` | EventChannel | 解壓進度串流 |
| `com.retro.rshop.tw/storage` | MethodChannel | 儲存權限與路徑 |
| `com.retro.rshop.tw/smb` | MethodChannel | SMB 操作 |
| `com.retro.rshop.tw/smb_progress` | EventChannel | SMB 傳輸進度串流 |

> ⚠️ **Channel 名稱含 applicationId 前綴 `com.retro.rshop.tw`** —— 這代表 `main` 與 `main-zh` 的 channel 名稱**不同**。若要合併分支，channel 字串必須同步修改 Kotlin 與 Dart 兩側（`native_smb_service.dart` 141 行）。

`SmbService.kt` 使用 `smbj` 0.13.0 處理 SMB2/SMB3 認證、檔案列舉與串流傳輸。

---

## 7. 資料層

### 7.1 SQLite（`DatabaseService`，1066 行）

儲存遊戲元資料、來源設定、下載歷史、成就資料。`sqflite` 2.4.2。

相關服務：
- `library_sync_service.dart`（630 行）— 遊戲庫同步
- `unified_game_service.dart`（94 行）— 統一遊戲查詢入口
- `config_storage_service.dart`（196 行）+ `config_parser.dart`（106）+ `config_bootstrap.dart`（10）— 設定檔匯入匯出
- `storage_service.dart`（528 行）— `SharedPreferences` 層設定

### 7.2 主機字典（`system_model.dart`，906 行）

約 66–67 種經典主機（NES / SNES / N64 / Game Boy / PS1 / PSP…），每筆含 platform ID、顯示名稱、副檔名清單、預設目錄映射。

配套：`romm_platform_matcher.dart`（128 行）把 RomM 的平台名稱對映到本地 `SystemModel`。

### 7.3 封面與快取（防 OOM 的關鍵）

| 服務 | 行數 | 職責 |
|------|------|------|
| `thumbnail_service.dart` | 388 | 縮圖產生與管理 |
| `cover_preload_service.dart` | 363 | 封面預載 |
| `thumbnail_index_service.dart` | 316 | 縮圖索引 |
| `image_cache_service.dart` | 248 | 記憶體 / 磁碟雙層快取 |
| `thumbnail_migration_service.dart` | 59 | 舊版縮圖遷移 |

搭配 `cached_network_image` 3.4.1 + `flutter_cache_manager` 3.4.1。

### 7.4 RetroAchievements 整合

| 服務 | 行數 | 職責 |
|------|------|------|
| `ra_api_service.dart` | 328 | RA 官方 REST API |
| `ra_sync_service.dart` | 355 | 成就同步與比對 |
| `ra_hash_service.dart` | 223 | ROM 雜湊計算（RA 專用演算法，非單純 MD5） |

模型：`ra_models.dart`（233 行）。

---

## 8. 狀態管理（Riverpod 2.6.1）

9 個 provider 檔案，共 1426 行：

| 檔案 | 行數 | 範圍 |
|------|------|------|
| `app_providers.dart` | 460 | 全域設定、主題、語系 |
| `game_providers.dart` | 197 | 遊戲清單與查詢 |
| `download_providers.dart` | 166 | 下載佇列狀態 |
| `source_health_providers.dart` | 147 | 來源連線健康度 |
| `ra_providers.dart` | 114 | RetroAchievements |
| `rom_status_providers.dart` | 113 | ROM 安裝狀態 |
| `shelf_providers.dart` | 108 | 自訂書架（`custom_shelf.dart` 174 行） |
| `installed_files_provider.dart` | 90 | 已安裝檔案 |
| `library_providers.dart` | 31 | 遊戲庫 |

> 混合模式注意：`DownloadQueueManager` 是 **`ChangeNotifier`**（非 Riverpod `Notifier`），`SourcesNotifier`（498 行）亦然。新增狀態時請確認要沿用哪種模式，避免第三種寫法。

---

## 9. 依賴清單（`pubspec.yaml`）

| 分類 | 套件 | 版本 |
|------|------|------|
| 狀態管理 | `flutter_riverpod` | 2.6.1 |
| 網路 | `dio` | 5.9.1 |
| HTML 解析 | `html` | 0.15.6 |
| FTP | `ftpconnect` | 2.0.10 |
| 資料庫 | `sqflite` | 2.4.2 |
| 安全儲存 | `flutter_secure_storage` | 9.2.4 |
| 一般儲存 | `shared_preferences` | 2.5.4 |
| 音效 | `flutter_soloud` | 2.1.7 |
| 前台服務 | `flutter_foreground_task` | 9.2.0 |
| QR 掃描 | `mobile_scanner` | 5.2.3 |
| 圖片快取 | `cached_network_image` / `flutter_cache_manager` | 3.4.1 / 3.4.1 |
| 圖片處理 | `image` | 4.3.0 |
| 壓縮 | `archive` | 3.6.1 |
| 雜湊 | `crypto` | 3.0.7 |
| 字型 | `google_fonts` | 6.3.3 |
| SVG | `flutter_svg` | 2.0.17 |
| 其他 | `path_provider` 2.1.5、`permission_handler` 11.4.0、`file_picker` 8.3.7、`share_plus` 10.1.4、`url_launcher` 6.3.2、`package_info_plus` 8.3.1、`confetti` 0.8.0、`intl` 0.20.2 | |
| 原生（Kotlin） | `smbj` | 0.13.0 |

---

## 10. 多語系

7 種語言 `.arb`：`en`（基準）、`de`、`es`、`fr`、`ja`、`pt`、`zh`。
設定於 `l10n.yaml`，產生 `lib/l10n/app_localizations*.dart`（**產生檔已納入 git**，改 `.arb` 後需重新產生並一併提交）。

> `main-zh` 把繁中統一到 `zh` locale（原有 `zh` 與 `zh-TW` 並存造成切換失效）。`app_localizations_zh.dart` 為 1582 行。
> 用語請依 [GLOBAL_DEV_NOTES.md](../../GLOBAL_DEV_NOTES.md) 的台灣在地化詞彙表。

---

## 11. 音效與觸覺

- `audio_manager.dart`（396 行）+ `flutter_soloud` — 主機選單風格音效，資產於 `assets/sounds/`
- `haptic_service.dart`（59 行）、`feedback_service.dart`（61 行）
- `sound_settings.dart`（39 行）— 音效設定模型
- `input_debouncer.dart`（76 行）— 輸入防抖（手把連續輸入去重）

---

## 12. 已知問題與待辦

| 項目 | 現況 | 位置 |
|------|------|------|
| Channel 名稱含 applicationId | `main` 與 `main-zh` channel 名稱不同，合併時易漏 | `MainActivity.kt` + `native_smb_service.dart` |
| `local` 型別不對稱 | `SourceType.local` 無對應 `ProviderType`，不走抽象層 | `source.dart` / `provider_config.dart` |
| `ProviderFactory` null assertion | `SmbProvider` 依賴 `_smbService!`，未 `init()` 就會崩 | `provider_factory.dart:20` |
| 兩種狀態管理模式並存 | Riverpod + `ChangeNotifier`（`DownloadQueueManager`、`SourcesNotifier`） | `services/` |
| 大型單檔 | `download_service` 1245、`database_service` 1066、`system_model` 906、`download_queue_manager` 694 | `services/` `models/` |
| 測試覆蓋 | `test/` 僅 `native_smb_service_test.dart` 一檔 | `test/` |
| 主機數量表述 | 文件稱 66 種，程式碼有 67 個建構 | `system_model.dart` |
| 多平台目錄未維護 | ios / linux / macos / windows / web 目錄存在但未實際支援 | 專案根 |

---

## 13. 修改功能的定位指引

| 想改的東西 | 動這些檔案 |
|-----------|-----------|
| **新增一種來源型別** | ① `models/config/source.dart` 加 `SourceType` ② `provider_config.dart` 加 `ProviderType` ③ `services/providers/` 新增實作 `SourceProvider` ④ `provider_factory.dart` 加 case ⑤ `source_resolver.dart` 的 `_typeMatches` / `_toProviderConfig` ⑥ `features/sources/` UI ⑦ 若不支援自動對映，確認 `supportsAutoMap` 為 false |
| **新增主機（平台）** | `models/system_model.dart` 加 `SystemModel(...)` → `romm_platform_matcher.dart` 補 RomM 平台名對映 → 確認副檔名與預設目錄 |
| **調整下載併發／重試** | `download_queue_manager.dart` 的 `_maxRetries` / `_maxQueueSize` / `maxConcurrent` 預設值 + `_isRetryableError()` + `_scheduleRetry()` jitter |
| **改下載傳輸邏輯（續傳、串流）** | `download_service.dart`（1245 行）+ 對應 provider 的 `resolveDownload()` + `download_handle.dart` |
| **改自動切換替代來源行為** | `download_queue_manager.dart` 的 `_switchToAlternativeSource()` + `source_resolver.dart` 的 `providersFor()` |
| **改手把按鍵行為** | `core/input/app_actions.dart`（動作）+ `app_intents.dart`（意圖）+ `global_input_wrapper.dart`（攔截）；手把相容問題看 `gamepad_key_fix.dart` |
| **改焦點高亮樣式** | `core/widgets/console_focusable.dart` **與** `widgets/console_dialog.dart`（兩處都要，否則不一致） |
| **新增對話框** | 用 `widgets/console_dialog.dart`（`main-zh` 新增），勿自行 `showDialog` —— 否則手把焦點會失效。記得包 `Material` |
| **改焦點同步／不跳焦點問題** | `core/input/focus_sync_manager.dart`（393 行）+ `overlay_scope.dart`（覆蓋層隔離）+ `focus_scope_observer.dart` |
| **改資料庫 schema** | `services/database_service.dart`（1066 行）—— 注意 migration 路徑 |
| **改封面載入／解 OOM** | `image_cache_service.dart` + `cover_preload_service.dart` + `thumbnail_service.dart` + `thumbnail_index_service.dart` |
| **改 RetroAchievements 比對** | `ra_hash_service.dart`（雜湊演算法，RA 有特殊規則）→ `ra_api_service.dart` → `ra_sync_service.dart` |
| **改 RomM API** | `romm_api_service.dart`（442 行）+ `romm_provider.dart` + `romm_pairing_service.dart`（370 行） |
| **改原生解壓／SMB** | `android/.../MainActivity.kt`（channel handler）+ `SmbService.kt`；Dart 側 `native_smb_service.dart` |
| **新增設定項** | `models/config/app_config.dart` → `storage_service.dart` 讀寫 → `providers/app_providers.dart` → `features/settings/` UI |
| **改音效** | `audio_manager.dart` + `models/sound_settings.dart` + `assets/sounds/` |
| **多語系文案** | `lib/l10n/app_*.arb`（**改完要重新產生 `app_localizations*.dart` 並提交**）；用語依 [GLOBAL_DEV_NOTES.md](../../GLOBAL_DEV_NOTES.md) |
| **改 onboarding 流程** | `features/onboarding/onboarding_screen.dart` + `widgets/`（11 檔，`main-zh` 大幅改過） |
| **改版本／套件名／APK 命名** | `pubspec.yaml`（version）+ `android/app/build.gradle.kts`（namespace / applicationId / outputFileName） |
