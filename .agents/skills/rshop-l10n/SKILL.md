---
name: rshop-l10n
description: "Add or change a user-visible string in R-Shop. Use when: any feature adds text. Seven languages, a localization class that is NOT named what you expect, and a missing-string failure mode that does not break the build — it ships blank."
---

# Skill: `rshop-l10n`

## Role

新功能的字串**要在同一次改動裡補齊**，不要留到之後。
漏掉的字串**不會讓建置失敗**，會直接出貨成空白。

---

## 型別叫 `L`，不是 `AppLocalizations`

`l10n.yaml` 設了 `output-class: L`。寫 `AppLocalizations.of(context)` 會得到
「undefined」—— 這個錯我犯過一次。用 `L.of(context)`。

---

## 七個檔案

`lib/l10n/app_{de,en,es,fr,ja,pt,zh}.arb` —— **七個語系，一個都不能漏。**

> 各專案不同：R-Shop 7、megingiard 4、ImageOverlay 2。不要憑印象套。

改完 `.arb` **要重新產生 `app_localizations*.dart`，並且跟 `.arb` 一起 commit**
（見 `AGENTS.md` §6）。

---

## 文件用語要跟出貨字串一致

寫 README / 使用手冊之前，**先去 `app_zh.arb` 撈實際的字串**。
詞彙表過得了關不代表名詞對得上 —— 使用者看到的是畫面上的詞，不是文件裡的詞。
