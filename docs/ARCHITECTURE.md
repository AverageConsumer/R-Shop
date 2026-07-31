# R-Shop 架構圖集（深度）

> **基準分支：`main-zh`** ｜ `1.7.0-zh+13` ｜ `com.retro.rshop.tw`
> 搭配 [SPEC.md](SPEC.md) 閱讀。

**與根目錄 [../ARCHITECTURE.md](../ARCHITECTURE.md) 的分工**：

| 文件 | 定位 | 內容 |
|------|------|------|
| [../ARCHITECTURE.md](../ARCHITECTURE.md) | 高階概覽（171 行 / 1 張圖） | 模組劃分、關鍵類別表、技術棧、功能總覽、目錄結構 |
| **本文件** | 深度架構（Mermaid 圖集） | 來源抽象層、下載狀態機與時序、焦點系統、Platform Channel、資料流 |

> ⚠️ 根目錄文件有幾處已知偏差（`FocusSyncManager` 路徑、絕對連結路徑、版本號），校正表見 [SPEC.md §0.2](SPEC.md)。

---

## 1. 整體分層

```mermaid
graph TB
    subgraph ENTRY["入口"]
        MAIN["main.dart<br/>ProviderScope · Theme · i18n<br/>GlobalInputWrapper · NoGlowScrollBehavior"]
        APP["RShopApp<br/>ConsumerStatefulWidget<br/>+ WidgetsBindingObserver"]
    end

    subgraph FEAT["features/ — 功能頁面（8 模組）"]
        HOME["home/<br/>eShop 風格首頁"]
        GL["game_list/<br/>分類清單 + logic"]
        GD["game_detail/<br/>詳情 + 成就（19 widgets）"]
        LIB["library/<br/>已下載遊戲庫"]
        ONB["onboarding/<br/>新手引導（11 widgets）"]
        PAIR["pairing/<br/>RomM 配對"]
        SRC["sources/<br/>來源管理"]
        SET["settings/<br/>設定（11 widgets）"]
    end

    subgraph CORE["core/ — 基礎設施（22 檔）"]
        INPUT["input/ ★ 手把焦點系統<br/>11 檔 / 1980 行"]
        CW["widgets/<br/>console_focusable 564"]
        RESP["responsive/<br/>breakpoints · spacing · typography"]
        THEME["theme/app_theme"]
    end

    subgraph PROV["providers/ — Riverpod（9 檔 1426 行）"]
        P1["app_providers 460"]
        P2["game · download · ra<br/>shelf · library<br/>rom_status · source_health<br/>installed_files"]
    end

    subgraph SVC["services/ — 業務服務（43 檔，最大層）"]
        RESOLVE["source_resolver 200<br/>provider_factory · source_provider"]
        PRVD["providers/<br/>web 256 · smb 164<br/>ftp 299 · romm 167"]
        DL["download_service 1245<br/>download_queue_manager 694<br/>download_foreground_service 161"]
        DB["database_service 1066<br/>library_sync_service 630<br/>storage_service 528"]
        RA["ra_api 328 · ra_sync 355<br/>ra_hash 223"]
        IMG["thumbnail 388 · cover_preload 363<br/>thumbnail_index 316 · image_cache 248"]
        NET["network_discovery 136（mDNS）<br/>romm_api 442 · romm_pairing 370"]
        LOCAL["rom_folder 180<br/>local_folder_matcher 157<br/>remote_folder_scanner 177"]
        AV["audio_manager 396<br/>haptic · feedback · input_debouncer"]
    end

    subgraph MODEL["models/ — 資料模型（11 檔）"]
        SM["system_model 906<br/>★ 約 66–67 種主機字典"]
        GI["game_item 121<br/>download_item 199<br/>game_metadata_info 179"]
        CFG["config/<br/>app_config 255 · provider_config 335<br/>source 313 · system_config 122"]
        RAM["ra_models 233<br/>custom_shelf 174"]
    end

    subgraph NAT["android/ — 原生（Kotlin）"]
        MA["MainActivity.kt<br/>5 個 Platform Channel"]
        SMBS["SmbService.kt<br/>smbj 0.13.0"]
    end

    MAIN --> APP
    APP --> FEAT
    FEAT --> INPUT
    FEAT --> CW
    FEAT --> RESP
    FEAT --> PROV
    PROV --> SVC
    SVC --> MODEL
    RESOLVE --> PRVD
    PRVD --> NET
    PRVD -.->|"SmbProvider 委派"| NAT
    DL --> PRVD
    DL --> MA
    DB --> MODEL
    MA --> SMBS

    style INPUT fill:#f9a825,color:#000
    style RESOLVE fill:#42a5f5,color:#000
    style SM fill:#66bb6a,color:#000
    style NAT fill:#ef5350,color:#fff
```

