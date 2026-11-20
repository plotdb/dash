# 主題 —— 同一份 def，換一個長相

`variation/` 那七個設計各自把主題寫在頁面裡，而且寫成一個函式（`theme-of(mode, panel)`）。
這一頁是收進套件之後的版本：**主題是一份 JSON**，跟 def 一樣可以存、可以傳、可以由另一個
UI 產生，也過得了 iframe。

開 `http://localhost:64500/initiative/theme/`。左邊是儀表板，右邊那一欄是**照主題的
`schema` 長出來的自訂面板** —— 宿主不必為每個主題各寫一份表單。


## 一個主題是三件事

少一件就只能換半套：

| | 在哪裡 | 為什麼不能少 |
|---|---|---|
| `blocks` | panel / kpi / filterbar 的 block | 有沒有卡片、是 1px 的框還是 3px 的縫，是 pug 的結構，CSS 變數搆不到 |
| `vars` | CSS custom property | 寫在 `board.root` 上。block 不是 shadow DOM，繼承得進去，所以 panel 的外觀不必接任何 JS |
| `cfg` | 圖表的 config | 圖表的顏色不吃 CSS，要算一份併回每個 panel 的 `cfg` 再重畫 |

三者的值都從**同一組 token** 長出來。這個方向很要緊：反過來（從 CSS 變數推圖表色票）走不通，
因為圖表要的有一半 CSS 沒有對應的概念 —— 色階的五個階、「沒有資料」的顏色、未選的那一段
往哪個底色退。token 當唯一來源，使用者改一個主色才會同時走到卡片邊框與圖表配色。


## 參照語法只有一條規則

字串**剛好**是 `"$name"` 就換成 `tokens[name]`，其他一律照字面：

```json
"hue":  {"cat": {"palette": {"colors": "$cat"}}},
"vars": {"--dash-accent": "$accent"}
```

不做運算，也不做巢狀表達式。一加運算就會變成一個要自己寫文件、要自己除錯的小語言，
而主題要能被另一個 UI 產生 —— 它得是純資料。

換進來的值不再往下解一次：token 指到 token 要嘛是寫錯，要嘛是無窮迴圈。


## def 裡沒有顏色

每張圖只說兩件事：

 - `hue` —— 這張圖畫的是**哪個維度**（書系 / 通路 / 地區）。那個維度在這個主題下是什麼
   顏色，是主題的事
 - `role` —— 這個 panel 是**什麼角色**（`kpi` / `filterbar` / `ref`）。它同時決定用哪一個
   block，以及要不要多套一層 cfg

合併順序，`panel` 自己的 `cfg` 放在最後：

```
主題 cfg → hue[panel.hue] → chart[圖種] → role[panel.role] → 使用者的 theme.cfg → panel.cfg
```

最後那一段是給「使用者調過的那一張圖」留的：換主題不該把他的調整洗掉。所以編輯器改的是
**那張圖自己的 cfg**（`updatePanel(id, {cfg})` 寫進 `p._cfg`），不是合併後的結果 ——
不然換主題時不是把他的修改洗掉，就是把主題的值當成他自己設的而焊死。

還有一個坑：**每次都要從 panel 原始的 cfg 重算**。拿已經套過主題的那一份再套一次新主題，
上一個主題的值會留在新主題沒覆蓋到的 key 上（例如只有深色底才需要設的 brush，切到淺色底
會留著一塊發亮的方塊）。


## `role` 的界線

`role` 可以讓某個主題換一個 block，但**換上去的 block 如果讀的是 def 的另一個部分，
那份 def 就只對那個主題成立了**。

這一頁踩過一次：`desk` 的主題帶了一個 kpi block，它不看 `chart`，自己畫一張卡片、還會寫
「佔全體 x%」。但那張卡片讀的是 `compare` 的子集，所以 def 得開 `compare: true` —— 一開，
`raw` 就變成未篩選的全體，而 `vanilla` 沒有 kpi block，退回 panel block 之後
`@makechart/number` 畫的是 `raw`：畫面上就是「篩了半天數字不動」。

所以這一頁的 KPI 四格刻意不寫 `role: \kpi`。要用它，要嘛每個主題都備齊那個角色的 block，
要嘛就別用。

（block 找不到時的退回順序是 `panel 自己指定的 → 主題給這個角色的 → 主題的預設 →
board 的預設`。中間那一段退回**主題的** panel block 很要緊：退回 board 的預設會變成一張
畫不出來的空卡片。）


## 版面是 def 的事

`theme.layout` 只是建議值，`def.theme.layout` 給 `true` 才套，而且只補 `def.layout`
**沒寫的鍵**。`report` 是 `auto` 高度往下捲、`pocket` 是 2 欄、`wall` 的 gap 是 3px ——
換主題不換版面，`report` 會變成一個擠在 100% 高度裡的東西；反過來硬換，使用者排好的格子
就沒了。所以這是一個獨立的選擇。

`split` 版面只認 `gap`：它的位置在一棵樹上（`layout.root`），`col` / `row` 塞進去不會有
任何作用，只會讓存回去的 def 多兩個看不懂的鍵。

兩份內建主題的建議版面都是 **12 欄**（2 / 3 / 4 / 6 都整除得開），所以同一份 def 換主題時
格子不必重排。


## API

```js
dash.themes                      // 內建清單: [{name, title, path}]
dash.theme(t, {base})            // 讀一份主題, 回傳解析後的結果
board.setTheme(theme)            // 併 cfg + 寫 CSS 變數 + 需要時換 block, 不清篩選
board.setMode('dark')            // 等同 setTheme({...現在的, mode})
board.theme                      // 解析後的結果 ( 含 tokens 與 schema, 給自訂面板回填 )
```

`setTheme` 回 Promise 是因為換 `name` 可能要重掛 block；只改 `tokens` / `mode` 的話不重掛，
就是重算 cfg、寫變數、`render!`。**兩條路都不動 filters** —— 換個長相不該讓使用者正在看的
篩選彈掉。

`mode` 沒寫死成 `light` / `dark` 就是跟著系統走，而且**持續**跟：系統在白天與夜晚之間切換
時畫面要換，不是只在開頁面時讀一次。「要不要記住使用者的選擇、記在哪」（localStorage 的
key、網址參數）是宿主的政策，套件不碰。

主題存在 `def.theme`，所以 `dash.dump(bd.def.theme)` 印出來的就是可以存回去的那一份。


## 路徑

```
theme/vanilla.json              內建主題
theme/desk.json
block/panel/index.html          預設的 panel block ( = vanilla 的那一份 )
block/filterbar/index.html
block/panel/desk/index.html     主題自己帶的
block/kpi/desk/index.html
block/filterbar/desk/index.html
```

主題裡的 `blocks` 直接指這些路徑，所以**宿主只要給 `theme.name`，不必知道 block 在哪**。
`board` 的 `themeBase` 預設是 `/assets/lib/@plotdb/dash/main/`（fedep 放東西的地方），
宿主換了位置才要給。

主題的來源在 `web/src/raw/theme/`，`tool/pack.js` 複製到套件根目錄 —— dev server 服務的
那一份就是發出去的那一份，示範頁改一個顏色不必再 build 一次。


## 還沒做的

 - 其餘三版（`report` / `wall` / `terminal`）還沒收進來
 - `vanilla` 沒有自己的 kpi block（見上面「`role` 的界線」）
 - 沒有「從現在的主題另存成一份新主題」的 API —— 目前要自己把 `board.theme.tokens` 抄出來
 - `schema` 只有 `color` / `colors` / `length` / `font` 四種型別，沒有分組、沒有條件顯示
