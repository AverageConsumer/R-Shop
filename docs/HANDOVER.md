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
`rshop-source-routing`（來源／路由／備援的不變式）· `rshop-l10n`。

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

---

## 2. 待辦

### 2.1 五個語系缺三個 onboarding 字串

`onboarding_folderExplanationTitle`、`onboarding_folderExplanationMessage`、
`onboarding_continueToPicker` 只有 `en` 與 `zh` 有，**de / es / fr / ja / pt 全缺**。

這就是 `test/l10n_completeness_test.dart` 的 `DE has all EN keys` 一直失敗的原因——
**它是真的缺，不是環境問題**，補完那一項就會綠。
（另外 6 個失敗才是環境造成的，見 §3。）

### 2.2 `analyze` 的 6 個既有問題

不是這幾輪造成的，但沒人清：

    lib/features/onboarding/widgets/romm_legacy_login_screen.dart:11   未使用的 import
    lib/features/sources/manual_source_add_screen.dart:14              未使用的 import
    lib/features/onboarding/widgets/welcome_chooser_step.dart:434      未使用的區域變數 color
    lib/widgets/console_dialog.dart:91                                 未使用的區域變數 rs
    lib/features/game_list/widgets/game_grid.dart:178                  cacheExtent 已棄用
    lib/features/library/library_screen.dart:1294                      cacheExtent 已棄用

---

## 3. 已知不修

### 3.1 測試基準：7 個失敗是既有的

`flutter test` 完整跑約 1760 通過 / 7 失敗。**7 個都不是回歸**：

    l10n_completeness: DE has all EN keys   真的缺字串，見 §2.1
    network_discovery: mDNS                 Windows socket errno 10042
    rom_folder_service ×3                   Windows 路徑行為
    romm_pairing_live_smoke ×2              需要真的有 RomM 跑在 localhost:8090

**另外有一個時序敏感的測試會偶爾多失敗一個**：
`game_list_controller: restoreFilters applies saved filters`。
**單次隔離執行失敗不足以認定回歸**——我為此誤判過一次，連跑三次就會發現它自己會過。

### 3.2 自動選最快的那條路線：決定不做

不是「還沒做」，是**做了會違反來源路由的不變式**——「同一台也當不同台」之下，
替使用者換一條路等於替他換了一個來源。連不上時走**備援**已經涵蓋真正需要的情境。
理由與重開條件見 `docs/FIX_LOGS.md` 的 `[R-Shop 自動選最快]`。

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
