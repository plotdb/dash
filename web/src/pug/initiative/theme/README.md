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


## 卡片的標題列

前五個主題同一套規則，由 panel block 實作：

```
[標題][副標題 小一號、淡色] ………… [提示 / 狀態 / 清除]
```

 - **一行，而且高度固定。** 固定高度不是 `min-height` —— 副標題與「篩選中」的行高跟標題
   不一樣，用 `min-` 的話有沒有它們就差一兩個 px，同一列卡片的圖表上緣還是會錯開
 - **收縮順序：先截副標題，截到沒了才輪到標題。** 作法是 `flex-shrink` 差 100 倍
   （副標題 `0 100 auto`、標題 `0 1 auto`），右側的提示與狀態 `flex: 0 0 auto` 不讓
 - **被截斷時 hover 整列**看得到完整的「標題 · 副標題」（`title` 屬性）。寫在標題列上
   而不是各寫一個：使用者看到的是被截掉的那一行，不是某個元素
 - **右側固定留給狀態與操作** —— 提示圖示、篩選中、清除這張圖的篩選，之後的選單也放這裡


## 操作提示由卡片自己算

卡片右側那個「?」，hover 會說這張圖能怎麼篩：

```
橫向框選可以篩「月份」
點圖例可以篩「書系」
```

**刻意不讓宿主在副標題寫「可點選 / 可框選」** —— 那是把介面的行為寫進資料，換一種圖或改
一個設定，那句話就默默變成錯的說明，而且沒有人會發現。這裡從 def 與圖表自己的設定推出來，
設定改了提示就跟著改。副標題回去講內容（「依書系, 每月的銷售額」）。

來源有兩個，合起來才完整：

 - **`chart.interactions!`** —— 圖表自己宣告哪個操作會發哪幾維的 filter，形狀是
   `{click, brush, legend}` → 維度名陣列（`@plotdb/chart` 3.16.0 起）。回 `null` 表示
   **沒宣告**，不是「沒有互動」
 - **`select` 代打** —— 圖自己不發資料點那一維時，點選是 board 接的（見 `bind-events`）。
   這一半圖表不知道，只有卡片知道，所以兩邊都要算

| 來源 | 提示 |
|---|---|
| `interactions!.click` | 點圖上的項目可以篩「X」 |
| `interactions!.brush` | 橫向框選可以篩「X」 |
| `interactions!.legend` | 點圖例可以篩「X」 |
| 圖沒發資料點那一維（`select` 代打） | 點圖上的項目可以篩「X」 |

欄位名先看這張圖自己的 `def.labels`，再退到整份 `def.labels`，都沒有就用原始欄位名。
排列順序固定是 click / brush / legend，不照 `interactions` 的 key 順序 —— 提示的排列
不該隨圖表的宣告而變。

**為什麼要問圖表，而不是自己猜。** 從外面看不出「會框選的圖點不點得動」：`bar` 兩種都像，
但它的 click 是用來換對齊，不發 filter；`line` 的資料點按下去也不發。猜就會給出一個按了
沒反應的提示。

**沒宣告的圖**（`interactions!` 回 `null`，例如目前的 `pie`）退回原本的推法：有
`cfg.brush.enabled` 就講框選，沒有就賭點得動，再加上 `cfg.legend.crossfilter`。那是個
猜測，但對沒宣告的圖還是比什麼都不說有用。

寫成完整的 `if` / `else` 區塊，不要寫成 `if ix? => for ...` 接一行 `else` ——
LiveScript 會把那個 `else` 當成 **for 的 else**（迴圈一次都沒跑時執行），於是退路只在
「有宣告但是空的」才跑，沒宣告的圖就什麼提示都沒有。

算的時機要在 `chart.config def.cfg` **之後** —— 早一步問到的是圖表的預設值，不是這個
panel 真正的設定（`line` 的 brush 就是這樣差一拍，提示會變成「點圖上的項目」）。

`pocket` 與 `rail` 的卡片沒有提示圖示（那兩版的標題列放不下），block 的程式會自己略過。


## 介面上的字: block 原生的 i18n

篩選列、卡片上的「篩選中」、KPI 的「佔全體 x%」、操作提示 —— 這些字不寫死在程式裡，
走 `@plotdb/block` 自己的 i18n：

 - **字串表**在 block 的 `pkg.i18n`，`{en: {...}, 'zh-TW': {...}}`
 - **key 就是英文原文**。漏翻一句時畫面上看到的是英文，不是一個 key
 - **靜態的字**在 pug 上標 `t="<key>"`，不寫內文；block 建 DOM 時就翻好，
   換語言時自己重譯（board 掛 block 時給了 `autoTransform: 'i18n'`）
 - **JS 現組的字**用 `init` 給的 `t(key)`，每個 block 有一個 `tr(key, vals)`
   順手把 `{n}` 換成值

