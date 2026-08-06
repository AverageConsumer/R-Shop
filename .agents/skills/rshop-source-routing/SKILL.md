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

翻成規格：**多個來源，一次看／同步一個；使用者可以把幾個來源宣告成一個群組，
連不上時群組裡的另一台自動代打。**

**不要**自作主張把兩個來源的清單合併起來當同一份看 —— 這是被明確否決過的。
**程式不准推論**兩個位址是不是同一台。

**但使用者可以宣告**（2026-08-05 補）：

> 「應該不是備援 而是 我想指定兩個來源 其實是指向同一台伺服器」「應該是設成群組」
> 「因為同一群組 應該實際是同一台之類 所以清單也只需要一份」

宣告成群組之後，那幾個來源就**共用一份清單**。這不牴觸「同一台也當不同台」——
那條管的是**推論**，群組是**宣告**。沒有東西會自己變成群組。

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
| `primarySourceId` | **使用中**：同步的目標，以及主畫面預設顯示 | 來源清單的 `[X]`／**打勾**圖示 |
| `Source.enabled` | **開／關**：關掉就不出現在主畫面，也不同步 | 來源清單的 `L1`／**眼睛**圖示 |
| `activeSourceId` | 主畫面現在單獨在看哪一個（null＝看全部開著的） | 主畫面的 L2/R2 |

**兩個功能不能共用同一個圖示。** 眼睛是開關，打勾是「用哪一個」。

**不要再發明第三個「是否顯示」的旗標。** 曾經加過 `Source.showOnHome`，
使用者一句話打回：「**你的停用啟用不就是眼睛嗎，不用再做一個**」。
`enabled` 為 false 的來源本來就不出現也不同步。

**`setEnabled(false)` 不清快取。** 曾經會清，理由是「不然格線還會顯示剛關掉的來源」——
**v14 之後那個理由消失了**：讀取一律走該系統當下的 providers，停用的來源不在裡面。
清了的話停用→啟用要重抓整份清單，而且背景清除會刪掉剛重抓回來的資料。
唯一直接讀表的是圖書館頁，過濾在那一側做。**`removeSource` 仍然清。**

**`resolveForSync` 讀的是 `primarySourceId ?? activeSourceId`。**
`?? activeSourceId` 是分家之前的設定檔的相容路徑，`fromJson` 也做同樣的回填 ——
**兩處要一起改，不然舊安裝會突然改同步對象。**

為什麼是 `activeSourceId` 留給「顯示」而不是反過來：顯示是靠
`_writeAndPublish` 依它重寫 `system.providers` 生效的，換一邊就得動整條讀取鏈。

**別再把「目前選的來源」鏡像成 State 的欄位。** 先前用 `_activeSourceId ??= stored`
種值，而 **`??=` 表達不了「刻意是 null」**——取消之後下一次 build 又種回去，
使用者要按兩次才取消得掉。畫面上的標籤一律直接讀設定檔。

---

## 不變式 3：代打是暫時的，不改變偏好（2026-08-05 改寫為群組）

**「備援」這個機制已經被群組取代。** `Source.fallbackSourceId` 還在設定檔裡讓舊版讀，
但**選路徑不再讀它**：載入時 `sourceGroupsFromFallbacks` 會把每一組配對遷成一個
兩人群組（偏好在前、模式 `ordered`），那正是舊備援的行為。兩邊都讀就是兩套機制搶同一個決定。

`chooseSource()` 選到群組裡的別人時，**`activeSourceId` 不會被改寫**。
`withEffectiveSource()` 重建的是**記憶體中的 config，磁碟完全不動**。

所以偏好的那台一旦醒過來，下一次自己就回去了 —— 不需要使用者再設定一次。
**如果哪天有人為了「讓它記住」而把 `activeSourceId` 寫回磁碟，這個自癒就死了。**

群組是**對稱的**，舊的配對是單向的——這是行為上真的差一截的地方：
選了群組裡的任何一個成員，偏好都是**群組自己的排頭**（同一台伺服器，選誰都一樣）。
舊測試裡「wan 沒有備援所以原地不動」那種前提因此不再成立。

模式兩種：`auto`＝**先回應的那台**（賽跑），`ordered`＝照使用者排的順序挑第一個通的。
兩者都在 `chooseGroupMember` / `resolveGroupMember` 裡，**成員之間**的賽跑，
與 `EndpointProbeService.firstResponder` 那層**同一台的多條路線**是巢狀的兩件事。

---

## 不變式 4：`url`/`host`/`port`/`share` 就是「現行路線」

`Source` 的頂層欄位**不是預設值，是當下生效的那條路**。
`withLiveEndpoint()` 會把選中的 endpoint 的值寫上去。

