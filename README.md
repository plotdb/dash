# @plotdb/dash

Dashboard utility, based on `@plotdb/block`.

一份 def 描述整個儀表板（資料來源、每一格畫什麼、版面、主題），`dash.board` 把它掛起來，
並負責 panel 的生命週期與跨圖篩選（crossfilter）。畫圖的是 `@plotdb/chart` 系的圖表 block，
dash 不碰繪圖。


## 安裝

    npm install @plotdb/dash

走 fedep 的專案在 `package.json` 的 `frontendDependencies.modules` 加上 `@plotdb/dash`，
`npx fedep` 之後頁面上載這兩個檔：

    /assets/lib/@plotdb/dash/main/index.min.js      # 掛出全域的 window.dash
    /assets/lib/@plotdb/dash/main/index.min.css     # 版面與卡片的基本 CSS

這兩個檔在套件根目錄。repo 裡它們在 `dist/`，`fedep publish` 發佈時會攤平到根目錄。
**不要指 `web/static/` 底下的任何東西**——那是 dev server 編給示範頁用的，不進版控也不發佈。


## 用法

```js
const board = new dash.board({
  root: document.querySelector('#board'),
  manager: blockManager,          // @plotdb/block 的 manager
  def: {
    data: {...},                  // 資料來源與欄位
    layout: {type: 'grid', columns: 12},
    theme: {name: 'desk', mode: 'auto'},
    panels: [
      {id: 'trend', title: '月銷售趨勢', area: [0, 0, 6, 4],
       chart: {name: '@makechart/line'}, binding: {...}}
    ]
  }
});
board.init();
```

主要的 API：

| | |
|---|---|
| `board.init()` / `board.reload(def)` | 掛起來 / 換一份 def |
| `board.setTheme(t)` / `board.setMode(m)` | 換主題 / 換明暗，不清篩選 |
| `board.relayout(layout)` | 只換版面，不重建 panel |
| `board.addPanel` / `updatePanel` / `removePanel` | 單格增修刪 |
| `board.setFilter` / `toggleFilter` / `clearPanel` | 篩選 |
| `dash.themes` | 內建主題清單 |
| `dash.lng(l)` / `board.setLng(l)` | 換語言（`en` / `zh-TW`），不給參數就是讀現在的 |

內建七份主題：`vanilla` / `desk` / `report` / `wall` / `terminal` / `pocket` / `rail`。


## 語言

介面上的字（篩選列、「篩選中」、KPI 的「佔全體 x%」、操作提示）走 `@plotdb/block`
原生的 i18n，附 `en` 與 `zh-TW`。**預設是 `en`** —— 套件不猜使用者要哪一種，語言是宿主的事：

```js
new dash.board({..., lng: 'zh-TW'})   // 掛起來就用這個語言
dash.lng('en')                        // 之後要換. board.setLng(l) 等效
dash.lng()                            // 讀現在的
```

換語言不清篩選，也不重建版面：靜態的字由 block 自己重譯，JS 現組的那幾句
（「清除 3 項」）跟著 `render` 重寫。語言是全域的（`block.i18n` 只有一份），
所以一頁上的兩個 board 不能各講一種話。自己寫一份 block 的話，字串表放在
`pkg.i18n`，pug 裡用 `t="<英文原文>"` 標要翻的節點。


## 文件與示範

 - `doc/index.md` —— def 的格式、版面、主題、build 的輸出
 - `npm start` 開示範站，`web/src/pug/initiative/` 底下每個概念各有一份 README：
   - `variation/` 七種卡片設計（同一份 def，只換 panel block）
   - `theme/` 主題格式、標題列規格、操作提示怎麼推出來的
   - `split/` 可拖的巢狀版面


## 開發

    npm start          # 示範站
    npm run build      # 編出 dist/
    npm run release    # build + 發佈（npm 與 GitHub release）

授權 MIT。