---

## 2. 多來源抽象層（核心設計）

```mermaid
graph TB
    subgraph USER["使用者設定"]
        S["Source<br/>models/config/source.dart"]
        ST["enum SourceType<br/>romm · smb · ftp · web · local<br/>（5 種）"]
        S --> ST
    end

    subgraph RESOLVE["SourceResolver（全靜態）"]
        R1["providersFor(system, ...)"]
        R2["_typeMatches(SourceType, ProviderType)"]
        R3["_connectionMatches(Source, ProviderConfig)"]
        R4["_toProviderConfig(...)"]
        R5["sourcesFor(...) 反查"]
    end

    subgraph ABS["抽象層"]
        PC["ProviderConfig<br/>enum ProviderType<br/>web · smb · ftp · romm<br/>（4 種）"]
        SP["abstract SourceProvider<br/>fetchGames(SystemConfig)<br/>resolveDownload(GameItem)<br/>testConnection()<br/>displayLabel"]
        PF["ProviderFactory<br/>.getProvider(config)"]
    end

    subgraph IMPL["實作（services/providers/）"]
        W["WebProvider 256<br/>HTTP 目錄索引 · dio"]
        SM2["SmbProvider 164<br/>→ NativeSmbService"]
        F["FtpProvider 299<br/>ftpconnect"]
        RM["RommProvider 167<br/>→ RommApiService 442"]
    end

    subgraph LOCALPATH["本地來源（不走抽象層）"]
        LF["rom_folder_service 180<br/>local_folder_matcher 157<br/>直接掃描檔案系統"]
    end

    ST --> R1
    R1 --> R2 & R3 & R4
    R4 --> PC
    PC --> PF
    PF --> W & SM2 & F & RM
    W & SM2 & F & RM -.->|"實作"| SP

    ST -.->|"local 無對應 ProviderType"| LF

    AUTO["SourceTypeX.supportsAutoMap<br/>僅 romm == true<br/>→ RomM 自報平台清單<br/>其他需 SystemSourceMapping"]
    ST -.- AUTO

    NULLW["⚠️ SmbProvider 依賴 _smbService!<br/>必須先 ProviderFactory.init(smbService:)<br/>否則 null assertion 崩潰"]
    SM2 -.- NULLW

    style LF fill:#ffe0b2,color:#000
    style NULLW fill:#ef5350,color:#fff
    style AUTO fill:#f9a825,color:#000
```

> **兩個列舉不對稱是刻意的**：`local` 沒有網路協定要抽象，直接走檔案系統掃描。新增來源型別時要同時處理兩個列舉與 `_typeMatches`。

---

## 3. 遊戲庫載入流程

