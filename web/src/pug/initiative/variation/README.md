# variation — 七種長相, 同一份 def

`vanilla`（原本的 `initiative/1st`）要回答的是「一個儀表板由哪些東西組成」，
所以刻意用最素的樣式。其餘六個回答接下來那一題：
**那些東西固定下來之後，長相能換到什麼程度**。

入口頁：`npx server -r web -p 64500` 後開 `http://localhost:64500/initiative/variation/`

| | 給誰看 | 長相 |
|---|---|---|
| [`vanilla`](vanilla/) 素版 | 要知道這東西由什麼組成的人 | 最素的那一份, 樣式全部來自 `dash.css` |
| [`desk`](desk/) 分析台 | 坐在螢幕前面、正在找原因的人 | 密集、滿版不捲動 |
| [`report`](report/) 報告 | 要把結論讀完的人 | 紙、襯線、無卡片、整頁往下捲 |
| [`wall`](wall/) 牆面 | 十公尺外走過去的人 | 色塊拼貼、3px 的縫、巨大的數字 |
| [`pocket`](pocket/) 口袋 | 拿著手機的人 | 一欄到底、拇指構得到的按鈕 |
| [`terminal`](terminal/) 主控台 | 整天開著它的人 | 等寬字、單色、1px 的框 |
| [`rail`](rail/) 側欄 | 要一眼掃完指標的人 | 指標立成一欄、一張主圖、報紙色票 |

七版都有 light / dark，第一次打開時跟著系統走。


## 七版共用的東西

同一份資料、同一批圖表 block（line / pie / bar / percent-list / taiwan-map）、
同一套 crossfilter 語意，以及同一個 `def` 結構 ——
`data` / `layout` / `panels`，每個 panel 一樣是 `area` / `chart` / `data` / `cfg`。

連 panel block 的程式都是同一份：`block/panel/0.0.1/index.ls` 七份**逐字相同**
（差別全在 pug 裡的外觀；程式用 `ld` 屬性而不是 class 名找節點，所以連那一個 class 名
也不再是例外）。KPI 那四格則有三種做法：
`vanilla` 用 `@makechart/number`，四個設計用 desk 寫的 kpi block，
`report` 拿掉了進度條與數字補間，`terminal` 把進度條換成字元畫的 `████░░░░`。

後面六版換掉的就三件事：

1. **panel block 的外觀** —— `index.pug` 裡的 pug 與 stylus
2. **一層主題** —— 一個 `theme-of(mode, panel)` 的結果 deep merge 進每個有圖的 panel 的 `cfg`
3. **`def.layout`** —— 欄、行高與 `gap`

第 1 點靠的是 `dash.board` 支援**每個 panel 指定自己的 panel block**
（`p.panel`，沒指定就用 board 的預設）；第 2 點靠的是圖表的 config 結構一致
（都從 `chart.utils.config.preset` 長出來），所以同一份東西可以套到每一張圖上。


## 看得出差別的那幾行

| | vanilla | desk | report | wall | pocket | terminal | rail |
|---|---|---|---|---|---|---|---|
| `layout.col` | 4 欄 | 12 欄 | 12 欄 | 12 欄 | **2 欄** | 12 欄 | 12 欄 |
| `layout.row` | `1fr 1fr` | `1.15fr 1fr` | 全是 em | `1.55fr 1.25fr` | 全是 em | `1.25fr 1fr` | 全是 em |
| `layout.gap` | `.8em` | `14px` | `26px` | `3px` | `10px` | `8px` | `26px` |
| `.dash` 高度 | `100%`（預設） | `100%` | `auto` | `100%` | `auto` | `100%` | `auto` |
| KPI 的位置 | 頂上一排 | 頂上一排 | 頂上一排 | 頂上一排 | 2x2 | 頂上一排 | **左邊一欄** |
| 分隔 | 卡片 + 細邊 | 卡片 + 陰影 | 一條細線 | 3px 的縫 | 圓角卡片 | 1px 的框 | 3px 的粗線 |
| 資料色相 | 六色 | 四色 | 四色（印刷） | 四色（海報） | 四色 | **單色四階** | 紅藍 + 灰階 |
| def 的位置 | 置中的視窗 | 右側抽屜 | 文件最後的附錄 | 沒有 | 可展開, 唯讀 | 沒有 | 沒有 |

「def 放哪裡」那一列是同一件事的幾種答案：取決於畫面還有沒有空間、
以及有沒有人在操作。


## light / dark

機制七版共用，寫在 [`mode.ls`](mode.ls)。會獨立成一個檔案，是因為
「換一個模式」要碰的東西住在三個不同的地方：

1. **頁面與 block 的 CSS** → 全部走 `<html data-mode>` 底下的 custom property。
   block 不是 shadow DOM，custom property 繼承得進去，所以 panel 與 KPI 的外觀
   **不必接任何 JS**
2. **圖表的顏色** → 在 config 裡，不吃 CSS。所以要重算一份 theme 併回每個 panel 的
   `cfg`，再 `bd.render!` —— panel block 每次 render 都會做 `chart.config def.cfg`，
   所以「重算 + 重畫」就夠了，不必 `reload`（reload 會把篩選清掉）
3. **使用者的選擇** → localStorage。沒選過就跟著系統，而且系統在白天 / 夜晚之間
   切換時畫面要跟著換，不是只在開頁面時讀一次

為了第 2 點，def 裡的顏色收乾淨了：panel 只說自己畫的是哪個維度（`hue: \cat`），
哪個維度在這個模式下是什麼顏色由主題那一層決定。KPI 的色條則直接寫
`accent: 'var(--n2-acc-1)'` —— 一個 custom property，所以 KPI block 連
「現在是哪個模式」都不必知道。

