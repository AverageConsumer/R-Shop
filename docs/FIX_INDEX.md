# R-Shop 解決方案索引

> **導覽**：先讀共用的 [GLOBAL_DEV_NOTES.md](../../GLOBAL_DEV_NOTES.md)（建置工具鏈、分支政策、紀錄格式），
> 再依需要讀本專案 `docs/` 的其餘各份：
> - [ARCHITECTURE.md](ARCHITECTURE.md) — 模組分層與依賴方向
> - [FIX_LOGS.md](FIX_LOGS.md) — 修復與功能紀錄（細節、取捨、教訓）
> - [HANDOVER.md](HANDOVER.md) — **還沒做完的事、等實機確認的事**。「繼續任務」先讀這份
> - [FIX_BY_FILE.md](FIX_BY_FILE.md) — **反查表：我要改這個檔，它身上以前發生過什麼**（自動產生）
> - [SPEC.md](SPEC.md) — 規格；**§12 定位指引回答「我要改 X，該動哪些檔」**
>
> 會重複的作法收在 [`.agents/skills/`](../.agents/skills/)：
> `rshop-build-deploy`（建置的三個陷阱）· `rshop-touch-and-gamepad`（**動 UI 之前一定先讀**）·
> `rshop-source-routing`（來源／路由／備援的四條不變式）· `rshop-l10n`。
> - [USER_GUIDE.md](USER_GUIDE.md) — 使用手冊


> 關鍵字對應 [FIX_LOGS.md](FIX_LOGS.md) 的 `## [關鍵字]` 標題，**必須逐字一致**。
> **不要在這裡寫死條目總數**——多個工作階段會同時追加，寫死的數字必定過時。
> 要對帳就跑 `grep -c '^## \[' docs/FIX_LOGS.md`。

