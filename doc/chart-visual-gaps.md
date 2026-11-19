# 圖表的視覺缺口 — 討論中

做 `initiative/2nd` ( 深色儀表板 ) 時撞到的東西。每一項都附實際的程式位置，
結論是**不改圖表的畫法，補圖表的設定面** —— 畫得對不對是資料正確性，已經是對的；
「好看」是主題層的事，而現在主題層能調的太少。

定案的項目往 `@plotdb/chart` 的 `TODO.md` 搬，這份只留還在討論的。

狀態：`[做了]` / `[可做, 待排]` / `[待定案]`


## 1. grid line  `[待定案]`

視覺落差最大的一項。現在只有刻度 ( `axis.tick.inner` 預設 8 )，沒有橫向的淡基準線；
現代儀表板幾乎一律相反 —— 拿掉刻度、留很淡的 grid。少了它，讀「這根大概多少」
要靠視線平移，畫面也會空。

`config.preset.axis` 裡沒有 grid 這一組。

**未定案：config 要長什麼樣。** 幾個要先想清楚的：

 - grid 屬於軸，還是屬於圖？寫成 `xaxis.grid` / `yaxis.grid` 的話，兩軸各自開關很自然，
   但「水平線要畫多長」是圖的繪圖區，不是軸自己的事
 - 線的位置跟刻度是同一組嗎？多數情況是，但軸標籤放不下時會被 stride / ends 抽掉，
   grid 要跟著少，還是維持原本的密度？( 我認為要分開：標籤抽稀、grid 不抽 )
 - 要不要有 minor grid


## 2. tooltip  `[降優先]`

本來列為缺口，但第一印象是「還沒動到滑鼠」的畫面，tooltip 不在其中。
樣式不跟主題走（`config.preset.tip` 只有 `enabled` / `format`）仍然是事實，
但排在後面。

真正有感的是內容而不是樣式：折線圖 hover 現在是單值，好的做法是 crosshair
加上該 x 位置**所有 series** 的值。這件事要等 direct labeling 的 anchor 機制（見 3）
做出來比較順。


## 3. direct labeling  `[待定案 — 但方向清楚]`

把系列名直接寫在線的末端 / 扇形上，取代 legend。

**legend 幫得上忙嗎？** 一半。legend 現在是「版面裡的一個方框」：它跟 `@plotdb/layout`
綁在一起（`legend.ls` 建構時就去拿 `layout.get-node(@name)`），做的是「在這個格子裡
排一列項目」。direct labeling 要的是「在這些座標附近擺字，避開彼此、避開邊界」，
是另一個排版問題。

但兩者的**項目模型是同一個**（key / text / 顏色 / 選取狀態），樣式也該共用。所以：

 - legend 保持是「方框」的 renderer
 - 另外做 `chart.utils.labels`：吃同一份 data，外加一個由圖表提供的
   `anchor(d) -> {x, y}`，負責擺放、避讓、必要時畫引線
 - **圖表只需要多實作 anchor**，這是只有圖表知道、工具算不出來的東西：
   line 是每條線最後一個點、pie 是扇形的質心、bar 是每組最後一根的頂端。各自幾行

邊界問題歸工具管（夾在繪圖區內、上下推開、被推開就畫引線）。
`@makechart/percent-list` 其實已經解過一模一樣的題目 —— 它有捲動標籤與引線，
位置是從隱藏的 html 量出來的（svg 沒有文字排版）。那套東西該被抽出來共用。

**未定案：** anchor 要以什麼形式宣告？我傾向跟第 5 項的 annotation 共用同一個 scope，
見下。


## 4. x 軸標籤的方向  `[可做, 待排]`

現況查證：`axis.label.direction` **已經有 `horizontal` / `vertical` 兩種**
（`axis.ls:200` 起，vertical 是 `rotate(-90)`），放不下時用 `label.strategy`
的 `stride` / `ends` 抽稀。

所以缺的是兩件事：

 - **傾斜**（例如 -45°）。目前只有 0° 與 90°。傾斜要改的是量測：
   判斷會不會撞到鄰居時，要用標籤在軸方向上的投影長度（`w·cosθ + h·sinθ`），
   不是現在的 `box.width`
 - **`auto`**。真正的痛點是「水平放不下就只能隱藏項目」—— 應該先試水平、
   再試傾斜、再試垂直，都放不下才抽稀。現在是要自己選一種，選錯就掉標籤

預設維持 `horizontal`，`auto` 是 opt-in。

`@makechart/bar` 會用：直方圖的區間標籤（`100–109` 這種）很容易放不下，
目前只能抽稀。預設維持 `horizontal` 是它那邊明確要求的。


