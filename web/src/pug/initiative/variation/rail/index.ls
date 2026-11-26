# rail「側欄」- 同一份 def, 把四個數字立起來.
#
# 另外五個設計的 KPI 都是橫的一排, 這一版把它們放進左邊一整欄、直的疊起來.
# 要換的東西只有 def.layout 裡的 area - 版面寫在 def 裡, 不在版型檔裡,
# 所以「重排」就是改幾個數字, 不必碰任何 block.
#
# 立起來之後數字可以放到 46px, 一眼就看完; 右邊整塊給一張主圖, 其餘三張是佐證.
# 色票是報紙的: 一個紅、一個藍、其餘全是灰階.

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/variation/rail/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 報紙的色票: 大部分是黑白, 顏色只用在需要分辨的地方.
# 長條圖是黑的 - 這一版唯一的一張單色圖就該用最黑的那個黑,
# 紅色留給「現在被選中的是哪一塊」.
day =
  ink: \#767d88                       # 軸線文字
  txt: \#3a3f47                       # 圖裡的一般文字
  grid: 'rgba(10,12,15,.13)'
  face: \#ffffff                      # 紙
  outline: 'rgba(10,12,15,.36)'
  ref: \#d7263d
  brush:
    fill: \#d7263d
    fillOpacity: 0.08
    stroke: 'rgba(215,38,61,.5)'
    strokeWidth: 1
    handleFill: 'rgba(215,38,61,.35)'
  hue:
    # 四個書系: 紅、藍、黑、灰. 不是四個色相平均分配 -
    # 報紙只有兩塊彩色可用, 剩下的靠明度
    cat: colors: <[#d7263d #1f4ea8 #0a0c0f #9aa1ab]>
    'cat-ramp': colors: <[#f4ccd2 #d7263d]>
    chn: colors: <[#1f4ea8 #6f8fcd #b9c6e0]>
    geo: colors: <[#0a0c0f]>
    'geo-ramp': colors: <[#e2e3e6 #acadb0 #76787a #404245 #0a0c0f]>

night =
  ink: \#858c97
  txt: \#c2c8d0
  grid: 'rgba(247,248,250,.16)'
  face: \#0c0d10
  outline: 'rgba(247,248,250,.28)'
  ref: \#ff4d60
  brush:
    fill: \#ff4d60
    fillOpacity: 0.10
    stroke: 'rgba(255,77,96,.55)'
    strokeWidth: 1
    handleFill: 'rgba(255,77,96,.4)'
  hue:
    # 黑白對調: 最強的那一個色從黑換成白
    cat: colors: <[#ff4d60 #6f9bff #f7f8fa #858c97]>
    'cat-ramp': colors: <[#3a2126 #ff4d60]>
    chn: colors: <[#6f9bff #3f6bbf #27385c]>
    geo: colors: <[#f7f8fa]>
    'geo-ramp': colors: <[#25272d #5a5b60 #8e9094 #c2c4c7 #f7f8fa]>

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

theme-of = (mode, p) ->
  c = if mode == \dark => night else day
  axis =
    caption: {show: false}
    label: {format: '.2~s', color: c.ink, font: {size: \.78em}}
    tick: {color: c.grid, inner: 4}
    baseline: {color: c.grid}
  th =
    color: c.txt
    margin: 2
    xaxis: axis
    yaxis: {} <<< axis <<<
      grid: {show: true}
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
    # 五列, 行高是絕對值 ( 跟 report / pocket 同一招 ): 高度由內容決定,
    # 不夠就往下捲. 一開始寫成 fr 去填滿視窗, 結果在 800px 高的筆電上,
    # 右下兩格各只分到 130px - 扣掉標題跟那條粗線之後畫不出東西來.
    #
    # 側欄的代價就在這裡: 四個數字直的疊起來要吃掉四列, 右邊的圖只能跟著切.
    # 要嘛給圖足夠的高度然後讓頁面捲, 要嘛把數字放回頂上那一排
    row: <[8.2em 8.2em 9em 9em 19em]>
    # gap 給到 26px: 這一版沒有卡片也沒有框, 分隔全靠留白與標題上的粗線
    gap: \26px

  panels: [
    # ---- 左側欄: 四個數字, 直的疊起來. 跟其他設計唯一的差別就是這四行 area
    * id: \gross, title: "總銷售額", unit: "萬元", accent: 'var(--rl-acc-1)'
      panel: kpi-block, area: {col: [1, 3], row: [1, 1]}
      data:
        measures: [{name: "銷售額", field: \amount, op: \sum, div: 10000}]
        compare: true

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: 'var(--rl-acc-2)'
      panel: kpi-block, area: {col: [1, 3], row: [2, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    * id: \price, title: "平均單價", unit: "元 / 冊", accent: 'var(--rl-acc-3)', note: \delta
      panel: kpi-block, area: {col: [1, 3], row: [3, 1]}
      data:
        # ratio 是 sum(amount) / sum(qty), 不是 avg(單價) - 後者每一筆的權重一樣,
        # 賣一本的小單會跟賣五百本的大單一樣重
        measures: [{name: "單價", field: \amount, op: \ratio, by: \qty}]
        compare: true

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: 'var(--rl-acc-4)'
      panel: kpi-block, area: {col: [1, 3], row: [4, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 主圖: 右邊九欄、上面兩列. 一個版面只能有一個主角
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · 點書系名篩選, 橫向拖曳框選月份區間"
      area: {col: [4, 9], row: [1, 2]}, hue: \cat
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {excludeSelf: true}
      cfg:
        mode: \line
        line: {mode: \curve, strokeWidth: 2.2}
        dot: {show: false}
        brush: {enabled: true}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, mode: \direct}
        common:
          subset: {mode: \shrink}
          annotation:
            reference: [{axis: \y, value: 784324}]
            notes: [{x: 0.008, y: 0.95, text: "虛線 — 單書系月均 78 萬", align: \start, size: \.72em}]

    * id: \region, title: "各地區銷售額", subtitle: "可框選 · 全黑, 排序本身就是訊息"
      area: {col: [4, 5], row: [3, 2]}, hue: \geo
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg:
        legend: {enabled: false}
        xaxis: {label: {direction: \auto}}
        common: {subset: {mode: \partial}}

    # 又高又窄的格子: 臺灣本島加離島的範圍剛好是這個比例
    * id: \map, title: "地區分布", subtitle: "深淺是銷售額"
      area: {col: [9, 4], row: [3, 2]}, hue: 'geo-ramp'
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        legend: {enabled: false}

    * id: \channel, title: "通路占比", subtitle: "可點選"
      area: {col: [1, 6], row: [5, 1]}, hue: \chn
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.72, padding: 0.015}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, actions: false}

    * id: \category, title: "書系占比", subtitle: "可點選 · 依占比深淺上色"
      area: {col: [7, 6], row: [5, 1]}, hue: 'cat-ramp'
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        common: {subset: {mode: \partial}}
  ]

# ---------------------------------------------------------------- runtime
view = null

bd = new dash.board do
  root: document.querySelector('[ld=board]')
  # 這一頁是中文的, 所以自己講一聲 - block 的字串表預設是英文, 語言是
  # 宿主的事 ( 套件不猜使用者要哪一種 ). 見 dash.lng
  lng: 'zh-TW'
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
      handler:
        mode: ({node}) -> node.textContent = "#{dmode.icon!} #{dmode.label!}"
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        chips: ({node}) ->
          mk = (f) ->
            v = if f.type == \range => f.values.join ' – '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            chip = document.createElement \span
            chip.className = \rl-chip
            chip.innerHTML = """<span class="k"></span><span class="v"></span><span class="x">✕</span>"""
            chip.querySelector('.k').textContent = f.field
            chip.querySelector('.v').textContent = v
            chip.querySelector('.x').addEventListener \click, -> bd.set-filter f.owner, null, f.dim
            chip
          node.innerHTML = ''
          for id, f of bd.filters => node.appendChild mk f
    window.bd = bd
    window.def = def
  .catch (e) -> console.error e
