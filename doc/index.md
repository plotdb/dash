# @plotdb/dash

dashboard utility, based on `@plotdb/block`.

 - a class for manipulating dashboard, accepting:
   - a DOM for rendering dashboard ( using ldview )
   - a configuration set for panels rendering and layout
   - a documented, standardized definition of panel blocks to use.
   - ability to extend and use own panel definition


## build

    ./build        # 或 npm run build

輸出五個檔案，全部在 repo 根目錄，不是 `dist/`：

    index.js                lsc 的輸出，可讀，給 debug 用
    index.min.js            `package.json` 的 `main` / `browser`
    index.css               `dash.styl` 的輸出（版面與卡片的基本 CSS）
    index.min.css           `package.json` 的 `style`
    block/panel/index.html      預設的 panel block
    block/filterbar/index.html  全域篩選列

後面四個由 `tool/pack.js` 產生，來源都在示範頁底下 —— 它們本來就是示範頁在用的那一份，
不是另外抄一份給套件。panel block 的來源是 `variation/vanilla/block/panel/0.0.1/`：
七個設計的那七份逐字相同（只差一個 class 名），vanilla 是共同的起點，所以它就是預設的
那一份；複製一份當「套件版」只會變成兩份會各自長歪的東西。`tool/pack.js` 的 pug filter
跟 `@plotdb/srcbuild` 的 pug builder 一致，所以 build 出來的跟 dev server 服務的是
同一個東西（byte-identical，可以自己 diff 看）。

宿主的 registry 這樣指：

    {name: "@plotdb/dash", path: "block/panel/index.html"}
    {name: "@plotdb/dash", path: "block/filterbar/index.html"}

為什麼在根目錄：
fedep 預設複製 ( 或 link ) 的就是套件的根目錄，`dist/` 是 `--use-dist` 的 legacy 模式。
所以頁面上的網址是 `/assets/lib/@plotdb/dash/main/index.min.js`。

相依的 `@plotdb/block`、`@plotdb/chart`、`ld$`、`Papa` 都當全域用，刻意不打包進來 ——
套用的頁面本來就會載這些。

本機開發接到別的專案 ( 例如 makechart ) 用 link：

    npx fedep -l "@plotdb/dash:/path/to/dash"
