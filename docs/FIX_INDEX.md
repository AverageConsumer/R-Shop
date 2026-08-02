# R-Shop 解決方案索引

> **導覽**：先讀共用的 [GLOBAL_DEV_NOTES.md](../../GLOBAL_DEV_NOTES.md)（建置工具鏈、分支政策、紀錄格式），
> 再依需要讀本專案 `docs/` 的其餘各份：
> - [ARCHITECTURE.md](ARCHITECTURE.md) — 模組分層與依賴方向
> - [FIX_LOGS.md](FIX_LOGS.md) — 修復與功能紀錄（細節、取捨、教訓）
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
| **R-Shop 來源備援** ✨ | 內外網兩台互為備援，連不上就換。**備援是暫時代打不是改變偏好** | `lib/models/config/source.dart`（`fallbackSourceId`） · `lib/services/source_failover.dart`（`chooseSource`） · `lib/services/sources_notifier.dart`（`setFallbackSource`） · `lib/features/sources/fallback_picker_overlay.dart` |
| **同步不知道是哪一台** | 徽章只寫進度不寫來源；連線方式只能新增不能刪；提示用的是「同一台伺服器」這種**使用者判斷不了**的判準 | `lib/providers/app_providers.dart`（`syncingSourceProvider`，標題列與徽章共用） · `lib/widgets/sync_badge.dart`（`_withSource`） · `lib/features/home/home_view.dart`（`_resolveSyncTarget` 抽出，**修掉自動同步沒走備援解析的漏洞**） · `lib/features/sources/endpoint_picker_overlay.dart`（`[X]` 刪 `[Y]` 改） |
| **備援接進同步** | 同步前先探測，連不上就換備援。**重建的是記憶體中的 config，磁碟不動**——所以偏好的來源會自己回來 | `lib/services/source_failover.dart`（`withEffectiveSource`／`resolveForSync`） · `lib/features/home/home_view.dart`（`_syncAll` 注入、`_fallbackInUse`、標題列橘色） · `lib/services/endpoint_probe_service.dart`（`_probeableEndpoints` 修復：**endpoints 為空時原本會靜默判定不可達**，而不可達正是觸發備援的條件） |
| **連線方式共用憑證** ⚠️ | `auth` 掛在 `Source`，**路由沒有自己的憑證**。同一台伺服器的多位址共用一個 token 沒問題；**指向另一台會送錯 token 回 401，而錯誤看起來像伺服器掛了**。兩台不同伺服器要用「兩個來源 + 備援」 | `lib/models/config/source.dart`（`endpoints` 註解說明假設） · `lib/features/sources/endpoint_picker_overlay.dart`（提示） · `lib/l10n/app_*.arb`（`sources_routeSameServerHint`） |
| **AppID 衝突** | `applicationId` 與原廠主線一致，無法共存 | `android/app/build.gradle.kts` · Kotlin package 重構 |
| **R-Shop Channel 名稱硬編** | 5 個 channel 名稱含 `applicationId`，Kotlin＋Dart 各自硬編共 20 處。**危險在靜默半合併** | `lib/services/platform_channels.dart`（新增，單一前綴） · `android/app/src/main/kotlin/.../MainActivity.kt`（`BuildConfig.APPLICATION_ID`） · `android/app/build.gradle.kts`（`buildFeatures.buildConfig = true`） · `native_smb_service` / `download_service` / `disk_space_service` / `device_info_service` |
| **R-Shop ProviderFactory 隱式初始化** | 文件稱「未 init 就崩」，查證後**生產不可達**，是契約缺陷 | `lib/services/provider_factory.dart`（具名 `StateError` + `@visibleForTesting reset()`） |