## 5. 空狀態  `[待定案 — 但方向清楚]`

完全沒有。篩到沒資料時是一片空白，不會說「沒有符合的資料」。
對「看起來不專業」的貢獻意外地大。

**不該每張圖各做**（會對不齊）。核心知道 `@data` 是不是空的，也知道繪圖區在哪
（layout 的 `view` 節點），所以：

 - 核心在 view 區塊上畫一層，文字走 i18n，圖表什麼都不用做
 - 客製走 block 的 plug（`base` 的 pug 已經有 `<plug>` 機制），
   宿主要換整塊就塞自己的節點進去 —— 這就是 headless 的用法
 - `cfg.empty: {enabled, text}` 給只想改字的情況

**未定案：有幾種「空」。** 至少三種，訊息不一樣：

 1. 根本沒有資料
 2. 有資料，但被篩光了
 3. `compare` 模式下 raw 有東西、subset 是空的 —— 這其實不該顯示空狀態，
    圖要照畫（整個是未選中的樣子）

核心分得出 1 跟 2 嗎？核心只看得到 host 餵進來的 raw，分不出來。
所以要嘛由 host 告知，要嘛只做一種通用訊息。


## 6. annotation  `[待定案 — 但該拆成兩層]`

「在哪畫條線、哪畫個圈、加個字」。關鍵是**這是兩種不同的東西，不要混在一起**：

 - **資料座標的 annotation**：釘在資料上（y=500 的參考線、圈住 2024/03）。
   需要圖表提供投影 `(資料) -> {x, y}` —— 跟第 3 項 direct labeling 要的 anchor
   **是同一個能力**。所以一個新 scope 解決兩件事
 - **視圖座標的 annotation**：釘在繪圖區的相對位置（0.2, 0.5 處一行註記）。
   **完全不需要圖表支援**，核心就能通用做掉。responsive 也因為是相對座標而免費

而**參考線是資料座標 annotation 裡最便宜的子集** —— 它只需要 scale，核心本來就有。
`cfg.reference: [{axis: 'y', value: 500, label: '...'}]` 對任何用
`chart.utils.scale` 的圖都能通用。

**建議的順序：參考線 → 視圖座標註記 → anchor scope → 資料座標 annotation + direct labeling。**
前兩項不必等任何設計定案。

**未定案：** anchor scope 的介面。`chart.scopes` 的名單是核心宣告的、擴充套件不能自己開
（這個摩擦是故意的），所以加進去之前要想清楚簽名。至少要能回答：
給一個 key / 一筆資料 / 一個值，它在螢幕上的哪裡？色塊對應（「這一塊是什麼顏色」）
是不是也走同一個 scope？


## 7. legend 的「全選 / 全不選」  `[可做, 待排]`

現況查證：`legend.selectable: false` **會連點選一起關掉**（`legend.ls:88` 直接 return），
不只是收掉那兩顆按鈕。所以「要 legend 可點、但不要那兩顆按鈕」目前辦不到 ——
我在 2nd 的圓餅圖上就是因此破版，只好把面板加寬。

這不是樣式問題，是兩件事被焊在一起了。最小的修法是拆開：

    legend.selectable  項目可不可以點（維持現狀）
    legend.actions     要不要顯示全選 / 全不選（預設 true，行為不變）

position 加 `top` / `left` 一併處理。


## 8. preset / 主題  `[做了]`

結論是**不需要核心支援**。圖表的 config 結構一致（都從 `chart.utils.config.preset`
長出來），所以宿主準備一份 generic config、deep clone 後併進每張圖的 cfg 就夠了。
`initiative/2nd/index.ls` 現在就是這樣做的（`theme` + `deep`），
每張圖少抄五行，換主題只改一處。

**但還有一個洞：d3 brush 的選取框不能 customize。** 預設是淺底加白邊，深色底上是
一塊發亮的方塊。我現在是在**頁面層**蓋 CSS（`.dash rect.selection`）繞過去的 ——
那不該是正常路徑，因為那是圖表 block 自己的 DOM，宿主本來不該伸手進去。

這是這一份裡唯一「主題層明確做不到、非得改核心」的項目。

**相容性要求（`@makechart/bar` 那邊提的）**：新增可設定的樣式時，**預設值必須跟現在
完全一樣**，否則 bar 這幾組 snapshot 會全部變動 —— `brush:*`、`filter:external`、
`bin:filter-external`、`bin:brush-drag`、`dash:*`。
另外 bar 自己會在 render 最後把 `rect.selection` 的 `shape-rendering` 設成 `auto`
（`bar/src/index.ls`），其餘維持 brush 的預設。如果預設值非改不可，要先通知它更新 snapshot。