## 🔌 來源與連線

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **R-Shop 連線路由** ✨ | 同一台伺服器的遠端與區網兩條路，切的是位址不是來源。**每條路各自存一份清單**（schema v14） | `lib/models/config/source.dart`（`SourceEndpoint`／`resolveEndpoint`／`withLiveEndpoint`）· `lib/services/sources_notifier.dart`（路由增刪改） · `lib/services/endpoint_probe_service.dart` · `lib/services/database_service.dart`（v14 migration、`saveGamesByRoute`、`getGamesForRoutes`） · `lib/services/source_resolver.dart` · `lib/models/config/provider_config.dart`（`endpointId`） · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/endpoint_edit_screen.dart` |
| **R-Shop 目前來源** ✨ | 兩個來源都啟用時會**兩個都抓再合併**，使用者無從得知在看哪一個 | `lib/models/config/app_config.dart`（`activeSourceId`） · `lib/services/source_resolver.dart`（`providersFor(activeSourceId:)`） · `lib/services/sources_notifier.dart`（`setActiveSource`） · `lib/features/home/home_view.dart`（標題列、L2/R2 切換） · `lib/features/settings/sources_screen.dart`（徽章） |
| **R-Shop 來源備援** ✨ | 移除群組與連線路線，改採多組備援鏈與自動選擇 (Auto-Select) 探測模式。**備援來源可獨立顯示與切換** | `lib/models/config/source.dart`（`fallbackSourceIds`／`fallbackAutoSelect`） · `lib/services/source_failover.dart`（多組探測與併發 auto-select） · `lib/services/sources_notifier.dart`（備援鏈管理） · `lib/features/sources/fallback_picker_overlay.dart` |
| **R-Shop 代理全域無縫同步與PR15提交** ✨ | 代理設定異動全域無縫同步，強化 `isFallback` 嚴格校驗，字串統一更名為代理，並成功提交 PR #15 | `lib/providers/app_providers.dart` · `lib/services/source_failover.dart` · `lib/features/settings/sources_screen.dart` · `lib/widgets/sync_badge.dart` |
| **R-Shop Multi-Fallback實機驗證完成** ✨ | 多組備援與連線方式 UI 實機操作驗證全數通過，包含開關眼睛、打勾使用中、自動選擇探測與高對比白邊框 | `lib/features/settings/sources_screen.dart` · `lib/features/sources/fallback_picker_overlay.dart` · `docs/HANDOVER.md` |
| **R-Shop 備援新建取消返回** | 從備援設定點「新建全新備援來源」後，取消或完成建立皆能復原/更新備援設定浮層而不致退回來源主清單 | `lib/features/settings/sources_screen.dart`（`_addingFallbackForSourceId`） · `test/widgets/sources_screen_test.dart` |
| **同步不知道是哪一台** | 徽章只寫進度不寫來源；連線方式只能新增不能刪；提示用的是「同一台伺服器」這種**使用者判斷不了**的判準 | `lib/providers/app_providers.dart`（`syncingSourceProvider`，標題列與徽章共用） · `lib/widgets/sync_badge.dart`（`_withSource`） · `lib/features/home/home_view.dart`（`_resolveSyncTarget` 抽出，**修掉自動同步沒走備援解析的漏洞**） · `lib/features/sources/endpoint_picker_overlay.dart`（`[X]` 刪 `[Y]` 改） |
| **備援接進同步** | 同步前先探測，連不上就換備援。**重建的是記憶體中的 config，磁碟不動**——所以偏好的來源會自己回來 | `lib/services/source_failover.dart`（`withEffectiveSource`／`resolveForSync`） · `lib/features/home/home_view.dart`（`_syncAll` 注入、`_fallbackInUse`、標題列橘色） · `lib/services/endpoint_probe_service.dart`（`_probeableEndpoints` 修復：**endpoints 為空時原本會靜默判定不可達**，而不可達正是觸發備援的條件） |
| **連線方式共用憑證** ⚠️ | `auth` 掛在 `Source`，**路由沒有自己的憑證**。同一台伺服器的多位址共用一個 token 沒問題；**指向另一台會送錯 token 回 401，而錯誤看起來像伺服器掛了**。兩台不同伺服器要用「兩個來源 + 備援」 | `lib/models/config/source.dart`（`endpoints` 註解說明假設） · `lib/features/sources/endpoint_picker_overlay.dart`（提示） · `lib/l10n/app_*.arb`（`sources_routeSameServerHint`） |
| **R-Shop 路線各自驗證** ✨ | 同一台伺服器的多個位址**各自需要登入**，但清單只有一份。`SourceEndpoint` 有自己的 `auth`，`Source.auth` 改為 getter；schema **v15** 唯一鍵拿掉 `endpoint_id`，v14 重複列去重 | `lib/models/config/source.dart` · `lib/services/sources_notifier.dart` · `lib/services/database_service.dart`（v15 遷移、`getGameCountsPerSource`／`deleteSourceCache`） · `test/database_service_v15_migration_test.dart` |
| **R-Shop 自動選最優路線** ✨ | 探測改回**延遲並排序**，沒有覆寫就挑最快的；`pin` 語意改為「使用者覆寫」。浮層顯示延遲與自動會選誰，編輯頁補上路線自己的登入欄位（留空＝沿用來源的） | `lib/services/endpoint_probe_service.dart`（`ProbeResults`／`probeFor`） · `lib/models/config/source.dart`（`resolveEndpoint` 改吃排序清單） · `lib/services/sources_notifier.dart`（`autoSelectEndpoint`／`clearEndpointOverride`／bootstrap 離線對齊） · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/endpoint_edit_screen.dart` · `lib/l10n/app_*.arb` · `test/widgets/endpoint_picker_overlay_test.dart` |
| **R-Shop 自動選最快** ⚠️ | 自動探測延遲挑最快的路線 —— 當初判定不做，**結論已被推翻並做掉了**，見 `R-Shop 自動選最優路線`。前提錯在把路線之間當成來源之間。不要照這條 | 無程式碼變更（需求判定） |
| **AppID 衝突** | `applicationId` 與原廠主線一致，無法共存 | `android/app/build.gradle.kts` · Kotlin package 重構 |
| **R-Shop Channel 名稱硬編** | 5 個 channel 名稱含 `applicationId`，Kotlin＋Dart 各自硬編共 20 處。**危險在靜默半合併** | `lib/services/platform_channels.dart`（新增，單一前綴） · `android/app/src/main/kotlin/.../MainActivity.kt`（`BuildConfig.APPLICATION_ID`） · `android/app/build.gradle.kts`（`buildFeatures.buildConfig = true`） · `native_smb_service` / `download_service` / `disk_space_service` / `device_info_service` |
| **R-Shop ProviderFactory 隱式初始化** | 文件稱「未 init 就崩」，查證後**生產不可達**，是契約缺陷 | `lib/services/provider_factory.dart`（具名 `StateError` + `@visibleForTesting reset()`） |

