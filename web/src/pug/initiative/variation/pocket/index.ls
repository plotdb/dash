# pocket「口袋」- 同一份 def, 排成一支手機.
#
# 前提只有三句, 其餘都是後果:
#
#  - 畫面只有一欄寬 -> def.layout.col 從 12 欄變成 2 欄, 八格排成一直行往下捲
#  - 操作的是拇指 -> 點擊目標一律 32px 以上, 主要動作放在畫面底部構得到的地方
#  - 人是站著看的 -> 一次只看一格, 所以每一格都要自己說得完整 ( 標題 + 一句話 )
#
# 這一版最有意思的一點: 換成手機沒有動到 dash.board 一行. 版面是 def 裡的
# col / row, 一欄的版面就是 col 給兩欄 - 格線系統本來就不在乎自己有多寬.

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/variation/pocket/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 手機的色票比桌機的保守: 螢幕小, 同樣一塊顏色佔的視角大得多, 太飽和會晃眼.
# 兩個模式的關係也跟桌機相反 - 深色模式的卡片比底色亮, 因為手機在暗處
# 是房間裡唯一的光源, 大面積的亮色只能給卡片, 不能給背景.
day =
  ink: \#8a92a2                       # 軸線文字
  txt: \#4a5260                       # 圖裡的一般文字
  grid: 'rgba(20,25,35,.10)'
  face: \#ffffff                      # 卡片底 ( 未選的那一段往這裡退 )
  outline: 'rgba(20,25,35,.38)'
  ref: \#c2721c
  brush:
    fill: \#3b4bd8
    fillOpacity: 0.08
    stroke: 'rgba(59,75,216,.45)'
    strokeWidth: 1
    handleFill: 'rgba(59,75,216,.32)'
  hue:
    cat: colors: <[#3b4bd8 #0e9f6e #d4557c #8b43cf]>
    'cat-ramp': colors: <[#3b4bd8 #8b43cf]>
    chn: colors: <[#f0b968 #c2721c #86490f]>
    geo: colors: <[#0f8f86]>
    'geo-ramp': colors: <[#d8e5e8 #a6d0d0 #74bab7 #41a49e #0f8f86]>

night =
  ink: \#7f8796
  txt: \#b9c0cc
  grid: 'rgba(255,255,255,.11)'
  face: \#171a21                      # 深色模式的卡片是亮的那一塊
  outline: 'rgba(255,255,255,.27)'
  ref: \#ffc078
  brush:
    fill: \#fff
    fillOpacity: 0.07
    stroke: 'rgba(142,162,255,.5)'
    strokeWidth: 1
    handleFill: 'rgba(142,162,255,.35)'
  hue:
    cat: colors: <[#8ea2ff #42d9a0 #ff87a6 #c58bff]>
    'cat-ramp': colors: <[#8ea2ff #c58bff]>
    chn: colors: <[#ffc078 #e8914a #a85c22]>
    geo: colors: <[#4fd1c5]>
    'geo-ramp': colors: <[#263037 #30585a #3a807e #45a9a2 #4fd1c5]>

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

# 字級整體比桌機大一到兩級: 手機離眼睛近, 但字的實體尺寸小得多,
# 而且沒有 hover 可以補救看不清楚的東西
theme-of = (mode, p) ->
  c = if mode == \dark => night else day
  axis =
    caption: {show: false}
    label: {format: '.2~s', color: c.ink, font: {size: \.84em}}
    tick: {color: c.grid, inner: 3}
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
    # 兩欄. KPI 一格一欄排成 2x2, 圖一律跨兩欄 -
    # 「一欄的版面」在 def 裡就只是這一行
    col: <[1fr 1fr]>
    # 行高全部是絕對值 ( 跟 report 同一招 ): 內容決定高度, 整頁往下捲.
    # 圖的高度給得比桌機大方 - 一次只看一格, 不必省空間給隔壁
    row: <[5.4em 5.4em 15em 13.5em 19em 14.5em 15em]>
    gap: \10px

  panels: [
    # ---- 四個數字排成 2x2. 直式手機一行塞不下四格, 塞得下也讀不到
    * id: \gross, title: "總銷售額", unit: "萬元", accent: 'var(--pk-acc-1)'
      panel: kpi-block, area: {col: [1, 1], row: [1, 1]}
      data:
        measures: [{name: "銷售額", field: \amount, op: \sum, div: 10000}]
        compare: true

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: 'var(--pk-acc-2)'
      panel: kpi-block, area: {col: [2, 1], row: [1, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    * id: \price, title: "平均單價", unit: "元 / 冊", accent: 'var(--pk-acc-3)', note: \delta
      panel: kpi-block, area: {col: [1, 1], row: [2, 1]}
      data:
        # ratio 是 sum(amount) / sum(qty), 不是 avg(單價) - 後者每一筆的權重一樣,
        # 賣一本的小單會跟賣五百本的大單一樣重
        measures: [{name: "單價", field: \amount, op: \ratio, by: \qty}]
        compare: true

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: 'var(--pk-acc-4)'
      panel: kpi-block, area: {col: [2, 1], row: [2, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 圖. 說明文字是一句話, 不是操作說明 - 手機上沒有「框選」這個動作可說
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · 點書系名可只看一系"
      area: {col: [1, 2], row: [3, 1]}, hue: \cat
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {excludeSelf: true}
      cfg:
        mode: \line
        line: {mode: \curve, strokeWidth: 2}
        dot: {show: false}
        # 手機上不開框選: 拖曳在捲動的頁面裡會跟捲動搶同一個手勢
        brush: {enabled: false}
        # legend 排在下面而不是 direct: 一欄的寬度裡, 線末端的標籤會蓋到資料
        legend: {crossfilter: true, subset: {mode: \dim}, position: \bottom, actions: false}
        common:
          subset: {mode: \shrink}
          annotation:
            reference: [{axis: \y, value: 784324}]

    * id: \region, title: "各地區銷售額", subtitle: "點一下只看那個縣市"
      area: {col: [1, 2], row: [4, 1]}, hue: \geo
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg:
        legend: {enabled: false}
        # 一欄寬放六個縣市名, 橫著排一定撞在一起
        xaxis: {label: {direction: \auto}}
        common: {subset: {mode: \partial}}

    * id: \map, title: "地區分布", subtitle: "深淺是銷售額"
      area: {col: [1, 2], row: [5, 1]}, hue: 'geo-ramp'
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        legend: {enabled: false}

    * id: \channel, title: "通路占比", subtitle: "點一下只看那個通路"
      area: {col: [1, 2], row: [6, 1]}, hue: \chn
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.7, padding: 0.015}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, actions: false}

    * id: \category, title: "書系占比", subtitle: "依占比深淺上色"
      area: {col: [1, 2], row: [7, 1]}, hue: 'cat-ramp'
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
        mode: ({node}) -> node.textContent = dmode.icon!
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        # def 只印出來, 不編輯. 印一次就好 - 這一版不會改到它
        dump: ({node}) -> if !node.textContent => node.textContent = dash.dump def.panels
        chips: ({node}) ->
          mk = (f) ->
            v = if f.type == \range => f.values.join ' – '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            chip = document.createElement \span
            chip.className = \pk-chip
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
