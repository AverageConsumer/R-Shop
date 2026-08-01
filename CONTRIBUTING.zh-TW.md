> [English](CONTRIBUTING.md) | **繁體中文**

# 為 R-Shop 做出貢獻

首先——**謝謝你！** 🎮 無論你是修正一個錯字，還是打造一整個全新功能，每一份貢獻都讓 R-Shop 變得更好。本專案由一位獨立開發者維護，而且他仍在邊做邊學，因此還請多多包涵與體諒。

## 如何貢獻

### 回報 Bug

1. 先查看[既有的 issue](../../issues) 以避免重複回報
2. 開一個新的 issue，並附上：
   - 清楚的標題
   - 重現該 bug 的步驟
   - 你預期的結果與實際發生的狀況
   - 你的裝置資訊（Android 版本、裝置型號）
   - 可以的話，附上螢幕擷圖或螢幕錄影

### 建議新功能

開一個帶有 **Feature Request** 標籤的 issue。描述你想要什麼，以及為什麼它會很有用。

### 提交程式碼

1. **Fork** 這個儲存庫
2. 從 `main` **建立一個 branch**（`git checkout -b feature/your-feature`）
3. **進行你的修改**——盡量讓每個 commit 聚焦且具描述性
4. 可以的話，**在實機上測試**（本 App 是為 Android 掌機設計的）
5. **開一個 Pull Request**，清楚描述你改了什麼以及為什麼

### 程式碼風格

- 遵循標準的 [Dart/Flutter 慣例](https://dart.dev/effective-dart/style)
- 讓 widget 保持專注——一個 widget、一項職責
- 使用 Riverpod 進行狀態管理（既有的模式）
- 為任何不易一目了然的邏輯加上註解

### 我們需要協助的地方

- 🐛 Bug 修正與穩定性改善
- 🎨 UI/UX 打磨與動畫
- 🎮 手把輸入改善（D-pad 導覽、手把支援）
- 📱 在不同 Android 裝置與掌機上測試
- 📝 文件與指南
- 🌍 翻譯／在地化

## 開發環境設定

1. 安裝 [Flutter](https://docs.flutter.dev/get-started/install)（SDK ≥ 3.0.0）
2. Clone 這個儲存庫
3. 執行 `flutter pub get`
4. 連接一台 Android 裝置或模擬器
5. 執行 `flutter run`

## 行為準則

友善待人、互相尊重、玩得開心。我們都因為熱愛復古遊戲而聚在這裡。 🕹️

## 授權條款

提交貢獻即表示你同意你的貢獻將依 [MIT License](LICENSE) 授權。
