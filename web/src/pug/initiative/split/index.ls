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

# geo 與 border 的大括號要寫出來. 寫成 `geo: colors: <[...]>, border: {...}` 的話,
# 隱式物件會一路吃到行尾, border 會變成 geo 的一個 key - 於是地圖的邊線設定跑進
# palette 底下, 圖表拿不到它, 畫面上就是「台灣沒有輪廓」
light = {fg: \#55585c, line: \#d8dadd, face: \#fff, geo: {colors: <[#d0e5ee #9fccdd #6eb2cc #3c98bc #0b7fab]>}, border: {color: \#a5a7ae, width: 1}, empty: \#e8e8e8}
dark  = {fg: \#9aa0a8, line: \#343a41, face: \#1d2024, geo: {colors: <[#2c353d #345565 #3c768d #4596b5 #4db6dd]>}, border: {color: \#565c64, width: 1}, empty: \#2a2a2d}

theme-of = (mode, p) ->
  c = if mode == \dark => dark else light
  ax = {caption: {show: false}, label: {format: '.2~s', color: c.fg}, tick: {color: c.line}, baseline: {color: c.line}}
  th = {color: c.fg, xaxis: ax, yaxis: ax, common: subset: {background: c.face}}
  # 地圖用的是 @makechart/twmapadv ( 見 def ). 它的顏色不在 palette 底下,
  # 而是 heat: 色階兩端 ( sequential )、以及「沒有資料」的顏色 ( empty ).
  #
  # empty 刻意用中性灰, 跟資料的藍色系分開: 沒有資料跟「數值最低」是兩件事,
  # 同一個色系的話, 使用者會把沒資料的縣市讀成「賣得最差」
  if p.id == \map => th <<< {
    heat: {sequential: c.geo, empty: c.empty}
    border: {color: c.border.color, width: 0.6}
    # 小格子裡縣市名會互相疊到, 所以縮小; 不關掉是因為它是這張圖認路的依據
    label: {font: {size: \.6em}, color: c.fg, halo: c.face}
  }
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

    # 地圖換成 @makechart/twmapadv.
    #
    #  - chart.data.level 是給 chart block 的參數 ( 不是資料 ): town = 全國,
    #    上層是縣市、下層是鄉鎮. 這一頁只有縣市資料, 所以只綁上層那一維
    #  - binding 要明寫: 這張圖有六個維度 ( town / village / value / size /
    #    cat / parts ), 自動推導會把數值綁到 value 也綁到 size 與 parts
    #  - 色階是連續的 ( heat.steps 預設 0 ), 所以六個縣市有六個深淺;
    #    沒有資料的十六個縣市走 heat.empty, 跟「最低的那一級」分得開
    * id: \map, title: "地區分布", subtitle: "可點選 · 深淺是銷售額, 灰色是沒有資料"
      chart: {name: "@makechart/twmapadv", data: {level: \town}}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      binding:
        town: {key: \key}
        value: {key: "銷售額", name: "銷售額", unit: "元"}
      # village.mode 預設是 click: 點一個縣市會展開成它底下的鄉鎮. 這一頁只有
      # 縣市資料, 展開之後每一個鄉鎮都是「沒有資料」- 使用者點下去, 看到的是
      # 自己剛剛選的那一塊變成一片空白. 所以關掉, 點選就只是發篩選
      cfg: {legend: {enabled: true}, village: {mode: \none}}
  ]

# ---------------------------------------------------------------- runtime
bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

dmode.theme bd, theme-of

# 這是示範頁, 把 board 掛出去方便在 console 直接試 ( bd.updatePanel(...) 之類 )
window.bd = bd

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

# ------------------------------------------------------- 編輯器用的那幾個 API
#
# 點一格 -> 它在樹上的位置 -> 在那一格增 / 刪 / 改. 這一段就是編輯器會做的事,
# 只是 UI 換成三顆按鈕.

# 要放進空格子的那一張圖. 跟 def.panels 裡的寫法完全一樣
spare =
  id: \category, title: "書系占比", subtitle: "可點選"
  chart: {name: "@makechart/percent-list"}
  data:
    groupby: \category
    measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
    compare: true
  cfg: {palette: palette, common: {subset: {mode: \partial}}}

sel = null     # 選取的格子在樹上的位置

paint = ->
  for n in document.querySelectorAll('.dash-cell') => n.classList.remove \sel
  spec = if sel => bd.spec-at sel else null
  if sel and (n = bd.node-at sel) => n.classList.add \sel
  node \path .textContent = if !sel => '( 還沒選 )' else "[#{sel.join ', '}]#{if spec?panel => " · #{spec.panel}" else ' · 空格子'}"
  for k, b of btn => b.classList.toggle \off, !spec
  btn.put.textContent = if spec?panel => '拿掉這張圖' else '放一張圖進去'
  btn.swap.classList.toggle \off, !spec?panel
  btn.hue.classList.toggle \off, !spec?panel

btn =
  put: node \put
  swap: node \swap
  hue: node \hue

# 點格子選取. 位置直接問 board - 自己從 DOM 往上數 index 要跳過分隔線,
# 而且這邊的 DOM 形狀一改, 那段程式就默默錯掉
bd.root.addEventListener \click, (e) ->
  p = bd.path-of e.target
  if !p or !p.length => return
  # 只選到葉子 ( 容器節點點不到, 因為它整片都被子節點蓋著 )
  sel := p
  paint!

btn.put.addEventListener \click, ->
  spec = if sel => bd.spec-at sel else null
  if !spec => return
  if spec.panel
    id = spec.panel
    bd.remove-panel id          # 真的刪掉: 連它發出的 filter 一起清
    node \msg .textContent = "拿掉了「#{id}」· 它發出的篩選也一起清掉了, 格子還在"
    paint!
  else
    # 先在樹上指過去, 再 relayout 把格子接起來, 最後把 panel 掛進去.
    # 反過來 ( 先 add 再 relayout ) 也可以 - 格子會先放著不進 DOM
    spec.panel = spare.id
    bd.relayout!
    bd.add-panel spare .then ->
      node \msg .textContent = "放了一張「#{spare.title}」進去 · 其他圖沒有重建"
      paint!

btn.swap.addEventListener \click, ->
  spec = if sel => bd.spec-at sel else null
  if !spec?panel => return
  p = bd.panel-of spec.panel
  now = p?chart?name
  next = if now == "@makechart/bar" => "@makechart/pie" else "@makechart/bar"
  # 換圖種: 這一個會重建 chart ( 本來就是另一張圖 ), 但 panel 本身不動
  bd.update-panel spec.panel, {chart: {name: next}}
  node \msg .textContent = "「#{spec.panel}」換成 #{next} · 只有這一格重建"

btn.hue.addEventListener \click, ->
  spec = if sel => bd.spec-at sel else null
  if !spec?panel => return
  p = bd.panel-of spec.panel
  warm = <[#dd6e6e #f2a154 #b6c454 #9b8bbd #6ab7d4 #0b7fab]>
  cold = palette.colors
  cur-warm = (p._cfg or p.cfg or {}).palette?colors?0 == warm.0
  # 只改 cfg: 不重建 chart, 篩選與選取狀態都不動
  bd.update-panel spec.panel, {cfg: {} <<< (p._cfg or p.cfg or {}) <<< {palette: {colors: (if cur-warm => cold else warm)}}}
  node \msg .textContent = "「#{spec.panel}」換了色票 · chart 沒有重建"

bd.on \relayout, -> paint!
# 增刪改也會動到樹 ( 例如拿掉一張圖, 那個葉子就不再指向任何 panel )
bd.on \panel, ->
  node \out .textContent = dash.dump bd.def.layout.root
  paint!

# 篩選面板要開放哪些欄位、怎麼稱呼, 也是 update-panel 改的.
#
# filterbar 每次 render 都會比對這幾個值, 改了就重建控制項 - 並且把不再開放的
# 那些欄位發出的篩選一起清掉 ( 不清的話, 那個篩選還在起作用, 但畫面上沒有任何
# 地方看得到它, 使用者也就取消不了 )
cols =
  * only: <[month region category channel]>
    labels: {month: "月份", region: "地區", category: "書系", channel: "通路"}
  * only: <[month region]>
    labels: {month: "月份", region: "縣市"}
few = false

node \cols .addEventListener \click, ->
  few := !few
  bd.update-panel \header, cols[if few => 1 else 0]
  node \cols .textContent = "篩選欄位: #{cols[if few => 1 else 0].only.length} 欄"
  node \msg .textContent = if few =>
    "只開放月份與地區 · 收起來的那幾欄, 它們發出的篩選也一起清掉了"
  else "四個欄位都開放 · 地區的顯示名稱也換回來了"

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
  paint!