`{n}` 用單括號而不是 `{{n}}`：block 內建的 i18n module 收了第二個參數但不做插值，
而宿主換成 `i18next` 的話它認的是雙括號 —— 單括號兩種 module 都不會先動手，
插值由 `tr` 自己做，兩邊的結果一樣。

key 裡**不要有 `.` 或 `:`**：內建的 module 拿 `.` 當巢狀路徑，拿 `:` 分 namespace。

同一份 JS 在七個設計裡逐字相同，所以**各設計挑的那句話也在同一張表裡**：篩選列的
標題有「篩選」( 素版 ) 與「全域篩選」( 分析台 ) 兩句，卡片的狀態有「篩選中」與
主控台的 `FILTERED` —— 挑哪一句是 pug 上的 `t=` 決定的，表要兩句都收。

主控台的 `ALL` / `FILTERED` 兩種語言一字不差，那是故意的：全大寫的英文是那一版的
身分，不是一句可以翻的話。

篩選列有幾句話是**建控制項的時候寫上去就不再動的**（分頁的「只要 / 排除」、
「全部範圍 …」），`sync` 不會重寫它們。所以它把語言算進 `_sig`，換語言時整組重建 ——
那條路本來就在了（欄位設定改掉時也是走它），篩選不會跟著掉。

語言由宿主決定（`new dash.board({lng})` / `dash.lng(l)`），預設 `en`。見 `doc/index.md`。


## block 的根要加 `ld-scope`

每個 block 的最外層 `div` 都掛 `ld-scope`：

```pug
div(ld-scope)
  .dash-panel(ld="panel")
```

**不加的話宿主的 ldview 會伸進 block 裡。** ldview 是用 `[ld=名字]` 選節點的，宿主頁面
自己若有一個同名的 `ld`，它的 view 會連 block 裡那一個一起選到，然後照自己的 handler
去寫。這個示範站就中過：頁面自己的編輯區有一個 `ld="hint"`，於是五個 variation 頁的卡片
提示氣泡（`ld="hintpop"`，掛在 `ld="hint"` 底下）被宿主的 `text` handler 用 `textContent`
整個洗掉，只有 `title` 屬性活下來 —— 看起來就是「hover 沒有氣泡，但有原生 tooltip」。

`ld-scope` 掛在 block 的最外層而不是 `.dash-panel` 上，是因為那一層正好是 block 自己
view 的 root：ldview 排除的是「自己 root **底下**某個 `[ld-scope]` 裡面」的節點，root
本身不算自己的後代，所以 block 自己選得到，外面選不到。


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


## 使用者的 token 也可以分模式

`def.theme.tokens` 跟主題自己的 `tokens` 同一個形狀：`light` / `dark` 兩個 key 是
**那個模式專用**的，其餘的鍵兩個模式共用。

```json
"theme": {
  "name": "desk", "mode": "auto",
  "tokens": {
    "radius": "0px",
    "light": {"accent": "#c0392b", "paper": "#fafafa"},
    "dark":  {"accent": "#ff7a6b", "paper": "#15171a"}
  }
}
```

合併順序（後面蓋前面）：

```
主題的 tokens.common → 主題的 tokens[mode] → 使用者共用的 → 使用者的 tokens[mode]
```

`mode: auto` 先照 `prefers-color-scheme` 解析出 `light` / `dark`，再用解析出來的那一個；
系統在白天與夜晚之間切換時整段重算一次，所以兩套值會各自生效。

需要它的理由：**一組套在淺色底剛好的值，在深色底上不會剛好**。底色與文字更是非分不可
（`#fafafa` 的紙在深色模式就是一面白牆），所以不分模式的話，使用者只能在兩個模式裡挑
一個能看的 —— 另一個就只好不給使用者調。

只給 flat tokens 的舊 `def` 行為完全不變：沒有 `light` / `dark` 這兩個 key，後面兩段
就是空的。反過來，**`light` / `dark` 不能再當普通 token 的名字用** —— 主題的 `tokens`
本來就是這樣（那兩個 key 一直是模式），這一版只是讓使用者那一層跟它對齊。