這樣設計的代價是省掉了一整輪改動：`SourceResolver`、`connectionKey`、
各個 provider **完全不必知道 endpoint 的存在**。要維持這個好處，
新程式碼一律讀頂層欄位，**不要自己去 `endpoints` 裡挑**。

`fromJson` 會從舊欄位補一個 id 為 `'primary'` 的 endpoint，**所以沒有設定檔遷移**。

---

## 不變式 5：憑證跟著路線走，清單跟著來源走（2026-08-04 改寫）⚠️

**舊版寫的是「路線共用來源的憑證」，那條已經作廢。** 使用者確認的前提是：
同一個來源底下的多條路線**就是同一台伺服器**，但**各自需要驗證**
（區網直連與 DDNS 走的是不同的前門）。所以：

- `SourceEndpoint` 有自己的可選 `auth`；**沒設就沿用來源層的**，舊設定檔因此零遷移。
- `Source.auth` 現在是 **getter**：`liveEndpoint?.auth ?? _defaultAuth`。
  下游（`SourceResolver`、各 provider）照樣只讀這一個，**不變式 4 不受影響**。
- 清單相反：**一個來源只存一份**（見下面的資料庫那節）。同一台伺服器的清單只有一份，
  存成多份是同一批資料的副本。

**程式分不出兩個位址是不是同一台，也不該去猜。** 曾經從埠號推論過一次，
推論是對的，但那不算數——能宣告的只有使用者。這就是「同一台也當不同台」的真正意思：
**預設不猜；他宣告了，才照宣告走。**

`connectionKey` **刻意不含憑證**，而且這是對的：它只用在舊設定檔的合併遷移
（`app_config.dart` 唯一的呼叫點，**runtime 沒有任何連線快取用它**），
同一個位址不論當初存的是哪組登入都該收成一個來源。它仍然每換一條路就變，
因為 `SourceEndpoint.sameAddressAs` 不准同一個來源有兩條位址相同的路線。

---

## 資料庫：一份清單屬於「快取擁有者」（schema v16，2026-08-05 改寫）

演進：v14 每條路線一份 → v15 收成每個來源一份 → **v16 收成每個「擁有者」一份**。
擁有者＝**有群組就是群組，沒有就是來源自己**（`AppConfig.cacheOwnerIdFor(sourceId)`）。
同一個道理往上搬一層：使用者宣告「這幾個來源是同一台」，跟宣告「這幾條路線是同一台」
一樣，結論都是**只該有一份清單**。

`games` 表有

```sql
source_id       TEXT NOT NULL DEFAULT '',   -- 誰抓的
endpoint_id     TEXT NOT NULL DEFAULT '',   -- 從哪條路抓的
cache_owner_id  TEXT NOT NULL DEFAULT ''    -- 這份清單屬於誰 ← 唯一鍵在這
```

**`NOT NULL DEFAULT ''` 不是隨便寫的** —— SQLite 的 UNIQUE 索引把 NULL 視為互不相同，
用得到 NULL 的話唯一鍵形同虛設，同一筆遊戲會無限重複。`''` 是本機掃描的桶子。

唯一索引：**`(systemSlug, filename, cache_owner_id)`**。
`source_id` 與 `endpoint_id` **都留著但都不進唯一鍵**，只做歸屬記錄。

**v16 遷移一列都不刪**：只加欄位、把 `cache_owner_id` 從 `source_id` 一對一補進去、換索引。
**合併與去重不在遷移裡**，在 `adoptCacheInto()` —— 群組存在設定檔裡，資料庫層讀不到，
在遷移裡用猜的去合併就是「憑猜測刪列」。

去重判準只有一條：`_onDeviceRank`（原 `_v15OnDeviceRank`）——
**已經下載到機器上的那一列一定活下來**（`purgeOrDetachSource` 會把它的
`provider_config`／`url` 清空，那就是識別記號），還有遠端 url 的可以重抓。
`_collapseDuplicates` 是唯一的實作，v15 與群組合併共用它。

群組的三個入口，**都在一個交易裡**：

    adoptCacheInto(ownerId:, memberIds:)    加入群組＝把成員的清單併進擁有者的，順便去重
    moveCacheOwnership(from:, to:)          擁有者自己退出＝整份清單交給下一個成員
    releaseCacheFrom(sourceId:, ownerId:)   一般成員退出＝**什麼都拿不到**，要重新同步

合併時會**暫時 drop 唯一索引**再重建——重建本身就是驗證，還有殘留就直接拋例外整筆 rollback。
`releaseCacheFrom` 會把離開者的 `source_id` 改蓋成擁有者，
而 `purgeOrDetachSource` 要帶 **`protectedOwnerIds`**（那個來源當時所在的群組），
否則刪掉一個成員會連群組的列一起帶走——它是用 `provider_config` 的 JSON 比對的，
欄位改了它也還是認得出那些列是誰抓的。

