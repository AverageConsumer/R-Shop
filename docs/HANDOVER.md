# R-Shop 交接：現在停在哪

> **這份是「未完成」清單，不是紀錄。** 做完的事寫進 [FIX_LOGS.md](FIX_LOGS.md) 並在
> [FIX_INDEX.md](FIX_INDEX.md) 補一列，然後**把它從這裡刪掉**。
> 留在這裡的每一條都應該是真的還沒做完。
>
> 使用者說「繼續任務」時，先讀這份。

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

### 2.3 自動選最快的那條路線

使用者提過但**當時決定先不做**：兩個位址即使是同一台伺服器，他也要當成獨立來源
（見 `.agents/skills/rshop-source-routing`）。所以「自動挑最快」目前沒有意義，
除非之後改變那個前提。

### 2.4 `FIX_BY_FILE.md` 有 2 條反查不到

`R-Shop 測試基準`、`R-Shop 實機重裝` —— 這兩條**本來就沒有程式碼變更**，
`**檔案**` 欄寫的是「無程式碼變更」。**這是正確狀態，不用補。**
只是每次跑 `scripts/build_fix_by_file.py` 都會提醒你有 2 條，別被它嚇到。

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

### 3.2 桌面平台的 7 個產生檔一直是未提交狀態

    linux/flutter/generated_plugin_registrant.{cc,h}
    linux/flutter/generated_plugins.cmake
    macos/Flutter/GeneratedPluginRegistrant.swift
    windows/flutter/generated_plugin_registrant.{cc,h}
    windows/flutter/generated_plugins.cmake

每次 `flutter pub get` 都會重寫。**這個專案只出 Android**，提交它們只會製造雜訊。
`git status` 看到它們是正常的，不要順手 `git add`。

> 這也是為什麼 **`git add` 一律用明確路徑，不要用 `-A`**——
> 而且工作區有多個視窗同時在改（見 `GLOBAL_DEV_NOTES.md` 開頭）。
