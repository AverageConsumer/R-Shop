---
name: rshop-touch-and-gamepad
description: "Add or change any R-Shop UI. Use when: writing a screen, overlay, dialog, or list row. The target device has a gamepad AND a touchscreen, so every function needs two entry points — and the three failure modes here (touch-dead overlays, focus lockout, hardcoded key names) are all invisible to flutter analyze."
---

# Skill: `rshop-touch-and-gamepad`

## Role

R-Shop 跑在 **AYN Thor** —— 3.92 吋掌機，**手把與觸控兩套輸入都在用**。
這份技能存在的原因是：底下四種錯誤**每一種都真的出貨過**，而且
`flutter analyze` 全綠、程式碼看起來也完全正常。

---

## 鐵則：每個功能兩個入口

> 使用者原話：「所以功能都要有兩個入口 一個是觸控 一個是手把(或按鍵)」

一個是觸控，一個是按鍵。**只有其中一個的功能等於沒做完。**

反例（真的發生過）：「目前顯示哪個來源」只能在首頁用 L2/R2 切 ——
使用者在來源設定頁想切，得先退回首頁。修法是在來源設定的**每一列前面加眼睛圖示**，
再在浮層右上角放一個，鍵與觸控各自都能走完。

---

## 陷阱 1：浮層的列是 `Container`，完全不吃觸控

**`ConsoleFocusable` 自己內建 `GestureDetector`**，所以用它包起來的卡片點得動。
浮層裡的列若是純 `Container` + 手動畫選取框，就是**零觸控處理**。

**外觀完全看不出差別。** 兩者都會highlight、都會回應搖桿。
只有真的用手指去點才知道死的。這個坑修了**三輪**才清乾淨，
因為每輪只修到當時被回報的那一個浮層。

**做法**：任何可選的列都要有 `onTap`，而且**點下去要走跟按鍵完全相同的那一條路徑**
（抽一個 `_pickSelected()` 之類的方法給兩邊共用），不要各寫一份。
`_OverlayButton`、`_TypeOptionTile` 這類自訂元件也一樣。

---

## 陷阱 2：焦點鎖死 —— 手把全失效只剩觸控

`_initialFocusClaimed` 這種 flag 一旦設成 `true` 就**永不重置**。
持有焦點的那張卡片被回收之後（例如刪掉最後一筆來源），
螢幕上**沒有任何節點有焦點**，手把從此完全沒反應。

**做法**：`_ensureInteractiveFocus` 要在**沒有任何節點有焦點時放棄宣告**
（把 flag 放掉），讓下一輪重新指派。列表可能被清空的畫面都要檢查這件事。

---

## 陷阱 3：按鍵名寫死

裝置支援三種配置：`ControllerLayout {nintendo, xbox, playstation}`。
**同一個實體鍵在三種配置下名字不同。** 所以

- ❌ `Text('L2')`、`Text('R2')`、`Text('X')`
- ✅ `GamepadIcons.assetPath(id, layout)`

還有一個相關的：**別在圖示旁邊擺一個裸的字母**。曾經在浮層標頭把眼睛圖示旁邊
放了個 `X`，使用者讀成「關閉按鈕」。提示文字要放在**底部提示列**，
不要放在會被誤認成按鈕的位置。

---

## 陷阱 4：版面與高度

- **溢位**：`RenderFlex overflowed` 在 3.92 吋螢幕上很容易發生，畫面會出現黃黑斜紋。
  浮層內容一律包 `SingleChildScrollView`。診斷靠 logcat，不是靠 `analyze`。
- **高度會跳**：`SystemChrome.setEnabledSystemUIMode(immersiveSticky)` 是在 `initState`
  跑的，所以**第一幀還有狀態列 inset，後面的幀沒有**。頂部元件若包 `SafeArea`，
  進場時會高一列然後縮回去。全螢幕沉浸的畫面**不要包 `SafeArea`**。
  **`rs.safeAreaTop` 也一樣，它不是常數。** 這個坑犯了兩次：橫幅的 `SafeArea`，
  以及 `home_grid_view` 的 `top: rs.safeAreaTop + 40.0`——症狀一模一樣
  （進場多一列空白，一移動就不見）。**看到 `safeAreaTop` 先懷疑。**
- **焦點白框要留內距**：`ConsoleFocusable` 的白框是緊貼 child 畫的。child 自己也有
  邊框（輸入框那種）時，兩條線差幾個像素，看起來像畫錯而不是焦點。
  **包一層 `Padding`，並給比內層大的 `borderRadius`。**
- **浮層會蓋住內容**：小螢幕上「疊在上面」跟「擠掉內容」的差別很明顯，
  設計時要想清楚要哪一種。

---

## 元件位置

| 用途 | 檔案 |
| --- | --- |
| 可聚焦列（自帶觸控） | `lib/core/widgets/console_focusable.dart` |
| 對話框（一律用這個） | `lib/widgets/console_dialog.dart` |
| 浮層焦點範圍／優先權 | `lib/core/input/overlay_scope.dart` |
| 手把圖示 | `lib/widgets/gamepad_icons.dart` |

---

## 交件前的自我檢查

**這不是原則，是出貨前要真的做的檢查：**

1. 這次加的每個功能，**用手指走一遍**能不能完成？
2. **只用手把**能不能完成？
3. 列表被清空之後，手把還有反應嗎？
4. 畫面上有沒有寫死的按鍵字母？
5. 進場的第一幀跟之後的幀，高度一樣嗎？

前例：`docs/FIX_INDEX.md` 的 **浮層只做了手把**。