**這是自動換路之所以無感的原因**：換路不會換到另一份清單，所以沒有空清單、
沒有重抓。**換群組成員同理**。

相關 API：`saveGamesByRoute(cacheOwnerOf:)`、`getGamesForRoutes(cacheOwnerOf:)`、
`getGames(cacheOwnerId:)`、`saveGames(cacheOwnerId:)`、
`getGameCountsPerCacheOwner()`、`getGameCountForOwner()`、`deleteCacheOwnedBy()`。
**後三個是 v16 改的名**（v15 時叫 `…PerSource`／`ForSource`／`deleteSourceCache`），
因為語意真的變了——名字裡寫 source 會讓人以為刪一個群組成員要順手刪快取，
而那正是現在不准做的事。`cacheOwnerOf` 不傳就等於「每個來源各自擁有」，
也就是沒有群組的安裝看到的行為。

---

## 探測與自動選路（2026-08-05 改寫）

`EndpointProbeService` 用 TCP connect，單點 1 秒／整體 3 秒，有 TTL 快取。
**它現在回的是延遲不是通不通**：`probeFor()` 給 `ProbeResults`（`ranked` 最快在前、
`latencyOf(id)` 給浮層顯示、`fastestId` 就是「自動」會挑的那一條）。
`reachableFor()` 留著，因為 `resolveForSync` 問的真的只是「這個來源整台通不通」。

`resolve()` 的規則：**釘選就用釘選的，否則挑能通的裡面最快的**。
`resolveEndpoint({List<String> reachable})` 吃的是**排序後的 id 清單**不是延遲——
`lib/models` 不准 import 服務層的型別，而且傳清單比只傳最快的那個好：
最快的那條被刪掉時會自動退到第二快，傳單一 id 就沒有退路。

**`pin: true` 的意思是「使用者覆寫」，不是「選定」。** 沒覆寫就自動，
浮層的「自動」那一列走 `clearEndpointOverride`。`autoSelectEndpoint` 探測完會**重讀一次狀態**
才動手——探測那一秒內使用者可能剛好釘選了，不重讀就會把他的覆寫蓋掉。

**`_bootstrap` 不探測。** 開機不能等網路，而且測試裡建個 notifier 就會開真的 socket。
它只做離線的對齊：釘選指向不存在的路線就退回 `auto`，有效的釘選把值鏡到頂層欄位（不變式 4），
真的有變才寫回磁碟。

> 為什麼自動選路現在合法：見 `docs/FIX_LOGS.md` 的 `[R-Shop 自動選最快]`——
> 那條當初判定「不做」，**錯在把路線之間當成來源之間**。「同一台也當不同台」管的是來源，
> 同一個來源底下的路線本來就是同一台、同一份清單，換路線換不掉使用者選的來源。

**已修過的坑**：`_probeableEndpoints()` 在 `endpoints` 為空時，
原本會靜默回報「不可達」—— 而不可達正是觸發備援的條件，
所以在程式碼裡直接建出來的 `Source` 會莫名其妙一直走備援。
現在會從 `Source` 自己的欄位合成一個 endpoint。

---

## 檔案

見 `docs/FIX_INDEX.md` 的 **R-Shop 連線路由**、**R-Shop 目前來源**、
**R-Shop 來源備援**、**備援接進同步**、**連線方式共用憑證** 五條 —— 檔案清單在那裡，
不要重新搜尋。

## 畫面（2026-08-05 群組完成後）

    群組編輯          lib/features/sources/group_picker_overlay.dart
                      未分組＝可選的同類型來源；已分組＝兩種模式＋成員（可排序、可退出）＋解散
    連線方式浮層      多一列「照我排的順序」。**點某條路線＝進入移動模式**（與群組成員同一個手勢），
                      不是「使用這條」——那個動作已經拿掉了，因為不鎖定就留不住。
                      要哪一條由三個入口決定：自動／照我排的順序／`[X]` 鎖定。
                      游標的初始位置要用 `_firstRouteIndex` 算，路線不是從索引 1 開始
    來源卡片          顯示「群組 · 名字」；「備援 → X」已經不存在
    主畫面            collapsedSources()：一個群組只佔 L2/R2 的一格；
                      橫幅寫「目前使用「某台」」，講的是實際在答的那一台

`fallback_picker_overlay.dart` **已刪除**。「備援」這個詞在畫面上不該再出現，
`sources_setFallback` / `sources_fallbackNone` 兩個字串已無人使用。

UI 那一面另見 `rshop-touch-and-gamepad`：這個功能的浮層
（endpoint picker、group picker、actions overlay、type picker）
**每一個都曾經是觸控死的**。群組浮層一開始就配了 widget 測試盯著每一列可點，
成員排序是「角落小圖示（觸控）＋ `[X]`／`[Y]`（手把）」，路線排序是 ◀ ▶ ＋角落箭頭。
