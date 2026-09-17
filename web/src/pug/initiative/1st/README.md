# 模組化儀表板 - 第一版概念示範

這是把 `case/taicca/vis2` 的 dashboard 拆成可重用模組的第一個可運行版本。
目的是先把「一個儀表板由哪些東西組成」講清楚，用實作把介面固定下來，
之後再討論哪裡要改。

看畫面：`npm start` 後開 `http://localhost:8080/initiative/1st/index.html`。


## 檔案

 - `web/src/ls/dash.ls` — 框架本體，輸出 `window.dash`，內含 driver / query / board
 - `web/src/styl/dash.styl` — 基本 CSS，提供 `.dash`、`.dash-cell`、`.dash-panel` 等組裝用 class
 - `web/src/pug/initiative/1st/block/panel/0.0.1/` — 通用 panel block ( 標題列 + 一張圖 )
 - `web/src/pug/initiative/1st/index.ls` — 示範用的 dashboard def 與啟動碼
 - `web/src/raw/assets/data/sales.json` — 示範資料 ( 合成，864 筆獨立書店銷售紀錄 )


## 四個部分怎麼對應

initiative 提的四件事，在這一版分別落在：

基本 CSS ( `dash.styl` )。只做兩件事：版面 ( `.dash` 是 grid 容器、`.dash-cell` 是格子 )
與卡片外觀 ( `.dash-panel` 及其 `.dash-head` / `.dash-body` )。顏色與間距走 CSS custom
property，套用的專案只改變數就能換皮。`.dash-cell` 的 `min-height: 0` 是必要的，
否則 svg 會把 grid 格子撐開而不是被格子限制住。

data driver ( `dash.driver` )。driver 只負責把資料源變成 rows ( plain object 陣列 )，
不做欄位運算。目前有 `json`、`csv`、`inline` 三種，另可直接給 `{load}` 物件或 function。
因此換資料源不影響 def 的其他部分。

dashboard def。一份純資料 ( 除少數 function hook )，描述資料源、版面、每張圖。
可以 JSON 化，所以未來能存檔、傳輸、或由另一個 UI 產生。

crossfilter。由 board 協調，見下節。


## def 長什麼樣子

    def =
      data: {type: \json, url: "/assets/data/sales.json"}

      layout:
        col: <[1fr 1fr 1fr 1fr]>
        row: <[6.5em 1fr 1fr]>
        gap: \.8em

      panels: [
        * id: \region, title: "各地區銷售額", area: {col: [3, 2], row: [2, 1]}
          chart: {name: \bar}
          data:
            groupby: \region
            measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
            sort: {by: "銷售額", dir: \desc}
          cfg: {palette, legend: {enabled: false}}
      ]

每個 panel 有四塊，剛好對應 initiative 列的項目：

 - `area` — 在版面上的位置 ( grid 的 [起點, 跨幅] )
 - `chart` — 用哪個 `@plotdb/chart` block
 - `data` — 資料對應。宣告式聚合，見下節
 - `cfg` — 圖的樣式，原封不動交給 `chart.config`


## 資料對應：宣告聚合，binding 自動推導

`panel.data` 描述「從共用 rows 聚合出這張圖要的 raw」：

 - `groupby` — 欄位名，或 `(row) -> key` 的 function
 - `series` — 把某欄位的每個值展開成獨立數值欄 ( 多線折線圖、堆疊長條圖用 )
 - `measures` — `[{name, field, op, unit}]`，`op` 可以是 `sum` / `count` / `avg` /
   `max` / `min` / `distinct`，或直接給 `(rows) -> value`
 - `sort` / `limit` / `const` ( 常數欄，例如給 number 圖的單位 )

