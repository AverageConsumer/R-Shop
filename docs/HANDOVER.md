# R-Shop 交接：現在停在哪

> **這份是「未完成」清單，不是紀錄。** 做完的事寫進 [FIX_LOGS.md](FIX_LOGS.md) 並在
> [FIX_INDEX.md](FIX_INDEX.md) 補一列，然後**把它從這裡刪掉**。
> 留在這裡的每一條都應該是真的還沒做完。
>
> **使用者會講的那句話是「R-Shop 繼續任務」。** 聽到就照下面的載入確認做完，
> 把清單念一次（**等實機確認的先講**），然後**問他要接哪一項**——不要自己挑了就動手。

---

## 開工前必做：載入確認（不是說明，是要執行）

**這份檔常常是被單獨打開的**——使用者的講法是「繼續未完成的事，先看 HANDOVER」。
所以先讀完下面五項再動待辦，**並在回覆裡以一行列出你實際讀到什麼**。
沒列出來就等於沒讀，只說「已讀取」不算。

| # | 要讀的 | 回覆裡要講出什麼 |
| :--- | :--- | :--- |
| 1 | `D:\ThorAPK\StudioProjects\GLOBAL_DEV_NOTES.md` | 建置工具鏈有沒有變、有無新增規則 |
| 2 | `R-Shop/AGENTS.md` | 這個專案特有的限制，哪幾條跟這次任務有關 |
| 3 | `docs/FIX_INDEX.md` 與 `docs/FIX_BY_FILE.md` | 你要碰的檔或症狀有沒有前例（**有就讀那一條**） |
| 4 | `R-Shop/.agents/skills/` | 跟這次任務相關的技能有哪些 |
| 5 | 長期記憶的 `MEMORY.md` | 使用者偏好裡跟這次任務有關的是哪幾條 |

**第 4 項**：`rshop-build-deploy`（建置的三個陷阱，含 `scripts/deploy.ps1`）·
`rshop-touch-and-gamepad`（**動 UI 之前一定先讀**）·
`rshop-source-routing`（來源／路由／**群組**的不變式）· `rshop-l10n`。

