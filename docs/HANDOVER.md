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

目前尚無待驗證項目（多組備援 Multi-Fallback 與來源 UI 實機驗證已於 2026-08-09 通過測試）。

---

## 2. 待辦

目前無進行中之待辦事項。

---

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