```mermaid
sequenceDiagram
    autonumber
    participant UI as game_list / library 畫面
    participant PR as Riverpod providers
    participant UGS as UnifiedGameService
    participant SR as SourceResolver
    participant PF as ProviderFactory
    participant SP as SourceProvider 實作
    participant DB as DatabaseService
    participant SYNC as LibrarySyncService

    UI->>PR: watch(gameProvider(system))
    PR->>UGS: 查詢某主機的遊戲
    UGS->>DB: 先查本地快取（離線可用）
    DB-->>UGS: 已知 GameItem 清單
    UGS-->>UI: 立即回傳（快速顯示）

    par 背景同步
        UGS->>SR: providersFor(system)
        SR->>SR: 比對 SourceType ↔ ProviderType<br/>_connectionMatches 判斷同伺服器
        SR-->>UGS: List&lt;ProviderConfig&gt;（可能多個來源）
        loop 每個 provider
            UGS->>PF: getProvider(config)
            PF-->>UGS: SourceProvider
            UGS->>SP: fetchGames(systemConfig)
            SP-->>UGS: List&lt;GameItem&gt;
        end
        UGS->>SYNC: 合併去重 + 元資料補全
        SYNC->>DB: 寫回 SQLite
        DB-->>PR: 通知變更
        PR-->>UI: 重繪
    end
```

**多來源合併**：同一款遊戲可能同時存在於 RomM 與 SMB → 合併為一筆 `GameItem`，但保留所有來源，供下載失敗時切換（見 §5）。

---

## 4. 下載狀態機

```mermaid
stateDiagram-v2
    [*] --> queued: addToQueue()<br/>（上限 _maxQueueSize = 100）

    queued --> downloading: _processQueue()<br/>availableSlots > 0<br/>（maxConcurrent 預設 2）

    downloading --> extracting: 下載完成 且 autoExtract
    downloading --> moving: 下載完成 且 !autoExtract
    downloading --> error: 失敗
    downloading --> cancelled: cancelDownload()

    extracting --> moving: 原生解壓完成
    extracting --> error: 解壓失敗

    moving --> completed: 歸檔至 targetFolder
    moving --> error: 移動失敗

    error --> queued: _scheduleRetry()<br/>retryCount < _maxRetries(3)<br/>帶 jitter 避免同時重試
    error --> queued: _switchToAlternativeSource()<br/>★ 重試耗盡 → 換來源
    error --> [*]: 無替代來源

    completed --> [*]
    cancelled --> [*]

    note right of completed
        isTerminal == true
        completed / cancelled / error
    end note

    note right of queued
        _persistQueue() 持久化
        → App 重啟後 restoreQueue()
        可續傳
    end note
```

---

## 5. 下載佇列管理時序

```mermaid
sequenceDiagram
    autonumber
    participant UI as 下載清單 UI
    participant Q as DownloadQueueManager<br/>(ChangeNotifier)
    participant DS as DownloadService
    participant SP as SourceProvider
    participant FG as ForegroundService
    participant NAT as MainActivity.kt

    UI->>Q: addToQueue(game, system, targetFolder, autoExtract)
    Q->>Q: _generateId(game, system) 去重
    Q->>Q: _persistQueue()
    Q->>Q: _processQueue()

    Q->>Q: availableSlots = maxConcurrent − activeCount
    Q->>DS: _startDownload(item)
    Q->>FG: _updateForegroundService() 啟動保活

    DS->>SP: resolveDownload(game)
    SP-->>DS: DownloadHandle（URL / 串流）
    loop 傳輸中
        DS-->>Q: 進度回報
        Q->>Q: _throttledNotificationUpdate()<br/>★ 節流，避免高頻重繪
        Q-->>UI: _safeNotify()
    end

    alt 下載成功 且 autoExtract
        DS->>NAT: MethodChannel "…/zip" 解壓
        NAT-->>DS: EventChannel "…/zip_progress" 進度
    end

    alt 下載失敗
        Q->>Q: _isRetryableError(error)?
        alt 可重試 且 retryCount < 3
            Q->>Q: _scheduleRetry(id, retryCount)<br/>jitter 延遲
        else 重試耗盡
            Q->>Q: _switchToAlternativeSource(id)<br/>★ 改用同主機其他來源
        end
    end

    Q->>Q: _onDownloadComplete(id)
    Q->>Q: _stopForegroundServiceIfIdle()<br/>★ 佇列空閒即停，省電
    Q-->>UI: onItemCompleted 回呼
```

---