`dash.query` 回傳 `{raw, meta}`，`meta` 記得 group 欄位名與各數值欄位。
panel 再拿 `meta` 與圖表自己宣告的 `mod.dimension` 對照，自動產生 binding：
數值型維度 ( type 含 `R` ) 接 measures，非數值維度只接 priority 最小的那一個。
只綁一個是因為圖表常有第二個分類維度是選用的分組 ( 例如 pie 的 `category` )，
一併綁上去會多出一整層視覺；要用就在 def 裡明寫 binding。所以多數 panel 不必寫 binding；
`number` 這種需要把 `unit` 綁到特定欄位的，在 def 裡寫 `binding` 覆蓋即可。


## crossfilter

一個 panel 可以同時篩好幾個欄位。`chart.filter` 的 payload 本來就是以 binding 維度為 key，
不同維度對應到不同的資料欄位：

 - 綁到分組欄位（`meta.key`）的那一維 → `data.groupby`。pie / bar / map 叫 `name`，line 叫 `order`，
   所以 panel 是用 binding 去認哪一維是「資料點」，不寫死維度名字
 - 綁到 measures 的那一維 → `data.series`。那些 measure 本來就是 series 欄位的值展開出來的，
   所以多 series line 的 legend 篩的是 category，跟它自己的 groupby（month）是不同欄位

board 的 `filters` 因此以「panel + 維度」為單位存，每一筆記著 `owner`：

    filters["trend:value"] = {owner: "trend", dim: "value", field: "category", values: [...]}
    filters["region:name"] = {owner: "region", dim: "name", field: "region", values: [...]}

算某個 panel 的資料時不套用它自己發出的 filter（標準 crossfilter 語意），現在就是依 `owner`
排除 —— 一個 panel 有幾筆就排除幾筆。發出 filter 的 panel 會帶 `.filtering` 樣式，
標題列出現可點掉的「篩選中」標籤（點掉會清光這個 panel 的所有維度）。

欄位預設自動推導，通常不用宣告；要覆寫就逐維度寫 `crossfilter: {order: "month", value: "category"}`，
舊的 `{field: ...}` 仍然有效（指的是資料點那一維），要整個關掉用 `crossfilter: false`。

filter 有兩種型別，由發出的圖決定，def 不必寫：

 - `index`：值列表。點選，以及類別軸上的框選（bar 的 brush 會把像素區間換算成被蓋到的那幾個類別）
 - `range`：區間 `[lo, hi]`，兩端都含。連續軸的框選要用這種 —— 月份、金額這類欄位相異值可能上千個，
   列舉不完，而且新資料一進來清單就失效。line 的 brush 發的就是 range

board 的 `_match` 依 type 分派比對方式，其餘都一樣。


## 選取 / 排除的呈現

`panel.data.compare` 打開後，同一個 query 會跑兩次 —— 一次全體、一次套用所有 filter ——
得到 key 相同的兩份結果，一起送給圖表：

    chart.set-raw {raw, binding, subset}

`subset` 是子集，跟 `raw` 共用同一份 binding，所以圖表不必為了篩選狀態多認識任何欄位。
分母是完全沒有篩選的全體，分子套用所有 filter ( 包含這張圖自己發出的那個 )；
這跟一般模式相反，因為對比要的就是「總量不動、看選中多少」。

怎麼表現則是圖的事，由 `cfg.common.subset.mode` 決定，三種模式共用同一份資料，
切換不必重算：

    cfg: common: subset: {mode: "dim"}       # 整個色塊降透明 ( 預設, 原本的行為 )
    cfg: common: subset: {mode: "partial"}   # 同一個色塊裡切出被選中的那段
    cfg: common: subset: {mode: "shrink"}    # 直接拿子集當值畫, 泡泡變小 / 消失

`partial` 不是多疊一層 stack —— 真正的 stacked bar 上再疊一層「其它」會讓堆疊的語意打架。
未選部分的顏色是該色塊自己顏色的灰階版，不是 palette 的另一個顏色，多 series 時才分得出
哪一段灰屬於哪一層。