## 🎮 輸入與焦點

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **使用中與顯示分家** ⚠️ | ① `??=` 種值表達不了「刻意是 null」，取消要按兩次。② **使用中**（同步＋預設顯示，`primarySourceId`）與**顯示**（主畫面 L2/R2，`activeSourceId`）拆成兩件事；同步改讀 primary。舊設定檔靠 `?? activeSourceId` 回填，無遷移。③ 兩個都放進來源清單：**眼睛＝開／關（`L1`，就是 `enabled`）、打勾＝使用中（`[X]`）**，兩個功能不共用圖示。**曾經多做一個 `Source.showOnHome` 是錯的，已收回** |
| **進場多一列空白** ⚠️ | `rs.safeAreaTop` **在沉浸模式下不是常數**——第一幀有、之後沒有。同一成因犯兩次：橫幅的 `SafeArea`、格線的 `top: rs.safeAreaTop + 40.0` | `lib/features/home/widgets/home_grid_view.dart` · `lib/features/home/home_view.dart` |
| **環裡多一個 A+B** | L2/R2 的環原本含「全部來源」那格，兩台就走成 A → B → A+B。拿掉該格，並在 bootstrap 正規化：開著的來源超過一個而沒選過時落在 `primarySourceId ?? 第一個` | `lib/features/home/home_view.dart`（`_cycleActiveSource`、橫幅） · `lib/services/sources_notifier.dart`（bootstrap 正規化） |
| **建置部署腳本** | 同一串指令重複手打，容易漏掉 JDK 檢查那步 | `scripts/deploy.ps1`（驗 JDK → analyze → build → install → 啟動 → 抓 logcat） |
| **R-Shop 來源停用快取** ✨ | 停用來源時（`setEnabled(id, false)`）不再呼叫 `_purgeCachedGamesFor`，消除在主執行緒上對數千筆遊戲進行檔案 `existsSync` 檢查與單筆 SQL 刪除所導致的凍結與 Lag | `lib/services/sources_notifier.dart`（`setEnabled`） · `test/sources_notifier_test.dart` |
| **切換來源會 lag** ⚠️ | ① 標籤讀 `bootstrappedConfigProvider`，`invalidate` 後**在重新讀檔完成前 `valueOrNull` 還是舊值**。解：`SourcesState` 鏡像兩個 id。② `setEnabled(false)` 同步等清快取（每筆 `File.existsSync`），改 `unawaited` | `lib/services/sources_notifier.dart`（`SourcesState.primarySourceId`／`activeSourceId`、`setEnabled` 的 `unawaited`） · `lib/features/settings/sources_screen.dart` |
| **焦點白框貼著字** | `ConsoleFocusable` 的白框緊貼 child；child 自己有邊框時兩條線差幾像素，像畫錯 | `lib/features/onboarding/widgets/ra_onboarding_screen.dart`（`_textBox` 加內距與較大 `borderRadius`） | `lib/models/config/app_config.dart`（`primarySourceId`） · `lib/services/sources_notifier.dart`（`setPrimarySource`） · `lib/services/source_failover.dart`（`resolveForSync`） · `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart` |
| **來源清單快捷鍵** ✨ | 停用／移除／目前顯示原本都得先開選單。綁 `[X]`／`L1`／`R1`，**L1/R1 是從全域的格線欄數搶過來的**，且**必須用 `overlayPriorityProvider` 擋浮層**（沒有東西處理 L1/R1，會作用在看不見的卡上）。移除補了確認框 | `lib/features/settings/sources_screen.dart`（`_SourceShortcutIntent`／`_focusedSourceId`／`_confirmRemoveSource`／`_buildHud`） · `lib/l10n/app_*.arb` · `test/widgets/sources_screen_test.dart` |
| **黃色條與雙入口** ⚠️ | 那條黃黑斜紋是 `RenderFlex` **版面溢位警示**不是功能；把功能從選單列搬到圖示上會**弄丟手把入口**（圖示預設只有觸控） | `lib/features/settings/sources_screen.dart`（選單改 `SingleChildScrollView`、卡片列與標頭各加一個眼睛） |
| **標頭高度與誤讀的按鍵字** | 圖示旁的裸字母 `X` 被讀成關閉鈕；沉浸模式在 `initState` 才切，**第一幀還有狀態列 inset**，包了 `SafeArea` 的標題列會進場高一列再縮回去 | `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart`（`_buildSourceBanner` 拿掉 `SafeArea`） |
| **R-Shop QR碼手把導覽** ✨ | `QrPairingScreen` 掃碼頁加入搖桿/D-pad 焦點切換邏輯與初始化 Focus，支援手把切換至返回按鈕與手動輸入按鈕及底部 ConsoleHud | `lib/features/pairing/qr_pairing_screen.dart` · `test/widgets/qr_pairing_screen_test.dart` |
| **R-Shop 主頁面移除來源切換** ✨ | 主頁面移除頂部來源條與 L2/R2 來源切換快捷鍵及 HUD 提示，改由來源清單統一管理主要與備援來源 | `lib/features/home/home_view.dart` |
| **R-Shop 來源與備援邊框與高對比風格** ✨ | 來源設置與備援設定浮層統一採用清晰全列白邊框 (Colors.white24 / Colors.white) 與純白高對比文字 | `lib/features/settings/sources_screen.dart` · `lib/features/sources/fallback_picker_overlay.dart` |
| **R-Shop 網格卡片版面溢位修復** ✨ | 主畫面縮小網格（欄數增加，卡片變窄）且遊戲數量達到數萬個時，卡片標籤 Row 未限制寬度觸發 OVERFLOWED BY 5.4 PIXELS 溢位警示條。修復：包裹 FittedBox(fit: BoxFit.scaleDown) 自動適應寬度 | `lib/features/home/widgets/home_grid_view.dart` |

