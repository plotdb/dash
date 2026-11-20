# split 版面示範
#
# 跟 variation/vanilla 用的是同一份資料、同一組 block、同一套 crossfilter,
# 換掉的只有 def.layout: 從一張格線換成一棵可以巢狀切分的樹.
#
# 這一頁要講的事:
#
#  - layout.type: \split 的樹長什麼樣, 以及 size 的兩種寫法
#  - 分隔線可以拖, 拖完 board 發 resize 事件, 把改過的 layout 交回來 -
#    那就是可以存回去的新版面
#  - board.relayout(layout) 只換版面不重建 panel: 圖表跟著節點搬家,
#    篩選狀態也還在 ( 跟 reload 的差別就在這裡 )

<-(-> it.apply {}) _

# block 直接借 variation/vanilla 的那一套 - 同一份 panel / filterbar,
# 只有版面不一樣, 這正是這一頁要講的
mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/variation/vanilla/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

palette = colors: <[#0b7fab #6ab7d4 #f2a154 #b6c454 #9b8bbd #dd6e6e]>

light = {fg: \#55585c, line: \#d8dadd, face: \#fff, geo: colors: <[#e8f2f6 #0b7fab]>, border: {color: \#c9ccd4, width: 0.8}}
dark  = {fg: \#9aa0a8, line: \#343a41, face: \#1d2024, geo: colors: <[#2b3138 #4db6dd]>, border: {color: \#454c55, width: 0.8}}

theme-of = (mode, p) ->
  c = if mode == \dark => dark else light
  ax = {caption: {show: false}, label: {format: '.2~s', color: c.fg}, tick: {color: c.line}, baseline: {color: c.line}}
  th = {color: c.fg, xaxis: ax, yaxis: ax, common: subset: {background: c.face}}
  if p.id == \map => th <<< {palette: c.geo, border: c.border}
  th

fb-block = {ns: \local, name: \filterbar, version: \0.0.1}

# ------------------------------------------------------------------ 版面
#
# 兩種切法, 示範 relayout: 同一批 panel, 換一棵樹就換一個版面.
#
#  - size 是數字: flex-grow 的比例 ( 2 的格子是 1 的兩倍寬 )
#  - size 是字串: 固定大小, 任何 CSS 長度都行
#  - 沒有 panel 的葉子: 空格子, 編輯器可以在上面放「新增圖表」
layouts =
  主控台:
    type: \split
    gap: \.8em
    resizable: true
    root:
      dir: \col
      children: [
        * size: \2.6em, panel: \header
        * size: 1, dir: \row
          children: [
            * size: 2, min: \18em, dir: \col
              children: [
                * size: 3, panel: \trend
                * size: 2, panel: \region
              ]
            * size: 1, min: \14em, dir: \col
              children: [
                * size: 1, panel: \channel
                * size: 1, panel: \map
                * size: 1
              ]
          ]
      ]

  左右對開:
    type: \split
    gap: \.8em
    resizable: true
    root:
      dir: \row
      children: [
        * size: 1, dir: \col
          children: [
            * size: \2.6em, panel: \header
            * size: 1, panel: \trend
            * size: 1, panel: \channel
          ]
        * size: 1, dir: \col
          children: [
            * size: 2, panel: \map
            * size: 1, panel: \region
          ]
      ]

# ------------------------------------------------------------------ def
def =
  data: {type: \json, url: "/assets/data/sales.json"}
  layout: layouts.主控台
  panels: [
    * id: \header, panel: fb-block
      only: <[month region category channel]>
      labels: {month: "月份", region: "地區", category: "書系", channel: "通路"}

    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · 可框選月份區間"
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {exclude-self: true}
      cfg:
        mode: \line
        line: {mode: \curve, strokeWidth: 2}
        brush: {enabled: true}
        palette: palette
        legend: {crossfilter: true, position: \right}
        common: {subset: {mode: \shrink}}

    * id: \region, title: "各地區銷售額", subtitle: "可框選"
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg: {palette: palette, legend: {enabled: false}, common: {subset: {mode: \partial}}}

    * id: \channel, title: "通路占比", subtitle: "可點選"
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.7}
        palette: palette
        legend: {crossfilter: true, position: \bottom}
        common: {subset: {mode: \partial}}

    * id: \map, title: "地區分布", subtitle: "可點選"
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg: {legend: {enabled: false}}
  ]

# ---------------------------------------------------------------- runtime
bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

dmode.theme bd, theme-of

node = (n) -> document.querySelector "[ld=#n]"
cur = \主控台

# 拖完分隔線, board 把改過的 layout 交回來 - 存回去就是新版面.
# 這裡只是把它印出來, 真的要存的話就是把這棵樹寫回文件
bd.on \resize, (l) ->
  node \out .textContent = dash.dump l.root
  node \msg .textContent = "剛剛拖過分隔線 · #{(new Date!).toLocaleTimeString!}"

bd.on \relayout, (l) -> node \out .textContent = dash.dump l.root

# 一個版面一顆按鈕. 具名 function 收 name, 不在迴圈裡寫 inline closure -
# LiveScript 的 `do (name) ->` 編出來是沒有參數的呼叫, 每顆按鈕會共用最後一個值
# ( 這跟 panel block 裡那個坑是同一個 )
mk-switch = (name) ->
  b = document.createElement \div
  b.className = if name == cur => 'btn primary' else \btn
  b.textContent = name
  b.addEventListener \click, ->
    cur := name
    for n in document.querySelectorAll('[ld=switch] .btn') => n.classList.remove \primary
    b.classList.add \primary
    # 只換版面: 圖表不重建, 篩選狀態也還在
    bd.relayout layouts[name]
    node \msg .textContent = "換成「#{name}」· 圖表沒有重建, 篩選也還在"
  node \switch .appendChild b

for name of layouts => mk-switch name

node \mode .addEventListener \click, -> dmode.toggle!
dmode.on -> node \mode .textContent = "#{dmode.icon!} #{dmode.label!}"

node \pin .addEventListener \click, ->
  l = bd.def.layout
  l.resizable = !l.resizable
  bd.relayout l
  node \pin .textContent = if l.resizable => "分隔線: 可拖" else "分隔線: 鎖住"
  node \pin .classList.toggle \primary, l.resizable

bd.init!then ->
  node \out .textContent = dash.dump bd.def.layout.root