每種圖用自己的幾何切這一刀，但切的都是同一個比例：

 - bar：沿長度切，被選中的那段從基線長出來
 - pie：沿角度切，從 wedge 的起始角順時鐘吃掉對應的比例。整片的角度與位置完全不動，
   所以單一 wedge 的選取效果不會被對比模式吃掉
 - percent-list：沿寬度切，左邊那段是被選中的部分。色塊的高度（占比）來自未篩選的全體
 - line：沒有色塊可切，`partial` 是畫成兩條線 —— 灰線是總量，彩線（帶點）是被選中的部分。
   只在單純的折線／面積上成立；stack、streamgraph、bump、diff 各有自己的 y 累積方式，
   子集要怎麼疊回去沒有單一答案，那些模式會退回 `dim`。
   **多條線時建議用 `shrink` 而不是 `partial`** —— 四條線配四條灰線就是八條，
   要看出哪條配哪條得靠顏色比對，很吃力。`compare` 已經讓 series 不會消失了，
   「總量多少」通常旁邊的 bar 或 percent-list 已經在講。demo 的 line 就是 `shrink`
 - 地圖不做。一塊縣市沒有自然的可切維度，橫著切像水位線、斜線填充是另一套視覺語言，
   都會讓人誤讀；它的工作是「哪裡有、哪裡多」，`dim` 就夠了

**`compare` 才是「項目不會消失」的關鍵。** 沒開 compare 時，panel 拿到的就是篩選後的 rows，
所以別人一篩，percent-list 的項目會少幾條、line 的 series 會整條不見（`series` 是從資料裡的
相異值推出來的）。開了 compare 之後分母永遠是未篩選的全體，項目與排序都固定下來，
變的只有每一項裡被選中的那一段。這是 query 層的事，跟畫法無關。

分子預設套用所有 filter，**包含這張圖自己發出的**——bar 點選之後被選中的那幾根整根上色、
其餘全灰，靠的就是這個。但圖自己已經把選取畫出來的時候會重複：line 的 brush 已經有一個框了，
分子再套一次會讓框外的月份全部掉到 0，整條線趴在底部，反而看不到自己在框什麼。
這種情況用 `compare: {excludeSelf: true}`，分子只套別人的 filter，分母仍是未篩選的全體。

pie 的比例在 parse 時就跟著 value 一起往上聚合，所以多層 ring 的內外圈都對得起來。

`shrink` 是核心直接拿子集覆寫數值維度，做完 mod 完全不必知道 subset 的存在。

subset 整套機制住在 `@plotdb/chart` 核心，不在 `@makechart/base`。它與 `filter` 是同一層級的
概念——同一份 binding、同一份 schema，另一份被篩過的資料——而 `filter` 本來就在核心。放在
base 等於把資料層的通用概念綁在特定繪圖技術上：base 綁死 d3，未來 webgl 的圖表不會用它，
但一樣需要 subset。

圖表要用到的部分透過核心宣告的 scope 拿：

    @subset.mode!               # dim / partial / shrink
    @subset.ratio d, \value      # 這一筆有多少比例被選中
    @subset.color color         # 未選部分的顏色 ( 該色的灰階再往背景靠 )
    @subset.set rows            # 只換子集, 不動主資料

scope 名單由核心宣告，擴充套件不能自己開新的——要開就得改核心，這個摩擦是故意的。mod 可以用
`mod.subset.<fn>` 覆寫裡面的個別函式，建構時合併掉，執行期不必每次判斷。另外核心保留 `local`
一個名字給圖表放自己的工具方法，內容核心完全不管，呼叫端寫 `@local.toggleSelect(e, d)` ——
在這之前這種方法只能寫成 `self.mod.toggleSelect.call self, e, d`，`this` 得自己接。


## 圖怎麼發 filter

兩條路，優先順序由圖自己宣告：

 - 圖本身支援選取的（bar 的 brush、pie 的 wedge、taiwan-map 的縣市），走
   `chart.filter(..., true)`，host 收到 `filter` 事件。`chart.canFilter()` 為 true 的就是這一類
 - 不支援的（percent-list、number），用 `select` 事件代打，由 board 做 toggle

