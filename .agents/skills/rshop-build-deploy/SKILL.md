---
name: rshop-build-deploy
description: "Build the R-Shop APK and put it on the AYN Thor. Use when: a change compiles and needs to run on hardware. Covers the JDK trap that has already cost two sessions, the setting that silently empties itself, and the signature mismatch that makes an install fail with no useful message."
argument-hint: "Optional: ADB serial if more than one device is connected"
---

# Skill: `rshop-build-deploy`

## Role

Take a finished change onto the physical device without re-diagnosing the same
three environment traps. **Every one of the traps below has already happened at
least once** — they are recorded because the error messages do not point at the
cause.

> **權限**：`AGENTS.md` §5 禁止未經允許安裝、部署、清資料。**建置與測試不用問，
> 推上裝置要問**。一個工作階段問一次就好，不是每次部署都問。

---

## Environment — verify, do not assume

| Key | Value |
| --- | --- |
| Flutter | `D:\flutter\bin\flutter.bat` — **not on `PATH`**；一定要打全路徑 |
| Gradle JDK | `C:\Program Files\Java\jdk-21` |
| ADB | `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` — 同樣不在 `PATH` |
| Package | `com.retro.rshop.tw` |
| APK 備份 | `D:\test-apk\` |

---

## Step 0 — 先驗 JDK 指向（30 秒，省掉一小時）

```bash
type "$APPDATA/.flutter_settings"
```

必須看到 `"jdk-dir": "C:\\Program Files\\Java\\jdk-21"`。

**這個檔案會自己變空。** 已經發生過一次：設好、建置成功、隔一段時間再建又炸。
所以這是每次建置前的檢查，不是一次性設定。空的就重設：

```bash
"D:/flutter/bin/flutter.bat" config --jdk-dir "C:\Program Files\Java\jdk-21"
```

### 為什麼不能靠 `JAVA_HOME`

Flutter 挑 JDK 的順序是 **`flutter config --jdk-dir` > Android Studio 的 `jbr` > `JAVA_HOME`**。
Android Studio 的 `jbr` 是 **Java 25**，而 R-Shop 用的 Gradle 8.14 解析不了 `25.0.2`
這種版號。**只設 `JAVA_HOME` 完全沒有作用**，因為 `jbr` 排在它前面。

### 它長什麼樣

```
> What went wrong:
   25.0.2
```

**就這一行，沒有別的。** 上一次我把它誤判成 NDK 沒裝，繞了很久。
要看到真相得加 `--stacktrace`，才會出現 `JavaVersion.parse`。

**改完 JDK 指向後一定要 `gradlew --stop`** — 舊的 daemon 會用舊的 JVM 活著，
不停掉的話設定改了也沒用。

> megingiard 不會中這招：它的 Gradle 9.3.1 有 `toolchainVersion=21`，
> 所以 JBR-25 無害。**兩個專案的行為不同，不要拿 megingiard 的經驗套過來。**

---

## Step 1 — 分析、建置

```bash
"D:/flutter/bin/flutter.bat" analyze
```

`analyze` 全綠 **不代表能用**。焦點跑掉、浮層蓋住內容、觸控點不動、版面溢位，
靜態分析一個都抓不到。見 `rshop-touch-and-gamepad`。

```bash
"D:/flutter/bin/flutter.bat" build apk --debug
```

第一次跑（或 `pub get` 之後）若冒出上百個 `flutter_riverpod` 之類的
「URI doesn't exist」，那是套件沒解析，不是程式壞了 —— 跑 `flutter pub get`。

---

## Step 2 — 上機

裝置上那版若是**別台機器建的 release 版**，debug 版覆蓋不上去，
而且資料備不出來（`run-as` 會回 `package not debuggable`，`ALLOW_BACKUP` 也沒開）。
**唯一的路是先移除再裝，資料會沒。** 移除前要問。

裝好之後，`adb exec-out run-as com.retro.rshop.tw cat …/app_flutter/config.json`
可以直接讀實機設定 —— **只有 debug 版行得通**，用來確認來源／備援真的存進去了。

---

## Step 3 — 收尾（三件事，少一件不算完成）

1. `docs/FIX_LOGS.md` 追加一條（**問題點 / 修復點 / 檔案** 三個固定欄位）
2. `docs/FIX_INDEX.md` 補一列
3. `python scripts/build_fix_by_file.py` 重跑

然後 **commit 並 push**。使用者的規則是**每累積約五項就部署並推送**；
**UI 改動不受這個上限——改一項就值得出一版**，因為 UI 問題只有實機才現形。

分支：R-Shop 的客製化一律進 **`main-zh`**，`main` 只放中文化。
`git add` 用明確路徑，**不要用 `-A`** —— 別的工作階段同時在改這個 repo。
