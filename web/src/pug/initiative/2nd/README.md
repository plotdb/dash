# 2nd — 三種長相, 同一份 def

`1st` 要回答的是「一個儀表板由哪些東西組成」，所以刻意用最素的樣式。
這一組回答接下來那一題：**那些東西固定下來之後，長相能換到什麼程度**。

入口頁：`npx server -r web -p 64500` 後開 `http://localhost:64500/initiative/2nd/`

| | 給誰看 | 長相 |
|---|---|---|
| [`design-1`](design-1/) 分析台 | 坐在螢幕前面、正在找原因的人 | 深色、密集、滿版不捲動 |
| [`design-2`](design-2/) 報告 | 要把結論讀完的人 | 紙、襯線、無卡片、整頁往下捲 |
| [`design-3`](design-3/) 牆面 | 十公尺外走過去的人 | 色塊拼貼、3px 的縫、巨大的數字 |


## 三版共用的東西

同一份資料、同一批圖表 block（line / pie / bar / percent-list / taiwan-map）、
同一套 crossfilter 語意，以及同一個 `def` 結構 ——
`data` / `layout` / `panels`，每個 panel 一樣是 `area` / `chart` / `data` / `cfg`。

連 panel block 的程式都是同一份：`block/panel/0.0.1/index.ls` 三份**逐字相同**，
只有 `index.pug` 的外觀不一樣。KPI block 的差別也只有兩處
（design-2 拿掉了進度條與數字補間），邏輯同樣是跟 board 要資料、
把 `compare` 的子集畫成比例。

換掉的就三件事：

1. **panel block 的外觀** —— `index.pug` 裡的 pug 與 stylus
2. **一層主題** —— 一個 `theme` 物件 deep merge 進每個有圖的 panel 的 `cfg`
3. **`def.layout`** —— 欄、行高與 `gap`

第 1 點靠的是 `dash.board` 支援**每個 panel 指定自己的 panel block**
（`p.panel`，沒指定就用 board 的預設）；第 2 點靠的是圖表的 config 結構一致
（都從 `chart.utils.config.preset` 長出來），所以同一份東西可以套到每一張圖上。


## 看得出差別的那幾行

| | design-1 | design-2 | design-3 |
|---|---|---|---|
| `layout.row` | `1.15fr 1fr` | `19em 24em 15.5em` | `1.55fr 1.25fr` |
| `layout.gap` | `14px` | `26px` | `3px` |
| `.dash` 高度 | `100%`（預設） | `auto` | `100%`（預設） |
| 格線 | 實線 | 虛線 `2 3` | 實線, 更淡 |
| `subset.background` | 卡片底 `#18202a` | 紙 `#fbfaf7` | 磚底 `#1c1a19` |
| 地圖漸層低端 | 不能太暗 | 不能太深 | 不能太暗 |
| def 的位置 | 右側抽屜 | 文件最後的附錄 | 沒有 |

最後兩列是同一件事的三種答案：底色換了，所有「往背景靠」的設定都要跟著換，
而 def 放哪裡取決於畫面還有沒有空間、以及有沒有人在操作。

每一版各自的理由寫在自己的 `README.md`。design-1 的那一份另外記了
**三個深色底踩到的核心問題**與**順手修掉的配色 bug**，那些是這一整組的副產品。