## 6. 手把焦點系統（控制器優先的核心）

```mermaid
graph TB
    HW["實體輸入<br/>D-pad · 手把按鍵 · 鍵盤"]

    HW --> GKF["gamepad_key_fix.dart 52<br/>★ 不同手把 keycode 差異修補"]
    GKF --> GIW["global_input_wrapper.dart 90<br/>攔截並轉發"]

    GIW --> AI["app_intents.dart 46<br/>Flutter Intent 定義"]
    AI --> AA["app_actions.dart 300<br/>全域動作實作"]

    GIW --> DEB["input_debouncer.dart 76<br/>連續輸入去重"]

    subgraph FOCUS["焦點管理"]
        FSM["focus_sync_manager.dart 393<br/>★ 焦點不遺失 · 不跳錯"]
        FSO["focus_scope_observer.dart 82<br/>範圍變化觀察"]
        OS["overlay_scope.dart 307<br/>對話框焦點隔離"]
    end

    AA --> FSM
    FSM <--> FSO
    FSM <--> OS

    subgraph MIXIN["畫面 Mixin"]
        CSM["console_screen_mixin.dart 239<br/>主機風格畫面通用行為"]
        SSM["searchable_screen_mixin.dart 280<br/>可搜尋畫面"]
    end

    FSM --> CSM & SSM

    subgraph WIDGET["可聚焦元件"]
        CF["core/widgets/console_focusable.dart 564<br/>★ 焦點視覺與行為"]
        CD["widgets/console_dialog.dart 252<br/>★ main-zh 新增<br/>手把最佳化對話框"]
    end

    CSM & SSM --> CF
    OS --> CD

    STYLE["main-zh 統一焦點高亮：<br/>白框 + 紅底<br/>⚠️ 改樣式要同時動<br/>console_focusable 與 console_dialog"]
    CF -.- STYLE
    CD -.- STYLE

    PITFALL["已修坑：ConsoleDialog 需包 Material<br/>否則文字出現黃色底線"]
    CD -.- PITFALL

    IP["input_providers.dart 181<br/>Riverpod 輸入狀態"]
    GIW --> IP

    style FSM fill:#f9a825,color:#000
    style CF fill:#f9a825,color:#000
    style CD fill:#66bb6a,color:#000
    style STYLE fill:#ffe0b2,color:#000
    style PITFALL fill:#ef5350,color:#fff
```

> **新增任何對話框請用 `ConsoleDialog`**，不要直接 `showDialog` —— 否則手把焦點會失效。

---

## 7. Platform Channel（Flutter ↔ Android）

```mermaid
graph LR
    subgraph DART["Flutter (Dart)"]
        DS["download_service.dart"]
        NSS["native_smb_service.dart 141"]
        SS["storage_service.dart 528"]
    end

    subgraph CH["Platform Channels<br/>（名稱含 applicationId 前綴）"]
        C1["com.retro.rshop.tw/zip<br/>MethodChannel"]
        C2["com.retro.rshop.tw/zip_progress<br/>EventChannel"]
        C3["com.retro.rshop.tw/storage<br/>MethodChannel"]
        C4["com.retro.rshop.tw/smb<br/>MethodChannel"]
        C5["com.retro.rshop.tw/smb_progress<br/>EventChannel"]
    end

    subgraph KT["Android (Kotlin)"]
        MA["MainActivity.kt<br/>註冊 5 個 channel<br/>progressSink · smbProgressSink"]
        SMB["SmbService.kt<br/>smbj 0.13.0<br/>SMB2/SMB3 認證 · 列舉 · 串流"]
        FG["ForegroundService<br/>flutter_foreground_task 9.2.0"]
    end

    DS --> C1 --> MA
    MA -.-> C2 -.-> DS
    SS --> C3 --> MA
    NSS --> C4 --> MA
    MA -.-> C5 -.-> NSS
    MA --> SMB
    MA --> FG

    WARN["⚠️ Channel 名稱含 com.retro.rshop.tw<br/>→ main 與 main-zh 名稱不同<br/>合併分支時 Kotlin 與 Dart 兩側都要改"]
    CH -.- WARN

    style WARN fill:#ef5350,color:#fff
```

