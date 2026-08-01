# R-Shop 修復與功能紀錄

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
- **Commit**：未提交


## [R-Shop ProviderFactory 隱式初始化] R-Shop: 未 init 就取 SMB provider 只拋裸的 null assertion

- **現象**：文件（`docs/SPEC.md`）長期記載「`SmbProvider` 依賴 `_smbService!`，未 `init()` 就會崩」。
- **查證後的定性修正**：**生產流程實務上不可達**。全 App 只有一個進入點，`main.dart:87` 的 `ProviderFactory.init()` 在 `runApp()` **之前**，所以任何 UI 觸發的 `getProvider` 必定在其後；唯一另一個 `@pragma('vm:entry-point')`（下載前景服務）的 handler 三個回呼全是空實作，不碰 ProviderFactory。所以這是**契約缺陷**（隱式初始化順序依賴 + static 狀態無法重設），不是現行 crash。**測試層面才真的可達**。
- **解**：`_smbService == null` 時丟具名 `StateError`，訊息點名 `ProviderFactory.init(smbService:)` 且說明正常應在 `main()` 的 `runApp()` 之前。新增 `@visibleForTesting reset()` 讓測試能重設 static 狀態，並補測試驗證訊息可辨識、以及未初始化時 `web` provider 仍正常。**未改建構式簽章**——改成注入式會牽動 4 個呼叫端。
- **教訓**：文件把一個缺陷寫成「會崩」，實際查證後是「不可達但脆弱」。**定性錯誤會影響修法選擇**：若真的會崩，該做的是改建構式注入；既然只是契約問題，加一個好訊息的 `StateError` 就夠，改動面小得多。
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
