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

### 2.0 多組備援來源與自動選擇 (Multi-Fallback)：已完成並成功部署（2026-08-06）

> 依使用者指示，**已徹底移除 SourceGroup（群組）與 SourceEndpoint（連線方式/路線）**，並重新設計為多組備援鏈 (`fallbackSourceIds`) 與自動選擇 (`fallbackAutoSelect`) 模式。
>
> 備援來源可獨立於主畫面顯示與切換，新增備援方式與一般來源完全一致。
> 全套單元測試已執行完成（無回歸），並透過 `deploy.ps1` 順利部署至 AYN Thor 實機（`d7195880`），PID 3917, logcat 正常無例外。

#### 已完成並通過：
1. **資料模型 (`Source`, `AppConfig`)**：重構為 `fallbackSourceIds` 及 `fallbackAutoSelect`。
2. **探測與服務 (`SourceFailover`, `EndpointProbeService`, `SourcesNotifier`)**：多組順序探測與併發 Auto-Select。
3. **UI 浮層 (`FallbackPickerOverlay`)**：新增/刪除/拖曳順序及自動選擇勾選。
4. **主畫面與設定畫面 (`home_view.dart`, `sources_screen.dart`)**：支援備援獨立顯示與獨立切換。


緊接著又把模式列收成一個打勾（同日）：**「照我排的順序」那一列拿掉了**，
第一列變成「自動選擇」的打勾——勾了用最快的，取消勾選就是照清單順序。
兩種狀態用兩列互斥表示，等於把打勾寫成長的。**群組浮層也一起改**，
它本來就只有 auto／ordered 兩個模式，收得更乾淨。

實機要看的：開啟浮層時反白的是不是**目前生效的那一列**；按 `[A]` 該列變琥珀色、
上下鍵能排順序、再按一次結束；用手指點那一列也要一樣；
第一列的打勾點得動、取消勾選之後排序才會生效；群組浮層同樣只剩一個打勾。

#### 目前的操作形狀（改過三輪才定案，不要憑直覺改回去）

    [A]      連線方式與群組成員都是＝進入移動模式
    [X]      連線方式＝鎖定／解除鎖定；群組＝往上移一格
    [Y]      連線方式＝修改；群組＝往下移一格
    [R1]/[L1] 移除路線／退出群組，**都會跳確認框**
    ▶ ◀     把焦點移到列尾的小圖示上，再用 [A] 執行
    ≡ 握把   觸控版的移動：點了進入移動模式，該列變琥珀色並換出上下箭頭，✓ 結束
    [B]      回到**該來源的動作選單**，不是來源清單

每一列底下都有一行說明，並且把 ▶ 這個動作寫進去——**圖示不寫出來就等於藏起來**。

#### 還沒做

1. 實機驗證上面那段 `[A]` 的新形狀。
2. 其餘實機驗證：主畫面 L2/R2 一個群組只佔一格、橫幅寫「目前使用「某台」」、
   群組成員多的時候**看有沒有黃黑斜紋**。
3. 都確認之後：把 `wip/source-groups` 併回 `main-zh`。

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