**第 5 項**：長期記憶在
`C:\Users\Guset\.claude\projects\D--ThorAPK-StudioProjects\memory\`。
**只有 Claude Code 開在這個工作區才會自動載入，其他 AI 工具拿不到，必須自己 Read。**
裡面是使用者的偏好與工作方式（回答要多短、批次多大就該部署、哪些坑重複踩過），
不讀的話會用錯的方式工作而不自知。

**收尾時同樣要執行**：寫 `docs/FIX_LOGS.md`（問題／修復／檔案 三個固定欄位）、
補 `docs/FIX_INDEX.md`、重跑 `python scripts/build_fix_by_file.py`、
**把做完的那條從本檔刪掉**。少做一件都不算完成。

---

## 1. 等實機確認（程式已出版，等回報）

已建置、已安裝、已啟動，`logcat` 乾淨，但**沒有人在螢幕上看過**。
UI 的東西 `analyze` 與單元測試都驗不到——見 `.agents/skills/rshop-touch-and-gamepad`。

| 要看什麼 | 預期 |
| :--- | :--- |
| 來源清單的眼睛 | 就是開／關（`enabled`）。關掉那筆從主畫面消失，**再開回來不用重新同步** |
| 來源清單的打勾 | 使用中。設了會順便把該來源打開；取消不會把它關掉 |
| 主畫面 L2/R2 | 只在來源之間走，**不應該再出現 A+B 那一格** |
| 主畫面橫幅 | 只寫一台的名字。**永遠不出現「全部來源」** |
| 主畫面進場 | 標題與圖示之間**進場與移動後應該一樣高**（不再多一列空白） |
| 來源清單 HUD | 五顆（返回／新增來源／使用中／停用／移除）。**看有沒有黃黑斜紋** |
| RetroAchievements 設定頁 | 焦點白框與文字之間有間距，不再貼在一起 |
| 切換啟用／使用中 | 應該即時，不再停頓 |

有黃黑斜紋就回報，那是版面溢位。

### 1.1 這一批（2026-08-05，**已安裝，等他看螢幕**）

> 已徵得同意後裝上 AYN Thor（`d7195880`），debug 版，`logcat` 乾淨。
> **v15 遷移在實機跑完**：`migration v15: collapsed 8534 duplicate rows`，沒有例外。

| 要看什麼 | 預期 |
| :--- | :--- |
| 連線方式浮層 | 每一列有**延遲毫秒數**；沒回應寫「沒有回應」，探測中寫「檢查中」 |
| 浮層的「自動選擇」 | 講出**會選哪一條**（名字，不是「最上面那條」）；選它＝解除鎖定 |
| 浮層的徽章 | 最快／使用中／已鎖定／專屬登入。**用手指點每一列都要會動**（不是只有手把） |
| 連線方式編輯頁 | 有登入欄位；**留空時畫面要說「沿用來源的登入資訊」**，填了要說「用自己的」 |
| 切到別條路線 | 清單不該重抓（換路不換清單），也不該把使用中的來源換掉 |
| 五語系的引導頁 | de/es/fr/ja/pt 的「設定遊戲庫路徑」那三句不再是空白 |
| 捲動 | 格線與圖書館換了 `scrollCacheExtent`，**捲動的順暢度應該完全沒變**（有變就是單位換錯了） |

---

## 2. 待辦

### 2.0 進行中：來源群組取代備援（2026-08-05 暫停，**程式在 `wip/source-groups` 分支上**）

> **`main-zh` 停在 `a49cce3`，那是已經裝到機器上、驗過的版本。**
> 這一項未完成的程式全部 commit 在 **`wip/source-groups`**（已推遠端）。
> 要接手就 `git checkout wip/source-groups`。**這份交接的最新版在那個分支上**。
>
> **那個分支現在編得起來了**（2026-08-05）：`flutter analyze` 全專案零問題，
> `flutter test` **1907 通過 / 6 失敗**，6 個就是 §3.1 那份既有清單。
> 資料層與邏輯層（第 1～5 項）已完成，**剩下的是畫面、字串與實機**。

#### 使用者要什麼（原話，不要再自行對映）

    「應該不是備援 而是 我想指定兩個來源 其實是指向同一台伺服器
      那它們可以選擇誰優先 或著自動」
    「應該說 走同一個來源類型 可以設定自動選擇」
    「應該是設成群組」
    「A 通就先用A 我有順序」
    「我要先回應的那台」
    「因為同一群組 應該實際是同一台之類 所以清單也只需要一份」

翻成規格，**這幾條是他確認過的，不要再改**：

- **群組取代備援。** 不是在備援之外多一個功能——「備援」這個詞要從畫面上消失，
  舊的 `fallbackSourceId` 遷成一個兩人群組（偏好在前、模式 `ordered`），那正是現行備援的行為。
  他上次就抱怨過功能重複（「不覺得功能重複了嗎?」）。
- **成員限同類型**（他的條件就是「走同一個來源類型」）。跨類型的既有配對照樣遷入，不然又變兩套機制。
- **模式兩種**：`auto`＝**先回應的那台**（賽跑，不是排序）、`ordered`＝照他排的順序挑第一個通的。
- **一個群組只存一份清單**（同一台就是同一份）。加入群組＝兩份快取合併去重；
  **移出群組＝那個來源沒有自己的清單，要重新同步**（UI 要有確認框）。
- 選中誰**只改記憶體中的 config，磁碟不動**（不變式 3，自癒的原因）。
- 主畫面 L2/R2 **一個群組只佔一格**，橫幅要寫出實際用的是哪一台。

#### 已完成（在 wip 分支上，測試綠）

    連線方式三種模式    EndpointSelection 加 ordered；auto 改成「先回應就贏」；pinned 不變
    firstResponder      先回應就回傳但不中斷整輪，其餘毫秒數照樣進 TTL 快取；同來源的探測併成一輪
    順序 API            Source.withEndpointsReordered / moveEndpoint（純函式，重排不會自己換路）
    資料庫 v16          快取擁有者改成群組（原第 1 項，2026-08-05 做完，見下）
    notifier 群組       建立／改名／刪除、加入／移出、排順序、切模式；擋跨類型；接上快取三入口
    選路三種模式        setEndpointSelection 的 ordered 分支、autoSelectEndpoint 走 resolve()、
                        reorderEndpoints／moveEndpointTo／useOrderedSelection
    測試                上述各檔全綠，另新增 database_service_v16 與 sources_notifier_groups 兩檔

**資料庫那一項做了什麼**（細節在 `.agents/skills/rshop-source-routing` 的資料庫那節）：

    cache_owner_id      新欄位，唯一鍵改成 (systemSlug, filename, cache_owner_id)
    v16 遷移            只加欄位、一對一補值、換索引，**一列都不刪**
    合併與去重          不在遷移裡，在 adoptCacheInto()——群組在設定檔，資料庫層讀不到
    _collapseDuplicates cedce1e 只有呼叫沒有本體，補上了；v15 與群組合併共用同一支
    _v15OnDeviceRank    更名 _onDeviceRank（現在不只 v15 在用），判準本身沒動
    三個入口            adoptCacheInto／moveCacheOwnership／releaseCacheFrom
    改名                getGameCountsPerCacheOwner／getGameCountForOwner／deleteCacheOwnedBy
    purgeOrDetachSource 多了 protectedOwnerIds，否則刪成員會帶走群組的列

#### 還沒做（**下次從這裡開始**）

> 第 1～5 項（資料層＋選路邏輯）**2026-08-05 全部做完**，程式在 `wip/source-groups`。
> 做了什麼看下面「已完成」那兩張表，以及 `.agents/skills/rshop-source-routing`。
> 一併做掉的還有：`chooseSource` 不再讀 `fallbackSourceId`（配對一律先遷成群組），
> 呼叫端 `library_sync_service` / `game_list_controller` / `game_list_screen`
> 都已改傳 `cacheOwnerOf: config.cacheOwnerIdFor`，
> `removeSource` 會先把群組的快取交接出去再清。

1. **UI 全部還沒動** —— 來源清單要有建立群組／加入／移出／排順序／切模式的入口，
   浮層要能選 `ordered`（**現在點某一列一律是釘選＝覆寫**，`ordered` 需要自己的入口）。
   ⚠️ **兩套入口都要**（觸控＋手把），先讀 `.agents/skills/rshop-touch-and-gamepad`。
2. **七語系字串**，與功能同一次補齊。
3. **`rshop-source-routing` 剩畫面那半的語彙** —— 不變式 3、資料庫那節、
   「使用者要的到底是什麼」都已改成群組；UI 那一面等畫面做完再補。
4. 全部做完才實機驗證。**v16 遷移會改使用者的資料庫**，裝上去之前先問他（部署政策，見 `AGENTS.md §5`）。
   > **不要為了這件事去查實機的資料。** 使用者 2026-08-05 明講「實機上資料的不管，只管你 app 開發就好」。
   > 遷移的安全性靠**設計本身**保證：整件事在一個交易裡、去重判準照抄 v15 的 `_v15OnDeviceRank`，
   > 而不是靠先去看他機器上有什麼。
   >
   > 順帶更正一個前提：本檔原本寫「他機器上約十萬列」，**那個數字在紀錄裡找不到出處**，已刪。
   > 有出處的只有 v15 那次的遷移日誌 `collapsed 8534 duplicate rows`。
   > 會被遷移碰到的是 `games` 表（遊戲庫快取，一列＝一款遊戲在某個來源底下的一筆），
   > 不是存檔也不是已下載的 ROM——最壞的情況是要重新同步。

### 2.1 同步的可達性判定還停在來源層級

`resolveForSync` 判定一個來源「可達」的條件是**任一條路線通**，但它同步時走的是
`liveEndpoint`——所以會出現「來源算通、實際走的那條是死的」而不觸發換路的情況。
自動選路目前只作用在使用者開浮層與明確呼叫 `autoSelectEndpoint` 的時候，**同步路徑沒接上**。
群組那一項做完後要一起看，兩者都在 `source_failover.dart`。

### 2.2 五語系的「已鎖定」用詞不一致

en/zh 是「Locked／已鎖定」，de/es/ja/pt 仍是「固定」（`Fixiert`／`Fijada`／`固定`／`Fixada`），
只有 fr 是 `Verrouillée`。翻譯時是照各檔既有用詞走的，**不算錯，但六種語言講的不是同一件事**。
要統一就六個檔一起改 `sources_routePinned` 與相關句子。

順帶：`app_ja.arb` 與 `app_pt.arb` 的 `sources_*` 區塊現在**跳脫方式混用**——
檔案整體慣例是 `\uXXXX`，先前有人直接寫了原字。不影響行為，看得刺眼而已。

---

## 3. 已知不修

### 3.1 測試基準：6 個失敗是既有的

`flutter test` 完整跑 **1907 通過 / 6 失敗**（`wip/source-groups`，2026-08-05 實測；
`main-zh` 是 1825 通過，差在群組那批新測試）。**6 個都不是回歸**：

    network_discovery: mDNS                 Windows socket errno 10042
    rom_folder_service ×3                   Windows 路徑行為
    romm_pairing_live_smoke ×2              需要真的有 RomM 跑在 localhost:8090

> 原本是 7 個。第 7 個（`l10n_completeness: DE has all EN keys`）**是真的缺字串**，
> 已補完並綠了——見 `docs/FIX_LOGS.md` 的 `[R-Shop onboarding 五語系缺字串]`。
> **教訓**：基準清單裡的每一條都要寫得出「為什麼它不算回歸」，寫不出來的那條就是還沒查。

**另外有一個時序敏感的測試會偶爾多失敗一個**：
`game_list_controller: restoreFilters applies saved filters`。
**單次隔離執行失敗不足以認定回歸**——我為此誤判過一次，連跑三次就會發現它自己會過。

### 3.2 ~~自動選最快的那條路線：決定不做~~ → 已重開並做完（2026-08-05）

**這條不再是「不修」。** 當初的理由是「同一台也當不同台，替他換路＝替他換來源」，
但那句話管的是**來源之間**，不是同一個來源底下的**路線之間**——
`[R-Shop 路線各自驗證]` 把路線收斂成同一台、同一份清單之後，重開條件就成立了。
現行行為見 `docs/FIX_LOGS.md` 的 `[R-Shop 自動選最優路線]`。

### 3.3 `FIX_BY_FILE.md` 的「反查不到」不是待辦

`build_fix_by_file.py` 印的 `entries without paths` **不用歸零**——環境診斷、部署作業、
需求判定本來就沒有程式碼變更，在反查表上無處可去。這個數字會隨這類紀錄往上走
（現在是 3）。腳本裡誤導的說明字串已改掉。
見 `docs/FIX_LOGS.md` 的 `[R-Shop 反查不到]`。

### 3.4 桌面平台的 7 個產生檔一直是未提交狀態

    linux/flutter/generated_plugin_registrant.{cc,h}
    linux/flutter/generated_plugins.cmake
    macos/Flutter/GeneratedPluginRegistrant.swift
    windows/flutter/generated_plugin_registrant.{cc,h}
    windows/flutter/generated_plugins.cmake

每次 `flutter pub get` 都會重寫。**這個專案只出 Android**，提交它們只會製造雜訊。
`git status` 看到它們是正常的，不要順手 `git add`。

> 這也是為什麼 **`git add` 一律用明確路徑，不要用 `-A`**——
> 而且工作區有多個視窗同時在改（見 `GLOBAL_DEV_NOTES.md` 開頭）。