要替使用者重配一組色的 UI（makechart 的「套用色盤」）需要的不只是「現在這個模式的值」，
而是兩個模式的原始值各是什麼，所以解析後的結果多帶一份 `baseTokens`：

```js
board.theme.tokens        // 這個模式下的結果 ( 已經併好, 給 $name 參照用的那一份 )
board.theme.baseTokens    // 主題原本那一份, 還分 common / light / dark
```


## 給人看的字

`title` / `desc` 與 schema 的 `label` / `desc` 可以是字串，也可以是一個以語系為 key 的
物件。兩種都收 —— 自己寫一份主題的人不該為了一句說明先學一套 i18n 格式。

```js
dash.text(f.label, 'en')          // 找不到就退回 zh-TW, 再找不到就拿第一個有值的
```

少一句翻譯時畫面上看到的是**另一個語言，不是空白**。反過來，本來就沒有說明的欄位就不要
放一個空字串進去 —— 那會被當成「這個語系漏翻」而退回另一個語言。

`desc` 與 `fit` 的讀者是**終端使用者，不是開發者**。宿主會把這兩段原文直接放進主題選單
（makechart 的儀表板就是這樣用的），讀的人正在選一個主題，手上沒有這個 repo。所以這兩段
請寫「它長什麼樣、適合什麼情境」，不要寫檔名、CSS 變數、API 這類實作細節 —— 那些寫在這份
README 或 `doc/` 裡。真的非提不可的話，要同時講清楚那只有**自己接 `@plotdb/dash`** 時才有
關係（`vanilla` 的 `desc` 就是這樣收尾的）。

schema 的 `label` / `desc` 同理：那是調色盤上每一格的說明，讀的人是在調顏色，不是在看原始碼。


## API

```js
dash.themes                      // 內建清單: [{name, title, path}]
dash.theme(t, {base})            // 讀一份主題, 回傳解析後的結果
board.setTheme(theme)            // 併 cfg + 寫 CSS 變數 + 需要時換 block, 不清篩選
board.setMode('dark')            // 等同 setTheme({...現在的, mode})
board.theme                      // 解析後的結果 ( 含 tokens 與 schema, 給自訂面板回填 )
board.theme.baseTokens           // 主題原本的 tokens, 還分 common / light / dark
```

`setTheme` 回 Promise 是因為換 `name` 可能要重掛 block；只改 `tokens` / `mode` 的話不重掛，
就是重算 cfg、寫變數、`render!`。**兩條路都不動 filters** —— 換個長相不該讓使用者正在看的
篩選彈掉。

`mode` 沒寫死成 `light` / `dark` 就是跟著系統走，而且**持續**跟：系統在白天與夜晚之間切換
時畫面要換，不是只在開頁面時讀一次。「要不要記住使用者的選擇、記在哪」（localStorage 的
key、網址參數）是宿主的政策，套件不碰。

主題存在 `def.theme`，所以 `dash.dump(bd.def.theme)` 印出來的就是可以存回去的那一份。


## 七份內建主題

| | 給誰看 | 自己帶的 block |
|---|---|---|
| `vanilla` 素版 | 要知道這東西由什麼組成的人 | panel / filterbar（也是預設） |
| `desk` 分析台 | 坐在螢幕前面、正在找原因的人 | panel / kpi / filterbar |
| `report` 報告 | 要把結論讀完的人 | panel / kpi |
| `wall` 牆面 | 十公尺外走過去的人 | panel / kpi |
| `terminal` 主控台 | 整天開著它的人 | panel / kpi |
| `pocket` 口袋 | 拿著一支手機的人 | panel / kpi |
| `rail` 側欄 | 要掃過一排指標的人 | panel / kpi |

來源就是 `variation/` 底下那七個設計，不是另外抄一份 —— 收進套件的是它們的
`theme-of` 與 CSS 變數，攤平成 token。


## 主題只換長相，`fit` 只是一句話

`pocket` 與 `rail` 跟前五份不一樣：**它們原本的識別有一半在版面上**（口袋是一欄到底，
側欄是把 KPI 立成一整欄）。但版面不歸主題管 —— `theme.layout` 只拿來補 `def.layout`
沒給的欄位，def 自己寫了就以 def 為準。理由是**版面是使用者排的，換個配色不該把人家
排好的格子推掉**。

所以這兩份收進來的是**長相**：圓角卡片對上無框的報紙、手機的 32px 目標對上 15px 的
問號圈、保守的小螢幕色票對上只有紅藍黑灰的報紙色票。至於它們配什麼版面，寫在新的
`fit` 欄位裡：