## 🎮 輸入與焦點

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **使用中與顯示分家** ⚠️ | ① `??=` 種值表達不了「刻意是 null」，取消要按兩次。② **使用中**（同步＋預設顯示，`primarySourceId`）與**顯示**（主畫面 L2/R2，`activeSourceId`）拆成兩件事；同步改讀 primary。舊設定檔靠 `?? activeSourceId` 回填，無遷移。③ 兩個都放進來源清單：**眼睛＝開／關（`L1`，就是 `enabled`）、打勾＝使用中（`[X]`）**，兩個功能不共用圖示。**曾經多做一個 `Source.showOnHome` 是錯的，已收回** |
| **進場多一列空白** ⚠️ | `rs.safeAreaTop` **在沉浸模式下不是常數**——第一幀有、之後沒有。同一成因犯兩次：橫幅的 `SafeArea`、格線的 `top: rs.safeAreaTop + 40.0` | `lib/features/home/widgets/home_grid_view.dart` · `lib/features/home/home_view.dart` |
| **停用不再清快取** ⚠️ | 停用→啟用要重抓整份清單才是真正的停頓，而且背景清除**會刪掉剛重抓的資料**。v14 之後讀取一律走 providers，停用的來源根本查不到，所以不必清。圖書館頁直接讀表，過濾改在那側（已下載的照樣列出）。`removeSource` 仍清 | `lib/services/sources_notifier.dart`（`setEnabled`） · `lib/features/library/library_screen.dart`（`_loadData` 過濾） |
| **切換來源會 lag** ⚠️ | ① 標籤讀 `bootstrappedConfigProvider`，`invalidate` 後**在重新讀檔完成前 `valueOrNull` 還是舊值**。解：`SourcesState` 鏡像兩個 id。② `setEnabled(false)` 同步等清快取（每筆 `File.existsSync`），改 `unawaited` | `lib/services/sources_notifier.dart`（`SourcesState.primarySourceId`／`activeSourceId`、`setEnabled` 的 `unawaited`） · `lib/features/settings/sources_screen.dart` |
| **焦點白框貼著字** | `ConsoleFocusable` 的白框緊貼 child；child 自己有邊框時兩條線差幾像素，像畫錯 | `lib/features/onboarding/widgets/ra_onboarding_screen.dart`（`_textBox` 加內距與較大 `borderRadius`） | `lib/models/config/app_config.dart`（`primarySourceId`） · `lib/services/sources_notifier.dart`（`setPrimarySource`） · `lib/services/source_failover.dart`（`resolveForSync`） · `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart` |
| **來源清單快捷鍵** ✨ | 停用／移除／目前顯示原本都得先開選單。綁 `[X]`／`L1`／`R1`，**L1/R1 是從全域的格線欄數搶過來的**，且**必須用 `overlayPriorityProvider` 擋浮層**（沒有東西處理 L1/R1，會作用在看不見的卡上）。移除補了確認框 | `lib/features/settings/sources_screen.dart`（`_SourceShortcutIntent`／`_focusedSourceId`／`_confirmRemoveSource`／`_buildHud`） · `lib/l10n/app_*.arb` · `test/widgets/sources_screen_test.dart` |
| **黃色條與雙入口** ⚠️ | 那條黃黑斜紋是 `RenderFlex` **版面溢位警示**不是功能；把功能從選單列搬到圖示上會**弄丟手把入口**（圖示預設只有觸控） | `lib/features/settings/sources_screen.dart`（選單改 `SingleChildScrollView`、卡片列與標頭各加一個眼睛） |
| **標頭高度與誤讀的按鍵字** | 圖示旁的裸字母 `X` 被讀成關閉鈕；沉浸模式在 `initState` 才切，**第一幀還有狀態列 inset**，包了 `SafeArea` 的標題列會進場高一列再縮回去 | `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart`（`_buildSourceBanner` 拿掉 `SafeArea`） |
| **浮層只做了手把** ⚠️ | ① 刪掉最後一筆來源後**手把完全失效只剩觸控**——`_initialFocusClaimed` 一旦為 true 永不重置，持有焦點的卡片被回收後螢幕上沒有任何節點有焦點。② 三個浮層的列是純 `Container`，**零觸控處理**；而 `ConsoleFocusable` 本身有 `GestureDetector`，所以卡片點得動、浮層點不動，**外觀完全看不出差別** | `lib/features/settings/sources_screen.dart`（`_ensureInteractiveFocus` 放棄宣告、`_OverlayButton.onTap`） · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/fallback_picker_overlay.dart` |

## 🛠️ 建置與環境

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **R-Shop 建置 JDK 不相容** ⚠️ | Gradle 8.14 解析不了 Java 25（Android Studio 的 `jbr`），只吐一行 `25.0.2`，**極易誤判成 NDK 缺失** | 無程式碼變更。`flutter config --jdk-dir` + `gradlew --stop` |
| **R-Shop 建置環境失聯** ⚠️ | 文件的 `D:\flutter` 是上一台機器的，本機從未裝過 | `AGENTS.md §5`（加註警告） |
| **R-Shop 測試基準** | `flutter test` 的 7 個既有環境失敗**不是回歸** | 無程式碼變更。診斷方法紀錄 |
| **R-Shop 實機重裝** | 裝置上是別台機器建的 **release** 版，debug 版覆蓋不上且資料備不出來 | 無程式碼變更。`run-as` 判斷法 |

---

## 維護規則

新增 `FIX_LOGS.md` 條目後，**同一次操作內**在上表補一列。
「主要動到的檔案」是這份索引的重點——下次要改同一塊，看這欄就知道去哪，不必重新搜尋。