## 🛠️ 建置與環境

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **R-Shop 建置 JDK 不相容** ⚠️ | Gradle 8.14 解析不了 Java 25（Android Studio 的 `jbr`），只吐一行 `25.0.2`，**極易誤判成 NDK 缺失** | 無程式碼變更。`flutter config --jdk-dir` + `gradlew --stop` |
| **R-Shop 建置環境失聯** ⚠️ | 文件的 `D:\flutter` 是上一台機器的，本機從未裝過 | `AGENTS.md §5`（加註警告） |
| **R-Shop 測試基準** | `flutter test` 的 7 個既有環境失敗**不是回歸** | 無程式碼變更。診斷方法紀錄 |
| **R-Shop 實機重裝** | 裝置上是別台機器建的 **release** 版，debug 版覆蓋不上且資料備不出來 | 無程式碼變更。`run-as` 判斷法 |
| **R-Shop onboarding 五語系缺字串** | `DE has all EN keys` 長期紅——**是真的缺三個 onboarding 字串**（de/es/fr/ja/pt），不是環境問題。缺字串不會讓建置失敗，會出貨成空白 | `lib/l10n/app_{de,es,fr,ja,pt}.arb` · `test/l10n_completeness_test.dart` |
| **R-Shop 語系鎖定詞彙統一** ✨ | 多語系（de/es/ja/pt）「已鎖定/Locked」相關詞彙統一與 `app_ja.arb` 格式整理 | `lib/l10n/app_{de,es,ja,pt}.arb` · `lib/l10n/app_localizations_{de,es,ja,pt}.dart` |
| **R-Shop analyze 六項** | 累積的 6 個 analyze 問題（未用 import／未用區域變數／`cacheExtent` 已棄用）。`cacheExtent` 要換 `ScrollCacheExtent.pixels()` 而非 `.viewport()`，**單位不同** | `lib/features/game_list/widgets/game_grid.dart` · `lib/features/library/library_screen.dart` · `lib/widgets/console_dialog.dart` · `lib/features/onboarding/widgets/{romm_legacy_login_screen,welcome_chooser_step}.dart` · `lib/features/sources/manual_source_add_screen.dart` |
| **R-Shop 反查不到** | `build_fix_by_file.py` 報的 `entries without paths` **不是待辦**——沒動到檔的紀錄在反查表上無處可去，數字只會隨這類紀錄往上走 | `scripts/build_fix_by_file.py`（改掉誤導的說明字串） |

---

## 維護規則

新增 `FIX_LOGS.md` 條目後，**同一次操作內**在上表補一列。
「主要動到的檔案」是這份索引的重點——下次要改同一塊，看這欄就知道去哪，不必重新搜尋。
