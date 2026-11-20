# split 版面

`def.layout.type: "split"` —— 一棵可以巢狀切分的樹，取代一張固定的格線。
`grid` 沒有拿掉，兩種並存。

看畫面：`npx server -r web -p 64500` 後開
`http://localhost:64500/initiative/split/`

這一頁跟 `variation/vanilla` 用**同一份資料、同一組 block、同一套 crossfilter**，
換掉的只有 `def.layout`。它借的就是 vanilla 的 `block/panel` 與 `block/filterbar`，
一行都沒改 —— 版面換了，panel 不知道這件事。


## 樹長什麼樣

    layout:
      type: \split
      gap: \.8em
      resizable: true
      root:
        dir: \col
        children: [
          * size: \2.6em, panel: \header
          * size: 1, dir: \row
            children: [
              * size: 2, min: \18em, dir: \col
                children: [
                  * size: 3, panel: \trend
                  * size: 2, panel: \region
                ]
              * size: 1, min: \14em, dir: \col
                children: [
                  * size: 1, panel: \channel
                  * size: 1, panel: \map
                  * size: 1
                ]
            ]
        ]

 - 有 `children` 的是容器（一刀切下去），其餘是格子
 - `dir` 直接對應 `flex-direction`：`col` 由上往下排，`row` 由左往右排。
   不另外發明一套字彙，是因為它就是原封不動寫進 `flex-direction` 的 ——
   中間多一層翻譯，只會多一個要記的規則
 - `size` 是**數字**就是 `flex-grow` 的比例（`2` 的格子是 `1` 的兩倍大）；
   是**字串**就是固定大小，任何 CSS 長度都行（`2.6em`、`240px`、`30%`）
 - `min` 是切分方向上的最小尺寸。沒有它，拖過頭會把對面那一格壓成 0，
   壓成 0 之後分隔線貼著邊，再也拉不回來
 - 沒有 `panel` 的葉子是**空格子**，畫成一個虛線框 —— 編輯器可以在上面放「新增圖表」
 - `panel` 指的是 `panels[].id`。split 模式下 panel 自己的 `area` 不看


## 拖分隔線

`resizable: true` 之後分隔線可以拖，拖完 board 發一個 `resize` 事件：

    bd.on \resize, (layout) -> ...   # layout 就是改過的那一棵樹

**改的是樹上的 `size`，不是只有 CSS。** 所以把這個 `layout` 存回文件就是新版面，
不必另外去讀 DOM 的尺寸再反推。

兩邊怎麼變：

 - 固定大小（字串）的那一邊，改的是它的像素值（`"2.6em"` → `"318px"`）
 - 兩邊都是彈性的，就按新的像素比例重分配 `flex-grow`，並且**保持兩者的總和** ——
   不保持的話，這一刀的比例會連帶影響到同一層其他沒被拖到的格子

分隔線本身就是格子之間的間距（寬度 = `layout.gap`），不另外佔空間，所以開不開
`resizable` 版面長得一樣。間距通常只有 `.8em` 上下，直接拿它當熱區很難點中，
所以 `.dash-handle-on` 的 `:before` 往兩邊各長 3px。


## `board.relayout(layout)`

只換版面，不重建 panel：

    bd.relayout layouts.左右對開

格子會被**搬到**新的位置（`appendChild` 既有的節點），圖表跟著節點走。所以：

 - 圖表不重建，連 svg 都是同一個物件
 - 篩選狀態不動（`reload(def)` 會清掉 `filters`，這個不會）
 - 尺寸變了圖表會自己重畫 —— `@plotdb/chart` 的核心對每張圖的根節點掛了
   `ResizeObserver`（`index.js:421`），所以拖分隔線、換版面、視窗縮放走的是同一條路，
   dash 這邊不必通知誰

樹上沒指到的 panel，它的格子會留著（從 DOM 上摘下來），只是不顯示。所以編輯器把一張圖
從版面上拿掉、再 undo 回來，中間不必重建圖表。


## `.dash-cell` 放進 flex 會不會有問題

不會，而且需要的設定跟 grid 完全一樣：`min-width: 0; min-height: 0`。

grid item 與 flex item 的 `min-*` 預設都是 `auto`，意思是「不能小於內容」——
而圖表的 svg 會把格子撐開，於是格子不是被版面決定大小，反過來撐爆版面。
`.dash-cell` 本來就壓成 0 了，所以搬進 flex 直接成立；新增的 `.dash-split`
（容器節點）也同樣壓成 0，否則巢狀的那幾層會各自被內容撐開。