反過來，**選取狀態要灌回每一張圖，不分哪一類**。選取是 board 在管的，圖自己不知道
「我身上哪幾項被選中」；不灌回去的話，用 select 代打的圖點下去毫無反應，看不出點了哪個。
percent-list 與 taiwan-map 就是讀 `binding.name.filter` 來把沒選中的畫淡。

兩個都接會互相蓋掉，所以 panel 在 `canFilter()` 為 true 時就不綁 `select` 了。

另外，filter 的真實狀態在 board，而 panel 每次 render 都會重建 binding，
所以重建後要把選取灌回圖裡（`chart.filter(..., false)`，不回頭再發事件）。
少了這一步，圖自己看到的永遠是「沒有選取」，shift 增刪就會每次都從頭開始。

灌回去對 bar 來說是要把值列表換算回 brush 的像素區間。這裡有兩個坑，都修掉了：
brush 掛在 `g.brush` 而不是 `g.view`（原本會丟 `extent of undefined`）；
區間的遠端剛好落在格線上會被 `Math.floor` 算進下一格，於是每同步一次就多吃一根，
來回幾次整排都被選中 —— 所以遠端退 1px。兩邊都沒有選取時則整個跳過，不去戳 brush。

第三個坑是灌回去會把使用者剛拉好的框拉直：框已經表示同一批 band，位置卻跳去對齊格線，
選的東西沒變只有框自己動了，手感很怪。所以 bar 與 line 在動 brush 之前都先反算目前這個框
代表什麼，跟要灌進去的值一樣就不動它 —— 使用者拉到哪就停在哪，外面來的篩選才會移動框。

「上次灌了什麼」是 panel 自己記的。binding 每次 render 都重建，圖身上的 filter 會跟著不見，
所以問圖認不出「剛剛有篩選，現在被清掉了」—— 不記的話，別人按「清除篩選」時 bar 的框會留在
畫面上，篩選明明已經沒了。

percent-list 的標籤會跑到卡片外面，有兩個獨立的原因，都修掉了。

主因是那個「捲動標籤」的位移。項目多到放不下時，hover 哪一塊就把標籤捲到哪裡，並夾擠成不要
捲過頭：`if last - offset < rbox.height => offset = last - rbox.height`。但項目全部放得下時
`last` 比區域高度小，夾出來的是負數 —— 負的位移等於往下推，整組標籤就被推到區域底部、掉出圖外。
只在 hover 過之後才會發生（沒 hover 過 `@idx` 是 undefined，整段不執行），所以光是載入頁面看不到。
全部放得下就不該捲，夾在 0 以上即可。

另一個是量測過期。標籤位置是從一份隱藏的 html 量出來的（svg 沒有文字排版，所以先讓瀏覽器排好
再照著擺），而量是在 resize 做的 —— 字型晚一步載入、根字級改變這類事情會讓文字重排卻不觸發
resize，基準點就過期了。改成每次畫之前重量一次，就幾個 `getBoundingClientRect`，本來 resize
也是這樣量的。

brush 還有一個副作用：它蓋在整個繪圖區上，hover 全部打在它身上，bar 的 tip 就再也出不來
（bar 的 tip 是從 `evt.target` 的 datum 取值的）。改成先用 `elementsFromPoint` 往下找真正被指到
的那一根，再從它取值 —— brush 自己的幾片在最上面，底下才是 bar。line 沒這個問題，因為它的 tip
本來就是從游標座標反推最近的資料點，不看 `evt.target`。

同一個「binding 會重建」的事實在 line 身上是另一種災情：line 在 render 裡同步 brush，而 panel
是先 `setRaw`（觸發一次 render，此時 binding 上還沒有 filter）再 `filter`，於是每次都先把框清掉、
再照值重畫一個 —— 使用者拉的框看起來就是自己跳走了，而且重畫的位置還會超出軸。所以 render 裡
只在 binding 真的有區間時才同步，清框交給 `mod.filter` 那條路；外推半格也夾在視圖寬度內，
頭尾兩個資料點就在軸的兩端，不夾就會突出去。