---

## 8. 資料層與快取

```mermaid
graph TB
    subgraph PERSIST["持久化"]
        SQL["SQLite (sqflite 2.4.2)<br/>database_service 1066<br/>遊戲元資料 · 來源設定<br/>下載歷史 · 成就"]
        SP["SharedPreferences<br/>storage_service 528<br/>應用設定"]
        SEC["flutter_secure_storage 9.2.4<br/>API key · 帳密"]
        FILES["檔案系統<br/>已下載 ROM · 縮圖快取"]
    end

    subgraph CACHE["封面快取鏈（防 OOM）"]
        CNI["cached_network_image 3.4.1<br/>+ flutter_cache_manager 3.4.1"]
        ICS["image_cache_service 248<br/>記憶體 / 磁碟雙層"]
        CPS["cover_preload_service 363<br/>預載"]
        TS["thumbnail_service 388<br/>縮圖產生"]
        TIS["thumbnail_index_service 316<br/>索引"]
        TMS["thumbnail_migration_service 59<br/>舊版遷移"]
    end

    subgraph SYNC["同步"]
        LSS["library_sync_service 630"]
        UGS["unified_game_service 94<br/>統一查詢入口"]
        CSS["config_storage_service 196<br/>config_parser 106<br/>config_bootstrap 10"]
    end

    subgraph MODELS["模型"]
        SM["system_model 906<br/>約 66–67 種主機<br/>platform ID · 副檔名 · 預設目錄"]
        RPM["romm_platform_matcher 128<br/>RomM 平台名 → SystemModel"]
    end

    UGS --> SQL
    LSS --> SQL
    LSS --> SM
    RPM --> SM
    CSS --> SQL
    CSS --> FILES

    TS --> TIS
    TIS --> FILES
    CPS --> ICS
    ICS --> CNI
    CNI --> FILES
    TMS -.->|"一次性"| TIS

    SEC -.->|"RomM / RA 憑證"| SQL

    style SM fill:#66bb6a,color:#000
    style ICS fill:#f9a825,color:#000
```

---

## 9. RetroAchievements 整合

```mermaid
sequenceDiagram
    autonumber
    participant UI as game_detail / achievements_screen
    participant PR as ra_providers 114
    participant RS as RaSyncService 355
    participant RH as RaHashService 223
    participant RA as RaApiService 328
    participant DB as DatabaseService

    UI->>PR: watch(raProvider(game))
    PR->>DB: 先查已快取成就
    DB-->>UI: 立即顯示（離線可用）

    PR->>RS: 觸發同步
    RS->>RH: 計算 ROM 雜湊
    Note over RH: ★ RA 有主機專屬雜湊規則，<br/>非單純檔案 MD5<br/>（不同主機演算法不同）
    RH-->>RS: hash
    RS->>RA: GET 遊戲 ID by hash
    RA-->>RS: gameId
    RS->>RA: GET 玩家成就進度
    RA-->>RS: 成就清單 + 解鎖狀態
    RS->>DB: 寫入 ra_models 資料
    DB-->>PR: 通知變更
    PR-->>UI: 顯示徽章與進度
```

---

## 10. 來源配對（RomM）

