> [English](CHANGELOG.md) | **繁體中文**

# 更新日誌

本專案所有重要變更都會記錄在這個檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/)。

---

## [1.6.0] — 2026-04-12

### 新增
- **Sources（來源）管理** — 統一的畫面，可新增、設定、停用與移除 RomM/SMB/FTP/Web 來源，具備主機等級的焦點處理與各系統對應設定
- **RomM 4.8 token 配對** — 透過 QR code 或手動輸入進行 Client API Token 驗證，並提供即時伺服器探測與連線驗證
- **各卡片來源圓點** — 遊戲卡片上的彩色圓點指示器，顯示哪些提供者供應該遊戲；當有 2 個以上來源時圓點會堆疊顯示
- **手動建立來源** — 類型選擇介面，可在 RomM 之外新增 SMB、FTP 或 Web 目錄來源
- **各系統對應編輯器** — 指定手動來源提供哪些系統，並以視覺化方式顯示對應數量
- **重新配對動作** — 直接從 Sources 畫面更新過期或借用的 RomM token
- **導覽選擇器** — 單一問題的歡迎流程（「你的 ROM 是怎麼存放的？」）取代舊的多步驟精靈，針對本機、網路與 RomM 使用者提供各自的設定路徑
- **ROM 資料夾選擇器** — 在導覽過程中選擇你的 ROM 基底資料夾；每一種選擇路徑都會執行本機檔案系統掃描

### 改善
- **僅合併模式** — 完全移除 failover；merge 現在是唯一的多來源策略（原本是未使用的無效程式碼，merge 在所有情況下表現更好）
- **預設啟用合併** — 新的與舊有的設定都會預設為 `mergeMode: true`，無需使用者介入
- **設定重新編排** — Sources 成為主要進入點；「Edit Consoles」更名為「Edit Systems」（唯讀，變更請前往 Sources）
- **統一的 RA 設定** — RetroAchievements 設定整合為單一輕量畫面，導覽與設定共用
- **透明的設定檔遷移** — v2 設定會在首次啟動時自動升級為 v3 格式，無需使用者操作；雙寫機制讓舊有程式碼路徑仍可運作

### 移除
- **RomM Server 磚塊** — 由功能更完整的 Sources 管理畫面取代
- **Scan Library 磚塊** — 請改用快速選單中的「Sync All」
- **Failover 模式** — merge 已能處理所有多來源情境；failover 從未在介面中開放
- **「Skip for now」導覽選項** — 會導致空白的主畫面且無法繼續下一步

### 修正
- 同步時間戳記現在會正確地從 `syncAll` 與 `syncSystem` 保存下來（先前會無聲遺失）
- 當某系統有 2 個以上的貢獻來源時自動合併提供者
- 停用來源後已安裝的遊戲仍會保持可見
- 舊有提供者已標記為受管理，讓停用／移除能真正清除它們
- 替代來源會保存於資料庫，讓多來源遊戲能撐過同步週期
- RA 畫面焦點裁切問題（內層 borderRadius 現在小於外層）

---

## [1.5.2] — 2026-04-09