`@makechart/pie` 的 wedge 點選是這次加的：單擊只選一個、shift 增刪、再點一次選到只剩自己的那個就清空。


## legend 也是一種篩選

legend 的勾選本來就是在挑資料，只是它一直只有一種表現（關掉就整個不見）與一種範圍（只影響自己）。
現在這兩件事都可以調，預設值都維持原本的行為。

怎麼呈現，跟 `common.subset` 同一套字彙，但放在 legend 自己的設定裡：

    cfg: legend: subset: {mode: "shrink"}   # 整個拿掉 ( 預設, 一直以來的行為 )
    cfg: legend: subset: {mode: "dim"}      # 位置與總量都留著, 只降透明
    cfg: legend: subset: {opacity: 0.2}     # dim 的透明度

兩者預設不同是刻意的：`common.subset.mode` 預設 `dim`，legend 預設 `shrink`。共用一個 key 的話，
既有的圖一升級 legend 行為就變了。`partial` 對 legend 沒有意義 —— legend 是整層的開關，不是比例，
所以填 `partial` 會當成 `dim`。同理 legend 沒有 `fade`（那是 partial 用來灰化的）。

圖表要支援 `dim`，就是把原本的 `if !legend.isSelected(k) => 跳過` 換成 `isVisible(k)`，
再對 `!isSelected(k)` 的那些降透明。`shrink` 時 `isVisible === isSelected`，所以不改行為。
目前 bar 與 pie 改好了，line 還是只有 shrink。

要不要對外發 filter：

    cfg: legend: {crossfilter: true}        # 預設 false

只有「legend 項目就是資料值」的圖該打開，而這不是圖表類型的屬性，是**綁定方式**的屬性：
line 的 legend 項目如果是 `data.series` 展開出來的（文學／人文社科…），那就是資料值；
換一份 def 用四個手挑的欄位當 measure，同一張 line 的 legend 就變成欄位名了。所以預設關著，
由 def 決定。

兩種圖的差別在於 legend 屬於哪一維：

 - pie：legend 與 wedge 都是 `name` 維，共用同一份選取，寫進 `binding.name.filter`
 - line：legend 是 `value` 維，跟資料點所在的 `order` 維是不同欄位，board 分成兩筆存

圖表用 `mod.filterDims` 宣告自己會發哪幾維的 filter。host 據此決定哪一維要拿 `select` 代打：
圖自己會發的那一維不必代打（兩個都接會互相蓋掉），圖只發別的維度時兩者並存 ——
line 開了 legend crossfilter 之後，legend 篩 category，資料點的 select 代打仍然管 month。

打開之後 legend 與 wedge 點選共用同一份選取（都寫進 `binding.name.filter`），
不會有兩套狀態打架：點 wedge，legend 的勾勾跟著變；點 legend，wedge 跟著亮暗。

這裡有個要小心的區別：**「全選」和「全不選」不一樣**。全選 = 沒有篩選，filter 整個清掉；
全不選 = 篩選出空集合，filter 還在，只是 `values` 是空陣列。兩者混為一談的話，
「全不選」按下去會彈回全選，那個按鈕就失去意義了（它存在就是為了讓人先清空再逐一挑）。
所以 `board.setFilter` 只有收到 `null` 才刪掉篩選，空陣列是有效的篩選值。


## def 檢視器

頁面右上角的「儀表板定義」開一個視窗，把「要定義的東西」依組列出來：資料源、版面、
圖表清單三組對應到 def 的實際位置，可以直接改字面量按「套用並重建」看結果；
資料對應、資料綁定、連動篩選三組沒有獨立位置 ( 寫在每個 panel 裡 )，只顯示欄位說明與寫法範例。

這份清單不是寫死在頁面裡的 HTML，而是 `dash.spec` 這份資料：

    dash.spec = [
      * key: \data, title: "資料源", path: <[data]>
        desc: "把資料源變成 rows ..."
        fields: [
          * key: \type, type: "json | csv | inline", desc: "driver 名稱 ..."
        ]
    ]

