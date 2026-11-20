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

**沒有主題的時候 `role` 沒有退路。** 整條鏈最後只剩 board 的預設 panel block，而那一份
不認得 `filterbar` 或 `kpi` 這種角色 —— 畫面上就是一張空卡片，只剩一個 id。所以一份用
`role` 寫的 def，等於宣告了「我要在有主題的情況下使用」。宿主的做法是讓每一份 def 都帶
`theme`（沒寫就補 `{name: "vanilla"}`），不要讓它落在沒有主題的狀態。

（dash 不自動補，是因為 `variation/` 那七個示範頁就是「沒有主題」的合法狀態：自動套一個
主題會換掉它們的 panel block，再用主題的變數蓋掉它們寫在 `:root` 的那一組。要的是 schema
而不是套用的話，用 `dash.theme('vanilla')` 讀就好，不必經過 board。）


## 版面是 def 的事

`theme.layout` 只是建議值，`def.theme.layout` 給 `true` 才套，而且只補 `def.layout`
**沒寫的鍵**。`report` 是 `auto` 高度往下捲、`pocket` 是 2 欄、`wall` 的 gap 是 3px ——
換主題不換版面，`report` 會變成一個擠在 100% 高度裡的東西；反過來硬換，使用者排好的格子
就沒了。所以這是一個獨立的選擇。

`split` 版面只認 `gap`：它的位置在一棵樹上（`layout.root`），`col` / `row` 塞進去不會有
任何作用，只會讓存回去的 def 多兩個看不懂的鍵。

兩份內建主題的建議版面都是 **12 欄**（2 / 3 / 4 / 6 都整除得開），所以同一份 def 換主題時
格子不必重排。


## 主題要自己畫底色

`theme.root` 是**直接寫在 `board.root` 上的樣式**（底色、文字顏色、字型），不是 custom
property：

```json
"root": {"background": "$paper", "color": "$text", "font-family": "$sans"}
```

需要它的理由是 `report`：它**沒有卡片**，本來就讓底色透出來。只給 custom property 的話，
宿主不會知道這個主題的紙是什麼顏色 —— 深色主題的文字就落在宿主的白底上，整頁幾乎看不見。
字型同理：`report` 的襯線、`terminal` 的等寬是那一版的身分，不該要宿主自己接線。

換主題時上一份 `root` 有而這一份沒有的屬性會被清掉，跟 `vars` 一樣。


## 給人看的字

`title` / `desc` 與 schema 的 `label` / `desc` 可以是字串，也可以是一個以語系為 key 的
物件。兩種都收 —— 自己寫一份主題的人不該為了一句說明先學一套 i18n 格式。

```js
dash.text(f.label, 'en')          // 找不到就退回 zh-TW, 再找不到就拿第一個有值的
```

少一句翻譯時畫面上看到的是**另一個語言，不是空白**。反過來，本來就沒有說明的欄位就不要
放一個空字串進去 —— 那會被當成「這個語系漏翻」而退回另一個語言。


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


## 五份內建主題

| | 給誰看 | 自己帶的 block |
|---|---|---|
| `vanilla` 素版 | 要知道這東西由什麼組成的人 | panel / filterbar（也是預設） |
| `desk` 分析台 | 坐在螢幕前面、正在找原因的人 | panel / kpi / filterbar |
| `report` 報告 | 要把結論讀完的人 | panel / kpi |
| `wall` 牆面 | 十公尺外走過去的人 | panel / kpi |
| `terminal` 主控台 | 整天開著它的人 | panel / kpi |

來源就是 `variation/` 底下那五個設計，不是另外抄一份 —— 收進套件的是它們的
`theme-of` 與 CSS 變數，攤平成 token。

後面三版**沒有自己的篩選列**（那是後來才加的功能，只有 `vanilla` 與 `desk` 寫了），
所以它們的 `blocks.filterbar` 指向素版那一份，再由各自的 `vars` 把 `--dash-*` 對應過去 ——
**外觀是素版的，顏色是這個主題的**。素版的篩選列本來就只用 `--dash-*`（只有兩個 box-shadow
是硬寫的），所以這條路走得通；但形狀（圓角卡片、藥丸按鈕）跟 `wall` 的 3px 縫或 `terminal`
的 1px 框不是同一種語言，要完全對齊就得各寫一份。


## 路徑

```
theme/vanilla.json              內建主題
theme/desk.json  theme/report.json  theme/wall.json  theme/terminal.json
block/panel/index.html          預設的 panel block ( = vanilla 的那一份 )
block/filterbar/index.html
block/panel/<主題>/index.html    主題自己帶的
block/kpi/<主題>/index.html
block/filterbar/desk/index.html
```

主題裡的 `blocks` 直接指這些路徑，所以**宿主只要給 `theme.name`，不必知道 block 在哪**。
`board` 的 `themeBase` 預設是 `/assets/lib/@plotdb/dash/main/`（fedep 放東西的地方），
宿主換了位置才要給。

主題的來源在 `web/src/raw/theme/`，`tool/pack.js` 複製到套件根目錄 —— dev server 服務的
那一份就是發出去的那一份，示範頁改一個顏色不必再 build 一次。


## 圖表在別的 block 裡要重新量一次

`desk` 的 panel block 標題列比 `vanilla` 高，於是 `@makechart/number` 用預設的
`numberSizeRate`（3）畫出來，數字上下會被切掉。這類「同一張圖換了一個殼就不合身」的調整
就放在主題的 `chart` 選擇器裡，宿主不必知道。

但 `numberSizeRate` **只是止血**：`@makechart/number` 的 `resize` 只依**寬度**縮放
（`box.height` 取了卻沒有用到），所以任何一個固定比例，換一個格子高度、或多一行單位就會
再次溢出。`desk` 給 `1.8`、`wall` 給 `1.6`（`wall` 的磚留白更大），都是在 104px 的格子加一行單位下
量出來的；單位那一行由 `unitSizeRate` 另外算、不跟著縮，所以它等於先從可用高度扣掉一截。
`vanilla` / `report` / `terminal` 在同一個格子高度下不會裁，就不加。
真正的修法在圖表那邊（`@makechart/number` 0.0.4 已修，待發版；發版後這兩個值都會拿掉）。

換主題時值得順手檢查的就是**會自己撐滿容器的那幾種圖** —— 大數字、字雲、儀表 ——
它們的尺寸是從容器量出來的，容器的內距一變就會溢出，而且不一定每一張都把兩個方向都量了。


## 還沒做的

 - `report` / `wall` / `terminal` 沒有自己的篩選列，沿用素版那一份（見上面）
 - `vanilla` 沒有自己的 kpi block（見上面「`role` 的界線」）
 - `pocket` / `rail` 還沒收進來 —— 那兩版換的主要是版面不是主題，要先想清楚
   「版面也算主題的一部分嗎」
 - 沒有「從現在的主題另存成一份新主題」的 API —— 目前要自己把 `board.theme.tokens` 抄出來
 - `schema` 只有 `color` / `colors` / `length` / `font` 四種型別，沒有分組、沒有條件顯示
