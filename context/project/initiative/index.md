hi, 看一下這專案的 dashboard 部份
/Users/tkirby/workspace/plotdb/case/taicca/vis2/web/src/pug/dashboard

dashboard 視覺化儀表板由多個 @plotdb/block -> @plotdb/chart 圖表組成, 有 crossfilter 機制.
dashboard 的角色大概就是中控台.
我現在想把他模組化, 包括

1. 基本 CSS: 大略上可以協助我們使用的 class 用來快速組裝儀表板
2. data driver: 從不特定資料源 ( 先預設有 json ) 匯入的資料
3. dashboard def:
  - 要有哪些圖
  - 儀表板的大致排版
    - 可能用 html/css, 可能用 js def.
  - per 圖:
    - 使用哪些資料對應圖. 參考 setRaw ( @plotdb/chart ) 會用到的 data, binding
    - 圖的樣式. 一樣是 @plotdb/chart 跟設定樣式或參數有關的部份
  - cross filtering 的動態
 
可以有問題, 但若行的話問問題前可以先快速做一個示範概念在 web/src/pug/initiative/1st/
有範本參考我們可以更好限縮方向.

使用  npm start 會自動啟動 src build ( src -> static ) 並開 web server.
可用 claude in chrome test.
