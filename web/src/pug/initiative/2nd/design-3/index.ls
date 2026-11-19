# design-3「牆面」- 同一份 def, 換一套外觀.
#
# 前提換了: 這一版假設沒有人坐在螢幕前面. 它掛在牆上, 十公尺外有人走過去看一眼.
# 所有決定都從這一句推出來:
#
#  - 沒有卡片, 只有磚. 格子之間留 3px 的縫, 縫就是分隔 - 遠看看不到 1px 的邊框,
#    看得到的是色塊的邊界
#  - 字大到該有的程度, 標題一律大寫緊排; 說明文字排在標題右邊, 垂直空間留給圖
#  - 狀態用面積, 不用小字. 篩選中的磚上緣是一道粗的強調色
#  - 沒有 def 編輯器. 牆上的螢幕不接鍵盤 ( 要看定義就去 design-1 或 design-2 )
#
# def 本身跟另外兩版是同一份東西, 只有 layout 的比例與 cfg 的顏色不同.

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/2nd/design-3/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 色票比另外兩版飽和一整級. 遠距離看, 低彩度的差別會糊在一起 -
# design-2 那種紙上的墨色在十公尺外全部是灰的
tile = \#1c1a19           # 磚底
ink = \#8d867d            # 軸線文字
grid = 'rgba(255,255,255,.10)'

cat = colors: <[#ffd166 #26c6a6 #ff5d73 #8ab4ff]>   # 書系 ( 類別 )
# 書系的四色沒有共同色族 ( 這一版的色票是海報式的, 四個色相各走各的 ),
# 所以漸層跟著打頭的那一個黃走 - 重點是不要跟地區的綠松撞成同一組
cat-ramp = colors: <[#3f3a2c #ffd166]>              # 書系 ( 依占比的漸層 )
chn = colors: <[#ffd166 #f3722c #9d2f1f]>           # 通路
geo = colors: <[#26c6a6]>                           # 地區 ( 單色 )
# 低端不能太接近磚底 ( #1c1a19 ) - 沒有資料的縣市拿的就是低端色,
# 太暗整座島會消失, 剩下幾塊亮的浮在黑底上
geo-ramp = colors: <[#36403d #26c6a6]>              # 地區 ( 漸層 )

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

axis-theme =
  caption: {show: false}
  label: {format: '.2~s', color: ink, font: {size: \.8em}}
  tick: {color: grid, inner: 4}
  baseline: {color: grid}

theme =
  color: ink
  margin: 2
  xaxis: axis-theme
  yaxis: {} <<< axis-theme <<<
    grid: {show: true, opacity: 0.09}
    tick: {color: grid, inner: 0}
    baseline: {show: false}
  common:
    subset: {background: tile}
    brush:
      fill: \#fff
      fillOpacity: 0.08
      stroke: 'rgba(255,209,102,.6)'
      strokeWidth: 1.5
      handleFill: 'rgba(255,209,102,.4)'

deep = (a = {}, b = {}) ->
  clone = (v) -> if v and typeof(v) == \object and !Array.isArray(v) => deep(v) else v
  ret = {}
  for k, v of a => ret[k] = clone v
  for k, v of b =>
    ret[k] = if v and typeof(v) == \object and !Array.isArray(v) => deep (ret[k] or {}), v
    else v
  ret

# ------------------------------------------------------------------ def
def =
  data: {type: \json, url: "/assets/data/sales.json"}

  layout:
    col: <[1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr]>
    row: <[.85fr 1.55fr 1.25fr]>
    # 縫就是分隔. 這一行等於 design-1 的 border + radius + box-shadow 三行
    gap: \3px

  panels: [
    * id: \gross, title: "總銷售額", unit: "萬元", accent: \#ffd166
      panel: kpi-block, area: {col: [1, 3], row: [1, 1]}
      data:
        measures: [{name: "銷售額", op: (rows) -> dash.agg.sum(rows, \amount) / 10000}]
        compare: true

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: \#26c6a6
      panel: kpi-block, area: {col: [4, 3], row: [1, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    * id: \price, title: "平均單價", unit: "元 / 冊", accent: \#ff8c61, note: \delta
      panel: kpi-block, area: {col: [7, 3], row: [1, 1]}
      data:
        measures: [
          * name: "單價"
            op: (rows) ->
              [a, q] = [dash.agg.sum(rows, \amount), dash.agg.sum(rows, \qty)]
              if q => a / q else 0
        ]
        compare: true

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: \#8ab4ff
      panel: kpi-block, area: {col: [10, 3], row: [1, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 圖. 說明文字只留一個詞 - 牆上沒有人要讀操作說明
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系"
      area: {col: [1, 9], row: [2, 1]}
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {excludeSelf: true}
      cfg:
        palette: cat
        mode: \line
        line: {mode: \curve, strokeWidth: 3}
        dot: {show: false}
        brush: {enabled: true}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, mode: \direct}
        common:
          subset: {mode: \shrink}
          annotation:
            color: \#ffd166
            reference: [{axis: \y, value: 784324}]
            notes: [{x: 0.01, y: 0.95, text: "單書系月均 78 萬", align: \start, size: \.74em}]

    * id: \channel, title: "通路占比", subtitle: "依銷售額"
      area: {col: [4, 3], row: [3, 1]}
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        palette: chn
        color: \#cfc7bc
        donut: {percent: 0.66, padding: 0.02}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \bottom, actions: false}

    * id: \region, title: "各地區銷售額", subtitle: "前六名"
      area: {col: [1, 3], row: [3, 1]}
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg:
        palette: geo
        legend: {enabled: false}
        # 這一格只有 3 欄寬, 六個縣市的名字橫著排不下. auto = 先試水平,
        # 放不下改傾斜, 再放不下轉垂直, 都不行才抽稀 - 以前只能隱藏其中幾個
        xaxis: {label: {direction: \auto}}
        common: {subset: {mode: \partial}}

    * id: \category, title: "書系占比", subtitle: "依銷售額"
      area: {col: [7, 3], row: [3, 1]}
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        palette: cat-ramp
        color: \#cfc7bc
        common: {subset: {mode: \partial}}

    # 跨兩列: 臺灣本島加離島的範圍又高又窄, 放在扁格子裡會縮成一小塊
    * id: \map, title: "地區分布", subtitle: ""
      area: {col: [10, 3], row: [2, 2]}
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        palette: geo-ramp
        legend: {enabled: false}
        border: {color: 'rgba(255,255,255,.14)', width: 0.7}
  ]

def.panels.map (p) -> if p.chart => p.cfg = deep theme, (p.cfg or {})

# ---------------------------------------------------------------- runtime
view = null

bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

bd.on \filter, -> if view => view.render!

block.i18n.change-language \zh-TW

mgr.init!
  .then -> bd.init!
  .then ->
    view := new ldview do
      root: document.body
      action: click: clear: -> bd.clear-filter!
      handler:
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        # 牆面版的 chip 只說「現在看的是哪一塊」, 不提供逐條刪除 -
        # 清掉就是全部清掉, 走過去的人不會想記得哪一條是哪一條
        chips: ({node}) ->
          node.innerHTML = ''
          for id, f of bd.filters
            v = if f.type == \range => f.values.join ' – '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            chip = document.createElement \span
            chip.className = \wl-chip
            chip.innerHTML = """<span class="k"></span><span class="v"></span>"""
            chip.querySelector('.k').textContent = f.field
            chip.querySelector('.v').textContent = v
            node.appendChild chip
    window.bd = bd
    window.def = def
  .catch (e) -> console.error e
