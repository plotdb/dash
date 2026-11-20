# @plotdb/dash

dashboard utility, based on `@plotdb/block`.

 - a class for manipulating dashboard, accepting:
   - a DOM for rendering dashboard ( using ldview )
   - a configuration set for panels rendering and layout
   - a documented, standardized definition of panel blocks to use.
   - ability to extend and use own panel definition


## build

    ./build        # 或 npm run build

把 `web/src/ls/dash.ls` 編成 `index.js` ( 可讀, 給 debug 用 ) 與 `index.min.js`
( `package.json` 的 `main` / `browser` 指這個 )。兩個都在 repo 根目錄，不是 `dist/`：
fedep 預設複製 ( 或 link ) 的就是套件的根目錄，`dist/` 是 `--use-dist` 的 legacy 模式。
所以頁面上的網址是 `/assets/lib/@plotdb/dash/main/index.min.js`。

相依的 `@plotdb/block`、`@plotdb/chart`、`ld$`、`Papa` 都當全域用，刻意不打包進來 ——
套用的頁面本來就會載這些。

本機開發接到別的專案 ( 例如 makechart ) 用 link：

    npx fedep -l "@plotdb/dash:/path/to/dash"
