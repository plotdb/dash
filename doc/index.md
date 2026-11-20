# @plotdb/dash

dashboard utility, based on `@plotdb/block`.

 - a class for manipulating dashboard, accepting:
   - a DOM for rendering dashboard ( using ldview )
   - a configuration set for panels rendering and layout
   - a documented, standardized definition of panel blocks to use.
   - ability to extend and use own panel definition


## 版面

兩種，由 `def.layout.type` 分支：

 - `grid`（預設）—— 一張格線，每個 panel 用 `area` 指定自己的位置
 - `split` —— 一棵可以巢狀切分的樹，分隔線可以拖；`board.relayout(layout)` 只換版面
   不重建 panel。見 `web/src/pug/initiative/split/README.md`


## 主題

`def.theme` 讓同一份 def 長成另一個樣子。一個主題是三件事 —— panel block 的外觀、
CSS custom property、圖表的 config —— 三者的值都從同一組 token 長出來。
內建五份：`vanilla` / `desk` / `report` / `wall` / `terminal`。
見 `web/src/pug/initiative/theme/README.md`。

```js
dash.themes                   // 內建清單
board.setTheme(theme)         // 不清篩選
board.setMode('dark')
board.theme                   // 解析後的結果 ( 含 tokens 與 schema )
```

```json
"theme": {"name": "desk", "mode": "auto", "tokens": {"accent": "#c0392b"}, "layout": true}
```


## build

    ./build        # 或 npm run build

輸出全部在 `dist/`：

    dist/index.js                lsc 的輸出，可讀，給 debug 用
    dist/index.min.js            `package.json` 的 `main` / `browser`
    dist/index.css               `dash.styl` 的輸出（版面與卡片的基本 CSS）
    dist/index.min.css           `package.json` 的 `style`
    dist/block/panel/index.html      預設的 panel block（= vanilla 的那一份）
    dist/block/filterbar/index.html  全域篩選列
    dist/block/*/<主題>/index.html    主題自己帶的那幾份
    dist/theme/<主題>.json            內建主題（vanilla / desk / report / wall / terminal）

`fedep publish` 會把 `dist/` 的內容攤平到發佈檔的根目錄，並改寫 `main` / `style` /
`browser` 的路徑，所以**裝起來的套件裡這些都在根目錄**——`index.min.js`、`block/`、
`theme/` 都是。下面講的路徑（以及主題 JSON 裡 `blocks` 的 `path`）都是裝起來之後的，
不帶 `dist/`。這是 plotdb 這一系的共同形狀，`@plotdb/layout`、`@plotdb/konfig` 也是這樣。

`index.js` / `index.min.js` 以外的由 `tool/pack.js` 產生，來源都在 `web/src` 底下 —— 它們本來就是示範頁在用的那一份，
不是另外抄一份給套件。panel block 的來源是 `variation/vanilla/block/panel/0.0.1/`：
七個設計的那七份逐字相同（只差一個 class 名），vanilla 是共同的起點，所以它就是預設的
那一份；複製一份當「套件版」只會變成兩份會各自長歪的東西。`tool/pack.js` 的 pug filter
跟 `@plotdb/srcbuild` 的 pug builder 一致，所以 build 出來的跟 dev server 服務的是
同一個東西（byte-identical，可以自己 diff 看）。

宿主的 registry 這樣指：

    {name: "@plotdb/dash", path: "block/panel/index.html"}
    {name: "@plotdb/dash", path: "block/filterbar/index.html"}

用主題的話連這一步都不必：主題的 `blocks` 自己指到套件裡的路徑，宿主只要給
`theme.name`。板子去哪裡找主題由 `board` 的 `themeBase` 決定，預設
`/assets/lib/@plotdb/dash/main/`。

為什麼在根目錄：
fedep 預設複製 ( 或 link ) 的就是套件的根目錄，`dist/` 是 `--use-dist` 的 legacy 模式。
所以頁面上的網址是 `/assets/lib/@plotdb/dash/main/index.min.js`。

相依的 `@plotdb/block`、`@plotdb/chart`、`ld$`、`Papa` 都當全域用，刻意不打包進來 ——
套用的頁面本來就會載這些。

本機開發接到別的專案 ( 例如 makechart ) 用 link：

    npx fedep -l "@plotdb/dash:/path/to/dash"