`vanilla` 是對照組：它幾乎沒有自己的樣式，所以 CSS 那邊只是把 `dash.css`
的 `--dash-*` 換一組值 —— 那份 stylus 的註解本來就寫著「讓套用的專案只改變數就能換皮」，
這一版等於是在驗收那句話。

**換模式不是換幾個變數。** 七版做下來，每一版都有一兩個設定必須跟著底色翻面：

 - `common.subset.background`（未選的那一段往哪個顏色退）
 - 地圖漸層的低端（沒有資料的縣市拿的就是低端色）
 - 色塊上的字（wall 的 KPI 磚、vanilla 的 chip、所有藥丸）
 - 色階的方向（terminal 的四階在深色底上「亮 = 強」，在紙上「深 = 強」）

前兩個在七份 README 裡都出現過，是跨主題時最容易漏的兩個。
反過來說，**中間調的顏色兩個底色通常都活得下去** —— vanilla 那六個色就原封不動。

## 入口頁的縮圖

是**真的截圖**，不是 CSS 畫的：每個設計 light / dark 各一張，裁成四五個 panel
的一塊（整頁縮成一格會小到看不出風格，而風格正是這一組在分的東西）。
存在 `web/src/raw/assets/shot/`，用 `tool/shot.sh` 重拍：

    npx server -r web -p 64500 &     # 先把 dev server 跑起來
    ./tool/shot.sh
    # 拍完重開 dev server: 圖在 web/src/raw/, 是開機時才複製到 web/static/ 的

裁切的位置寫在 `tool/shot-crop.py`，一個設計一組 `(x, y, 寬)` 的比例 ——
滿版的那幾個裁左上角，版心置中的 `report` 要往中間移，`pocket` 直接用手機的寬度拍。

兩件跟截圖有關、但其實是頁面本身該有的事，順便補上了：

 - **`?mode=light|dark`**：網址可以指定模式（不寫進 localStorage）。
   headless chrome 沒辦法先寫 localStorage，也不方便改系統的 prefers-color-scheme；
   順便也方便把某一個模式的連結傳給別人
 - **`prefers-reduced-motion`**：`dash.css` 現在會把動畫與轉場關掉，
   四個有數字補間的 KPI block 也會直接換數字。headless 一個頁面只畫得出兩三格 frame，
   原本截到的都是跑到一半的數字（3,736 而不是 3,765）

`vanilla` 的 KPI 是 `@makechart/number`，它的數字跑動一度在這邊關不掉
（補間寫在套件裡），所以縮圖曾經從 KPI 那一列底下開始裁。回報之後
`@makechart/number` 0.0.3 修掉了三件事：補間改成按時間而不是按 frame
（120Hz 的螢幕上本來會跑兩倍快）、停止條件從浮點等號改成 epsilon
（原本 `run === number` 永遠不成立，四張 number 就是四條永遠在跑的
`requestAnimationFrame`，實測每秒 240 次），以及新增 `tween` 設定並認
`prefers-reduced-motion`。所以現在它跟其他六版一樣從頭拍。


## 地圖：色階是「分級」，不是漸層

`@makechart/taiwan-map` 把 `palette.colors` 當成**分級**用：給兩個顏色就只有兩級。
原本七版都只給兩個，結果是六個有銷售的縣市裡只有前兩名上色，第三名（臺中市 620 萬）
拿到的顏色跟**完全沒有資料**的縣市一模一樣 —— 看起來像壞掉，實際上是級距只有兩段。

打開 legend 就看得到：兩個顏色時它寫的是

    7,200,000 - 12,000,000 元
    2,200,000 - 7,200,000 元

現在七版的 `geo-ramp` 都給五階，從低端到強調色等距內插出來的。

另外，**沒有資料的縣市跟最低一級同色**，這一點目前沒辦法分開 —— `taiwan-map` 的設定
只有 `border` 與 `legend`，沒有「無資料」的顏色。要分開得改圖表。

## 地圖：輪廓要自己撐住

縣市邊界原本是 `rgba(..., .14~.22)` 配 0.6~0.8px，對卡片底的對比只有 1.3~1.9，
而「沒有資料」那一級的填色對卡片底只有 1.1~1.2 —— 兩個都看不見，所以整座島是透明的。

現在的規則是算出來的，不是調出來的：**邊界對卡片底取對比 2.4、線寬 1px，
最低一級的填色對卡片底取對比 1.30**。前者讓線讀得到，後者讓陸地在沒有任何資料時
仍然是一塊看得出形狀的面。七個設計各自的底色不同，所以每一版的 alpha 與色票都不一樣，
但目標對比是同一個。

## desk 固定帶一個 xlfont 字型

七版裡只有 `desk` 的主題層帶 `font: {family: {name: 'Taipei Sans TC'}}`，
當成字型那條路的長期回歸點：它會走 `@makechart/base` 的 konfig 字型元件 →
xlfont 子集載入 → 把 `xfl-*` 掛到 svg 上，所以每次重拍縮圖就會順便驗到那一串。

字型名必須在 xlfont 的 meta（`xlfont.maketext.io/meta/meta.json`）裡；不在的話拿到的是
一個空物件，畫面上就是瀏覽器的預設字型，**不會報錯也不會有人發現**。

每一版各自的理由寫在自己的 `README.md`。desk 的那一份另外記了
**三個深色底踩到的核心問題**與**順手修掉的配色 bug**，那些是這一整組的副產品。