`c.min` 只寫在切分的那個方向上（`dir: row` 的容器寫 `min-width`），不是兩個方向都寫 ——
兩邊都寫會連帶限制住跟這一刀無關的那個方向。


## 編輯器要的那幾個 API

`reload(def)` 什麼都做得到，但它整個重建，連篩選都清掉 —— 改一張圖的顏色不該讓使用者
正在看的篩選消失。所以增刪改各有一支：

    bd.add-panel {id: \category, title: "書系占比", chart: ..., data: ...}   # -> Promise
    bd.remove-panel \category                                              # -> true / false
    bd.update-panel \category, {cfg: ...}                                  # -> Promise
    bd.panel-of \category                                                  # -> panel def

**`addPanel`：順序不拘。** 位置是版面決定的（split 的葉子寫 `panel: <id>`，grid 的 panel
自己寫 `area`），所以先 `relayout` 再 `add`、或先 `add` 再 `relayout` 都行 ——
樹上還沒指到它的時候，格子會先建好但不進 DOM，下一次 relayout 把它接上去。

**`removePanel` 是真的刪掉**，跟 relayout 那個「摘下來不銷毀」是兩回事。它會：

 - 銷毀 panel 實例（panel block 的 `destroy` 會把圖也拆掉）
 - **清掉它發出的 filter** —— 不清的話，畫面上會留著一個沒有來源的篩選，使用者找不到
   地方取消它
 - 把樹上那個葉子的 `panel` 拿掉，格子留在原地變成空格子（grid 版面則是把格子移除 ——
   grid 的位置是 `area` 給的，留一個空的沒有意義）

**`updatePanel` 只有換圖種才重建。** `chart` 變了就重建那一格（本來就是另一張圖），
`data` / `cfg` / `binding` / `title` 都只是改 def 再 render —— panel block 拿到的 def
跟 board 這邊是同一個物件，所以改了就看得到。

有一個細節：主題層把 theme 併在 `p._cfg` 之上（見 `../variation/mode.ls`），所以
`updatePanel` 改 `cfg` 時會連 `_cfg` 一起改，否則下次重算主題會把舊的那份又翻出來。

三支都會發 `panel` 事件：`{type: \add | \remove | \update, id, ...}`。


## 點格子算位置：不要自己數 index

每個節點身上都寫著 `data-path`（例如 `"1.1.2"`），每次 relayout 重算，所以：

    bd.path-of node      # DOM 節點 -> [1, 1, 2]；根是 []，分隔線與版面外的是 null
    bd.spec-at path      # 位置 -> 樹上那個物件（改它就是改 def）
    bd.node-at path      # 位置 -> DOM 節點

**自己從 DOM 往上數 index 是可以算對，但它賭的是這邊的 DOM 形狀不會變。** 現在要跳過
分隔線，之後若多包一層容器、或是不可拖的時候不再產生分隔線，那段程式就會默默算錯 ——
錯的方式還是「選到隔壁那一格」，不會報錯。`data-path` 是這邊維護的，形狀改了它跟著改。


## 這一頁示範的事

 - **兩種切法**（「主控台」「左右對開」）：同一批 panel，換一棵樹就換一個版面
 - **分隔線鎖 / 不鎖**：`resizable` 切換之後 relayout
 - **點一格**會顯示它在樹上的位置（`pathOf`），然後可以在那一格放圖、拿掉圖、
   換圖種、換色票 —— 編輯器會做的事就是這幾樣，只是 UI 換成三顆按鈕
 - **右邊那塊** 一直印著目前的 `layout.root`，拖完分隔線會看到 `size` 跟著變


## 還沒做的

 - **切割與合併的 UI**（把一格再切成兩格、把兩格併回去）。這是編輯器的事，
   dash 只負責依樹畫出來；但如果之後發現每個宿主都要寫一遍，就該收進來
 - 分隔線只吃滑鼠，沒有鍵盤操作，也沒有 `touch` 事件
 - 沒有「雙擊分隔線還原成等分」這類便利操作
 - 空格子只有一個虛線框，沒有提供放東西的介面（那是宿主的 UI）
 - `grid` 與 `split` 之間沒有轉換工具
