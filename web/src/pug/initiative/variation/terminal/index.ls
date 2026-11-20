# terminal「主控台」- 同一份 def, 當成一個終端機畫面.
#
# 兩個決定推出其餘全部:
#
#  1. 整頁等寬字, 包括圖表裡的文字. 跟 report 把整頁換成襯線是同一招 -
#     svg 的 text 吃 CSS 繼承, 所以在 panel 上設 font-family 就夠了
#  2. 整頁只有一個色相. 連四個書系都是同一個色的四階 -
#     這是這一版唯一真正「危險」的決定, 代價寫在 README
#
# 另一個差別在 KPI block: 進度條是字元畫的 ████░░░░, 不是 CSS 的色條.
# 理由是這個畫面上沒有別的東西是圖形, 一條色條會是唯一不是字的元素.

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/variation/terminal/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 單色. 另外四個設計的規則是「色相留給資料」, 這一版把那條規則拿掉了:
# 所有維度共用同一個色相, 分類靠的是明度順序與標籤.
#
# 這在資料視覺化上是明確的取捨 - 四條線的顏色只差明度, 交叉的地方分不出誰是誰.
# 所以 line 一定要配 legend.mode: direct ( 名字寫在線的末端 ), 不能只靠色塊對照.
amber =
  ink: \#6f757e                       # 軸線文字
  txt: \#9aa0a8                       # 圖裡的一般文字
  grid: \#22262b
  face: \#111214                      # panel 底 ( 未選的那一段往這裡退 )
  outline: \#4d5258
  ref: \#ffb000
  brush:
    fill: \#ffb000
    fillOpacity: 0.10
    stroke: 'rgba(255,176,0,.55)'
    strokeWidth: 1
    handleFill: 'rgba(255,176,0,.4)'
  hue:
    # 四個書系 = 同一個琥珀色的四階. 順序跟著 series 的出現順序,
    # 所以「最亮的那一條」永遠是第一個書系
    cat: colors: <[#ffd79a #ffb000 #c77f00 #7d5200]>
    'cat-ramp': colors: <[#3a2c12 #ffb000]>
    chn: colors: <[#ffd79a #c77f00 #7d5200]>
    geo: colors: <[#ffb000]>
    'geo-ramp': colors: <[#332917 #664b11 #996c0c #cc8e06 #ffb000]>

paper =
  ink: \#767b83
  txt: \#4a4e55
  grid: \#d5d2c9
  face: \#f8f7f3
  outline: \#a5a198
  ref: \#9a5e00
  brush:
    fill: \#9a5e00
    fillOpacity: 0.10
    stroke: 'rgba(154,94,0,.5)'
    strokeWidth: 1
    handleFill: 'rgba(154,94,0,.35)'
  hue:
    # 紙上的四階反過來排: 最深的是第一個書系. 在白底上「深」才等於「強」
    cat: colors: <[#5c3800 #9a5e00 #c08a3c #ddb77e]>
    'cat-ramp': colors: <[#efe6d4 #9a5e00]>
    chn: colors: <[#ddb77e #c08a3c #7a4a00]>
    geo: colors: <[#9a5e00]>
    'geo-ramp': colors: <[#e4dac7 #d2bb95 #bf9c64 #ac7d32 #9a5e00]>

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

theme-of = (mode, p) ->
  c = if mode == \light => paper else amber
  axis =
    caption: {show: false}
    label: {format: '.2~s', color: c.ink, font: {size: \.76em}}
    tick: {color: c.grid, inner: 4}
    baseline: {color: c.grid}
  th =
    color: c.txt
    margin: 2
    xaxis: axis
    # 格線是實線但很淡. 終端機的畫面本來就是一格一格的, 格線在這裡不突兀
    yaxis: {} <<< axis <<<
      grid: {show: true, color: c.grid, opacity: 1}
      tick: {color: c.grid, inner: 0}
      baseline: {show: false}
    common:
      subset: {background: c.face}
      brush: c.brush
  if p.hue => th.palette = c.hue[p.hue]
  if p.id == \map => th.border = {color: c.outline, width: 1}
  if p.id == \trend => th.common.annotation = {color: c.ref}
  th

# ------------------------------------------------------------------ def
def =
  data: {type: \json, url: "/assets/data/sales.json"}

  layout:
    col: <[1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr]>
    # 比 desk 更扁的 KPI 列: 這一版的 KPI 沒有卡片的留白, 只有三行字
    row: <[5.4em 1.25fr 1fr]>
    gap: \8px

  panels: [
    # ---- KPI. 標題一律大寫 - 這四個是欄位名, 不是句子
    * id: \gross, title: "GROSS 總銷售額", unit: "萬元"
      panel: kpi-block, area: {col: [1, 3], row: [1, 1]}
      data:
        measures: [{name: "銷售額", field: \amount, op: \sum, div: 10000}]
        compare: true

    * id: \qty, title: "QTY 總銷售冊數", unit: "冊"
      panel: kpi-block, area: {col: [4, 3], row: [1, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    * id: \price, title: "AVG 平均單價", unit: "元 / 冊", note: \delta
      panel: kpi-block, area: {col: [7, 3], row: [1, 1]}
      data:
        # ratio 是 sum(amount) / sum(qty), 不是 avg(單價) - 後者每一筆的權重一樣,
        # 賣一本的小單會跟賣五百本的大單一樣重
        measures: [{name: "單價", field: \amount, op: \ratio, by: \qty}]
        compare: true

    * id: \coverage, title: "GEO 涵蓋地區", unit: "縣市"
      panel: kpi-block, area: {col: [10, 3], row: [1, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 圖. 說明文字寫成參數的樣子: 這一版的語氣是「這張圖是怎麼算出來的」
    * id: \trend, title: "月銷售趨勢", subtitle: "sum(amount) by month × category"
      area: {col: [1, 7], row: [2, 1]}, hue: \cat
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {excludeSelf: true}
      cfg:
        mode: \line
        # 直線不是曲線: 月是離散的點, 曲線是在補一段不存在的資料.
        # 其他設計選了好看, 這一版選了誠實 - 這也是「主控台」的語氣
        line: {mode: \line, strokeWidth: 1.6}
        dot: {show: true, size: 2}
        brush: {enabled: true}
        # direct 在這裡不是選擇, 是必要的: 四條線只差明度, 靠色塊對照認不出來
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, mode: \direct}
        common:
          subset: {mode: \shrink}
          annotation:
            reference: [{axis: \y, value: 784324}]
            notes: [{x: 0.008, y: 0.94, text: "ref — avg/series/month 784,324", align: \start, size: \.7em}]

    * id: \channel, title: "通路占比", subtitle: "sum(amount) by channel"
      area: {col: [8, 5], row: [2, 1]}, hue: \chn
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.78, padding: 0.01}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, actions: false}

    * id: \region, title: "各地區銷售額", subtitle: "sum(amount) by region · top 6"
      area: {col: [1, 5], row: [3, 1]}, hue: \geo
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg:
        legend: {enabled: false}
        common: {subset: {mode: \partial}}

    * id: \category, title: "書系占比", subtitle: "share by category"
      area: {col: [6, 4], row: [3, 1]}, hue: 'cat-ramp'
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        common: {subset: {mode: \partial}}

    * id: \map, title: "地區分布", subtitle: "choropleth"
      area: {col: [10, 3], row: [3, 1]}, hue: 'geo-ramp'
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        legend: {enabled: false}
  ]

# ---------------------------------------------------------------- runtime
view = null

bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

# 主題套到每個有圖的 panel 上, 並且在換模式時重算、重畫 ( 見 ../mode.ls )
dmode.theme bd, theme-of
dmode.on -> if view => view.render!

bd.on \filter, -> if view => view.render!

block.i18n.change-language \zh-TW

mgr.init!
  .then -> bd.init!
  .then ->
    view := new ldview do
      root: document.body
      action: click:
        clear: -> bd.clear-filter!
        mode: -> dmode.toggle!
      text:
        # 狀態列. 一行字講完「現在看的是多少列、幾個條件」
        stat: ->
          n = bd.rows-all!.length
          "rows #{n.toLocaleString 'en-US'} / #{bd.rows.length.toLocaleString 'en-US'} · filters #{Object.keys(bd.filters).length}"
      handler:
        mode: ({node}) -> node.textContent = if dmode.get! == \dark => '[ LIGHT ]' else '[ DARK ]'
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        chips: ({node}) ->
          mk = (f) ->
            v = if f.type == \range => f.values.join '..'
            else if f.values.length => f.values.join '|'
            else '∅'
            chip = document.createElement \span
            chip.className = \tm-chip
            chip.innerHTML = """<span class="k"></span><span>=</span><span class="v"></span><span class="x">✕</span>"""
            chip.querySelector('.k').textContent = f.field
            chip.querySelector('.v').textContent = v
            chip.querySelector('.x').addEventListener \click, -> bd.set-filter f.owner, null, f.dim
            chip
          node.innerHTML = ''
          for id, f of bd.filters => node.appendChild mk f
    window.bd = bd
    window.def = def
  .catch (e) -> console.error e
