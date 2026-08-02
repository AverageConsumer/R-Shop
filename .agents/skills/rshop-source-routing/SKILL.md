---
name: rshop-source-routing
description: "Touch anything about sources, connection routes, which source is in use or shown, or failover. Use when: editing source.dart, app_config.dart, sources_notifier.dart, source_failover.dart, source_resolver.dart, or the games table. Holds the five invariants that make switching cheap and self-healing — breaking any one of them loses the user's cached library, strands them on the wrong server, or redirects a sync they didn't ask to redirect."
---

# Skill: `rshop-source-routing`

## Role

這一塊的設計繞了四圈才對，因為需求很容易被讀成別的意思。
底下五條不變式是**整個功能之所以能用的原因**，改任何相關的檔之前先讀。

---

## 使用者要的到底是什麼

> 「我並不是要同時顯示兩個來源，而是**一次顯示一個來源，可以切換**」
> 「**就算是同一台，我也要當不同台**」
> 「至少要能指派一個備援就好」「timeout 後切換另一個來源」

翻成規格：**多個來源，一次看／同步一個，可以指派備援；連不上時備援自動代打。**

**不要**把兩個來源的清單合併起來當同一份看 —— 這是被明確否決過的。
即使兩個位址其實是同一台伺服器，**也一律當作獨立的來源**。

---

## 不變式 1：切換來源不能碰快取

`switchEndpoint`、`setEndpointSelection`、`addEndpoint`、`updateEndpoint`、
`removeEndpoint`、`setFallbackSource`、`setActiveSource` —— **全部走 `updateSource`，
而且一個都不准呼叫 `_purgeCachedGamesFor`。**

這就是切換之所以是免費的原因：每條路線的清單各自存著，切回去馬上就在。
一旦有人在這些路徑上加了清快取，使用者每切一次就要重掃一次整個圖書館。

---

## 不變式 2：「使用中」與「顯示」是兩個欄位，不要合併

| 欄位 | 意思 | 誰在改 |
| --- | --- | --- |
| `primarySourceId` | **使用中**：同步的目標，以及主畫面預設顯示 | 來源清單的 `[X]`／**打勾**圖示（`setPrimarySource`） |
| `activeSourceId` | **顯示**：主畫面現在在看哪一個 | 主畫面的 L2/R2、來源清單的 `L2`／**眼睛**圖示（`setActiveSource`） |

**兩個功能不能共用同一個圖示。** 眼睛只代表「在看哪一個」，打勾只代表「用哪一個」——
它們一度是同一個設定，使用者分不清正是當初要拆開的原因。

**`resolveForSync` 讀的是 `primarySourceId ?? activeSourceId`。**
`?? activeSourceId` 是分家之前的設定檔的相容路徑，`fromJson` 也做同樣的回填 ——
**兩處要一起改，不然舊安裝會突然改同步對象。**

為什麼是 `activeSourceId` 留給「顯示」而不是反過來：顯示是靠
`_writeAndPublish` 依它重寫 `system.providers` 生效的，換一邊就得動整條讀取鏈。

**別再把「目前選的來源」鏡像成 State 的欄位。** 先前用 `_activeSourceId ??= stored`
種值，而 **`??=` 表達不了「刻意是 null」**——取消之後下一次 build 又種回去，
使用者要按兩次才取消得掉。畫面上的標籤一律直接讀設定檔。

---

## 不變式 3：備援是暫時代打，不改變偏好

`chooseSource()` 選到備援時，**`activeSourceId` 不會被改寫**。
`withEffectiveSource()` 重建的是**記憶體中的 config，磁碟完全不動**。

所以偏好的那台一旦醒過來，下一次自己就回去了 —— 不需要使用者再設定一次。
**如果哪天有人為了「讓它記住」而把 `activeSourceId` 寫回磁碟，這個自癒就死了。**

---

## 不變式 4：`url`/`host`/`port`/`share` 就是「現行路線」

`Source` 的頂層欄位**不是預設值，是當下生效的那條路**。
`withLiveEndpoint()` 會把選中的 endpoint 的值寫上去。

這樣設計的代價是省掉了一整輪改動：`SourceResolver`、`connectionKey`、
各個 provider **完全不必知道 endpoint 的存在**。要維持這個好處，
新程式碼一律讀頂層欄位，**不要自己去 `endpoints` 裡挑**。

`fromJson` 會從舊欄位補一個 id 為 `'primary'` 的 endpoint，**所以沒有設定檔遷移**。

---

## 不變式 5：路線共用來源的憑證 ⚠️

`auth` 掛在 `Source` 上，**endpoint 沒有自己的憑證**。

同一台伺服器的多個位址共用一個 token 沒問題。
**指向另一台伺服器就會送錯 token 換回 401 —— 而 401 看起來像伺服器掛了**，
使用者無從判斷。兩台不同的伺服器要用「**兩個來源 + 備援**」，不是兩條路線。

UI 上的提示字串是 `sources_routeSameServerHint`。

---

## 資料庫：每條路線各存一份

schema **v14**。`games` 表加了

```sql
source_id  TEXT NOT NULL DEFAULT '',
endpoint_id TEXT NOT NULL DEFAULT ''
```

**`NOT NULL DEFAULT ''` 不是隨便寫的** —— SQLite 的 UNIQUE 索引把 NULL 視為互不相同，
用得到 NULL 的話唯一鍵形同虛設，同一筆遊戲會無限重複。

唯一索引：`(systemSlug, filename, source_id, endpoint_id)`。
孤兒清除也要**帶上這三個欄位**，否則會刪掉別條路線的資料。
串連刪 `game_metadata` / `ra_matches` 前要先檢查 `stillReferenced`。

相關 API：`saveGamesByRoute()`（依每筆遊戲**自己的** `providerConfig` 分組）、
`getGamesForRoutes()`、`getGameCountsPerRoute()`、`deleteRoute()`。

---

## 探測

`EndpointProbeService` 用 TCP connect，單點 1 秒／整體 3 秒，有 TTL 快取。

**已修過的坑**：`_probeableEndpoints()` 在 `endpoints` 為空時，
原本會靜默回報「不可達」—— 而不可達正是觸發備援的條件，
所以在程式碼裡直接建出來的 `Source` 會莫名其妙一直走備援。
現在會從 `Source` 自己的欄位合成一個 endpoint。

---

## 檔案

見 `docs/FIX_INDEX.md` 的 **R-Shop 連線路由**、**R-Shop 目前來源**、
**R-Shop 來源備援**、**備援接進同步**、**連線方式共用憑證** 五條 —— 檔案清單在那裡，
不要重新搜尋。

UI 那一面另見 `rshop-touch-and-gamepad`：這個功能的四個浮層
（endpoint picker、fallback picker、actions overlay、type picker）
**每一個都曾經是觸控死的**。
