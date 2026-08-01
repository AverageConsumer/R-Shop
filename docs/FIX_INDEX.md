# R-Shop 解決方案索引

> 關鍵字對應 [FIX_LOGS.md](FIX_LOGS.md) 的 `## [關鍵字]` 標題，**必須逐字一致**。
> **不要在這裡寫死條目總數**——多個工作階段會同時追加，寫死的數字必定過時。
> 要對帳就跑 `grep -c '^## \[' docs/FIX_LOGS.md`。

## 🔌 來源與連線

| 關鍵字 | 症狀 / 根因 | 主要動到的檔案 |
| :--- | :--- | :--- |
| **R-Shop 連線路由** ✨ | 同一台伺服器的遠端與區網兩條路，切的是位址不是來源。**每條路各自存一份清單**（schema v14） | `lib/models/config/source.dart`（`SourceEndpoint`／`resolveEndpoint`／`withLiveEndpoint`）· `lib/services/sources_notifier.dart`（路由增刪改） · `lib/services/endpoint_probe_service.dart` · `lib/services/database_service.dart`（v14 migration、`saveGamesByRoute`、`getGamesForRoutes`） · `lib/services/source_resolver.dart` · `lib/models/config/provider_config.dart`（`endpointId`） · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/endpoint_edit_screen.dart` |
| **R-Shop 目前來源** ✨ | 兩個來源都啟用時會**兩個都抓再合併**，使用者無從得知在看哪一個 | `lib/models/config/app_config.dart`（`activeSourceId`） · `lib/services/source_resolver.dart`（`providersFor(activeSourceId:)`） · `lib/services/sources_notifier.dart`（`setActiveSource`） · `lib/features/home/home_view.dart`（標題列、L2/R2 切換） · `lib/features/settings/sources_screen.dart`（徽章） |
| **R-Shop 來源備援** ✨ | 內外網兩台互為備援，連不上就換。**備援是暫時代打不是改變偏好** | `lib/models/config/source.dart`（`fallbackSourceId`） · `lib/services/source_failover.dart`（`chooseSource`） · `lib/services/sources_notifier.dart`（`setFallbackSource`） · `lib/features/sources/fallback_picker_overlay.dart` ⚠️ **尚未接進同步流程** |
| **AppID 衝突** | `applicationId` 與原廠主線一致，無法共存 | `android/app/build.gradle.kts` · Kotlin package 重構 |
| **R-Shop Channel 名稱硬編** | 5 個 channel 名稱含 `applicationId`，Kotlin＋Dart 各自硬編共 20 處。**危險在靜默半合併** | `lib/services/platform_channels.dart`（新增，單一前綴） · `android/app/src/main/kotlin/.../MainActivity.kt`（`BuildConfig.APPLICATION_ID`） · `android/app/build.gradle.kts`（`buildFeatures.buildConfig = true`） · `native_smb_service` / `download_service` / `disk_space_service` / `device_info_service` |
| **R-Shop ProviderFactory 隱式初始化** | 文件稱「未 init 就崩」，查證後**生產不可達**，是契約缺陷 | `lib/services/provider_factory.dart`（具名 `StateError` + `@visibleForTesting reset()`） |

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