所以規格只有一份，UI 從它長出來；之後要接 `@plotdb/konfig` 生正式表單，來源也是這裡。

編輯器用的是 JS 物件字面量而不是 JSON，因為 def 裡可以放 function ( `measures.op`、`groupby` )。
序列化與讀回是 `dash.dump` / `dash.load`，只給編輯器用。


## 這一版沒做的

 - 沒有 detail / 放大視窗，也沒有 dashboard 之間的切換 ( taicca 版的 `add-dashboard` / `toggle` )
 - 沒有全域的時間區間控制項。line 的 brush 已經可以發 range，但那是某張圖發出的；
   由 toolbar 發出的全域 filter 仍然沒有 ——
   目前 board 只認得 panel 發出的 filter
 - 版面只有 grid 一種。`def.layout.type` 是之後要加 flow / free 版面的分支點
 - filter 還沒有排除 ( exclude )：「除了這幾項以外」。taicca 版的「出品人比例」用的是這個 ——
   選項幾十個時，要表達「不要這一兩個大宗」用值列表得點選其他四十項，而且下個月多一個
   出品人清單就錯了。跟值列表差一個 not，但 crossfilter 的「不套用自己」對它的意義不一樣：
   排掉 A 若不套用自己，A 還留在自己圖上，看起來像沒生效
 - `common.subset` 現在由核心併進每張圖的設定，所以設定面板一律看得到這一組，
   但一張圖支不支援 subset 是它自己的事 —— 沒實作的圖照樣把開關秀給使用者，切了沒反應。
   缺一個「這張圖不支援 / 不提供這一組」的宣告機制
 - 沒有 loading 狀態與錯誤處理
 - def 檢視器是唯讀規格 + 純文字編輯，沒有依 spec 生出實際的表單控制項


## 要決定的事

 - def 要走到多純？目前 `measures.op` 與 `groupby` 允許塞 function，
   彈性夠但就不能純 JSON 化。要不要改成註冊具名運算 ( 例如 `op: "unit-price"` )？
 - panel 與 chart 的界線：現在 panel block 認得 `chart.mod.dimension` 來自動 binding。
   這讓 def 很短，但也讓 panel 綁死在 `@plotdb/chart` 上
 - 全域 filter ( 時段、子產業 ) 要不要進 def，還是留給宿主頁面自己處理


## 環境備註

 - chart 走 fedep 安裝：`@makechart/*` 列在 `package.json` 的依賴與 `frontendDependencies`，
   `npx fedep` 會裝到 `web/static/assets/lib/@makechart/<name>/<version>/` 並建 `main` symlink
 - `@plotdb/chart` ( 核心的 subset / scope / filterDims、legend、config ) 與 `bar`、`pie`、
   `line`、`percent-list`、`taiwan-map` 目前都是本地改動版，還沒發版。`@makechart/base` 已經
   改回原狀，不必跟著發。改完用 `./tool/sync-charts.sh chart bar pie line percent-list taiwan-map`
   蓋過去；下一次 `npx fedep` 會還原回 npm 版
 - 發版順序有相依：`@plotdb/chart` 先，其餘五張圖後
 - 示範資料用 `node tool/gen-sales.js` 產生，固定 seed 可重現。地區 / 通路 / 書系之間
   刻意做成有關聯（都會區網路強、花蓮以寄售為主、藝術設計偏網路）—— 三個維度互相獨立的話，
   對比模式下每一塊被選中的比例都會長得一樣，看起來像壞掉
 - registry 規則沿用 `makechart/server/module/makechart/registry`：block 與 lib 都在
   `/assets/lib/<name>/<version|main>/`，本專案自己的 block 用 `ns: local`
 - makechart 的 base 需要 d3 7.9.0 ( 舊的 chart block 是 d3 4 加一堆 d3-* 模組 )，
   所以 `package.json` 的 d3 已升到 7.9.0
 - `web/src/pug/ref/index.pug` 目前 build 失敗，因為它 `extends /base.pug` 而 `base.pug`
   已隨其他檔案一起移到 `ref/` 下