```mermaid
flowchart TD
    START["新增 RomM 來源"] --> WAY{"配對方式"}

    WAY -->|QR 掃描| QR["mobile_scanner 5.2.3<br/>相機即時掃描"]
    WAY -->|QR 圖片| QRI["從相簿載入圖片解碼"]
    WAY -->|手動輸入| MAN["manual_pairing_screen<br/>（main-zh 修改 218 行）"]
    WAY -->|區網發現| MDNS["network_discovery_service 136<br/>mDNS / Zeroconf"]

    QR & QRI --> PARSE["romm_pairing_service 370<br/>解析 URL + API Key"]
    MAN --> PARSE
    MDNS --> LIST["列出區網 RomM 伺服器"]
    LIST --> PARSE

    PARSE --> AUTH["AuthConfig<br/>user / pass / apiKey / domain"]
    AUTH --> PREF{"RomM 4.8+<br/>Client API Token？"}
    PREF -->|有| BEARER["★ Bearer Token 優先"]
    PREF -->|無| BASIC["帳號密碼"]

    BEARER & BASIC --> TEST["RommProvider.testConnection()<br/>→ SourceConnectionResult"]
    TEST --> OK{"success?"}
    OK -->|是| SAVE["存入 Source<br/>secure_storage 保存憑證"]
    OK -->|否| ERR["顯示 error / warning"]

    SAVE --> AUTOMAP["supportsAutoMap == true<br/>→ 自動抓取平台清單<br/>不需逐主機設路徑"]
    AUTOMAP --> MATCH["romm_platform_matcher<br/>對映到本地 SystemModel"]

    style BEARER fill:#66bb6a,color:#000
    style AUTOMAP fill:#f9a825,color:#000
```

**對比其他來源**（smb / ftp / web / local）：`supportsAutoMap == false`，**必須**為每個主機建立 `SystemSourceMapping` 指定路徑。

---

## 11. 狀態管理現況（兩種模式並存）

```mermaid
graph TB
    subgraph RIV["Riverpod 2.6.1（9 檔 1426 行）"]
        R1["app_providers 460<br/>設定 · 主題 · 語系"]
        R2["game_providers 197"]
        R3["download_providers 166"]
        R4["source_health_providers 147"]
        R5["ra_providers 114"]
        R6["rom_status_providers 113"]
        R7["shelf_providers 108"]
        R8["installed_files_provider 90"]
        R9["library_providers 31"]
    end

    subgraph CN["ChangeNotifier（services 層）"]
        C1["DownloadQueueManager 694"]
        C2["SourcesNotifier 498"]
    end

    UI["features/ 畫面"]
    UI -->|"ref.watch()"| RIV
    UI -->|"ListenableBuilder /<br/>addListener"| CN

    R3 -.->|"橋接"| C1
    R4 -.->|"橋接"| C2

    NOTE["⚠️ 兩種模式並存<br/>新增狀態前先確認沿用哪種<br/>避免出現第三種寫法"]
    CN -.- NOTE

    style NOTE fill:#f9a825,color:#000
```

---

## 12. `main-zh` 增量總覽

```mermaid
graph LR
    subgraph ID["識別變更"]
        A1["applicationId<br/>com.retro.rshop → .tw"]
        A2["Kotlin 路徑<br/>rshop/ → rshop/tw/"]
        A3["version 1.7.0-zh+13"]
        A4["顯示名稱 R-Shop-zh"]
        A5["APK: R-Shop-v{ver}.apk"]
    end

    subgraph L10N["語系"]
        B1["統一到 zh locale<br/>（修正 zh / zh-TW 混用<br/>造成切換失效）"]
        B2["app_localizations_zh.dart<br/>1582 行"]
    end

    subgraph UI2["UI / 手把體驗"]
        C1["★ ConsoleDialog 新增<br/>widgets/console_dialog.dart 252"]
        C2["焦點高亮統一<br/>白框 + 紅底"]
        C3["Onboarding 改版<br/>5 檔大幅修改"]
        C4["B 鍵離開確認"]
        C5["Select 鍵 → 匯入設定"]
        C6["返回鈕與標題統一<br/>pairing / sources"]
    end

    subgraph BUILD["建置"]
        D1["APK 自動複製至<br/>D:\\test-apk"]
    end

    RISK["⚠️ 合併回上游的風險點<br/>① Kotlin 改名 → 全檔 diff<br/>② Channel 名稱含 applicationId<br/>　 Kotlin 與 Dart 兩側都要改"]

    ID -.- RISK
    style C1 fill:#66bb6a,color:#000
    style RISK fill:#ef5350,color:#fff
```
