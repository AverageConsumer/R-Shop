# R-Shop 修復與功能紀錄

> **導覽**：先讀共用的 [GLOBAL_DEV_NOTES.md](../../GLOBAL_DEV_NOTES.md)（建置工具鏈、分支政策、紀錄格式），
> 再依需要讀本專案 `docs/` 的其餘各份：
> - [ARCHITECTURE.md](ARCHITECTURE.md) — 模組分層與依賴方向
> - [FIX_INDEX.md](FIX_INDEX.md) — 症狀 → 過去解過的條目
> - [SPEC.md](SPEC.md) — 規格；**§12 定位指引回答「我要改 X，該動哪些檔」**
> - [USER_GUIDE.md](USER_GUIDE.md) — 使用手冊


> 本專案自己的詳細紀錄。關鍵字索引見 [FIX_INDEX.md](FIX_INDEX.md)。
> 跨專案／全域的問題仍記在 `D:\ThorAPK\StudioProjects\FIX_LOGS.md`。

## 寫入格式

每條**必須**有 `**檔案**` 欄位，列出這次實際改動的檔案與位置。
那是下次要改同一塊時最需要的資訊——有它就不必重新搜尋整個專案。

    ## [關鍵字] 一句話講清楚症狀
    
    - **檔案**：`lib/services/foo.dart:120-160`（做了什麼）
               `lib/models/bar.dart`（新增欄位 X）
    - **現象** / **根因** / **解** / **驗證** / **教訓** / **Commit**

新增條目後，**同一次操作內**補 [FIX_INDEX.md](FIX_INDEX.md)（關鍵字須與 `## [關鍵字]` 逐字一致）。
一律用**追加**，不要讀全檔再寫回——多個工作階段可能同時在寫。

---

## [AppID 衝突] R-Shop: 無法與原版共存
- **原因**：`applicationId` 與原廠主線一致。
- **解法**：修改 ID 為 `com.retro.rshop.tw` 並執行 Kotlin Package 重構。
- **檔案**：`android/app/build.gradle.kts` · `android/app/src/main/kotlin/com/retro/rshop/tw/MainActivity.kt`（package 重構）

---


## [R-Shop 建置環境失聯] R-Shop: 文件寫的 Flutter SDK 路徑在這台機器上根本不存在

- **現象**：準備驗證 R-Shop 的改動時，`D:\flutter\bin\flutter.bat` 不存在。全碟遞迴搜尋（`C:` 與 `D:`，深度 6）**零命中**，`flutter` / `dart` 也不在 PATH。
- **根因**：`SKILLS.md` 與 R-Shop 舊 `AGENT.md` 的建置環境是從**上一台機器**（`C:\Users\Mini-PC\...` 時代）繼承來的。目前這台是使用者 `Guset` 的機器，從來沒裝過 Flutter。佐證：R-Shop 的 `.dart_tool\`、`pubspec.lock`、`build\` **全都不存在**——這個工作副本從未解析過相依套件。
- **危險之處**：兩個子代理都照文件跑 `D:\flutter\bin\flutter.bat`，都失敗。**若當時把「照著跑了」當成「驗證過了」，整批未編譯的程式碼就會被當成已驗證交出去。**
- **解**：安裝 Flutter stable **3.44.8 / Dart 3.12.2**（官方 `storage.googleapis.com/flutter_infra_release`，1813 MB，解壓至 `D:\flutter`）。專案要求 `sdk: '>=3.0.0 <4.0.0'`，符合。
- **連帶踩到的兩個環境坑**：
  - `flutter pub get` 相依解析成功（142 個套件）但最後失敗於 `Building with plugins requires symlink support` —— Windows 需啟用**開發人員模式**。只擋 Android 建置，**不擋 `analyze` 與 `test`**（`.dart_tool\package_config.json` 已產生）。
  - PowerShell 5.1 的 `Invoke-WebRequest` 預設用 IE 解析引擎，在 NonInteractive 下會直接拋「無法提示」而不是網路錯誤。加 `-UseBasicParsing`。
- **教訓**：**環境路徑屬於「每台機器不同」的事實，不該只寫在跟著 repo 走的文件裡。** 已在 R-Shop `AGENTS.md §5` 加註警告，並明令「不要回報你沒真的拿到的 `flutter analyze` / `flutter test` 結果，就說被擋住了」。
- **檔案**：無程式碼變更。`AGENTS.md` §5（加註路徑警告）· `.agents/skills/rshop-build-deploy/SKILL.md`（現行工具鏈）
- **Commit**：未提交（環境設定，非程式碼變更）


## [R-Shop 測試基準] R-Shop: 完整測試有 8 個失敗，其中 7 個是既有環境問題、1 個是隨機不穩定

- **現象**：`flutter test` 跑出 1652 通過 / 8 失敗。乍看像是改壞了東西。
- **查證方法**（重點在方法，不在結論）：先 `git stash push -u` 退回乾淨 HEAD 跑**完整**測試取得基準，再還原比對。**第一次只跑 5 個檔想省時間，結果不可比**——完整跑是 77 個檔平行執行，負載完全不同，差異全是假的。
- **結果**：乾淨 HEAD 也是 **8 個失敗**。其中 **7 個兩邊完全相同**：
  | 失敗 | 性質 |
  |---|---|
  | `l10n_completeness: DE has all EN keys` | 德文真的缺 3 個 key（`onboarding_folderExplanation*`、`onboarding_continueToPicker`）|
  | `network_discovery: mDNS` | Windows socket `errno = 10042`（`joinMulticast` 不受支援）|
  | `rom_folder_service` ×3 | 測試期望檔名，服務回傳完整路徑——Windows 路徑行為 |
  | `romm_pairing_live_smoke` ×2 | 標了 `live` tag，需要真的有 RomM 跑在 `localhost:8090` |
- **第 8 個每次不一樣**：基準跑出 `config_storage: AsyncLock save during load does not deadlock`，含改動那次跑出 `game_list_controller: Filter persistence restoreFilters`。**兩者單獨執行都通過**（隔離跑 234 個測試全綠），都是時序敏感型 → 平行負載下的既有不穩定測試。
- **教訓**：**比對基準時，執行條件必須一致**。測試數量、平行度、機器負載任一不同，得到的差異就沒有意義。另外「失敗總數相同」還不夠——要逐項比對名稱，否則會漏掉「一個修好、一個弄壞」互相抵銷的情況。
- **檔案**：無程式碼變更（診斷方法紀錄）
- **Commit**：未提交（診斷紀錄）


## [R-Shop Channel 名稱硬編] R-Shop: 5 個 platform channel 名稱散在 20 處，合併 upstream 會靜默半套

- **現象**：無人回報。盤點 R-Shop 已知問題時發現。
- **根因**：5 個 platform channel（`/zip`、`/zip_progress`、`/storage`、`/smb`、`/smb_progress`）的完整名稱含 `applicationId`，在 Kotlin 與 Dart 兩側**各自硬編**，共 20 處（Kotlin 5 + Dart 6 + 測試 9）。本分支是 `com.retro.rshop.tw`，upstream `main` 是 `com.retro.rshop`。
- **真正的危險不是衝突，是靜默半合併**：若合併時採用 upstream 的 Kotlin 卻保留本地的 Dart，**編譯完全通過**，但執行期所有 `invokeMethod` 拋 `MissingPluginException`（SMB／解壓／儲存空間全掛）。而 `native_smb_service.dart:61-63` 把 `PlatformException` 吞成 `(success: false, error: ...)`，錯誤會偽裝成「連線失敗」，極難定位。Kotlin 檔還位於 `.../kotlin/com/retro/rshop/tw/` 目錄下，git 多半判為 add/add 而非修改，3-way merge 直接失效。
- **解**：Dart 側新增 `lib/services/platform_channels.dart`（單一 `kChannelPrefix` + 五個具名常數）；Kotlin 側 `MainActivity.kt:19-32` 改用 `BuildConfig.APPLICATION_ID` 組出前綴。**執行期字串值完全未變**，是純重構。
- **必要的連帶改動**：AGP 8.11.1 預設關閉 BuildConfig，`android/app/build.gradle.kts` 必須加 `buildFeatures { buildConfig = true }`，否則編不過。
- **成果**：全 repo 的 `'com.retro.rshop...'` 字面值從 **20 處降到 1 處**。
- **實機驗證** ✅：`flutter build apk --debug` 成功（202.4 MB，exit 0），安裝到 AYN Thor 啟動正常，logcat **無 `MissingPluginException`**——這正是本條最該驗的一項，代表 Kotlin 與 Dart 兩側名稱仍然對得上。
- **教訓**：`analyze` 與 `test` **碰不到 Kotlin 與 Gradle**。這類改動只有 `flutter build apk` 會驗到——單元測試全綠不代表這條改動是對的。**而這次差點驗不成**：建置一開始因 JDK 版本問題失敗，見 `[R-Shop 建置 JDK 不相容]`。
- **檔案**：`lib/services/platform_channels.dart`（新增）· `android/app/src/main/kotlin/com/retro/rshop/tw/MainActivity.kt` · `android/app/build.gradle.kts`（`buildFeatures.buildConfig`）· `lib/services/native_smb_service.dart` · `lib/services/download_service.dart` · `lib/services/disk_space_service.dart` · `lib/services/device_info_service.dart`
- **Commit**：未提交


## [R-Shop ProviderFactory 隱式初始化] R-Shop: 未 init 就取 SMB provider 只拋裸的 null assertion

- **現象**：文件（`docs/SPEC.md`）長期記載「`SmbProvider` 依賴 `_smbService!`，未 `init()` 就會崩」。
- **查證後的定性修正**：**生產流程實務上不可達**。全 App 只有一個進入點，`main.dart:87` 的 `ProviderFactory.init()` 在 `runApp()` **之前**，所以任何 UI 觸發的 `getProvider` 必定在其後；唯一另一個 `@pragma('vm:entry-point')`（下載前景服務）的 handler 三個回呼全是空實作，不碰 ProviderFactory。所以這是**契約缺陷**（隱式初始化順序依賴 + static 狀態無法重設），不是現行 crash。**測試層面才真的可達**。
- **解**：`_smbService == null` 時丟具名 `StateError`，訊息點名 `ProviderFactory.init(smbService:)` 且說明正常應在 `main()` 的 `runApp()` 之前。新增 `@visibleForTesting reset()` 讓測試能重設 static 狀態，並補測試驗證訊息可辨識、以及未初始化時 `web` provider 仍正常。**未改建構式簽章**——改成注入式會牽動 4 個呼叫端。
- **教訓**：文件把一個缺陷寫成「會崩」，實際查證後是「不可達但脆弱」。**定性錯誤會影響修法選擇**：若真的會崩，該做的是改建構式注入；既然只是契約問題，加一個好訊息的 `StateError` 就夠，改動面小得多。
- **檔案**：`lib/services/provider_factory.dart`
- **Commit**：未提交


## [R-Shop 連線路由] R-Shop: 同一台伺服器的遠端與區網兩條路，切的是位址不是來源 ✨ 功能新增（非修復）

> ⚠️ **進度：模型層與 `SourcesNotifier` 已完成並驗證（42 個測試全通過）。探測服務、切換器 UI 與位址編輯畫面尚未動工。**

- **需求**：使用者有一台 RomM，同時從遠端與區網登入，想在兩種連線方式之間切換，而且「一次顯示一個，不要兩個疊在一起」，其他來源型別（SMB/FTP/Web）也要能這樣切。
- **三次修正需求理解的過程**（值得記著，我連錯兩次）：
  1. 先理解成「多個來源的全域篩選器」→ 錯，使用者要的是連線方式不是來源。
  2. 再理解成「兩個 Source 互斥切換」→ 也錯，那會讓同一台伺服器的同一批遊戲存兩份、合併去重後看不出走哪條線。
  3. 正解：**一個 Source 帶多個連線位址（endpoint），一次只有一個生效**。
- **關鍵設計決定**：頂層連線欄位（`url`/`host`/`port`/`share`）**就是「目前生效的路由」**，`endpoints` 只是候選清單。因此 `SourceResolver`、`connectionKey`、`hostLabel`、`ProviderFactory`、四個 provider **一行都不用改**——切換只是把選中位址寫回頂層欄位。
- **不需要設定檔遷移**：`Source.id` 不變，`fromJson` 在沒有 `endpoints` 鍵時自動從舊欄位補出第一條路由（id 為 `primary`），舊設定檔直接可用。
- **但需要資料庫改動（v13→v14）** —— 這點我來回搞錯兩次，值得記著：
  - 我先假設「同一台伺服器＝同一份遊戲資料」，據此宣稱不必動 DB。
  - 使用者否決：「你想把遠端查的清單跟數量與在家區網查到的當作同一份看啊，不用這樣啊」「就是遠端清單改成區網清單而已」。**要的是每條路由各自留一份清單與數量，切過去就看那條路自己查到的東西。**
  - 教訓：「同一台伺服器」是我的推論，不是需求。使用者要的是**能分別看見每條路的結果**，那本來就不可能靠共用一份資料達成。
- **選路規則**（`resolveEndpoint()`，純函式，`reachable` 由呼叫端探測後傳入）：
  - `pinned`：使用者的選擇**絕對優先，就算連不上也不改道**。鎖定的意義正是「不要自己跑掉」，讓同步噴出真正的連線錯誤比較誠實。
  - `auto`：取清單順序中第一個通的。清單順序即偏好順序，把區網放前面，「在家快、在外通」就自然成立。
  - `auto` 且全都不通：回傳**第一條**而非 null——回 null 會讓同步靜靜地什麼都不做。
  - pin 指向已刪除的路由：退回 auto，不卡死。
- **切換時刻意保留**：帳密（兩條路通往同一台伺服器，共用同一組帳號，每次切換都要重新登入毫無意義）、`knownPlatforms`、`Source.id`。
- **`SourcesNotifier` 層**（`switchEndpoint` / `setEndpointSelection` / `addEndpoint` / `updateEndpoint` / `removeEndpoint`）：全部走 `updateSource`，因此**永遠不碰 `_purgeCachedGamesFor`**。這是本功能最關鍵的不變量——若切換路由會清快取，每次切換就等於一次完整重新同步，功能本身就沒意義了。專案裡 `setEnabled(false)` 與 `removeSource` **會**清快取，兩者語意必須分乾淨。
  - 邊界決定（各有測試）：**拒絕刪除最後一條路由**（沒有路由的來源等於沒有位址）；刪掉正在用的那條由第一條遞補；刪掉被鎖定的那條則清 pin 並退回 auto，不留懸空指標；**重複位址拒絕新增**（忽略標籤，`http://h:1/` 與 `http://h:1` 視為同一個，否則 `liveEndpoint` 會變成任意選一個）；編輯正在用的那條立即生效，編輯待命的那條不動現行連線；`setEndpointSelection(pinned)` 在還沒選過時鎖定**目前正在用的**那條（使用者看到什麼就是什麼意思）。