```json
"fit": {
  "zh-TW": "配一欄到底的版面：2 欄格線、每一格跨滿、行高用絕對值讓整頁往下捲。",
  "en": "Pairs with a single-column layout: a 2-column grid, every cell spanning both…"
}
```

`fit` 是**給人看的一句話，不是設定**。板子不會照著它動任何東西，宿主自己決定要不要
把這句話變成一個「要不要連版面一起換」的選項。`theme.layout` 照舊帶著（口袋是 2 欄、
側欄是 12 欄五列），def 沒寫版面時才會派上用場。

`desc` 與 `fit` 都經由 `board.theme` 拿得到（`board.theme.desc` / `board.theme.fit`），
兩個都可能是字串或以語系為 key 的物件，用 `dash.text` 取。

`report` / `wall` / `terminal` / `pocket` / `rail` **沒有自己的篩選列**（那是後來才加的功能，只有 `vanilla` 與 `desk` 寫了），
所以它們的 `blocks.filterbar` 指向素版那一份，再由各自的 `vars` 把 `--dash-*` 對應過去 ——
**外觀是素版的，顏色是這個主題的**。素版的篩選列本來就只用 `--dash-*`（只有兩個 box-shadow
是硬寫的），所以這條路走得通；但形狀（圓角卡片、藥丸按鈕）跟 `wall` 的 3px 縫或 `terminal`
的 1px 框不是同一種語言，要完全對齊就得各寫一份。


## 路徑

```
theme/vanilla.json              內建主題
theme/desk.json  theme/report.json  theme/wall.json  theme/terminal.json
theme/pocket.json  theme/rail.json
block/panel/index.html          預設的 panel block ( = vanilla 的那一份 )
block/filterbar/index.html
block/panel/<主題>/index.html    主題自己帶的
block/kpi/<主題>/index.html
block/filterbar/desk/index.html
```

主題裡的 `blocks` 直接指這些路徑，所以**宿主只要給 `theme.name`，不必知道 block 在哪**。
`board` 的 `themeBase` 預設是 `/assets/lib/@plotdb/dash/main/`（fedep 放東西的地方），
宿主換了位置才要給。

上面是**裝起來之後**的路徑，不帶 `dist/`：repo 這一側產物在 `dist/` 底下，
`fedep publish` 會把 `dist/` 攤平到發佈檔的根目錄。

主題的來源在 `web/src/raw/theme/`，`tool/pack.js` 複製到 `dist/theme/` —— dev server 服務的
那一份就是發出去的那一份，示範頁改一個顏色不必再 build 一次。


## 圖表在別的 block 裡要重新量一次

換主題時值得順手檢查的是**會自己撐滿容器的那幾種圖** —— 大數字、字雲、儀表 ——
它們的尺寸是從容器量出來的，容器的內距一變就可能溢出，而且不一定每一張都把兩個方向都量了。

這條路踩過一次，值得記下來。`desk` 與 `wall` 的 panel block 留白比 `vanilla` 大，
`@makechart/number` 畫出來的數字上下被切掉。當時在主題的 `chart` 選擇器裡放了
`numberSizeRate` 當止血，但那是**治標的**：`@makechart/number` 0.0.3 的 `resize`
只依**寬度**縮放（`box.height` 取了卻沒有用到），而單位那一行又由 `unitSizeRate` 另外算、
不跟著縮 —— 所以任何一個固定比例，換一個格子高度、或多一行單位就會再次溢出
（量過：繪圖區 41px 時連 1.8 都還溢出 6px）。

0.0.4 起它會把高度一起算進去，寬高兩邊夾住，止血值就都拿掉了 —— 現在七份主題都沒有
`numberSizeRate`，數字反而比止血時大。**遇到這類「換了個殼就不合身」的圖，先確認它有沒有
把兩個方向都量過，再決定要不要在主題層壓一個值。**


## 還沒做的

 - `report` / `wall` / `terminal` 沒有自己的篩選列，沿用素版那一份（見上面）
 - `vanilla` 沒有自己的 kpi block（見上面「`role` 的界線」）
 - `pocket` / `rail` 還沒收進來 —— 那兩版換的主要是版面不是主題，要先想清楚
   「版面也算主題的一部分嗎」
 - 沒有「從現在的主題另存成一份新主題」的 API —— 目前要自己把 `board.theme.tokens` 抄出來
 - `schema` 只有 `color` / `colors` / `length` / `font` 四種型別，沒有分組、沒有條件顯示
