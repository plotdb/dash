# 模組化儀表板 - 第二版

同一份框架、同一份資料、同一套 crossfilter 語意，換一組 panel block 與一層主題。
`1st` 要回答的是「一個儀表板由哪些東西組成」，這一版要回答的是
**「那些東西固定下來之後，長相能換到什麼程度」**。

看畫面：`npx server -r web -p 64500` 後開 `http://localhost:64500/initiative/2nd/`
( 第一版在 `/initiative/1st/` )。


## 跟 1st 的差別

比對兩份 `index.ls` 會看到 def 的結構一模一樣 —— `data` / `layout` / `panels`，
每個 panel 一樣是 `area` / `chart` / `data` / `cfg`。換掉的只有三件事：

**1. KPI 那四格換了 block。** 1st 用 `@makechart/number` 畫，能把數字自動放大，
但一格只講得出一個數字。這一版改用自己寫的 `block/kpi/0.0.1`：它跟隔壁的 panel block
收到一樣的 `{def, board}`，一樣每次 render 跟 board 要資料，只是畫法不同 ——
多了單位、左緣色條、以及「這個數字是全體的多少」。

那個比例不是另外算的，是 `data.compare` 本來就會送出的子集：

    data:
      measures: [{name: "銷售額", op: (rows) -> dash.agg.sum(rows, \amount) / 10000}]
      compare: true

分母是未篩選的全體，分子套用所有 filter —— 跟 compare 模式的圖表看到的是同一份東西。
平均值型的指標 ( 平均單價 ) 用 `note: \delta`，因為「平均單價佔全體 65%」沒有意義，
要看的是比全體高還是低。

**2. 圖表卡片換了外觀。** `block/panel/0.0.1` 的程式邏輯跟 1st 的那一份完全相同
( crossfilter 的接線、binding 的自動推導、選取狀態灌回圖裡 )，差別只在 pug 與 stylus。

**3. 一層主題。** 深色底，介面狀態只用亮度不用色相。

為了第 1 點，`dash.board` 多支援一件事：**每個 panel 可以指定自己的 panel block**。

    * id: \gross, panel: {ns: \local, name: \kpi, version: \0.0.1}, ...

沒指定就用 board 的預設，所以 1st 不受影響。


## 顏色是分派的，不是挑的

同一個儀表板上有三個維度在被畫，規則只有一條：**色相留給資料，介面狀態只用亮度。**

 - **書系 ( category )** 是四個並列的類別 → 四個色相，給趨勢圖的 series 用
 - **通路 ( channel )** 是另一個維度 → 自己一組琥珀色階，不跟書系搶色相
 - **地區 ( region )** 只有一個量 → 長條圖單色，地圖用同一個色相的漸層，兩張圖看起來是一組
 - **介面**（篩選中的卡片、chip、按鈕）一律用白的不同透明度。資料已經佔滿所有色相了，
   狀態再去搶一個，使用者就得記「橘色是通路還是篩選中」

`書系占比` ( percent-list ) 沒有跟趨勢圖共用同一組對應，因為 percent-list 是
**依占比大小上色的** —— 顏色是位置的函數，不是項目的函數
( `tint.get Math.ceil(((offset + value/2) / total) * 5)` )。
所以給它同一個色族的漸層：看得出是同一個維度，但不假裝每一條都對得上。
要讓它跟趨勢圖逐項對齊，得先改 percent-list 本身。


## 深色底踩到的三件事

都不是這一頁的問題，是「圖表預設為淺色底而寫」的地方：

**`common.subset` 的未選色寫死往白色靠。** `partial` 模式下沒被選中的那一段，
顏色是「該色的灰階再往背景靠」—— 但程式裡的背景是常數 `255`，深色底上就會冒出一塊亮灰。
核心加了 `common.subset.background`，沒設時依序退回 `cfg.background` 與白色
( 也就是一直以來的行為 )：

    cfg: common: subset: {mode: \partial, background: \#18202a}

**legend 的「全選 / 全不選」是英文。** 文字走 `@plotdb/block` 的全域 i18n module，
預設 `en`，頁面要自己切：

    block.i18n.change-language \zh-TW

**d3 brush 的選取框是淺底加白邊。** 在頁面層 ( 不是 block 裡 ) 蓋掉 `rect.selection`，
因為要套到圖表 block 自己的 DOM 上。


## 順手修掉的配色 bug

`@makechart/line` 與 `@makechart/bar` 在 `parse` 時沒有 `@tint.reset!`
( `pie` 與 `percent-list` 本來就有 )。配色是依「第幾個遇到的 key」分配的，
圖表在還沒有資料時會先畫自己的範例資料，範例的 key 把 palette 的前幾格用掉之後，
真實資料只好拿**內插出來的**顏色 —— 4 色 palette 配 4 個書系，結果四條線全是中間色。
`palette` 設了等於沒設，而且不會報錯。

兩張圖各補一行就好。1st 也跟著受惠。


## 版面

12 欄，讓 KPI ( 各 3 欄 ) 與圖 ( 3~6 欄 ) 共用同一組格線。

    row 1   [ 總銷售額 ][ 總銷售冊數 ][ 平均單價 ][ 涵蓋地區 ]
    row 2   [ 月銷售趨勢        ][ 通路占比 ][ 地區分布 ]
    row 3   [ 各地區銷售額 ][ 書系占比 ][    ↑ 跨兩列    ]

地圖跨兩列，因為臺灣本島加離島的範圍又高又窄，放在扁格子裡會縮成右上角一小塊。
地圖的色階低端也不能太接近卡片底色 —— 沒有資料的縣市拿的就是低端色，太暗整座島會消失，
剩下幾塊亮的浮在黑底上，看不出那是地圖。


## 這一版沒做的

 - 沒有淺色主題的切換。顏色都走 CSS custom property 與 def 裡的 palette，
   要做就是再寫一組值，但沒有實際做出來
 - 沒有 responsive。版面是固定的 12 欄 grid，窄螢幕會擠
 - `1st` 列出的那些仍然沒做 ( detail 視窗、全域時間控制項、exclude 型 filter、
   loading 與錯誤處理 )