- **每條路由各自存清單（schema v14）**：`games` 加 `source_id` / `endpoint_id`，唯一索引由 `(systemSlug, filename)` 改成 `(systemSlug, filename, source_id, endpoint_id)`。
  - **兩欄是 `NOT NULL DEFAULT ''` 而非可為 null** —— SQLite 的 UNIQUE 索引把 NULL 視為互異，用 null 會讓本機掃描悄悄失去去重。本機檔案存在 `''`/`''` 這個「無路由」桶，因為它們本來就不屬於任何路由。
  - **孤兒刪除縮到路由範圍**：不改的話，區網同步會把遠端那條路的整份資料當孤兒刪光。
  - **cascade 要先確認沒有別的路由還列著該檔**：`game_metadata` / `ra_matches` 的鍵是 `(system, filename)`，沒有路由維度；區網刪掉一款就連帶清掉封面與 RA 進度，而遠端那份還在顯示它。
  - migration 用 `json_extract` 從 `provider_config` 回填 `source_id`（該鍵一直都在），`endpoint_id` 補成 `primary`，對應 `Source.fromJson` 自動補出的那條路由 → **既有資料不會消失**。
  - 順帶解決舊有的「依來源查詢只能 `LIKE '%\"source_id\":\"x\"%'` 掃全表」問題，現在是索引查詢。