### 修正
- **RomM 平台篩選器 (#11)** — `platform_ids` 查詢參數的序列化方式會被 RomM API 忽略，導致每個系統都收到跨平台混雜的整個媒體庫。加上近期 RomM 版本中較大的 RetroAchievements 中繼資料負載，這也會讓媒體庫較大的使用者在同步時卡在 0/N。篩選器現在改用重複的查詢參數（`platform_ids=1&platform_ids=2`），伺服器才會真正套用。
- **同步接收逾時** — 從 30 秒提高到 90 秒。單一 500 筆 ROM 的分頁若內嵌 RA 成就與螢幕截圖，可能達數 MB，在伺服器延遲較高時尤其明顯。

### 新增
- **遠端失敗時退回本機** — 當某系統的遠端來源（RomM/SMB/FTP/Web）失敗時，同步現在會退回為僅本機的檔案系統掃描，讓使用者不會看不到本機已存在的 ROM。已套用於全部四條同步路徑（完整同步、智慧同步、媒體庫掃描、單一系統同步）。
- **持續顯示的錯誤標籤** — 同步失敗時，左上角的狀態標籤現在會轉為紅色、輕微脈動，並持續顯示到下一次同步開始（先前是琥珀色且 6 秒後自動消失，很容易錯過）。

---

## [1.5.1] — 2026-03-16

### 改善
- **詳細畫面焦點可見度** — 焦點指示器現在改用白色邊框與光暈，而非僅使用強調色，確保不論系統主題色為何都清楚可見
- **正確的焦點追蹤** — 子元件（主要按鈕、圖示按鈕、螢幕截圖、版本卡片）只有在其所屬區塊真正取得焦點時才會顯示焦點高亮；消除多個元素同時出現的幻影焦點
- **動作按鈕固定位置** — 下載／刪除與收藏／分享／書架按鈕在橫向模式下現在固定於左欄底部，所有詳細檢視畫面皆一致
- **變體選擇器重新設計** — 精簡的標籤膠囊搭配地區旗標、長 ROM 名稱採跑馬燈捲動檔名、更寬的覆蓋層（螢幕寬度 55%）、封鎖 D-pad 左右以防止焦點外洩
- **Other Versions 區塊** — 現在只顯示 RomM/IGDB 的同系列項目，而不再重複列出變體選擇器中已可見的本機變體
- **通用 4:3 與 16:9 版面** — 在 9 個覆蓋層／對話框元件中，以螢幕相對的 `clamp()` 數值取代寫死的像素限制，避免窄螢幕溢位與寬螢幕空間浪費
- **MarqueeText 元件** — 新的共用跑馬燈捲動元件，用於版本卡片與同系列項目中的長文字；取得焦點時捲動，否則顯示靜態省略號

### 修正
- **變體選擇器焦點還原** — 在變體選擇器開啟時從下載佇列返回，現在會正確將 D-pad 焦點還原到選擇器
- **圖示按鈕取得焦點時的尺寸變化** — 移除收藏／分享／書架按鈕的文字標籤，該標籤會在 4:3 螢幕上造成多行換行
- **LanguageBadges 溢位** — 移除版本卡片上的語言旗標，該旗標會在緊湊版面中造成 RenderFlex 溢位

### 內部
- 將 `MarqueeText` 抽出到 `lib/widgets/marquee_text.dart`，供變體選擇器與同系列區塊共用
- `isSectionFocused` 參數貫穿 `ActionButtonsRow`、`ScreenshotsCarousel`、`OtherVersionsSection`
- 詳細畫面的 `_buildPrimaryActionSection` 與 `_buildIconButtonsSection` 現在會從父層接收 `isFocused`

---

## [1.5.0] — 2026-03-15

### 新增
- **具冷卻時間的智慧同步** — 應用程式啟動時改用 `syncSmart()`，會跳過上次同步時間仍在設定冷卻視窗內的系統，大幅減少頻繁啟動時的多餘網路流量
- **各系統自動同步開關** — 每台主機可透過主機設定中新增的「Auto-sync on app launch」開關個別選擇不自動同步；停用的系統只會從快速選單手動同步
- **同步冷卻時間設定** — 新的設定項目（總是／15 分鐘／30 分鐘／1 小時／2 小時／6 小時），控制每個系統自動重新同步之間的最短間隔（預設：1 小時）
- **從快速選單進行單一系統同步** — 主畫面的 Start 選單現在會針對目前選取的主機顯示「Sync [System Name]」，並附上易讀的「Synced X ago」副標題；會取消任何進行中的自動同步、同步該單一系統，然後繼續處理其餘過期的系統
- **快速選單的 Sync All** — 專屬的「Sync All」項目取代舊的「Retry Sync」選項；會強制完整同步每一個已設定的系統，不受冷卻時間限制
- **從遊戲詳細畫面移出書架** — 當遊戲已加入所有書架時，「Add to Shelf」動作會改為「Remove from Shelf」，並提供顯示所屬書架的選擇器；由篩選規則比對到的遊戲會使用排除而非移除
- **快速選單副標題** — `QuickMenuItem` 新增選用的 `subtitle` 欄位，會以較小字體顯示在標籤下方
- **ROM 檔案分享** — 遊戲詳細畫面的分享按鈕現在會透過系統分享面板分享實際的 ROM 檔案（遊戲需已安裝）；分享面板關閉後會重新進入沉浸模式

### 改善
- **設定後同步** — 從設定返回時現在只會強制同步新增的主機，而不是清除所有新鮮度並重新同步全部
- **書架選擇器對話框** — 接受自訂的 `title` 參數（用於「REMOVE FROM SHELF」與「ADD TO SHELF」的區分）
- **各系統最後同步時間保存** — `StorageService` 透過 SharedPreferences 依系統 ID 記錄最後同步時間，可撐過應用程式重新啟動
- **等待同步完成** — `LibrarySyncService.waitForCompletion()` 回傳一個在目前同步結束時解析的 Future，讓「先取消再動作」的流程更乾淨
- **遊戲詳細畫面初始焦點** — 進入詳細畫面時預設焦點落在下載／刪除按鈕

### 移除
- **設定中的各系統同步清單** — 帶有遊戲數量的各主機同步項目已從 System 分頁移除，改採更快速的快速選單同步流程
- **「Retry Sync」快速選單項目** — 由更靈活的「Sync [System]」與「Sync All」選項取代

### 內部
- `SystemConfig.autoSync` 欄位（預設 `true`），支援 JSON 序列化與 `copyWith`
- 導覽狀態中的 `ConsoleSetupState.autoSync`，透過 `OnboardingController.setAutoSync()` 串接
- app_providers.dart 中的 `SyncCooldownNotifier` / `syncCooldownProvider`，搭配循環切換的介面
- `StorageService.getLastSyncTime()` / `setLastSyncTime()`，以 ISO 8601 格式保存各系統資料
- `LibrarySyncService.syncSmart()`，具備冷卻時間、forceSystemIds 與 autoSync 篩選
- `LibrarySyncService._syncCompleter`，供 syncAll、syncSmart、syncSystem 共用的 `waitForCompletion()`
- HomeView 中的 `_resumeAutoSyncAfterManual` 旗標，用於「取消→手動→恢復」流程
- library_sync_service_test.dart 與 settings_widgets_test.dart 新增 143 行測試（總計 1666 行）

### 修正
- **模糊背景外溢** — 遊戲詳細畫面封面背景的 `ImageFiltered` 模糊效果會超出元件邊界繪製；已用 `ClipRect` 包住，避免模糊影像從底部邊緣滲出

---

## [1.4.2] — 2026-03-09

### 新增
- **各系統同步** — 可從設定同步個別主機，而不必一次全部同步（感謝 @yangeric，#7）
- **各系統 ROM 數量** — 設定現在會為每一台已設定的主機顯示遊戲數量徽章 (#7)
- **可設定的同步逾時** — 針對較慢的連線（Synology NAS 等）可選擇 1、2、5 或 10 分鐘 (#7)
- **遊戲數量 provider** — `gameCountsPerSystemProvider`，提供同步後穩定的 ROM 數量 (#6)

### 修正
- **封面搜尋進度超過 100%** — 連續執行「Search Game Covers」不再累加計數器；以世代為基礎的取消機制確保狀態乾淨（感謝 @yangeric，#8）
- **資料庫串聯刪除** — 刪除遊戲時現在也會移除孤立的 `game_metadata` 與 `ra_matches` 資料列
- **背景重新整理的孤立資料安全性** — `saveGames` 的孤立資料刪除現在改為明確指定（`deleteOrphans` 參數），避免不完整的抓取清空已快取的遊戲

### 內部
- `LibrarySyncService.syncSystem()`，用於單一系統同步
- `syncTimeoutProvider`，在設定中提供循環切換的介面
- `CoverPreloadService._generation` 計數器，用於防護過時的工作程序
- 新增 78 個測試（總計 1615 個），涵蓋封面重設、資料庫串聯、同步逾時、各系統同步

---

## [1.4.1] — 2026-03-07

### 修正
- **ZIP 安裝狀態不一致** — 遊戲詳細畫面現在會正確地對存在於 ROM 資料夾中的封存檔（.zip、.rar）顯示「Installed」，與遊戲清單的徽章一致（感謝 @yangeric，#5）
- **ZIP 刪除** — 刪除以 .zip 封存形式保留的遊戲現在能正常運作，而不會無聲失敗
- **autoExtract 設定被忽略** — 各系統的自動解壓縮開關現在會被遵守；關閉時，下載的 .zip 檔案會原樣移動到 ROM 資料夾，而不是無條件解壓縮
- **RomM 分頁逾時** — 大型媒體庫（每個平台 7000 個以上的 ROM）不再逾時；每頁的錯誤處理會在失敗時回傳部分結果而非完全沒有結果（感謝 @yangeric，#4）
- **提供者逾時區隔** — RomM 的分頁抓取取得專屬的 10 分鐘逾時；FTP/SMB/Web 維持較緊的 60 秒安全網
- **不穩定的測試** — `clearFilters resets all` 在完整測試套件負載下不再間歇性失敗

---

## [1.4.0] — 2026-03-06

### 修正
- **3DS 副檔名支援** — 新增 .cci、.cxi 與 .app ROM 格式（感謝 @yangeric，#1）
- **RomM Switch 下載** — 由 RomM 以 ZIP 封存形式提供的遊戲，現在會透過解析 Content-Disposition 標頭正確偵測並解壓縮（感謝 @gulasch，#2）
- **刪除後的過時遊戲快取** — 已刪除的遊戲現在會立即從遊戲集合中消失，而不是殘留到下次背景重新整理

### 改善
- **主畫面輪播效能** — AnimatedBuilder 現在包住個別項目而非整個 PageView，減少不必要的重建
- **遊戲清單效能** — 收藏 provider 改用選擇性監看，避免無關的收藏變動觸發重建
- **可見系統查詢** — 單一批次的 `systemsWithCache()` 查詢取代 N 次個別的 `hasCache()` 呼叫
- **同步錯誤回報** — 失敗的來源現在會依系統追蹤並附上具體的錯誤訊息（顯示「2 sources unavailable」而非籠統的「Offline — cached data」）
- **媒體庫畫面** — `setEquals` 防護可避免已安裝檔案未變動時的不必要重建
- **縮圖遷移** — 批次大小由 3 提高到 15（ThumbnailService 本身已有容量防護）
- **記憶體** — `gameMetadataProvider` 現在使用 `.autoDispose`，在詳細畫面關閉時釋放中繼資料

### 內部
- `DatabaseService.deleteGame()`，用於針對性移除快取項目
- `DatabaseService.systemsWithCache()`，用於批次檢查系統是否存在
- `LibrarySyncState.failedSystems` 以各系統的失敗對應表取代單一的 `error` 字串
- 170 個以上的新資料庫 upsert 測試（封面保留、孤立資料清理、跨系統隔離、大批次）
- 更新導覽與同步測試以配合 remoteSetup 步驟與 failedSystems 格式

---

## [1.3.0] — 2026-03-01

### 新增
- **主機商店風格的遊戲詳細畫面** — 重新設計的詳細畫面，具備結構化版面、區塊標題與參考數位商店的下載區域
- **IGDB 中繼資料** — RomM 遊戲現在會透過玻璃擬態的「About This Game」卡片顯示類型、開發商、發行年份、遊戲模式與簡介（取自 RomM 的 IGDB 資料）
- **簡介覆蓋層** — 有中繼資料時，可從快速選單開啟完整的遊戲簡介
- **變體選擇器覆蓋層** — 在多版本遊戲上按 A 會開啟專屬選擇器，顯示所有變體、安裝狀態，以及各變體的下載／刪除動作
- **遊戲中繼資料資料庫** — 新的 `game_metadata` 資料表（資料庫 v8）將 IGDB 中繼資料與遊戲項目分開儲存，可撐過媒體庫重新同步

### 改善
- **快速選單整合** — Tags、Description、檔名切換與 Achievements 現在改由快速選單存取，不再使用專屬按鈕捷徑
- **詳細畫面版面** — 直向模式使用可捲動版面並採用自適應的封面長寬比；橫向模式使用雙欄版面搭配可展開的資訊卡
- **下載動作按鈕** — 重新設計為獨立元件，具備明確的狀態（下載、刪除、已安裝、加入中、無法使用）與變體數量徽章

### 內部
- `GameMetadataInfo` 模型，具備 `hasContent`、`genreList`、`averageRating` 輔助方法
- `gameMetadataProvider`（`FutureProvider.family`），用於非同步載入中繼資料
- `RommRom` 擴充為可解析 `summary`、`genres`、`companies`、`first_release_date`、`game_modes`、`average_rating`
- `RommProvider.fetchGames()` 以射後不理的副作用方式儲存中繼資料
- 194 個新的 API 服務測試，涵蓋中繼資料解析的邊界情況

---

## [1.2.0] — 2026-02-27

### 新增
- **RetroAchievements 整合** — 連接你的 RA 帳號以追蹤成就、透過雜湊比對驗證 ROM，並直接在 R-Shop 中檢視各遊戲進度
- **成就畫面** — 專屬檢視器，含已取得／未解鎖徽章、點數、進度條、精通狀態與完整 D-pad 導覽
- **RA 導覽步驟** — 首次執行精靈中的選用設定，附連線測試與略過選項
- **RA 設定畫面** — 從設定管理憑證（透過 SecureStorage 加密），並可測試連線
- **下載後雜湊驗證** — 下載完成的 ROM 會在背景自動計算雜湊並與 RA 資料庫比對
- **RA 同步服務** — 三階段背景同步（目錄抓取 → 名稱比對 → 雜湊驗證），具 24 小時新鮮度快取與取消支援
- **遊戲卡片上的 RA 徽章** — 每張卡片都會顯示成就數量與比對類型（名稱比對為金色，雜湊驗證為綠色）；完全完成時顯示精通外框
- **加入佇列提示** — 遊戲加入下載佇列時，右下角會出現動畫通知
- **隱藏空的主機** — 設定 → Preferences 中的新開關，可從主畫面隱藏沒有遊戲的系統

### 改善
- **同步徽章** — 現在會顯示媒體庫同步（青色）與 RA 同步（金色）兩個膠囊，各自獨立追蹤進度
- **遊戲詳細畫面** — 中繼資料下方新增 RA 資訊區塊，顯示比對狀態、進度條與「View Achievements」按鈕；快速選單新增「Achievements」選項
- **下載覆蓋層** — 視覺調整與更好的狀態顯示
- **SystemModel** — 15 個以上的系統現在帶有 RA 主機 ID（NES、SNES、N64、GB、GBC、GBA、Mega Drive、SMS、Game Gear、32X、Atari 2600/7800、Lynx、NDS）
- **媒體庫畫面** — 當同一款遊戲存在多種格式時，會對已安裝項目去重複
- **封面預先載入服務** — 提升可靠性與錯誤處理

### 內部
- 資料庫結構描述 v7 — 新資料表：`ra_games`（目錄快取）、`ra_hashes`（雜湊索引）、`ra_matches`（比對結果）
- 10 個以上系統的雜湊計算：單純 MD5、NES（去除 iNES 標頭）、SNES（copier 標頭）、NDS（多區段）、Lynx、Atari 7800
- `RaNameMatcher` 具備四層退回機制：完全相符 → 包含 → No-Intro 檔名 → 模糊比對（Levenshtein）
- 新的 provider：`raGameProgressProvider`、`raRefreshSignalProvider`、`raMatchResultProvider`、`raSyncServiceProvider`
- 1,209 個測試（由 1,069 個增加）— 新套件：RA 雜湊服務、RA 模型、RA 名稱比對器、擴充的資料庫與導覽測試

---

## [1.1.0] — 2026-02-27

### 新增
- **原生 SMB** — 以 Kotlin MethodChannel 服務（`SmbService.kt`）取代 smb_connect 函式庫，在 Android 上支援資料夾下載、進度回報與可靠的逾時處理
- **資料夾下載** — 以多檔案目錄形式儲存的遊戲（bin/cue、m3u）現在可透過 SMB 與 FTP 以完整資料夾下載
- **遊戲手把按鍵圖示** — SVG 圖示組（Xbox、PlayStation、Nintendo Switch），用於情境感知的控制器提示
- **RomM 設定畫面** — 完整的伺服器管理（新增／編輯／移除）與連線測試，可直接從設定進入
- **網路常數** — 集中的逾時數值（`NetworkTimeouts`），供所有提供者共用
- **檔案工具** — 防當機的原子式檔案移動（`moveFile`），具備暫存與清理機制

### 改善
- **導覽流程改版** — 重新設計的設定精靈，簡化主機設定、本機資料夾偵測與 RomM 整合
- **FTP 提供者** — 主機驗證（主機名稱、IPv4、IPv6）、注入防護、可設定的逾時
- **Web 提供者** — 強化安全性的目錄解析（過濾路徑穿越、控制字元、過長的 href）
- **下載服務** — SMB 與 FTP 通訊協定支援資料夾感知下載，並提供各檔案進度
- **友善的錯誤訊息** — 擴充面向使用者的錯誤對應，涵蓋網路、驗證與提供者失敗
- **Console HUD／Quick Menu／Control Button** — 簡化算繪並整合遊戲手把圖示

### 內部
- 1,069 個測試（由 970 個增加）— 新套件：SMB 提供者（14）、FTP 提供者（8）、Web 提供者（12）、FocusSyncManager（32）、OverlayPriorityManager（14）、file_utils（5）、friendly_error 擴充
- 移除 `smb_connect` 相依套件（由原生 Kotlin 實作取代）
- `NativeSmbService` Dart 包裝層，對應 `com.retro.rshop/smb` MethodChannel
- `NativeSmbDownloadHandle` / `NativeSmbFolderDownloadHandle` 下載控制代碼型別

---

## [1.0.0] — 2026-02-26

### 亮點
- **穩定版釋出** — R-Shop 脫離 beta
- **SVG 平台圖示** — 全部 29 個系統圖示由 PNG 遷移為銳利的 SVG 格式
- **Android 套件重構** — 由 `com.example.r_shop` 遷移至 `com.retro.rshop`
- **網路安全性設定** — 針對本機網路通訊協定的專屬 XML 設定

### 改善
- **測試涵蓋率** — 950 個以上的測試，涵蓋控制器、服務、模型與工具程式
- **程式碼品質** — 零 TODO/FIXME 標記、零無聲攔截、所有錯誤路徑皆有記錄
- **相依套件整潔度** — 所有相依套件皆固定到確切版本

### 內部
- 新測試套件：GameListController（43 個測試）、GameMergeHelper（12 個測試）、ImageHelper（19 個測試）
- 另外 8 個測試檔案，涵蓋 app config、音訊管理器、設定解析器、導覽流程、provider 與封面預先載入

---

## [0.9.9] Beta — 2026-02-25

### 新增
- **Custom Shelves（自訂書架）** — 建立個人遊戲收藏，可手動整理、使用篩選規則（依系統、地區、語言）或混合模式；支援重新排序、重新命名與各書架的排序模式
- **Device Info Service** — 自適應的記憶體分層（低／標準／高 RAM），會自動調整影像快取大小、格線快取範圍與封面預先載入池，以配合低階掌機
- **Shelf Picker Dialog** — 從媒體庫與遊戲詳細畫面快速將遊戲加入書架
- **System Selector Overlay** — 以視覺化的系統徽章依系統篩選媒體庫檢視

### 改善
- **設定畫面重構** — 拆分為 Preferences、System 與 About 分頁，並抽出 `DeviceInfoCard` 元件（1048→604 行）
- **下載覆蓋層重構** — 抽出 7 個元件至 `lib/widgets/download/`（DownloadItemCard、CoverThumbnail、PulsingDot、LowSpaceWarning、StatusLabel、DownloadProgressBar、DownloadActionButton）（1477→793 行）
- **書架編輯畫面重構** — 將 GameListOverlay、TextInputDialog 抽出到共用元件庫（1108→631 行）
- **RomM 導覽流程重構** — 抽出 RommConnectView、RommSelectView、RommFolderView、RommActionButton（1405→122 行）；狀態類別移至 `onboarding_state.dart`（1713→1362 行）
- **媒體庫畫面重構** — 抽出 ReorderableCardWrapper、LibraryEntry 為專屬元件（1490→1386 行）
- **相依套件版本固定** — 其餘 16 個使用 caret 範圍的相依套件全部固定為確切解析版本，以確保建置可重現

### 內部
- 新模型：`CustomShelf`、`ShelfFilterRule`，具備 JSON 序列化
- 新 provider：`CustomShelvesNotifier` / `customShelvesProvider`，用於書架的 CRUD
- `DeviceInfoService`，具備 `MemoryTier` 分類
- 約 20 個新測試檔案，涵蓋下載佇列管理器、統一遊戲服務、媒體庫同步、縮圖服務、自訂書架、資料庫服務、設定儲存、影像快取、儲存服務與元件測試

---

## [0.9.8] Beta — 2026-02-23

### 新增
- **當機記錄服務** — 本機環形緩衝記錄檔（約 500KB）會捕捉所有未攔截的錯誤，附上時間戳記與堆疊追蹤；儲存在應用程式快取中並跨工作階段保留
- **匯出錯誤記錄** — 新的設定項目（位於 System 下），可透過系統分享面板分享當機記錄以便回報問題；僅在記錄有資料時顯示
- **硬碟空間預先檢查** — 當裝置儲存空間低於 1 GB 時，下載會被拒絕並顯示明確的錯誤

### 改善
- **HTTP 下載遞迴深度防護** — `_downloadHttp` 的續傳重啟路徑現在強制單次重試上限，避免伺服器持續回傳不符的內容長度時造成無限遞迴
- **FocusSyncManager 索引安全性** — `ensureFocusNodes()` 會在剪除已釋放的節點後夾制 `_selectedIndex`；`validateState()` 會在欄數變動時夾制 `_targetColumn` — 避免快速調整格線大小時焦點跳到無效位置
- **Zone 對齊** — `WidgetsFlutterBinding.ensureInitialized()` 與 `runApp()` 現在在同一個 `runZonedGuarded` zone 中執行，消除啟動時的「Zone mismatch」警告
- **覆蓋層優先權釋放** — 所有 scope 類別（`OverlayFocusScope`、`DialogFocusScope`、`SearchFocusScope`、`ExitConfirmationOverlay`）都在 `dispose()` 中透過 `Future()` 延後執行 `release()`，修正 Riverpod 的「cannot modify provider during widget tree build」當機
- **詳細畫面版面** — 系統名稱徽章以 `Flexible` 包裝並設定省略號溢位，修正系統名稱較長（例如「PlayStation 2」）時在窄螢幕上的 `RenderFlex` 溢位
- **ConfigModeScreen dispose** — 音訊管理器改在 `initState` 中快取，避免在元件釋放後才呼叫 `ref.read()`
- **下載佇列查詢** — `getDownloadById()` 改用簡單迴圈取代 `firstWhere` + try/catch，消除佇列還原期間吵雜的「Bad state: No element」記錄洗版

### 修正
- **覆蓋層優先權當機** — 在元件卸載期間釋放覆蓋層 token 不再拋出 Riverpod 狀態修改錯誤（先前會導致「At least listener of the StateNotifier threw an exception」當機）
- **FocusSyncManager 焦點遺失** — 項目數量減少後，選取索引可能指向已釋放的 `FocusNode`，造成無聲的焦點失效

### 內部
- 新的 `CrashLogService` 單例（`lib/services/crash_log_service.dart`），提供 `log()`、`logError()`、`getLogFile()`、`clearLog()`、`getLogContent()`
- `app_providers.dart` 中的 `crashLogServiceProvider`，在 `main.dart` 中覆寫
- 全域錯誤處理器（`FlutterError.onError`、`PlatformDispatcher.onError`、`runZonedGuarded`）現在除了 `debugPrint` 之外也會寫入當機記錄
- 移除 `FocusSyncManager._enforceFocus()` 中針對延後焦點的吵雜 `debugPrint`（每次捲動都會觸發）

---

## [0.9.7] Beta — 2026-02-22

### 新增
- **縮圖流程** — 常駐的 isolate 縮圖產生器（400px JPEG），在啟動時進行背景遷移，並在媒體庫掃描期間主動預先載入封面
- **ROM 狀態 provider** — 透過檔案系統監看器與下載完成監聽器即時追蹤 ROM 安裝狀態，取代手動輪詢
- **已安裝檔案 provider** — 集中式的 isolate 掃描索引，涵蓋所有系統中全部已安裝的 ROM 檔案
- **封面預先載入** — 新的設定項目，可為所有遊戲批次產生縮圖
- **關於區塊** — 設定中的應用程式版本、GitHub/Issues 連結與彩蛋標語
- **Zip 解壓縮上限** — 由 2 GB 提高到 8 GB

### 改善
- **智慧封面載入** — 縮圖優先顯示，搭配 magic byte 驗證、對損毀快取項目重新編碼為 JPEG，以及捲動時抑制載入以減少快速捲動時的卡頓
- **控制器按鈕樣式** — 膠囊形狀的肩鍵／扳機鍵、各配置對應的面板按鍵顏色（Xbox 綠／紅／藍／黃、PlayStation 配色），以及 Nintendo +/− 按鍵的形狀繪製器
- **快速選單提示** — 面板按鍵提示現在會顯示符合配置的配色
- **遊戲卡片效能** — 以靜態的 `Transform.scale`／`Container` 取代 `AnimatedScale`／`AnimatedContainer`，讓格線捲動更順暢；`SelectionAwareItem` 使用 `ValueNotifier`，在選取變更時只重建受影響的卡片
- **搜尋覆蓋層** — 抽出 `SearchableScreenMixin`（由 GameListScreen 與 LibraryScreen 共用），並將 `SearchOverlay` 元件從 `features/game_list/widgets/` 移到 `widgets/` 以便跨畫面重用
- **FocusSyncManager** 由 `features/game_list/logic/` 移至 `core/input/`，供 Library 與 Scan 畫面使用
- **媒體庫畫面** — 現在使用 `SearchableScreenMixin`、`SelectionAwareItem`、`FocusSyncManager` 與捲動抑制，行為與 GameListScreen 一致
- **影像快取速率限制器** — 可取消的待處理請求、提高並行抓取上限（50），以及主機層級的速率限制偵測
- **資料庫結構描述 v4** — 新增 `thumb_hash` 與 `has_thumbnail` 欄位；縮圖旗標會在遊戲清單重新整理後保留
- **`OverlayGuardedAction`** — 通用且可重用的守護動作，取代各畫面各自的私有動作類別

### 修正
- **Zip bomb 防護** — 解壓縮後的封存大小上限為 2 GB；超過上限時會中止解壓縮並顯示明確錯誤
- **Web 提供者路徑穿越** — 目錄清單解析器會拒絕絕對 URL 與 `../` 的 href 值
- **覆蓋層優先權拆解** — `OverlayFocusScope`、`DialogFocusScope` 與 `SearchFocusScope` 改用 `addPostFrameCallback` 搭配 try/catch，取代原始的 `Future()`，避免快速切換畫面時發生「disposed notifier」當機
- **停用 Android 備份** — `android:allowBackup="false"` 可避免非預期的資料還原破壞應用程式狀態
- **格線導覽防護** — `_GridNavigateAction` 現在會在 `isEnabled` 中檢查 `overlayPriorityProvider`，避免覆蓋層開啟時仍能用 D-pad 導覽
- **焦點還原** — `mainFocusRequestProvider` 現在集中在 `ConsoleScreenMixin.initState` 中設定

### 內部
- 新相依套件：`image: ^4.3.0`、`crypto: ^3.0.6`
- 新增 `GameItem.hasThumbnail` 欄位；`copyWith` 相應擴充
- `adjustColumnCount()` 輔助方法抽出至 `ConsoleScreenMixin`
- 刪除 4 個過時檔案：`animated_background.dart`、`radial_glow.dart`、`folder_analysis_view.dart`、`search_overlay.dart`（game_list 副本）

---

## [0.9.6] Beta — 2026-02-21

### 新增
- **Scan Library** 畫面 — 設定項目會開啟帶動畫的主機格線，顯示各系統掃描進度、遊戲數量徽章與完成摘要
- **智慧導覽自動偵測** — 會在常見路徑（`/storage/emulated/0/ROMs`、`/Roms`、`/roms`）偵測既有的 ROM 資料夾，並提供掃描、建立、選取或略過等選項
- **快取優先的遊戲清單載入** — 清單會先從 SQLite 快取即時載入，再無聲地從遠端提供者重新整理；只有在清單真的變動時才更新介面（以檔名比對差異）
- **離線指示器** — 同步失敗時顯示琥珀色的「Offline — cached data」提示；同步徽章會顯示失敗狀態
- **提供者重新排序** — 可在主機設定面板中用 D-pad 或方向按鈕調整提供者優先順序
- **Test & Save** — 單一按鈕即可測試提供者連線並在成功時自動儲存（取代獨立的 Save 按鈕）
- **使用者指南**（`docs/USER_GUIDE.md`）— 完整指南，涵蓋所有功能、操作方式、支援的系統與疑難排解

### 改善
- **ROM 格式涵蓋範圍** 擴充至 10 個以上的系統 — GameCube（ISO/GCM/CISO）、Wii（WBFS/WIA/CISO）、PS2（CSO）、PS3（PKG）、PSP（PBP）、Mega Drive（BIN/SMD）、Dreamcast（CDI/GDI）、Saturn（ISO）、Arcade（7z）、N64（V64）、SNES（SMC）
- **以 isolate 進行本機掃描** — 檔案系統掃描透過 `compute()` 移交給 Dart isolate，讓介面更順暢
- **媒體庫同步新鮮度** — 5 分鐘快取可避免多餘的重新同步；`clearFreshness()` 會在設定變更後強制重新整理
- **同步涵蓋僅本機的系統** — `syncAll()` 現在也包含沒有遠端提供者的系統
- **批次化的安裝狀態檢查** — 以每批 20 個的方式平行處理
- **篩選器直通** — 沒有地區／語言中繼資料的遊戲現在會通過篩選器，而不會被排除
- **主機格線徽章** — 僅本機的系統會顯示藍色資料夾徽章，而非綠色的提供者勾選標記
- **設定後重新同步** — 從設定返回後會重新載入設定並清除新鮮度
- **媒體庫已安裝偵測** — 能正確比對已解壓縮的 ROM 檔案（例如 `Game.zip` → `Game.iso`）
- **以媒體庫為基礎的搜尋** — 在主畫面按 Y 會導向 Library 並開啟搜尋，取代獨立的全域搜尋覆蓋層

### 修正
- **GameDetail 變體索引** 已夾制在有效範圍內（避免變體清單變動時當機）
- **搜尋覆蓋層** 焦點處理改善

### 內部
- 移除 `GlobalSearchOverlay`（675 行）— 由帶 `openSearch: true` 的 Library 取代
- 移除 `RepoManager` 與 `RomHeaderParser`
- 從 `pubspec.yaml` 移除 `archive` 相依套件
- 抽出 `GameMergeHelper` 處理去重複邏輯（遠端與本機合併、封存展開、多檔案偵測）
- `SystemModel` 新增 `archiveExtensions`、`allRomExtensions`、`allGameExtensions` 與 `isGameFile()`
- 從 `app_providers`、`config_providers`、`download_providers` 清理未使用的 provider
- `LibrarySyncService` 擴充 `discoverAll()`、`isFresh()`、`hadFailures` 狀態

---

## [0.9.5] Beta — 2026-02-20

### 新增
- **媒體庫畫面** — 統一的跨系統遊戲瀏覽器，具備 All/Installed/Favorites 分頁、搜尋、排序模式（A-Z／依系統）與可調整的格線縮放（LB/RB）
- **背景媒體庫同步** — 啟動時自動同步提供者，並在主畫面顯示即時進度徽章
- **Quick Menu**（Start/+ 按鈕）— 情境覆蓋層，提供搜尋、設定、縮放與下載的捷徑
- **主畫面格線版面** — 可在主畫面切換輪播與格線檢視；格線欄數可用 LB/RB 調整
- **ROM 標頭解析器** — 從 GB、GBC、GBA、NDS 與 SNES 的 ROM 標頭擷取內部遊戲標題（原始檔 + ZIP）
- **收藏切換**（Select/- 按鈕）— 從遊戲詳細畫面快速收藏
- **分頁切換**（LB/RB）— 在 Library 與篩選覆蓋層中切換篩選分頁
- **僅本機篩選** — 篩選覆蓋層中的新開關，僅顯示已安裝在本機的 ROM

### 改善
- **BaseGameCard** 取代舊的遊戲卡片 — 統一設計，含系統徽章、已安裝指示、收藏愛心、變體數量與提供者標籤
- **版本卡片** 簡化 — 大幅重構，移除多餘的版面邏輯
- **ConsoleHud** 重構 — 更乾淨的插槽算繪、一致的間距、正確區分嵌入式與定位式模式
- **篩選覆蓋層** — 改善版面，加入僅本機開關與多層篩選
- **全域搜尋** — 結果現在會一致地顯示提供者標籤與地區旗標
- **控制器配置** 偏好設定可跨工作階段保留
- **主畫面版面** 偏好設定（輪播／格線）可跨工作階段保留

### 修正
- **下載覆蓋層 HUD 位置** — 按鍵圖例卡在左上角而非右下角（AnimatedOpacity 包住 Positioned 破壞了 Stack 版面）
- **Quick Menu 下載選項** 現在只要佇列中有任何項目（包含已完成／失敗）就會顯示，而非僅限進行中與排隊中
- 收藏名稱遷移會在應用程式啟動時清理舊有的 ID
- **多檔案 ROM 的媒體庫項目重複** — 遠端封存合併現在會將解壓縮後的資料夾名稱加入去重複集合（bin/cue 遊戲不再出現兩次）
- **子目錄中的 ROM 未被偵測** — `scanLocalGames`、`exists` 與 `delete` 現在會針對所有 ROM 副檔名檢查子目錄，而非僅限多檔案格式

### 內部
- 新的 `QuickMenuOverlay` 元件，具備覆蓋層優先權與控制器感知的捷徑提示
- `AdjustColumnsIntent` 整合各畫面的縮放控制
- `ToggleOverlayAction` 改用 `onToggle` 回呼，而非發布狀態請求
- `SyncBadge` 元件，用於即時顯示同步進度
- `LibrarySyncService` 改為 `StateNotifier<LibrarySyncState>`
- app_providers 中的 `homeLayoutProvider`、`homeGridColumnsProvider`、`controllerLayoutProvider`

---

## [0.9.4] Beta — 2026-02-20

> [!WARNING]
> **遷移須知：** 由 `<= 0.9.3` 版本升級到 `0.9.4` 或更新版本時，因為後端資料庫與設定架構有重大變更，需要**全新安裝**。舊有的設定無法乾淨地轉移過來。

### 新增
- 啟用全域搜尋（主畫面，Y 按鈕）— 跨系統搜尋，含地區旗標與標籤徽章
- 僅本機模式 — 沒有提供者的主機會顯示本機掃描到的 ROM 檔案，並附上橫幅提示
- FTP 下載進度 — 即時回報每個區塊的進度，不再停在 0%
- 下載閒置監控 — 60 秒停滯偵測並顯示明確的錯誤訊息
- 遊戲手把按鍵修正 — 攔截某些遊戲手把驅動程式（AYN Thor 等）在按鍵放開／重複時送出的不符邏輯按鍵
- 版本卡片上的提供者類型徽章（RomM、SMB、FTP、WEB）
- 下載覆蓋層分區清單（Downloading／Queued／Complete 標題），具備以 ID 穩定的焦點與自動捲動
- 佇列清空時下載覆蓋層自動關閉
- SMB 網域驗證欄位
- `ProviderConfig.validate()` 與 `shortLabel` 輔助方法
- `showConsoleNotification()` — 全應用程式共用的主題化浮動 SnackBar
- `getUserFriendlyError()` — 將原始例外對應為可讀的訊息

### 改善
- RomM 設定畫面改版 — 焦點感知的光暈邊框、可用 D-pad 導覽的欄位、以提示形式呈現的連線測試、各主機同步狀態與批次「Update stale」動作
- 設定畫面 — 重新啟用 RomM Server 項目、並行下載元件加上箭頭符號、Reset App 移到 HUD 的 X 按鈕
- 主畫面空狀態會顯示帶有設定／離開動作的 HUD 列；載入狀態為黑色畫面（不會閃爍）
- 遊戲詳細載入時顯示遊戲名稱與系統配色的載入圈
- 遊戲清單標題顯示目標資料夾路徑與僅本機橫幅
- 遊戲格線提供情境相關的空狀態（搜尋無結果、篩選無結果、僅本機為空、連線錯誤）
- 平台圖示已壓縮（檔案大小約縮小 70%）
- 所有動作捷徑改用 `includeRepeats: false`（按住按鍵不再重複觸發；D-pad 保留重複）
- `OverlayFocusScope` / `DialogFocusScope` — `_hasClaimed` 旗標可避免重複釋放覆蓋層優先權
- RomM 封面退回鏈（CDN → small → large → 第一張螢幕截圖）
- `UnifiedGameService` 的提供者呼叫包裹在 30 秒逾時中
- `RommApiService` / `WebProvider` — 連線 15 秒／接收 30 秒逾時
- README 更新，加入支援系統表格與「Building from Source」章節

### 修正
- **Zip Slip 漏洞** — Android 的 ZIP 解壓縮會在寫入前驗證正規化路徑
- **路徑穿越** — `DownloadService` 與 `RomManager` 中的 `_safePath` 都改用 `p.basename()`
- **原子式設定寫入** — `ConfigStorageService.saveConfig` 先寫入 `.tmp` 再重新命名
- **資料庫初始化競爭條件** — `DatabaseService` 改用單一的 `static Future<Database>?` 防護
- **AudioManager BGM 重新初始化迴圈** — `_hasAttemptedReinit` 旗標可避免遞迴重試
- **重試計時器洩漏** — `DownloadQueueManager` 會追蹤 `Timer` 實例，並在 dispose 時取消
- **FailedUrlsCache 無上限成長** — 以 `Map<String, DateTime>` + 5 分鐘 TTL 取代 `Set<String>`
- **刪除對話框預設為 CANCEL**（選取索引為 1，而非 0）
- FTP 下載取消現在會中斷 FTP 連線
- `totalBytes` 夾制 — 將 `<= 0` 視為未知，讓進度條能正確運作
- 全域搜尋的 `providerConfig` 傳遞 — 結果會以正確的提供者開啟
- `RepoManager` 的 Dio 連線洩漏 — 在 `finally` 區塊中呼叫 `dio.close()`
- `GameDetailController` / `GameListController` — 釋放防護可避免在 dispose 後呼叫 `notifyListeners()`
- 在全域搜尋的文字欄位中按 Escape/B 會將焦點移到結果，而不是關閉搜尋
- 搜尋覆蓋層的左右方向鍵在編輯時不再外洩到格線

### 內部
- `DownloadItem` 完全不可變（所有欄位皆為 `final`），並序列化 `systemId` + `providerConfig`
- `DatabaseService` 結構描述 v3（新增 `provider_config` 欄位並含遷移）
- `gamepad_key_fix.dart` 在應用程式啟動時透過 `main()` 安裝
- 下載覆蓋層重構為 `_buildSectionedList` / `_buildCard` / `_buildSectionHeader` 輔助方法

---

## [0.9.3] Beta — 2026-02-19

### 新增
- RomM 導覽精靈 — 引導式的首次執行設定，含連線測試、平台自動探索與資料夾指派
- 遊戲清單篩選覆蓋層（X 按鈕）— 依地區與語言篩選 ROM，並依主機分別保存
- 全域搜尋覆蓋層基礎架構（跨系統搜尋，已串接但觸發功能停用至 v0.9.4）
- Android 前景服務 — 下載可在背景繼續，並顯示常駐通知
- 下載佇列保存 — 排隊中與發生錯誤的下載可撐過應用程式重新啟動
- 自動下載重試搭配指數退避（3 次嘗試，5 秒／15 秒／45 秒）
- 設定中可調整的並行下載上限（1–3）
- RomM 設定畫面，可編輯伺服器網址、API key 與憑證
- 本機資料夾掃描器與模糊系統 ID 比對器，用於導覽時的資料夾指派

### 改善
- RomM 的 ROM 清單抓取現在改為分頁（每頁 500 筆，大型媒體庫不再逾時）
- RomM 平台 API 同時接受 `items` 與 `results` 回應鍵（支援多版本）
- 下載覆蓋層的動作按鈕具備情境感知（取消／重試／清除）
- 篩選與搜尋在遊戲清單中互斥
- 導覽的主機設定不再要求必須有提供者（只設定目標資料夾也有效）

### 修正
- RomM 的 ROM 抓取使用了格式錯誤的 `platform_ids` 查詢參數
- 下載覆蓋層對已完成的項目顯示「Retry」
- 篩選器啟用時，遊戲格線傳入的是未經篩選的變體清單
- 系統清單重新整理後，主畫面輪播索引會跳動

### 內部
- 新增 `flutter_foreground_task` 相依套件
- Android manifest：前景服務、通知與電池最佳化權限
- 抽出 `FilterState` / `ActiveFilters` 模型；導覽控制器新增 `RommSetupState`
- `DownloadQueueManager` 現在接受 `StorageService`；`GameDetailController` 接受 `DownloadQueueManager`
- `local_folder_matcher_test.dart` 單元測試

---

## [0.9.2] Beta — 2026-02-18

### 新增
- 遊戲卡片上針對已下載 ROM 的已安裝指示 LED 燈條
- 供導覽與設定模式畫面共用的 `ConsoleSetupHud` 元件
- `ConsoleHud` 以插槽為基礎的 API（`a`、`b`、`x`、`y`、`start`、`select`、`dpad`），取代原始的按鍵清單
- `ConsoleFocusable` 透過 `Scrollable.ensureVisible` 在取得焦點時自動捲動

### 改善
- 導覽流程改版 — 簡化流程，並為提供者測試／儲存動作加入防護檢查
- 輸入系統：全域 Actions 現在改用 `isEnabled()` 進行覆蓋層檢查，取代內嵌的防護判斷
- `NavigateAction` 冷卻時間（100 毫秒）可避免按住 DPAD 時的連續快速導覽
- `OverlayFocusScope` 在單一操作中同時取得優先權並請求焦點
- 焦點狀態還原改用 `getFocusState()` 公開 API，而非直接存取 `StateNotifier.state`
- `ConfigModeScreen` 簡化，與導覽流程共用 HUD 邏輯

### 修正
- 移除 `ConsoleFocusable` 的 `tick()` 回饋，修正按住 DPAD 產生重複導覽的問題
- `ConsoleFocusable.didUpdateWidget` 能正確處理焦點節點的替換
- `ExitConfirmationOverlay` 的覆蓋層優先權生命週期（在 `initState` 設定、在 `dispose` 重設）

### 內部
- 移除 `GameSourceService`（由統一的提供者系統取代）
- `SystemModel` 重構以支援多來源的提供者設定
- `FocusScopeObserver` 與 `OverlayScope` 清理

---

## [0.9.1] Beta — 2026-02-17

### 新增
- 多來源提供者系統 — 每台主機都可使用 Web、SMB、FTP 或 RomM 來源
- RomM 伺服器整合，透過 IGDB 自動比對平台
- 以 JSON 為基礎的設定系統，支援匯入／匯出
- 設定中的設定編輯器，可在導覽流程後新增／移除／編輯主機
- 統一遊戲服務，支援跨多來源的 merge 與 failover 策略
- 互動式導覽精靈，可逐台主機設定

### 改善
- 所有可取得焦點的元件都支援滑鼠／觸控（點擊即可取得焦點並啟動）
- 音量滑桿現在會回應拖曳與輕點輸入
- 主畫面只顯示已設定的主機
- 所有 HUD 按鈕與動作類別都加入輸入去抖動（避免重複觸發動作與重複音效）

### 修正
- 將 `romPath` 更名為 `targetFolder`，以解決下載系統中的路徑混淆
- 下載佇列可向後相容舊有的 JSON 格式
- 簡化應用程式啟動邏輯（不再需要對 romPath/repoUrl 進行 null 檢查）
- 「Reset App」現在會完整清除所有偏好設定、SQLite 快取與影像快取

### 內部
- 新相依套件：`smb_connect`、`ftpconnect`、`share_plus`
- provider 重新整理：`config_providers.dart`、`game_providers.dart`
- `GameItem` 現在帶有 `providerConfig`，以支援需驗證的下載

---

## [0.9.0] Beta — 首次發行

- 主機風格的介面，完整支援控制器
- 下載佇列，具備即時進度與自動解壓縮（ZIP/7z）
- 透過 libretro-thumbnails 自動取得封面圖
- 針對大型媒體庫（5000 筆以上）的積極快取
- 跨所有系統的即時搜尋
- 支援 17 個系統（Nintendo、Sony、SEGA）