- **接線**：`ProviderConfig` 加 `endpointId`；`SourceResolver` 五處填入 `source.liveEndpoint?.id`；新增 `DatabaseService.saveGamesByRoute()` 依每個 `GameItem` 自己的 `providerConfig` 分組存檔（**呼叫端不必知道路由**，15 個呼叫點只換方法名）；`getGamesForRoutes()` 讓遊戲清單只讀「這個系統目前生效的那些路由 + 本機桶」。
- **UI**：`EndpointPickerOverlay`（動作選單 → 連線方式）顯示自動／各路由／可達狀態／新增；`EndpointEditScreen` 輸入標籤與位址。七語系各補 13 個字串。切換器**開啟時停在目前生效的那條**（誤按 A 是無操作）、**每次開啟重新探測不吃快取**（會打開它就是想知道現在哪條通）。
- **測試**：`source_endpoint_test` 21 ＋ `sources_notifier_endpoints_test` 21（注入 `_SpyDb` 斷言 **switch/add/remove 皆不 purge、`setEnabled(false)` 仍 purge**）＋ `endpoint_probe_service_test` 19 ＋ `database_service_routes_test` 14（含 **「區網同步絕不刪掉遠端那條路」** 與 cascade 保護）。合計 75 個，全通過；完整套件 1693→ 僅剩 7 個既有環境失敗，**零回歸**。
- **教訓**：**需求裡的「切換來源」有歧義，而不同解讀導致的架構完全不同**（一個要動資料庫 schema，一個完全不用）。連錯兩次的共同原因是我拿使用者的詞去對映系統既有的概念（Source），而不是先問「你要切的到底是什麼」。
- **檔案**：`lib/models/config/source.dart` · `lib/services/sources_notifier.dart` · `lib/services/endpoint_probe_service.dart` · `lib/services/database_service.dart`（v14 migration）· `lib/services/source_resolver.dart` · `lib/models/config/provider_config.dart` · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/endpoint_edit_screen.dart`
- **Commit**：未提交


## [R-Shop 建置 JDK 不相容] R-Shop: Gradle 8.14 看不懂 Java 25，只吐一行「25.0.2」

- **現象**：`flutter build apk --debug` 失敗，Gradle 的 `* What went wrong:` 底下**只有一行 `25.0.2`**，沒有任何其他訊息。
- **誤判過程**（值得記著）：`25.0.2` 看起來像版本號，而 SDK 底下確實**沒有 `ndk` 目錄**，所以我第一時間判定是「NDK 未安裝」。**錯的。** 真正的堆疊要加 `--stacktrace` 才看得到：
  ```
  java.lang.IllegalArgumentException: 25.0.2
      at ...intellij.util.lang.JavaVersion.parse(JavaVersion.java:307)
      at ...JavaVersion.current()
      at ...KotlinCoreEnvironment.<init>
  ```
  `25.0.2` 是 **JDK 版本**——Android Studio 的 `jbr` 是 Java 25，而 Gradle 8.14 內嵌的 Kotlin DSL 編譯器在解析自己執行環境的 Java 版本時就拋例外，連 `build.gradle.kts` 都還沒編譯完。
- **第二個坑：改 `JAVA_HOME` 沒用。** 設成 JDK 21 後**還是報 25.0.2，而且只跑 1 秒**。原因有二：(a) Flutter 挑 JDK 的優先序是 **`flutter config --jdk-dir` ＞ Android Studio 的 JBR ＞ `JAVA_HOME`**，JBR 蓋過了環境變數；(b) 舊的 Gradle daemon 仍跑在 Java 25 上被重用。「1 秒就結束」正是重用 daemon 的特徵。
- **解**：`flutter config --jdk-dir="C:\Program Files\Java\jdk-21"` ＋ `gradlew --stop`。之後建置一路通過（936 秒，途中 Gradle **自動補裝** NDK 28.2.13676358 與 23.1.7779620、SDK Platform 36、CMake 3.22.1——**不需要 cmdline-tools／sdkmanager**，Gradle 有自己的下載器）。
- **不影響 megingiard**：它是 Gradle 9.3.1 且 `gradle/gradle-daemon-jvm.properties` 釘了 `toolchainVersion=21`，由 Gradle 自行挑 JVM，**`JAVA_HOME` 對它根本無效**。所以同一條「JAVA_HOME 設 jbr」的舊指令對 megingiard 無害、對 R-Shop 致命。**兩套機制不要互相照抄。**
- **教訓**：Gradle 把例外訊息當成 `What went wrong` 的全部內容時（只有一個裸值、沒有句子），**先加 `--stacktrace`**，不要照那個值的「長相」去猜它是什麼。
- **檔案**：無程式碼變更。`.agents/skills/rshop-build-deploy/SKILL.md`（Step 0 的檢查步驟）
- **Commit**：未提交（環境設定）


## [R-Shop 實機重裝] R-Shop: 舊版是 release 簽章，debug 版覆蓋不上且資料備不出來

- **現象**：新建的 debug APK 無法 `adb install -r` 覆蓋裝置上的 `com.retro.rshop.tw`。
- **根因**：兩者簽章不同——裝置上是 `1dbe6fec…`，新版是 `cf35438e…`。追查後發現裝置上那份是**上一台機器建的 release 版**（`run-as` 回 `package not debuggable`），而本機**沒有 `android/key.properties`**，所以現在只能產 debug 簽章。
- **資料無法備份**：`run-as` 因非 debuggable 被拒；`adb backup` 也不行——`dumpsys` 的 `flags` 裡沒有 `ALLOW_BACKUP`。兩條路都堵死，**使用者確認可接受後才移除**。
- **實際損失與倖存**：
  - ❌ 消失：app 內部資料（`config.json` 的 RomM 來源與 token、遊戲庫 DB、縮圖快取）
  - ✅ 倖存：`/storage/emulated/0/ROMs` **19 GB / 253 檔 / 22 個主機資料夾**——移除 app 不影響外部儲存
  - ✅ 保留：移除前已把舊的 release APK 拉下來存到 `D:	est-apk\R-Shop-v1.7.0-zh-RELEASE-舊機簽章.apk`（99.7 MB），要回舊版可用
- **教訓**：**動裝置上的 app 之前先確認它是哪種簽章**。`run-as` 能不能用就是最快的判斷——不能用代表是 release 版，那麼資料多半也備不出來（release 通常關掉 `allowBackup`）。這個判斷要在**移除之前**做，不是之後。
- **檔案**：無程式碼變更（`run-as` 判斷法）
- **Commit**：未提交（部署作業）


## [R-Shop 目前來源] R-Shop: 兩個來源都啟用時會合併同步，使用者無從得知現在看的是哪一個 ✨ 功能新增（非修復）

- **現象**：使用者設了兩個 RomM 來源（`Thor localhost` = 區網 IP、`Thor out` = DDNS），回報「我要怎麼判斷目前同步的是哪一個來源，我一次只會同步也只會看一個，沒看到切換跟顯示」。
- **查證**：用 `adb exec-out run-as … cat config.json` **直接讀實機設定**（此版是 debug 建置，`run-as` 可用），確認是**兩個獨立 Source**、各自只有一條自動回填的 `primary` 路由、且**兩個都 `enabled: true`**。
- **根因**：R-Shop 的既有行為是「所有啟用的來源都抓，然後用 `UnifiedGameService._fetchMerged` 合併，優先序高的贏」。所以使用者不只是「看不出是哪一個」，而是**兩個都在同步、清單是混合的**。而唯一的控制手段 `setEnabled(false)` **會 purge 快取**，切回來要重新同步。
- **這是我第四次修正需求範圍**，前三次見 `[R-Shop 連線路由]`。決定性的一句是使用者說的「**就算是同一台，我也要當不同台**」——來源一律各自獨立，與背後是不是同一台伺服器無關。**這是他的模型，不是可以從 URL 推論的東西**（那兩個網址同為 9080 埠，我原本推論是同一台，且推論正確，但無關緊要）。
- **解**：`AppConfig.activeSourceId`（null＝全部，維持既有行為）。`SourceResolver.providersFor()` 加 `activeSourceId` 過濾 → **同步與清單一次跟上**，因為兩者都是讀 `system.providers`。
  - **切換絕不 purge**：走 `_writeAndPublish` 重建 providers，不碰 `_purgeCachedGamesFor`。因為先前已做 per-route 分開存（見 `[R-Shop 連線路由]`），另一個來源的遊戲仍在 DB，切回去立即可見。`setEnabled(false)` / `removeSource` 仍會 purge，語意分開且各有測試。
  - **未知 id 退回「顯示全部」而非空清單**：來源被刪掉時若還被選著，不能讓使用者得到一個空的遊戲庫。
  - **停用勝過選中**：已關閉的來源即使是 active 也不參與。
- **UI**：來源卡片加綠色「目前顯示」徽章（否則這件事完全不可見）；`[A]` 動作加「只看這個來源／顯示全部來源」。七語系各補 4 個字串。
- **測試**：`test/active_source_test.dart` 13 個，含 `NEVER purges — switching back must be instant, not a re-sync`、`but disabling a source still purges it`、未知 id、停用勝過選中、重載後保留。完整套件 1720 通過 / 7 個既有環境失敗，**零回歸**。
- **教訓**：**使用者說「切換」時，先確認他實際在 UI 上建了什麼**。這次直接讀實機 `config.json` 一眼就看出我做的功能在錯的層級——比再問一輪快，也比猜可靠。debug 建置的 `run-as` 就是這個能力的來源。
- **檔案**：`lib/models/config/app_config.dart` · `lib/services/source_resolver.dart` · `lib/services/sources_notifier.dart` · `lib/features/home/home_view.dart` · `lib/features/settings/sources_screen.dart`
- **Commit**：未提交

---


## [R-Shop 來源備援] R-Shop: 內外網兩台伺服器互為備援，連不上就換 ✨ 功能新增（非修復）

> ⚠️ **進度：模型／選路邏輯／指派 UI 已完成並驗證。接同步流程尚未動工**——所以現在設得起來、看得到，但還不會作用。

- **需求**：使用者有兩台 RomM（Thor localhost 內網、Thor out 外網 DDNS），要求「增加一個關聯性」「timeout 後切換另一個來源」，並明確表示「**至少要能指派一個備援就好**」。
- **關鍵決定：備援是暫時代打，不是改變偏好。** `Source.fallbackSourceId` 只記「誰來頂」，`AppConfig.activeSourceId`（使用者選的偏好）**完全不動**。
  - 理由：使用者選的是「我要用內網那台」。人在外面連不上而改用外網是**當下的權宜**；若永久切過去，回到家還得手動切回來。不動偏好，回家再同步時內網通了就自動用回內網。
  - 畫面仍看得出來：標題列會標示正在用備援，不會讓人誤以為在用內網。
- **四個邊界（各有測試）**：
  - **兩個都連不上 → 停在偏好那個**。這樣同步的錯誤訊息指的是使用者真正想連的機器；報備援的錯會害他去查錯的機器。
  - **偏好被停用 → 不失效轉移**。停用是主動關閉不是斷線，悄悄把遊戲庫交給另一台伺服器是錯的。
  - **備援指向自己 / 已刪除 → 忽略**，不會迴圈也不會懸空。
  - **沒有選定來源 → 無事可做**（正在顯示全部）。
- **探測沿用 `EndpointProbeService`**：TCP 連得上即可達，短逾時。**不能等同步逾時**——RomM 的同步逾時至少 10 分鐘，等它跑完才切換體感極差。
- **UI**：Sources → `[A]` → 「備援來源」開 `FallbackPickerOverlay`（列出其他來源＋「不設定」，已選的打勾）；卡片顯示 `備援 → <名稱>`，否則設完看不出來。只有兩個以上來源才出現此選項。七語系各補 3 個字串。
- **測試**：`test/source_failover_choice_test.dart` 11 個，全數通過。
- **待辦**：接進同步流程（同步前探測 → 不通改用備援 → 標題列標示備援中）。
- **檔案**：`lib/models/config/source.dart` · `lib/services/source_failover.dart` · `lib/services/sources_notifier.dart` · `lib/features/sources/fallback_picker_overlay.dart`
- **Commit**：未提交


## [連線方式共用憑證] R-Shop: 路由沒有自己的 auth，指向別台伺服器會 401

- **檔案**：`lib/models/config/source.dart`（`endpoints` 欄位註解說明假設；`SourceEndpoint` 刻意**沒有** auth 欄位）
             `lib/features/sources/endpoint_picker_overlay.dart`（切換器加同伺服器提示）
             `lib/l10n/app_*.arb`（七語系新增 `sources_routeSameServerHint`）
- **現象**：使用者問「我 romm 一個外網一個內網，他好像要做認證的耶，這樣切換的了嗎？」
- **查證**：`auth` 掛在 `Source` 上（`source.dart:226`），`SourceEndpoint` **只有 id/label/url/host/port/share，沒有憑證欄位**。`withLiveEndpoint` 原樣保留 `auth`，`SourceResolver` 四處都餵 `source.auth` 給 provider。
- **結論：「連線方式」只適用於同一台伺服器的多個位址。** RomM 的 token 由伺服器發、不綁位址，所以同一台的兩個位址共用一個 token 沒問題；**但指向另一台伺服器就會送錯 token，回 401，而那個錯誤看起來像伺服器掛了**，極難聯想到是設定用錯機制。
- **使用者的情境不適用路由**：他明確說過「其實是不同的兩台伺服器」。正確做法是**兩個獨立來源各自登入，再用 `fallbackSourceId` 配成備援**——切換來源時 auth 跟著換（見 `[R-Shop 來源備援]`）。他現有的設定本來就是對的。
- **解**：不改架構（per-endpoint 憑證會讓「同一台伺服器」這個前提失去意義，也讓 token 續期變成 N 份）。改為**把假設講出來**：切換器加一行提示指向正確做法，並在 `Source.endpoints` 的註解寫明為什麼沒有 per-route auth，免得後人以為是漏做。
- **教訓**：**設計時的隱含假設要寫在使用者看得到的地方，不是只寫在程式註解裡。** 我在程式碼裡註明了「both routes reach the same server with the same account」，但 UI 上一個字都沒有——使用者當然會拿它來接兩台不同的伺服器。會問這題的人不只一個。
- **Commit**：未提交

## [備援接進同步] R-Shop: 同步前先探測，連不上就換備援那台

- **檔案**：`lib/services/source_failover.dart`（`withEffectiveSource`／`resolveForSync`）
             `lib/features/home/home_view.dart`（`_syncAll` 注入、`_fallbackInUse` 狀態、標題列橘色標示）
             `lib/services/endpoint_probe_service.dart`（`_probeableEndpoints` 修復）
- **需求**：使用者要「綁定多台，可以依序或自動，幫我選連線正常的那台」。他決定**兩台各自獨立設定**，理由是「連線位置不同，兩次都會需要認證，就相當於兩台不同的伺服器了」。
- **注入點**：`_syncAll` 拿到 config 之後、傳給 `LibrarySyncService` 之前，用 `resolveForSync` 重建一份**記憶體中的** config。**磁碟上什麼都沒改**，所以偏好的來源會自己回來——這是整個設計的核心，不是實作細節。
- **只探測最多兩台**：偏好的通就完全不探備援（探了也改變不了結果，在掌機上省一次連線）。有測試釘住 `net.asked` 只有一筆。
- **短逾時**：TCP 連得上即可，**不能等 RomM 的同步逾時**（至少 10 分鐘）。
- **手動切換來源會清掉備援標示**——使用者主動選了就是他說了算。
- **順手修掉一個真實破綻**：`EndpointProbeService.reachableFor` 原本遇到 `endpoints` 為空就直接回傳空集合。而**位址回填只發生在 `Source.fromJson`**，程式碼裡直接建構的 `Source`（有 `url` 但 `endpoints` 空）會被**靜默判定為不可達**——而「不可達」正是觸發備援的條件，等於可能在沒真的連過的情況下就把某台停用掉。改為 endpoints 為空時用來源本身的連線欄位探測。**這是測試抓到的，不是我想到的**：測試直接建構 Source，剛好是正式路徑從沒遇過的形狀。
- **測試**：`source_failover_sync_test.dart` 9 個（含「偏好未被更動」「偏好通就不探備援」「兩台都不通停在偏好」）。完整套件 1740 通過 / 7 個既有環境失敗，零回歸。
- **Commit**：`d5d7522`（功能）、`e79007e`（探測修復）

## [同步不知道是哪一台] R-Shop: 徽章只寫進度沒寫來源；連線方式也只能新增不能刪

- **檔案**：`lib/providers/app_providers.dart`（新增 `syncingSourceProvider`）
             `lib/features/home/home_view.dart`（`_resolveSyncTarget` 抽出，自動同步也走它；標題列改讀 provider）
             `lib/widgets/sync_badge.dart`（`_withSource` 把來源名接在主機名後）
             `lib/features/sources/endpoint_picker_overlay.dart`（`[X]` 移除、`[Y]` 編輯、錯誤訊息、提示列）
             `lib/l10n/app_*.arb`（`sources_routeCannotRemoveLast` 新增；`sources_routeSameServerHint` 改寫）
- **使用者回報三件事**：
  1. 「連線方式新增後沒有可以移除的方法」
  2. 「是不是要說明 不需要驗證的話 / 要驗證要走備援方式」
  3. 「同步中 指的是哪一台?? 好像沒有標示出來」
- **解 1**：`[X]` 移除、`[Y]` 編輯目前反白的那條，**刻意不放在 `[A]`**——切換是最常做的動作，要保持一鍵。刪最後一條時 notifier 會拒絕，UI 要**顯示原因**而不是默默沒反應（沒有位址的來源無法使用）。
- **解 2**：提示原本寫「同一台伺服器的不同位址」——那是**我的技術判準**，使用者未必知道兩個位址背後是不是同一台。改成他實際遇到的現象：「**如果那個位址要你重新登入**，請改成新增來源再互設備援」。判準要用使用者觀察得到的東西表達。
- **解 3**：新增 `syncingSourceProvider`，標題列與徽章讀同一份，不會各說各話。徽章從 `3/8 · SNES` 變成 `3/8 · SNES · Thor localhost`，用備援時標「（備援）」。
- **順手修掉的漏洞**：**自動背景同步（`syncSmart`）原本沒走備援解析**，只有手動同步會。所以背景同步可能一直打連不上的那台，而徽章顯示的是另一台。抽出 `_resolveSyncTarget` 讓兩條路徑共用。
- **教訓**：這三項都是**只有實機操作才會發現**的（同類第六、七、八次，見記憶 `ui-problems-only-surface-on-device`）。特別是第 2 點——**寫給使用者看的說明，判準要用他觀察得到的現象，不是我的內部模型**。
- **驗證**：1740 通過 / 7 個既有環境失敗，零回歸。
- **Commit**：未提交

## [浮層只做了手把] R-Shop: 刪掉最後一筆來源後手把失效；三個浮層完全不吃觸控

- **檔案**：`lib/features/settings/sources_screen.dart`（`_ensureInteractiveFocus` 放棄宣告、`_OverlayButton` 加 `onTap`、動作選單加回「只看這個來源」）
             `lib/features/sources/endpoint_picker_overlay.dart`（`_RouteRow` 加 `onTap`，4 個呼叫點）
             `lib/features/sources/fallback_picker_overlay.dart`（`_Row` 加 `onTap`，3 個呼叫點）
- **使用者回報**：「當我刪除最後一筆來源，回到新增來源，我的控制都失效只剩觸控」「點選來源後的頁面卻不能觸控」「到新增來源我又不能觸控」「來源設定那邊也要能指定本次要顯示哪個，不然我還要跑去主頁面」
- **焦點卡死的根因**：`_ensureInteractiveFocus` 開頭是 `if (_initialFocusClaimed || ...) return;`。那個旗標**一旦設為 true 就永不重置**。刪掉最後一筆來源時，持有焦點的卡片連同它的 `FocusNode` 一起被回收（`_gcFocusNodes`），螢幕上再也沒有任何節點有焦點，而旗標讓它不再重取——手把因此完全沒反應，只剩觸控還能用。**解**：焦點不在任何卡片也不在空狀態按鈕上時就放棄宣告，讓空狀態接手。
- **觸控的根因**：`ConsoleFocusable`（來源卡片用的）**本身有 `GestureDetector`**，所以卡片點得動；但三個浮層裡的列是我自己寫的純 `Container`，**一個點擊處理都沒有**。做浮層時只想著手把，忘了這台機器有觸控螢幕。**解**：三處都包 `GestureDetector(behavior: HitTestBehavior.opaque)`，且**點一下直接執行**而不是只移動游標——已經點到的東西還要再確認一次是純粹的摩擦。
- **「只看這個來源」加回來源頁**：先前是照使用者說的「那邊不用控制」拿掉的。他實際用過後說「不然我還要跑去主頁面」——**兩邊都要有**：扳機是快速路徑，但決定要哪個來源的當下人就在來源清單上。
- **教訓**：**手把與觸控是兩套獨立的輸入，做了一套不代表另一套會動**。既有元件（`ConsoleFocusable`）兩套都處理，我自訂的浮層只做了一套，而它們外觀一模一樣——從畫面上看不出差別，只有真的去點才會發現。
- **驗證**：1740 通過 / 7 個既有環境失敗，零回歸。
- **Commit**：未提交

> **後續（2026-08-02）**：漏了第四個浮層——`_SourceTypePickerOverlay`（按 `[Y]` 的來源種類選單）。
> 使用者回報「新增來源還是不能觸控」。**我只修了他當時點過的三個，沒有回頭找同類的。**
> 這次掃過整個 `lib/` 並**逐一核對每個呼叫點**（連線方式 4/4、備援 3/3、動作＋種類 2/2，
> 既有的離開確認框本來就有），確認沒有漏網。
> 修的時候順手把類型選單的選取抽成 `_pickSelected()`，讓按鍵與觸控走**同一條路徑**——
> 各自呼叫 `onPick` 的話，日後有人在按鍵那條加一個步驟，觸控就會悄悄不同步，
> 那正是這次問題的同一種病因。

## [黃色條與雙入口] R-Shop: 那條黃色是版面溢位警示；把功能搬到圖示上會弄丟手把入口

- **檔案**：`lib/features/settings/sources_screen.dart`（動作選單改 `SingleChildScrollView`、卡片列加眼睛圖示、選單標題右上角加眼睛＋綁 `[X]`）
- **黃色條**：使用者問「來源設定的取消上面蓋了一條黃色條，不知道幹嘛用」。**那不是功能，是 Flutter 的版面溢位警示（黃黑斜紋）。** logcat 證實 `A RenderFlex overflowed by 39 pixels on the bottom`——我在動作選單陸續加了「只看這個來源／備援來源／連線方式」三列，3.92 吋螢幕裝不下。**解**：選單改可捲動，之後再加列也不會重現。
- **查法值得記**：先用 `adb shell screencap` 想直接看，但截到的是雙螢幕的另一面；改用 `adb logcat` grep `RenderFlex|overflowed` 一次命中。**版面問題優先查 logcat，比截圖可靠。**
- **雙入口**：使用者要求「目前顯示」也能在來源設定裡操作，並指出「可以做成右上角的眼睛圖示，不一定要佔一列」，接著訂下規則：**功能都要有兩個入口，一個觸控、一個手把（或按鍵）**。
  - 我原本把它從選單搬到清單列上的眼睛圖示——**那是純觸控的 `GestureDetector`，手把按不到**。只做觸控跟只做手把一樣違規。
  - **解**：選單標題右上角放小眼睛（觸控）＋綁 `[X]`（手把），提示列寫出來。用角落圖示而非多一列，因為選單先前就已經溢位過。
- **教訓**：**把功能從 A 處搬到 B 處時，要確認 B 處兩套輸入都有**。搬移看起來只是移動，實際上會連帶改變可達性——選單列本來按鍵與觸控都通，圖示按鈕預設只有觸控。
- **驗證**：實機無溢位、無崩潰。
- **Commit**：見下

## [標頭高度與誤讀的按鍵字] R-Shop: 圖示旁的裸字母被當成關閉鈕；標題列進場高一列再縮回去

- **檔案**：`lib/features/settings/sources_screen.dart`（動作選單標頭）· `lib/features/home/home_view.dart`（`_buildSourceBanner`）
- **裸字母**：使用者問「來源那邊你右上圖示也寫一個 X 是幹嘛用？」。眼睛圖示旁邊那個 `X` 是想標示綁定的按鍵，但**擺在圖示旁就讀成了關閉按鈕**。而且它還違反我自己記下的規則——裝置支援 `nintendo/xbox/playstation` 三種配置，**同一個實體鍵在三種配置下名字不同，字母不能寫死**。**解**：刪掉標頭那個字，按鍵提示只留在底部提示列。
- **高度會跳**：使用者說「主頁面的標題在初始時跟下面圖示隔了兩行，但是向下移動後又變成隔一行」。根因是 `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` 在 `initState` 才執行，所以**第一幀還帶著狀態列 inset，後面的幀沒有**——標題列包了 `SafeArea`，就會進場高一列然後縮回去。**解**：全螢幕沉浸的畫面不要包 `SafeArea`，改用純 `IgnorePointer`。
- **教訓**：**`SafeArea` 的 inset 在沉浸模式下是會變的量，不是常數。** 只要 `initState` 之後才切沉浸，第一幀跟穩態就不一致。這種「只在進場時出現一次」的差異，靜態分析與截圖都抓不到，只有真的進出畫面才看得見。
- **Commit**：`dac11d6`

## [來源清單快捷鍵] R-Shop: 停用／移除／目前顯示原本都得先開選單，改成清單上直接按 ✨ 功能新增（非修復）

- **檔案**：`lib/features/settings/sources_screen.dart`（`additionalShortcuts` 三個綁定、`_SourceShortcutIntent`／`_SourceShortcutAction`、`_focusedSourceId`／`_focusedSource`、`_confirmRemoveSource`、`_buildHud`、`_Header` 計數列）· `lib/l10n/app_*.arb`（七個語系各 5 個新字串）· `test/widgets/sources_screen_test.dart`
- **需求**：使用者要「停用／移除／使用中」在**來源清單上就能按**，不要每次都先進動作選單。
- **綁定**：`[X]` 目前顯示（與動作選單標頭同一顆，語意一致）· `L1` 停用／啟用 · `R1` 移除。三個都同時出現在 HUD 上，而 **HUD 的每個提示本身就是可點的按鈕**——手把與觸控各自都走得完，符合雙入口規則。
- **L1／R1 是全域搶來的**：`app_actions.dart` 把 L1/R1 綁在 `AdjustColumnsIntent`（格線欄數）。`ScreenActionsWrapper` 把 `additionalShortcuts` **展開在預設之後**，所以本畫面覆蓋得掉，其他畫面不受影響。
- **一定要擋浮層**：動作選單自己吃掉 `[X]`，但**沒有任何東西處理 L1/R1**——不擋的話浮層開著時按下去會作用在看不見的那張卡上。`_SourceShortcutAction.isEnabled` 用 `overlayPriorityProvider == OverlayPriority.none` 擋掉，跟 `_GridNavigateAction` 同一套判準。
- **移除要先問**：`_removeSource` 原本**完全沒有確認**。在選單裡要三次刻意的按壓才點得到，勉強可以；掛到 `R1` 之後變成一鍵，所以補了 `showConsoleDialog`。訊息據實寫：清單會消失，但**已下載到裝置上的遊戲會保留**——`purgeOrDetachSource` 對檔案還在的那些是 `detach`（把 `provider_config` 設 NULL）而不是 delete。
- **焦點要自己記**：HUD 的字要跟著焦點那張卡變（停用／啟用、只看這個／看全部），但**焦點變動不會觸發 rebuild**。所以在 `_focusFor` 建節點時掛 listener 記進 `_focusedSourceId`。**只在取得焦點時寫，失焦不清**——卡片之間移動會經過一個誰都沒有焦點的瞬間，清掉的話每按一次方向鍵 HUD 就閃一次。
- **順手修掉的中文化漏洞**：標題副標原本是 `'$count source${count == 1 ? "" : "s"} · [Y] add new'` ——**寫死英文，又把 `[Y]` 寫死在字串裡**（裝置支援三種手把配置，按鍵名不能寫死）。改成 `sources_countLabel`，按鍵名交給 HUD 依 `ControllerLayout` 繪製。標題本身依使用者要求改成「來源清單」。
- **後續改名**：使用者說「只看這個／看全部 這功能應該叫做 **目前使用這個** 而不是看全部」。他從頭到尾用的詞是「使用」不是「顯示」——他一次只用一個來源，所以「看全部」根本不在他的模型裡。改成 `sources_useThisShort`（目前使用這個）／`sources_stopUsingShort`（取消使用），卡片徽章 `sources_activeSource` 從「目前顯示」改成「**使用中**」（這是他自己在需求裡用的字）。**ARB 的 key 也一起改**，因為 `viewOnly`／`viewAll` 已經描述錯了。順帶查到 `sources_useThisSource`／`sources_showAllSources` 兩個 key **在 Dart 裡已經沒有任何使用**——眼睛搬到列上時選單那兩列就拿掉了，字串留著沒清。
- **驗證**：`analyze` 無新增問題；`sources_screen_test.dart` 9 項全過（新增 3 項：三個提示都在、停用的來源顯示「啟用」、沒有焦點時不顯示）。HUD 從 2 顆變 5 顆，1080×1920@369dpi 橫向邏輯寬約 832，估算約 460 不會溢位，且 `ControlButton` 的文字有 `maxWidth` + ellipsis 保底。
- **Commit**：見下

## [使用中與顯示分家] R-Shop: X 要按兩次才取消；而且「在看哪一個」跟「用哪一個」本來就不該是同一件事

- **檔案**：`lib/models/config/app_config.dart`（新增 `primarySourceId`／`primarySource`／`clearPrimarySource`） · `lib/services/sources_notifier.dart`（`setPrimarySource`、`_writeAndPublish` 的 `setPrimary`） · `lib/services/source_failover.dart`（`resolveForSync` 改讀 primary） · `lib/features/settings/sources_screen.dart`（拿掉 `_activeSourceId` 鏡像） · `lib/features/home/home_view.dart`（橫幅顏色、`_cycleActiveSource` 註解） · `test/active_source_test.dart` · `test/source_failover_sync_test.dart`
- **現象**：使用者說「為啥我會按了 目前→取消→取消 變兩次取消的流程」。
- **根因**：`sources_screen` 用 `_activeSourceId ??= storedActive` 從設定檔種值。**`??=` 表達不了「刻意是 null」**——按下取消之後欄位變成 null，下一次 build 又從設定檔種回原本的 id（而且此時 `invalidate` 還沒回來，讀到的是舊值），所以標籤又變回「取消使用」，得再按一次。**解：整個鏡像欄位拿掉**，畫面上每個標籤都直接讀設定檔。卡片上的徽章本來就是直接讀的——所以 HUD 跟徽章其實一直可能不一致，只是先前沒被注意到。
- **使用者接著提出的分家**：「一個是**使用中**（主畫面預設顯示 以及 同步的），一個是**顯示**（顯示在主畫面 可以切換選擇的），是兩種功能」。
- **做法**：`AppConfig` 加 `primarySourceId`。
  - `activeSourceId` 維持原意＝**顯示**（主畫面 L2/R2 切的那個）。這樣**不必動顯示路徑**——顯示是靠 `_writeAndPublish` 依 active 重寫 `system.providers` 生效的，改成執行期覆寫要動到整條讀取鏈。
  - `primarySourceId` ＝ **使用中**：同步的目標；設定它時順帶把顯示也指過去（「主畫面預設顯示」）。
  - `resolveForSync` 改讀 `primarySourceId ?? activeSourceId`。**`?? activeSourceId` 是舊設定檔的相容路徑**，`fromJson` 也做同樣的回填，所以沒有遷移步驟。
  - 來源清單的 `[X]`／眼睛／徽章一律指 **使用中**；主畫面的 L2/R2 只動 **顯示**。
- **橫幅多了一個訊號**：顯示的來源就是使用中的那個才是綠色，切走了變灰。不然「我在看 A，但同步跑去 B」完全看不出來——這正是分家之後才可能出現的困惑。
- **驗證**：`analyze` 無新增問題。完整 `flutter test` 1753 passed / 7 failed，**7 個與既有基準完全相同**（見 `[R-Shop 測試基準]`）。新增 10 項測試，其中「一次按壓就清掉，沒有第二次取消」直接釘住這次的 bug。
- **兩個功能都要進來源清單**：使用者接著說「來源清單那邊 增加的功能是 **是否顯示** 跟 **使用中** 兩個」。分家之後「顯示」只剩主畫面的 L2/R2 能改，等於又變成「要跑去別的畫面」——正是最早那條抱怨。
  - 卡片上放**兩個圖示**：**眼睛＝顯示**（`activeSourceId`）、**打勾＝使用中**（`primarySourceId`）。**兩個功能不能用同一個圖示**，否則使用者又回到分不清的狀態；動作選單標頭那顆也從眼睛改成打勾（那裡指的是使用中）。
  - 按鍵：`L2` 顯示這個／顯示全部。**選 L2 是因為主畫面就是用扳機切顯示的**——同一個動作，換個畫面還是同一顆。`[X]` 維持使用中。
  - HUD 因此變成六顆（返回／新增來源／顯示／使用中／停用／移除）。
- **再一次修正：眼睛是複選不是單選**。使用者說「**有眼睛就代表都可以看到，所以是選填功能**，不用再顯示全部這個文字，而是 主畫面顯示」。我原本把眼睛接到 `activeSourceId`（單選），錯了。
  - 改成 `Source.showOnHome`（bool，預設 true，持久化）。**每個有眼睛的來源都會出現在主畫面，可以同時多個。**
  - `providersFor` 的過濾規則：**只有在沒指定來源時才套用可見性**。指定了來源就是刻意指定的——**使用中的來源被隱藏時，同步還是要照跑**，不然「隱藏」會變成偷偷停掉同步。
  - **隱藏不清快取**（`setEnabled(false)` 才清）。這是「隱藏」與「停用」唯一的差別，也是使用者按眼睛時預期能按回來的原因。
  - 隱藏當下正被單獨檢視的那個來源時要把 `activeSourceId` 清掉，否則主畫面被收窄到一個不該顯示的來源，會整片空白。主畫面的 L2/R2 環也跳過隱藏的來源。
  - 提示文字固定一句 `sources_showOnHome`（中文「**主畫面顯示**」）。**複選不需要方向性文字**——列上的眼睛本身就說明了現在是開還是關。舊的 `showThisShort`／`showAllShort` 移除。
- **橫幅在只剩一個可見來源時收起來**：使用者說「當顯示只剩一個 並且 是使用中，主畫面就不用 顯示全部來源 的文字了」。原本只判斷 `sources.length < 2`，所以兩個來源關掉一個之後，橫幅還在，而且寫著「全部來源」——**那句話本身就是錯的**，畫面上只有一個來源，只是它剛好是全部可見的。改成：可見來源只剩一個且它就是使用中的那個 → 整條收起來；可見只剩一個但不是使用中的 → 橫幅留著並**寫出它的名字**，不寫「全部來源」。
- **「全部來源」這句話整個拿掉**：使用者說「**永遠不用出現 全部來源 這個文字**」，並且「橫幅收起來 那行應該就可以不見，不然他又會跟移動後的高低不一致」。
  - 橫幅的職責改成**只寫一台伺服器的名字**。沒有單一一台可寫時（多個來源同時顯示、沒有單獨選擇）就**整行消失**，不寫佔位字。
  - 收起來一律 `SizedBox.shrink()`——**零高度，不是空白列**。留一條空白條會讓下面的東西依狀態差一行，正是先前那個高度不一致。
  - `sources_allSources` 因此變成死字串，連同先前查到的 `sources_useThisSource`／`sources_showAllSources` 一起從七個語系刪掉。
- **我把橫幅收得太過頭**：上一輪為了拿掉「全部來源」，我讓「多個來源同時顯示、沒單獨選一個」也收起橫幅。使用者回報「**我明明都顯示了 但是我的橫幅文字卻消失了**」「**顯示在主畫面有選的話 主畫面橫幅都要出現**」。
  - 規則改成：**只要有任何一個來源開著眼睛，橫幅就在**。只有一個都沒開才收（`SizedBox.shrink()`）。
  - 多個同時顯示時**把名字列出來**（`A · B`），不是佔位字。這是實話——畫面上就是那幾個。
  - 這樣高度也穩定了：使用者問「原始 移動時候 到底是 有橫幅那行還是沒有」，答案現在是**一直都有**。
- **選使用中會強制打開眼睛，取消不會關掉**：使用者原話。**同步一個看不到的來源不是一個值得存在的狀態**；反過來，放棄指派並不代表不想再看它，**偷偷把別人沒要求隱藏的東西藏起來是比較糟的那個猜測**。
- **`showOnHome` 整個收回去**：使用者說「**你的停用 啟用 不就是眼睛嗎 = = 不用再做一個**」。對——`enabled` 為 false 的來源本來就不會出現在主畫面也不會同步，我等於做了第二個一樣的開關。
  - `Source.showOnHome` 刪除，`setShowOnHome` 刪除，`L2` 綁定刪除，`sources_showOnHome` 七語系刪除。
  - **卡片上的眼睛改成 `enabled` 的開關**，`L1` 停用／啟用維持不變（同一件事的按鍵入口）。`setPrimarySource` 改成把 `enabled` 打開。
  - 代價要記住：**眼睛關掉會清掉那個來源的快取清單**（`setEnabled(false)` 一直都會清），再打開需要重新同步。這是併回 `enabled` 的必然後果。
- **主畫面進場多一列空白**：使用者說「一開始兩行(有一行空白行) 但是移動後 變成一行」。不是橫幅——是 `home_grid_view.dart` 的 `top: rs.safeAreaTop + 40.0`。**沉浸模式在 `initState` 才切，第一幀還有狀態列 inset**，跟先前橫幅那次是同一個成因，只是換一個地方。改成固定 `40.0`。
  - **教訓：這個專案裡任何 `rs.safeAreaTop` 都要懷疑。** 全螢幕沉浸之下它不是常數。
- **RA 設定頁的白框貼著字**：`ra_onboarding_screen.dart` 的 `_textBox` 把 `ConsoleFocusable` 直接包住 Column，焦點白框緊貼標籤與輸入框自己的邊框，兩條線差幾個像素，看起來像畫錯而不是焦點。加內距 `fromLTRB(8,6,8,8)` 並把 `borderRadius` 提到 12。
- **切換會 lag**：使用者說「在來源清單 切換啟用 跟使用 時 會 lag」。兩個成因：
  - **UI 在等磁碟**：畫面的標籤讀 `bootstrappedConfigProvider`，而切換後要 `invalidate` 再等重新讀檔；**在那之前 `valueOrNull` 回的還是舊值**，所以按下去看起來沒反應。解：`SourcesState` 加上 `primarySourceId`／`activeSourceId` 兩個鏡像，`_writeAndPublish` 設 state 時一起發佈，畫面改讀 notifier——同一幀就更新。
  - **清快取擋在路上**：`setEnabled(false)` 會 `await _purgeCachedGamesFor`，那支要走過該來源每一筆快取並對每筆做 `File.existsSync`。改成 `unawaited`——`updateSource` 已經先把 providers 重寫掉了，被關掉的來源在第一筆被碰到之前就已經不在任何查詢裡，清除只是後續整理。
- **停用→啟用第二次按會停頓**：使用者原話「啟用後在停用 在起用 會停頓一下」。上一輪只把清快取改成不擋，**但快取還是被清掉了**——所以重新啟用時整份清單要重抓，那才是停頓。而且清除在背景跑，使用者手快的話**會刪掉剛重抓回來的資料**。
  - **改成停用完全不清快取。** 當初清除的理由是「不然格線還會顯示剛關掉的來源」，那在 schema v14 之後就不成立了：每筆列按路線存，讀取一律走該系統當下的 providers，**停用的來源不在 providers 裡，那些列根本不會被查到**。
  - 唯一直接讀表不走 providers 的是圖書館頁（`getAllGames`），所以過濾改在那一側做：`provider_config.sourceId` 屬於已停用的來源、而且檔案不在裝置上，就跳過。**已經下載到裝置上的照樣列出**——它就在機器上，跟來源開不開無關。
  - `removeSource` 仍然清除，那個來源不會回來了。
- **環裡多一個 A+B**：使用者原話「為什麼 主頁面的 來源 有A 有B 卻還有A+B」。L2/R2 的環原本是 `全部 → s1 → … → sn → 全部`，第 0 格代表 `activeSourceId = null`＝合併顯示所有來源。兩台就走成 A → B → A+B——**那個 A+B 不是清單上的任何一個來源**。
  - 環改成只有來源本身，拿掉第 0 格。沒選過或 id 失效時，第一次按直接落在第一個（反向則落在最後一個）。
  - 光拿掉環還不夠：**開機時 `activeSourceId` 若是 null 而開著的來源超過一個，畫面本來就是合併的**。所以 notifier bootstrap 加一段正規化，落在 `primarySourceId ?? 第一個開著的`。**只有一個來源時維持 null**——那時 null 的意思是「就這一個」，沒有東西可以合併。
  - 橫幅因此不再需要用 `·` 串名字，那段拿掉。
- **測試基準的教訓（再一次）**：完整套件先跑出 8 個失敗，其中 `game_list_controller: restoreFilters` 看起來像回歸；單獨執行也失敗一次，我一度判定是我改壞的。**但接著連跑三次都通過**，完整套件重跑也回到 7 個。**單次的隔離執行不足以認定回歸**——這個測試就是既有紀錄裡點名的時序敏感型之一。
- **Commit**：見下


## [R-Shop 自動選最快] R-Shop: 「自動挑最快的那條路線」在現行前提下沒有意義，決定不做

> ⚠️ **這條的結論已被 `[R-Shop 路線各自驗證]` 與 `[R-Shop 自動選最優路線]` 推翻，2026-08-05。**
> 底下的推理沒有錯，**錯在前提**：當時把「兩個位址」一律當成兩個來源，所以替使用者換一條路
> ＝替他換一個來源。使用者後來確認的前提是——**同一個來源底下的多條路線就是同一台伺服器**
> （只是各自需要登入），清單也收斂成一份。在那個前提下換路線**換不到別的清單、也換不掉他選的來源**，
> 不變式 2 與 3 都沒有被碰到，所以自動選最快是可以做的，而且已經做了。
>
> **「同一台也當不同台」仍然成立**——它管的是**來源之間**，不是同一個來源底下的路線之間。
> 這兩件事當初被混為一談，這條紀錄就是那次混淆的產物。**要看現行行為請讀
> `[R-Shop 自動選最優路線]`，不要照這條。**

- **問題**：待辦裡掛著「自動選最快的那條路線」——多個位址時由程式探測延遲、自己挑最快的那個。使用者提過，但當時就決定先不做，理由沒有寫下來，所以每次讀交接都會再想一次「這條到底還要不要做」。
- **修復**：不做，並把理由寫進紀錄。前提是使用者的原話「**就算是同一台，我也要當不同台**」（`.agents/skills/rshop-source-routing`「使用者要的到底是什麼」那節）。來源一律各自獨立，**與背後是不是同一台伺服器無關**——這是他的模型，不是可以從 URL 推論出來的東西。
- **檔案**：無程式碼變更（需求判定）

「自動挑最快」預設兩個位址是**同一份東西的兩條路**，程式因此有權替使用者換一條。但在「同一台也當不同台」之下，換一條路等於**替他換了一個來源**——那是他明確要自己決定的事（`activeSourceId` 的存在就是為了這個）。所以這不是「還沒做」，是**做了會違反不變式 2 與 3**。

真正需要自動換路的情境已經有東西在做了：連不上時走**備援**（`chooseSource` / `withEffectiveSource`），而備援刻意**只改記憶體中的 config、不寫磁碟**，所以偏好的那台醒過來就自己回去。速度不是那條路的觸發條件，**可達性才是**——這也是對的，延遲高一點跟連不上是兩件事，只有後者值得替使用者做決定。

**要重開這條的唯一理由**：使用者哪天改變「同一台也當不同台」的前提。在那之前把它留在待辦只會讓每個工作階段重新評估一次。

> **後記**：前提真的改了——不是他推翻了「同一台也當不同台」，是我們發現那句話講的是**來源之間**，
> 而「路線」這一層從頭到尾都在同一台伺服器裡面。條件觸發了，這條就重開並做掉了。
> **一條寫清楚重開條件的「不做」是有用的**：它讓下一次的判斷變成核對條件，而不是重新辯論一遍。

## [R-Shop 反查不到] R-Shop: `build_fix_by_file.py` 每次都報 2 條沒有路徑，那是正確狀態不是漏洞

- **問題**：`python scripts/build_fix_by_file.py` 收尾時固定印出 `entries without paths: 2`，看起來像有兩條紀錄漏了 `**檔案**` 欄。
- **修復**：不用補。那兩條是 `R-Shop 測試基準` 與 `R-Shop 實機重裝`，**本來就沒有程式碼變更**，`**檔案**` 欄寫的就是「無程式碼變更」。實跑確認 `files: 29　entries without paths: 2`，數字與內容都與紀錄相符。順手改掉腳本裡誤導的那句話，讓它不必靠交接文件解釋。
- **檔案**：`scripts/build_fix_by_file.py`（「尚未指明檔案的條目」那段的說明字串）

反查表的用途是「**我要改這個檔，它身上以前發生過什麼**」。沒有動到任何檔的紀錄（環境診斷、部署作業、需求判定）**在這張表上本來就無處可去**，不是資料缺失。原本的說明寫「缺漏或標為待補，所以無法反查。**補上之後重跑即可**」——那句話對這幾條是錯的，等於每個工作階段都被指示去補一個不該存在的東西，交接文件為此還得反過來澄清一次。改成點名「多數是正確狀態」，只有「待補」才是真的欠。

**這個數字不會歸零，也不該當成待辦。** 寫完上面那條 `[R-Shop 自動選最快]`（純需求判定，沒有程式碼變更）之後，它就從 2 變成 3。所以基準值會隨著這類紀錄增加而往上走，**只要對照最後新增的那幾條即可，不必整檔掃**。


## [R-Shop 路線各自驗證] R-Shop: 憑證跟著路線走，清單跟著來源走（schema v15）

- **問題**：一個來源底下的多條連線方式（區網直連、DDNS）**共用同一組憑證**——`auth` 掛在 `Source` 上，路線沒有自己的。使用者實際的設定是同一台伺服器、但兩個位址**各自需要驗證**，所以他只能拆成兩個來源才會動，而拆成兩個來源又拿到了兩份各自同步的清單。同時「連線方式手動切、來源自動備援」剛好是反的：**該自動的那個是手動，比較該由他決定的那個反而自動**。使用者原話：「不覺得功能重複了嗎?」
- **修復**：`SourceEndpoint` 加自己的可選 `auth`，沒設就沿用來源層的（舊設定檔零遷移）；`Source.auth` 改成 getter `liveEndpoint?.auth ?? _defaultAuth`，下游照樣只讀這一個。清單反過來收斂：schema v15 把唯一鍵從 `(systemSlug, filename, source_id, endpoint_id)` 改成 `(systemSlug, filename, source_id)`，`endpoint_id` 留著只記「上次從哪條路抓的」。
- **檔案**：`lib/models/config/source.dart`（`SourceEndpoint.auth`／`hasOwnAuth`／`Source.auth` getter／`defaultAuth`）· `lib/services/sources_notifier.dart`（endpoint 增刪改帶憑證）· `lib/services/database_service.dart`（v15 遷移與去重、`getGameCountsPerSource`／`getGameCountForSource`／`deleteSourceCache`）· `test/database_service_v15_migration_test.dart`（新增）· `test/database_service_routes_test.dart`（改寫）· `test/source_endpoint_test.dart` · `test/source_resolver_test.dart` · `test/sources_notifier_endpoints_test.dart`

**整個設計就兩句：憑證跟著路線走，清單跟著來源走。** 這兩句是反方向的，而反方向才是對的——路線之所以是不同的路線，就是因為它們的**入口**不同（不同的前門、不同的登入）；而它們之所以是同一個來源的路線，是因為門後面是**同一台機器、同一份清單**。舊設計把兩者都綁在同一層，所以兩邊都錯。

**我原本打算「讀取時把兩份清單合併」，那是錯的解。** 使用者一句話點掉：「你覺得清單只有一份 你分的出來嗎」。要寫合併邏輯，就表示分裂本身不該存在。**程式分不出兩個位址是不是同一台，也不該去猜**——先前從埠號推論過一次，推論是對的，但那不算數。能宣告這件事的只有使用者，這就是「同一台也當不同台」的真正意思：**預設不猜，他宣告了才照宣告走**。他宣告了，清單就是一份。

**`connectionKey` 刻意不含憑證，查證後確認是對的。** 我一開始要求把憑證算進去，理由是「換路線換 token 時它必須跟著變，否則會重用錯的連線」。實際上它只用在舊設定檔的合併遷移（`app_config.dart:209` 是唯一呼叫點，**runtime 沒有任何連線快取用它**），而同一個位址不論當初存的是哪組登入都該收成一個來源——folding 進去反而會把它們拆回兩個。它本來就每換一條路就變，因為 `sameAddressAs` 不准同一個來源有兩條位址相同的路線。

**v15 去重唯一有資料風險的地方**：`games` 表沒有本機路徑欄位，安裝狀態是從檔案系統推的，而遷移不能做那種 IO。表內唯一的訊號是 `purgeOrDetachSource` 留下的狀態（`provider_config` / `url` 被清空——那種列的存在本身就代表檔案在磁碟上找到過）。判準收在 `_v15OnDeviceRank`，換訊號只要改那一行。去重用 self-join 找**輸家**而不是找贏家，配一個全序（先看是否在裝置上，再看 `id` 最小），所以每組必定恰好活一筆；刪之前先把 `cover_url` / `has_thumbnail` / `alternative_sources` 從同組撿回來。最後還有一道 `NOT IN (SELECT MIN(id) …)` 保險並記 log——**留下任何一筆重複都會讓 `CREATE UNIQUE INDEX` 拋例外，而每次啟動都拋例外的遷移等於資料庫再也打不開**。

`deleteRoute` 改名 `deleteSourceCache` 不只是換字：**刪一條路線現在不准順手刪快取**，舊名字會讓人以為要。

**未完成的部分見 `docs/HANDOVER.md` §2.0**——自動選最優路線、UI、七語系都還沒做。


## [R-Shop 自動選最優路線] R-Shop: 探測改回延遲並排序，沒有覆寫就自己挑最快的那條

- **問題**：`EndpointProbeService` 只回「通不通」，所以「自動」等於「清單裡第一條通的」——使用者要用最快的那條就得自己去挑，而挑了之後 `pin: true` 又把它永久固定住，網路換了也不會變。同時路線各自驗證的資料層已經完成，UI 卻還沒有地方輸入路線自己的憑證，功能等於沒接上。
- **修復**：探測改回延遲：`probeFor()` 給 `ProbeResults`（`ranked` 最快在前、`latencyOf(id)`、`fastestId`），`resolve()` 在沒有覆寫時挑能通的裡面最快的；`pin: true` 的語意從「選定」改成「**使用者覆寫**」，浮層加一列「自動」走 `clearEndpointOverride`。連線方式編輯頁補上路線自己的登入欄位（留空＝沿用來源的），浮層每一列顯示延遲、最快、使用中、已鎖定、專屬登入。
- **檔案**：`lib/services/endpoint_probe_service.dart`（`ProbeResults`／`RouteLatency`／`probeFor`） · `lib/models/config/source.dart`（`resolveEndpoint` 改吃排序後的 `List<String>`） · `lib/services/sources_notifier.dart`（`autoSelectEndpoint`／`clearEndpointOverride`／`autoSelectAllEndpoints`、bootstrap 離線對齊） · `lib/features/sources/endpoint_picker_overlay.dart`（延遲欄、自動列、徽章） · `lib/features/sources/endpoint_edit_screen.dart`（路線憑證欄位＋繼承說明） · `lib/l10n/app_*.arb`（10 個新 key，`sources_routeAutoHint`／`sources_routeSameServerHint` 改寫） · `test/endpoint_probe_service_test.dart` · `test/source_endpoint_test.dart` · `test/sources_notifier_endpoints_test.dart` · `test/widgets/endpoint_picker_overlay_test.dart`（新增）

**這條做的事，`[R-Shop 自動選最快]` 當初判定「不做」。** 不是那次判斷草率，是**前提真的變了**：當時把「兩個位址」一律當成兩個來源，換路＝替使用者換來源；`[R-Shop 路線各自驗證]` 之後，同一個來源底下的路線就是同一台伺服器、同一份清單，換路換不到別的清單也換不掉他選的來源。**「同一台也當不同台」管的是來源之間，不是路線之間**——這兩層被混為一談，才生出那條「不做」。舊紀錄已加註取代，不要照它。

**`resolveEndpoint` 吃的是排序後的 id 清單，不是延遲。** `lib/models` 不准 import 服務層的型別，這是一個理由；更實際的理由是**傳清單比傳「最快的那一個」多一層韌性**——探測到套用之間那條最快的路被刪掉時，會自動退到第二快，傳單一 id 就只剩清單順序可退。

**`_bootstrap` 不探測，是刻意的。** 開機不能等網路，而且測試裡建一個 notifier 就會開真的 socket。它只做離線對齊：釘選指向不存在的路線就退回 `auto`，有效的釘選把值鏡回頂層欄位（不變式 4），真的有變才寫磁碟。

**`autoSelectEndpoint` 探測完會重讀一次狀態才動手。** 探測那一秒內使用者可能剛好按下釘選，不重讀就會把他的覆寫蓋掉——**自動化蓋掉使用者剛做的決定，比自動化沒生效更糟**。

**順手修掉一個既有的競態**：被整體預算放棄的探測，原本仍可能把自己加進**已經回傳且已經寫進快取**的那個 `Set`，於是「這條路通」會在快取裡憑空出現。現在結果先快照再進快取，並補了測試。

**UI 兩個入口**：浮層每一列的 `onTap` 走 `_tapRow`，它先把游標移過去再呼叫 `_activate()`——**跟按 `[A]` 完全同一條路徑**，不是各寫一份（`rshop-touch-and-gamepad` 的鐵則；這四個浮層每一個都曾經是觸控死的）。新增的 widget 測試就是在測這件事。

**憑證欄位留空必須產生 `null`，不是空的 `AuthConfig`。** `hasOwnAuth` 只問物件在不在，空物件會宣稱「這條路線用自己的登入，而且沒有帳密」——那會讓一個本來繼承得好好的路線變成 401。`_authOrNull()` 就是為這件事存在的。畫面上還即時顯示現在是「沿用來源的登入資訊」還是「用自己的」，因為「空白＝繼承」是一條**看不見的規則**，只寫在說明裡不夠。


## [R-Shop onboarding 五語系缺字串] R-Shop: `DE has all EN keys` 一直紅，是真的缺字串不是環境問題

- **問題**：`test/l10n_completeness_test.dart` 的 `DE has all EN keys` 長期失敗，混在「7 個既有失敗」裡被當成環境問題略過。實際上 `onboarding_folderExplanationTitle`／`onboarding_folderExplanationMessage`／`onboarding_continueToPicker` 只有 en 與 zh 有，**de / es / fr / ja / pt 五個語系全缺**——使用者在那五個語系下看到的是空白。
- **修復**：五個 `.arb` 各補三個 key，位置與 en 一致。順便拿 en 的 key 集合對六個語系全掃一次，確認沒有別的缺口。
- **檔案**：`lib/l10n/app_{de,es,fr,ja,pt}.arb` · `test/l10n_completeness_test.dart`（區域函式 `_translationKeys` 改名，清掉 analyze 的 info）

**教訓在「既有失敗」這個標籤本身。** 一旦某個失敗被寫進交接的「已知不修」，之後每個工作階段都會直接跳過它——**包括它其實是真的壞掉的那一個**。這次是交接文件自己點名「它是真的缺，不是環境問題」才沒有繼續被略過。所以基準清單裡的每一條都該寫**為什麼**它不算回歸（Windows socket、Windows 路徑、需要真的伺服器），寫不出理由的那條就是還沒查清楚。

**缺字串不會讓建置失敗，會直接出貨成空白**（`rshop-l10n`）。這也是為什麼字串要跟功能同一次補齊，而不是「之後補」。


## [R-Shop analyze 六項] R-Shop: 清掉累積的 6 個 analyze 問題，含兩處已棄用的 `cacheExtent`

- **問題**：`flutter analyze` 長期帶著 6 個問題：2 個未使用的 import、2 個未使用的區域變數、2 處已棄用的 `cacheExtent`。不是某一次改動造成的，但沒人清，於是每次跑 analyze 都要先分辨「這 6 個是舊的」。
- **修復**：全部清掉。`cacheExtent: X` 改成 `scrollCacheExtent: ScrollCacheExtent.pixels(X)`，兩檔各補 `import 'package:flutter/rendering.dart'`（`material.dart` 沒轉出 `ScrollCacheExtent`）。現在 `flutter analyze` 是乾淨的。
- **檔案**：`lib/features/onboarding/widgets/romm_legacy_login_screen.dart` · `lib/features/sources/manual_source_add_screen.dart` · `lib/features/onboarding/widgets/welcome_chooser_step.dart` · `lib/widgets/console_dialog.dart` · `lib/features/game_list/widgets/game_grid.dart` · `lib/features/library/library_screen.dart`

**`.pixels()` 不是 `.viewport()`，這個選擇有理由。** Flutter 3.41 起 `cacheExtent`（double，邏輯像素）換成 `ScrollCacheExtent`，兩個 factory 的**單位不同**：`.pixels(double)` 與舊的完全等價，`.viewport(double)` 是 viewport 主軸長度的倍數。這兩處的值來自 `device_info_service.dart` 依記憶體分級算出的像素值（格線 200/400/600、圖書館 300/600/800），**本來就是以像素為單位設計的**，換成 `.viewport()` 會把分級意圖整個破壞掉。SDK 自己的相容轉接也是 `ScrollCacheExtent.pixels(cacheExtent!)`。

**`console_dialog.dart` 刪掉未使用的 `rs` 之後，`responsive.dart` 的 import 跟著變成未使用**——只清一半會換來一個新 warning。焦點白框的樣式完全沒動：那份樣式同時存在於這個檔與 `core/widgets/console_focusable.dart`，**動一邊就會兩邊不同步**（`AGENTS.md` §3）。

## [R-Shop 來源群組] 「備援」換成群組：幾個來源是同一台，就只有一份清單

- **問題**：使用者要的不是備援。他的話是「應該不是備援 而是 我想指定兩個來源 其實是指向同一台伺服器，那它們可以選擇誰優先 或著自動」「應該是設成群組」「因為同一群組 應該實際是同一台之類 所以清單也只需要一份」。舊的 `fallbackSourceId` 是單向配對，他上一輪就抱怨過功能重複（「不覺得功能重複了嗎?」）。
- **修復**：`SourceGroup`（成員有序、模式 `auto`／`ordered`）取代備援；`games` 表加 `cache_owner_id`，唯一鍵從來源改成擁有者，一個群組只存一份清單；notifier 補齊群組 CRUD，每個動作都同時把快取安置好；畫面上「備援」整個消失，換成群組編輯浮層與連線方式浮層的「照我排的順序」。
- **檔案**：`lib/models/config/app_config.dart`（`SourceGroup`／`sourceGroupsFromFallbacks`／`sanitizeGroups`／`cacheOwnerIdFor`／`collapsedSources`） · `lib/services/database_service.dart`（schema v16、`_collapseDuplicates`、`adoptCacheInto`／`moveCacheOwnership`／`releaseCacheFrom`、`purgeOrDetachSource` 的 `protectedOwnerIds`） · `lib/services/sources_notifier.dart`（群組 CRUD、`ordered` 分支、`reorderEndpoints`／`moveEndpointTo`／`useOrderedSelection`） · `lib/services/source_failover.dart`（`chooseSource`／`resolveForSync` 走群組） · `lib/services/endpoint_probe_service.dart`（`resolve()`） · `lib/features/sources/group_picker_overlay.dart`（新增，取代刪掉的 `fallback_picker_overlay.dart`） · `lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart` · `lib/widgets/sync_badge.dart` · `lib/features/game_list/{game_list_screen.dart,logic/game_list_controller.dart}` · `lib/services/library_sync_service.dart` · `lib/l10n/app_{de,en,es,fr,ja,pt,zh}.arb` · `test/{database_service_v16_migration,sources_notifier_groups,widgets/group_picker_overlay}_test.dart`

**遷移為什麼一列都不刪。** v16 只加欄位、把 `cache_owner_id` 從 `source_id` 一對一補上、換索引。合併留給 `adoptCacheInto`，因為群組住在設定檔裡、資料庫層讀不到——在遷移裡猜使用者分了哪些群組，就是憑猜測刪列。舊的配對照樣自動變成群組，但那發生在 `AppConfig.fromJson`（`sourceGroupsFromFallbacks`），而且群組的擁有者就是配對的排頭，所以既有安裝**一次也不用重新同步**。

**去重判準沒有另發明。** `_v15OnDeviceRank` 改名 `_onDeviceRank`（現在不只 v15 用），規則照舊：已經下載到機器上的那一列贏，因為那是使用者真的擁有的東西，遠端的重抓就有。合併時會**暫時 drop 唯一索引**再重建——重建就是驗證，還有殘留就整筆 rollback，不會留下半合併的圖書館。

**移出群組什麼都拿不到，是刻意的。** 合併之後沒有任何欄位記得哪一筆是哪個成員先看到的，而「這個問題不重要」正是群組的前提。所以要嘛騙人地平分，要嘛老實讓它重新同步——選後者，並且 UI 一定要先問。

**刪掉群組成員時的連坐。** `purgeOrDetachSource` 是用 `provider_config` 的 JSON 比對的，刪掉的成員名字還印在那些列上，即使 `source_id` 已經改蓋成擁有者。所以多了 `protectedOwnerIds`：屬於還活著的群組的列不准動。順便修掉一個舊的過度殺傷——那兩個 UPDATE／DELETE 只比對 `(systemSlug, filename)`，會連別的來源同名遊戲一起清掉。

**群組是對稱的，舊配對是單向的。** 這讓兩個舊測試的前提失效：以前「wan 沒有備援所以原地不動」，現在 wan 和 lan 同在一個群組，選誰都是選那個群組，偏好一律是群組的排頭。測試改成「不在群組裡的來源才原地不動」，另外補一條把新語意釘住。

**兩套入口都做了。** 群組浮層每一列都能點，成員順序有角落的上下箭頭（觸控）也綁 `[X]`／`[Y]`（手把）；連線方式浮層的「照我排的順序」是自己一列（點某條路線一律是釘選＝覆寫，兩件事不能共用同一個手勢），路線順序用 ◀ ▶ 與角落箭頭。這一塊的四個浮層每一個都曾經是觸控死的，所以新的那個一開始就補了 widget 測試盯著。

## [R-Shop 群組合併卡住] 加入群組按下去像當掉——去重的自連結沒有索引

- **問題**：實機上點「與其他來源設成群組…」再選另一個來源，畫面完全沒反應。沒有例外、沒有崩潰，logcat 只有 `database has been locked for 0:00:10`。
- **修復**：`_rekeyOwnership` 為了改寫 `cache_owner_id` 會先 drop 唯一索引，而那個索引正是去重自連結唯一的支撐；補上臨時索引 `idx_games_dedupe_tmp (cache_owner_id, systemSlug, filename)`，結束時 drop 再重建唯一索引。**65k 列從十分鐘以上變成 411 毫秒。**
- **檔案**：`lib/services/database_service.dart`（`_rekeyOwnership` 的臨時索引） · `test/database_service_merge_perf_test.dart`（新增，65k 列的計時守衛） · `lib/features/sources/group_picker_overlay.dart`（`_busy` 擋重入）

v15 的遷移**知道**要建這個臨時索引（那段還寫了註解說明為什麼），v16 的執行期路徑是另外寫的，就漏了。**同一個道理散在兩處實作，第二處一定會忘記**——這也是為什麼去重本身收在 `_collapseDuplicates` 一支裡。

抓到它的方法值得記：實機沒有任何錯誤訊息可查，改用**本機測試重現規模**（seed 65k 列再計時），一次就現形。那個測試留下來了，門檻設 30 秒——有索引是毫秒級、沒索引是分鐘級，中間沒有灰色地帶。順帶：跑失控的效能測試要先設 timeout，砍掉 dart 程序會留下 `build/native_assets/windows/sqlite3.dll` 的鎖擋住下一次測試。

## [R-Shop 群組浮層焦點] 建立群組之後手把不動了

- **問題**：群組建好，浮層還在畫面上，但手把完全沒反應。
- **修復**：來源清單的 `_ensureInteractiveFocus` 會在「沒有卡片持有焦點」時把焦點搶回第一張卡，而它的例外只認得動作選單。寫入群組會重建整個清單，於是焦點被搶走。改成任何浮層開著都不搶（`_anyOverlayOpen`），浮層每次寫入後也自己把焦點要回來。
- **檔案**：`lib/features/settings/sources_screen.dart`（`_anyOverlayOpen`） · `lib/features/sources/group_picker_overlay.dart`（`_reclaimFocus`）

**「焦點不能鎖死」的另一面**：那段搶焦點的程式本身是為了修「刪光來源之後手把失效」而寫的，方向相反但同一個節點。加浮層的人要記得去更新它的例外清單，否則新浮層一律中槍。

## [R-Shop 浮層操作形狀] 游標看不見、模式列會關掉、排序看不出來

- **問題**：實機回報四件——① 群組設定往下走，畫面不跟著捲，看不到下面的項目；② 連線方式選「自動選擇」或「照我排的順序」會直接關掉浮層；③ 從最上面往上繞回「取消」時游標消失，而且取消那列被底下的提示遮住；④ 排序按了看不出有沒有動。
- **修復**：①③ 每一列給 `GlobalKey` 並在移動後 `Scrollable.ensureVisible`（**包含最後兩列**，漏掉就是游標消失的原因），捲動區加下方 padding 讓提示不遮住最後一列；② 模式是設定不是目的地，選了留在原地就地更新，只有選某條路線（＝覆寫）才關閉；④ 移動前後量測該列的 y 座標，用 180 毫秒把它從舊位置滑到新位置。
- **檔案**：`lib/features/sources/endpoint_picker_overlay.dart` · `lib/features/sources/group_picker_overlay.dart` · `test/widgets/{endpoint_picker_overlay,group_picker_overlay}_test.dart`

**按鍵重排也是他要的**：`[A]` 從「切換並鎖定」改成單純「使用這條路線」，鎖定移到 `[X]`，移除移到肩鍵 `[R1]`／`[L1]` 並補確認框；群組的退出同樣移到肩鍵。理由一致：**天天按的動作放最順的鍵，破壞性的動作放遠一點並且先問**。

**排序的互動形狀繞了三圈**：先做成兩個小箭頭（他問「那個箭頭是幹嘛用? 不是應該移除嗎??」）→ 改成點一下跳出動作選單（「我要的移動 不是開視窗 是那邊會有小圖示 我焦點移到小圖示上面」）→ 最後定案：圖示留在列上，▶ 把焦點移上去，按下移動鍵之後上下鍵直接連續排序。**每一列底下加一行說明，並且把 ▶ 這個動作寫進去**——圖示不寫出來就等於藏起來。

## [R-Shop 連線方式對齊群組] 按 A 沒有停在你選的那條，而且游標開在錯的一列

- **問題**：實機回報「連線方式點 `[A]` 還是有問題」。兩件事疊在一起：① 開啟浮層時游標算錯一列——路線列從索引 2 開始（上面多了「照我排的順序」），`_initialIndex()` 卻回 `i + 1`，所以鎖在第一條路線的來源一打開，游標其實停在「照我排的順序」那列，不動就按 `[A]` 等於把整個來源改成 ordered 模式；② `[A]` 在路線列是 `switchEndpoint(pin: false)`，下一次探測可以自己換走，使用者看到的是「我選的那條又跳回去了」。
- **修復**：使用者指定「連線方式參考群組設定那邊的拖移方式跟 `[A]` 的方式」。`[A]`／點擊路線列改成進入移動模式（與群組成員完全相同的手勢），浮層留在原地；`_initialIndex()` 改用 `_firstRouteIndex`，並讓 ordered 模式直接開在 ordered 那列。
- **檔案**：`lib/features/sources/endpoint_picker_overlay.dart`（`_initialIndex`／`_activate`／新增 `_toggleSorting`／HUD 的 `[A]` 標籤／`_actionsForRoute` 的 ≡ 改共用） · `lib/l10n/app_*.arb`（`sources_routeRowHint` 七語系） · `test/widgets/endpoint_picker_overlay_test.dart`

**「使用這條路線」這個動作被拿掉了，不是搬家。** 拿掉是對的：它本來就留不住——不鎖定就等下一次探測，鎖定的話那是 `[X]`。現在三條路各自有明確的入口：要最快的走「自動」，要自己的順序走「照我排的順序」加 `[A]` 排序，要死釘一條走 `[X]` 鎖定。`sources_routeUse` 這個字串因此沒人用了，七個語系都還留著，沒有刪。

**那個差一列的 bug 是加「照我排的順序」那一列時漏改的**，`_initialIndex` 的註解還寫著「開在生效中的那條，所以不動就按 `[A]` 是 no-op」——註解描述的正是它做不到的事。加了 `_firstRoutePinnedSource` 這個 fixture 盯著：鎖在**第一條**路線才踩得到，鎖在第二條只是差一列、看起來像選錯，不會改到模式。

**兩支浮層現在是同一套手勢**：`[A]` 移動、`[X]`／`[Y]` 是各自的第二第三動作、肩鍵是破壞性動作、▶ 走到列尾圖示、≡ 是觸控版的移動、✓ 結束。列底下那行說明改成不寫按鍵字母（`sources_groupMemberHint` 裡寫死的 `[A]` 在 PlayStation 配置下就是錯的，那條先留著沒動）。

## [R-Shop 模式收成打勾] 兩列互斥的模式，其實是一個打勾寫成長的

- **問題**：連線方式與群組兩個浮層都用**兩列互斥**表示只有兩種狀態的設定（自動／照我排的順序）。要關掉「自動」得去點另一列，而「照我排的順序」那一列講的東西底下的清單已經在講了。使用者指示：「移掉照我排序，把自動選擇改成選填、打勾之類，群組跟連線有這個情況都改一下」。
- **修復**：兩個浮層各收成**一列打勾**。勾了＝自動（最快的／先回應的那台），沒勾＝照清單順序。副標依勾選狀態換成原本兩列各自的說明，`Icons.check_box` / `check_box_outline_blank` 當列首圖示，「使用中」徽章拿掉——打勾本身就是徽章。模型層的 `EndpointSelection.ordered` 與 `SourceGroupMode.ordered` **原封不動**，改的只有 UI。
- **檔案**：`lib/features/sources/endpoint_picker_overlay.dart`（`_rowCount`／`_firstRouteIndex` 改 1／刪 `_orderedIndex`／`_activate` 的第 0 列改成切換） · `lib/features/sources/group_picker_overlay.dart`（模式兩列合一、成員索引 `i + 2` → `i + 1`） · `lib/l10n/app_*.arb`（`sources_groupModeAuto` 改成「自動選擇」） · `test/widgets/{endpoint_picker_overlay,group_picker_overlay}_test.dart`

**索引偏移這次改成不寫死**。上一輪才因為 `i + 1` 對不上 `_firstRouteIndex` 而出事，這輪列數又變了一次——同一個地方兩天內漏改兩次，所以 `_initialIndex` 改成一律走 `_firstRouteIndex`，測試也留著 `_firstRoutePinnedSource` 這個 fixture 盯著「開在鎖定的那條，不是開在打勾那列」。**下次再加一列，這裡不用跟著改。**

**沒用到的字串留著沒刪**：`sources_routeOrdered`、`sources_groupModeOrdered`、`sources_routeUse` 三個現在沒有呼叫點，七個語系都還在。刪掉要動 21 個地方而且對行為沒有影響，等哪次順手再說。

## [R-Shop 同步路線解算] resolveForSync 未解算 selected/winner source 的 liveEndpoint 導致多路線來源同步時走預設死路線

- **問題**：當來源具有多條連線路線（例如 LAN IP 與 DDNS）時，`resolveForSync` 雖然能判定該來源「有任意路線通」，但產出的 AppConfig/ProviderConfig 仍維持 `source.liveEndpoint` 的預設位址（例如處於外網時的 LAN IP）。導致 `LibrarySyncService` 在同步時仍連向已死的首選位址而失敗。
- **根因**：`resolveForSync` 僅透過 `svc.reachableFor(source)` 檢查整體可達性，並未將 `svc.resolve(source)` 算出的最新可達 `SourceEndpoint` 套用到內存中的 `Source` 物件。
- **修復**：在 `resolveForSync` 中，於確定選定/備援來源（`choice.source`）後，呼叫 `svc.resolve(choice.source)` 取得最佳可達 endpoint，並透過 `choice.source.withLiveEndpoint(resolvedEp)` 產生更新後的 `Source` 物件，隨後將其替換回 `AppConfig.sources`，使產出的 `ProviderConfig` 具有正確的 URL 與 endpointId。
- **檔案**：`lib/services/source_failover.dart:354-378`（在 resolveForSync 中新增選定來源之 liveEndpoint 解算與 config 替換） · `test/source_failover_sync_test.dart:212-261`（新增多路線來源同步測試）


## [R-Shop 備援架構重構] 移除群組與連線路線，改採多組備援鏈與自動選擇模式

- **問題**：原有的 `SourceGroup`（群組）與 `SourceEndpoint`（連線方式/路線）造成架構過於複雜。使用者指示：「不用群組 也不用連線方式 改用備援 但是備援 可以多組 然後 新增備援的方式跟 被備援的來源 一樣的方式新增」「備援來源是否單獨顯示於主畫面選擇 可以是其他來源 也可以變成獨立來源 備援除了順序 增加一個自動選擇的 選填項」。
- **根因**：舊架構使用雙層抽象（Sources -> Endpoints 與 SourceGroups -> Members），導致管理複雜。
- **修復**：
  1. 重構 `Source` 模型：移除 `SourceEndpoint` / `EndpointSelection` / `SourceGroup`，新增 `fallbackSourceIds: List<String>` 與 `fallbackAutoSelect: bool`。備援來源為獨立的 `Source` 實例，可獨立顯示與切換。
  2. 重構服務層：簡化 `EndpointProbeService` 為單一 Source TCP 探測；重構 `SourceFailover` / `resolveForSync` 支援多組順序備援鏈與併發自動選擇 (Auto-Select) 探測；`SourcesNotifier` 新增備援鏈管理方法。
  3. UI 浮層更新：刪除 `GroupPickerOverlay` 與 `EndpointPickerOverlay`，新增 `FallbackPickerOverlay`，支援勾選「自動選擇」、拖曳/上下調備援順序、刪除備援、新建備援來源與選擇既有來源。
- **檔案**：`lib/models/config/source.dart` · `lib/models/config/app_config.dart` · `lib/services/source_failover.dart` · `lib/services/endpoint_probe_service.dart` · `lib/services/sources_notifier.dart` · `lib/services/source_resolver.dart` · `lib/features/sources/fallback_picker_overlay.dart` · `lib/features/settings/sources_screen.dart` · `lib/features/home/home_view.dart` · `test/source_failover_sync_test.dart` · `test/source_failover_choice_test.dart` · `test/endpoint_probe_service_test.dart`
- **驗證**：單元測試套件執行通過（包含 multi-entry fallback 測試），且透過 `deploy.ps1` 順利打包並實機部署至 AYN Thor 測試（PID 3917, logcat 正常無例外）。



## [R-Shop ƴsب^] sإsƴӷΧ^ӷ]w

- **D**Gbƴ]wBh]FallbackPickerOverlay^Iu+ sإsƴӷvɡAF _fallbackPickerSourceIdC򤣽צbӷܾ [B] BbsWӷ^BΦ\إ߷sӷA|^ӷ]wDM]SourcesScreen^A^ƴ]wBhΦ۰ʸjwsƴC
- **״_**Gb _SourcesScreenState sW _addingFallbackForSourceId lܵo_ƴsتӷ IDCsWAɡA۰ʫ_ _fallbackPickerSourceId ^ӳƴ]wBhF\sWɡA۰ʩIs ddFallbackSource jwsӷí}ƴ]wBhC
- **ɮ**Glib/features/settings/sources_screen.dart]sW _addingFallbackForSourceId AP _addFreshFallbackSource / _closeTypePicker / _addManualSource / _addRommSource / _addRommLegacy _޿^ P 	est/widgets/sources_screen_test.dart]sW fresh fallback _ա^


## [R-Shop 來源停用快取] 停用來源時執行整庫刪除與實體檔案檢查導致畫面卡死

- **問題**：使用者在來源設定頁面停用來源（Toggle Disabled）時，畫面出現極大的 Lag 甚至當掉。
- **根因**：setEnabled(id, false) 在停用時誤呼叫了 _purgeCachedGamesFor(id)。該方法會對資料庫中該來源的數千筆遊戲逐一進行 SD 卡/儲存空間 File.existsSync() 實體檔案檢查與單筆 SQL 刪除，在主執行緒上造成嚴重 UI 卡死與卡頓。且依據專案規範「停用不再清快取」，停用來源只需變更 nabled 狀態，不應清除快取（永久刪除來源 
emoveSource 才需清除）。
- **修復**：從 setEnabled 中移除 _purgeCachedGamesFor 的呼叫。停用來源切換變為 0ms 即時反應，重新啟用來源時亦可即時從快取載入。
- **檔案**：lib/services/sources_notifier.dart（setEnabled 移除快取清理） · 	est/sources_notifier_test.dart

## [R-Shop QR碼手把導覽] QrPairingScreen 掃碼頁不支援手把搖桿切換焦點與按鈕選擇

- **問題**：開啟 QR code 掃瞄頁面（QrPairingScreen）時，手把搖桿/D-pad 無法在「左上角返回按鈕」與「底部手動輸入配對碼按鈕」之間切換焦點；且全域鍵盤監聽強制攔截了 [A] 鍵，導致游標就算停在返回按鈕上按下 [A] 仍會強制跳轉至手動輸入頁面。
- **根因**：_handleScreenKey 寫死了全域 [A] 鍵觸發 _openManual()，且 initState 未指派初始焦點至可聚焦按鈕；畫面缺乏上下方向鍵切換邏輯與 ConsoleHud 手把提示。
- **修復**：
  1. initState 中加入 ddPostFrameCallback 預設聚焦至「手動輸入配對碼」按鈕（_manualFocus），畫面開啟即顯示白色手把焦點框。
  2. _handleScreenKey 移除全域 [A] 攔截，交由 ConsoleFocusable 自身的焦點處理；新增搖桿/D-pad 上/下（rrowUp/rrowDown）方向鍵在 _manualFocus 與 _backFocus 之間的切換邏輯並播放按鍵音效。
  3. 底部加入 ConsoleHud 顯示手把提示 ([B] 返回 · [A] 確定 / 選擇)。
- **檔案**：lib/features/pairing/qr_pairing_screen.dart（手把焦點切換、ConsoleHud 與初始化焦點） · 	est/widgets/qr_pairing_screen_test.dart（新增手把導覽單元測試）

## [R-Shop QR碼手把導覽] QrPairingScreen 掃碼頁不支援手把搖桿切換焦點與按鈕選擇

- **問題**：開啟 QR code 掃瞄頁面（QrPairingScreen）時，手把搖桿/D-pad 無法在「左上角返回按鈕」與「底部手動輸入配對碼按鈕」之間切換焦點；且全域鍵盤監聽強制攔截了 [A] 鍵，導致游標就算停在返回按鈕上按下 [A] 仍會強制跳轉至手動輸入頁面。
- **根因**：_handleScreenKey 寫死了全域 [A] 鍵觸發 _openManual()，且 initState 未指派初始焦點至可聚焦按鈕；畫面缺乏上下方向鍵切換邏輯與 ConsoleHud 手把提示。
- **修復**：
  1. initState 中加入 ddPostFrameCallback 預設聚焦至「手動輸入配對碼」按鈕（_manualFocus），畫面開啟即顯示白色手把焦點框。
  2. _handleScreenKey 移除全域 [A] 攔截，交由 ConsoleFocusable 自身的焦點處理；新增搖桿/D-pad 上/下/左/右（rrowUp/rrowDown/rrowLeft/rrowRight）方向鍵在 _manualFocus 與 _backFocus 之間的切換邏輯並播放按鍵音效。
  3. 底部加入 ConsoleHud 顯示手把提示 ([B] 返回 · [A] 確定 / 選擇)。
- **檔案**：lib/features/pairing/qr_pairing_screen.dart（手把焦點切換、ConsoleHud 與初始化焦點） · 	est/widgets/qr_pairing_screen_test.dart（新增手把導覽單元測試）

## [R-Shop 語系鎖定詞彙統一] 多語系「已鎖定/Pinned」詞彙統一與 Unicode 跳脫清理

- **問題**：sources_routePinned、sources_routeLock、sources_routeUnlock、sources_routeReleasePin 等連線與鎖定相關詞彙在 de/es/pt/ja 語系之間用詞不一致（如 de 混用 Fixiert/festlegen、es/pt 混用 Fijada/Fixada、ja 混用 固定/ロック），且 pp_ja.arb 檔案後半段跳脫格式混用。
- **根因**：過往多語系翻譯分散新增時使用了非標準同義詞。
- **修復**：
  1. 統一德語 (Gesperrt/Sperre aufheben)、西班牙語與葡萄牙語 (Bloqueada/Desbloquear)、日語 (ロック中/ロックを解除) 的「鎖定/Locked」系列翻譯詞彙。
  2. 重新執行 lutter gen-l10n 產生 pp_localizations_*.dart 檔案。
- **檔案**：lib/l10n/app_{de,es,ja,pt}.arb · lib/l10n/app_localizations_{de,es,ja,pt}.dart

## [R-Shop 主頁面移除來源切換] 主頁面移除頂部來源標籤條與 L2/R2 手把切換來源功能

- **問題**：先前主頁面頂部設有來源標籤條（Source Banner），並允許手把 L2/R2 觸發切換作用來源；使用者明確需求為簡化介面，主頁面一次只顯示目前唯一作用來源，來源與備援來源的選擇與切換統一在「來源清單」頁面設定。
- **根因**：舊設計在主頁面上提供了額外來源切換入口。
- **修復**：
  1. lib/features/home/home_view.dart 移除頂部來源條 _buildSourceBanner() 及其在 ody 版面中的 Column 擴展包覆。
  2. 移除全域快捷鍵 TabLeftIntent (L2) / TabRightIntent (R2) 觸發來源切換的監聽綁定及 _cycleActiveSource() 輔助函式。
  3. 移除底部 ConsoleHud 手把提示中的 L2: 前的提供元 與 R2: 次的提供元 按鈕圖示。
- **檔案**：lib/features/home/home_view.dart（移除來源顯示條、L2/R2 Intents 與 HUD 提示）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）

## [R-Shop 來源與備援邊框與高對比風格] 來源設置與備援設定採用全列白邊框與純白高對比文字風格

- **問題**：來源設置與備援設定浮層項目邊框不夠顯眼，副標題與說明文字顏色較暗（`Colors.grey.shade500`），手把焦點與視覺選取清晰度有待提升。
- **根因**：過往卡片未統一設置清晰的白邊框與高對比白字。
- **修復**：
  1. `SourcesScreen`（`_SourceCard`）：邊框統一改為清晰白邊框（未聚焦時 `Colors.white24` 1.5px，聚焦時 `ConsoleFocusable` 純白 2px 邊框與深紅高亮背景）；副標題、類型、主機與遊戲計數統一採用純白/亮白（`Colors.white` / `Colors.white70`）高對比字體。
  2. `FallbackPickerOverlay`（備援設定）：全面對齊 `SourcesScreen` 風格，選項列均採用 `0xFF1C1C1C` 卡片底色、`Colors.white24` 未選邊框 / `Colors.white` 2px 選取白邊框、`Colors.white` 與 `Colors.white70` 高對比文字。
- **檔案**：`lib/features/settings/sources_screen.dart`（_SourceCard 白邊框與高對比文字） · `lib/features/sources/fallback_picker_overlay.dart`（對齊來源設置視覺風格與邊框）
