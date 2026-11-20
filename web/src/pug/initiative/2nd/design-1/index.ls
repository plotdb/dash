# @plotdb/dash 第二版
#
# 跟 1st 比, 框架、資料、crossfilter 的語意一模一樣. 換掉的只有兩件事:
#
#  - panel block: 圖表卡片換了一套外觀, KPI 那四格換成不掛圖表的 kpi block
#    ( board 現在允許每個 panel 指定自己的 block, 見 dash.ls 的 init )
#  - 一層主題: 介面狀態只用亮度不用色相, 色相全部留給資料.
#    這一層現在是 theme-of(mode, panel) - 同一套規則各給 light / dark 一組值
#
# 顏色的分派是有規則的, 不是挑好看的:
#  - 書系 ( category ) 是四個並列的類別 -> 四個色相, 給 line 的 series 用.
#    percent-list 是依「占比大小」上色的 ( 顏色是位置的函數, 不是項目的函數 ),
#    沒辦法跟 line 共用同一組對應, 所以給它同一個色族的漸層 - 看得出是同一個維度,
#    但不假裝每一條都對得上
#  - 通路 ( channel ) 是另一個維度 -> 自己的一組琥珀色階, 不跟書系搶色相
#  - 地區 ( region ) 只有一個量 -> bar 單色, 地圖用同一個色相的漸層, 兩張圖看起來是一組

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/2nd/design-1/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 一個模式 = 一組色票. 兩個模式刻意用同一個結構寫, key 完全一樣 - 這一點很要緊:
# chart.config 是「併進去」的, 新主題沒提到的 key 會留著上一個模式的值,
# 兩邊不對稱就會換不乾淨 ( 例如只在深色底才設的 brush, 切到淺色會留著一塊白框 ).
#
# 色相的分派規則兩個模式都一樣, 只是在淺色底上整體壓暗一級 - 同一個藍在白底上
# 要更深才讀得到.
dark =
  ink: \#8b98a8                      # 軸線文字
  txt: \#c3ced4                      # 圖裡的一般文字 ( pie / percent-list 的項目 )
  grid: 'rgba(255,255,255,.13)'
  # partial 模式下「沒被選中」的那一段, 顏色是該色的灰階往背景靠.
  # 背景預設是白色, 深色底不設這個就會冒出一塊亮灰
  face: \#18202a
  outline: 'rgba(255,255,255,.16)'   # 地圖的縣市邊界
  ref: \#ffd08a                      # 參考線
  # 刷選框. d3 的慣例是淺底白邊, 深色底上會變成一塊發亮的方塊.
  # 這本來得在頁面層寫 CSS 蓋掉圖表 block 自己的 DOM, 現在是設定
  brush:
    fill: \#fff
    fillOpacity: 0.06
    stroke: 'rgba(255,255,255,.28)'
    strokeWidth: 1
    handleFill: 'rgba(255,255,255,.22)'
  # 哪個維度用哪一組色, 由 panel 的 hue 指定 ( 見 def ). def 只說「這張圖畫的是
  # 哪個維度」, 顏色是這一層的事 - 所以兩個模式共用同一份 def
  hue:
    cat: colors: <[#7f9cf5 #5ddba4 #f0a3b4 #c08ef0]>      # 書系 ( 類別 )
    'cat-ramp': colors: <[#7f9cf5 #c08ef0]>               # 書系 ( 依占比的漸層 )
    chn: colors: <[#ffd08a #f0a04b #b4702a]>              # 通路
    geo: colors: <[#4fc3b0]>                              # 地區 ( 單色 )
    # 低端不能太接近卡片底色 - 沒有資料的縣市拿的就是低端色, 太暗整座島會消失,
    # 剩下幾塊亮的浮在黑底上, 看不出那是地圖
    'geo-ramp': colors: <[#223139 #5fe0c8]>               # 地區 ( 漸層 )

light =
  ink: \#6c7a8c
  txt: \#3b4757
  grid: 'rgba(20,30,45,.14)'
  face: \#ffffff                      # 卡片是純白的, 未選的那一段往白色退
  outline: 'rgba(20,30,45,.18)'
  ref: \#b4772a
  brush:
    fill: \#1b2a3a
    fillOpacity: 0.07
    stroke: 'rgba(20,30,45,.32)'
    strokeWidth: 1
    handleFill: 'rgba(20,30,45,.26)'
  hue:
    cat: colors: <[#3f5fd6 #0f9d79 #d0608a #8a4fd1]>
    'cat-ramp': colors: <[#3f5fd6 #8a4fd1]>
    chn: colors: <[#e0a53f #c0742a #8a4f17]>
    geo: colors: <[#0f8f86]>
    # 淺色底的低端是反過來的: 不能太深, 沒有資料的縣市該看起來像沒上色
    'geo-ramp': colors: <[#eaeff4 #0c7d75]>

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

# 所有圖表共用的那一層. 圖表的 config 結構是一致的 ( 都從 chart.utils.config.preset
# 長出來 ), 所以同一份東西可以套到每一張圖上, 不必每個 panel 各抄一次.
# 沒有這一層的話, 換主題就是去每個 panel 裡改五行, 換模式是改十行.
#
# 收第二個參數 panel 的理由: 有幾項設定逐 panel 不同, 但值跟著模式走
# ( 用哪一組色票、地圖邊界、參考線顏色 ). 它們寫在 def 的 cfg 裡就得為每個模式
# 各寫一份 def, 所以一併收在這裡.
#
# xaxis / yaxis 對 pie / percent-list / map 是多餘的 key, 圖表會忽略 -
# 寧可多給, 也不要為了少給而把主題拆成好幾份
theme-of = (mode, p) ->
  c = if mode == \light => light else dark
  axis =
    caption: {show: false}
    label: {format: '.2~s', color: c.ink, font: {size: \.78em}}
    tick: {color: c.grid, inner: 4}
    baseline: {color: c.grid}
  th =
    color: c.txt
    margin: 2
    xaxis: axis
    # 格線只開 y 軸. x 軸在長條圖是類別軸, 一個類別一條會變雜訊 -
    # 該開哪一軸是看軸的性質, 不是看圖的種類, 所以核心預設關閉、逐軸打開.
    # 有格線就不必再留刻度與基線, 兩者講的是同一件事
    yaxis: {} <<< axis <<<
      grid: {show: true}
      tick: {color: c.grid, inner: 0}
      baseline: {show: false}
    common:
      subset: {background: c.face}
      brush: c.brush
  if p.hue => th.palette = c.hue[p.hue]
  if p.id == \map => th.border = {color: c.outline, width: 0.7}
  if p.id == \trend => th.common.annotation = {color: c.ref}
  th

# ------------------------------------------------------------------ def
def =
  data: {type: \json, url: "/assets/data/sales.json"}

  layout:
    # 12 欄, 讓 KPI ( 3 欄 ) 與圖 ( 3~8 欄 ) 共用同一組格線
    col: <[1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr]>
    row: <[6.4em 1.15fr 1fr]>
    gap: \14px

  panels: [
    # ---- KPI. 用 kpi block, 所以沒有 chart; compare 讓它知道「全體是多少」
    * id: \gross, title: "總銷售額", unit: "萬元", accent: 'var(--n2-acc-1)'
      panel: kpi-block, area: {col: [1, 3], row: [1, 1]}
      data:
        measures: [{name: "銷售額", op: (rows) -> dash.agg.sum(rows, \amount) / 10000}]
        compare: true

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: 'var(--n2-acc-2)'
      panel: kpi-block, area: {col: [4, 3], row: [1, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    # 平均值型的指標: 「佔全體 65%」沒有意義, 要看的是比全體高還是低
    * id: \price, title: "平均單價", unit: "元 / 冊", accent: 'var(--n2-acc-3)', note: \delta
      panel: kpi-block, area: {col: [7, 3], row: [1, 1]}
      data:
        measures: [
          * name: "單價"
            op: (rows) ->
              [a, q] = [dash.agg.sum(rows, \amount), dash.agg.sum(rows, \qty)]
              if q => a / q else 0
        ]
        compare: true

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: 'var(--n2-acc-4)'
      panel: kpi-block, area: {col: [10, 3], row: [1, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 圖. 這些沿用預設的 panel block
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · 點 legend 篩書系, 橫向拖曳框選月份區間 · 虛線為單書系月均"
      area: {col: [1, 6], row: [2, 1]}, hue: \cat
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
        dot: {show: true, size: 2.5}
        brush: {enabled: true}
        # direct: 書系的名字直接寫在線的末端, 不另外排一疊清單.
        # 四條線在右端會收斂, 擠在一起的會被推開並畫引線 ( 核心的 utils.labels )
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, mode: \direct}
        common:
          subset: {mode: \shrink}
          # 參考線是資料座標的註記, 要圖表實作 space scope ( line 有 ).
          # 有一條基準線之後, 「這個月這個書系算好還是算差」才看得出來 -
          # 四條線互相比只看得出相對高低, 看不出跟常態比如何
          annotation:
            reference: [{axis: \y, value: 784324}]
            # 說明文字用視圖座標的註記, 不掛在線的末端 - 參考線的標籤目前沒有避讓,
            # 貼在右緣會壓到資料線. 左下角這一塊本來就是空的
            notes: [{x: 0.012, y: 0.94, text: "虛線 — 單書系月均 78 萬", align: \start, size: \.72em}]

    * id: \channel, title: "通路占比", subtitle: "可點選 · 通路自己一組色階"
      area: {col: [7, 3], row: [2, 1]}, hue: \chn
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.74, padding: 0.015}
        common: {subset: {mode: \partial}}
        # actions: false - 只有三項, 「全選 / 全不選」兩顆比項目本身還佔位置.
        # 項目照樣可以點 ( 以前關掉按鈕就等於關掉選取, 現在拆開了 )
        legend: {crossfilter: true, subset: {mode: \dim}, position: \bottom, actions: false}

    * id: \region, title: "各地區銷售額", subtitle: "可框選 · 單色, 排序本身就是訊息"
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

    # 刻意不排序: 項目順序跟著資料裡第一次出現的順序走, 與上面 line 的 series
    # 順序一致, 同一個書系才會是同一個顏色
    * id: \category, title: "書系占比", subtitle: "可點選 · 依占比深淺上色"
      area: {col: [6, 4], row: [3, 1]}, hue: 'cat-ramp'
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        common: {subset: {mode: \partial}}

    # 跨兩列: 臺灣本島加離島的範圍又高又窄, 放在扁格子裡會縮成右上角一小塊
    * id: \map, title: "地區分布", subtitle: "可點選 · 深淺是銷售額, 與左下長條圖同一個維度"
      area: {col: [10, 3], row: [2, 2]}, hue: 'geo-ramp'
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        legend: {enabled: false}
  ]

# ---------------------------------------------------------------- runtime
view = null
ui = {group: \data, sync: true, msg: ''}

bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

# 主題套到每個有圖的 panel 上 ( panel 自己寫的贏 ), 並且在換模式時重算、重畫.
# 見 ../mode.ls - 六個設計共用同一份機制, 各自只提供一個 theme-of
dmode.theme bd, theme-of
dmode.on -> if view => view.render!

bd.on \filter, -> if view => view.render!

group-of = (key) -> dash.spec.filter(-> it.key == key).0
value-of = (g) -> if g.path => g.path.reduce ((a, k) -> if a? => a[k] else void), def
text-of = (g) -> if g.path => dash.dump(value-of g) else (g.sample or '')

switch-group = (key) ->
  ui <<< {group: key, sync: true, msg: ''}
  view.render!

apply = ->
  g = group-of ui.group
  if !g.path => return
  try
    v = dash.load view.get('editor').value
  catch e
    ui.msg = "解析失敗: #{e.message}"
    return view.render \msg
  def[g.path.0] = v
  ui.msg = "套用中…"
  view.render \msg
  # 編輯器送回來的是一份新的 panels, 上面沒有主題 - 重建之前先套一次,
  # 不然會先閃一下圖表的預設顏色
  dmode.retheme def.panels
  bd.reload def
    .then -> ui.msg = "已套用"
    .catch (e) -> ui.msg = "重建失敗: #{e.message}"
    .then -> view.render!

# 圖表的 legend ( 全選 / 全不選 ) 走 @plotdb/block 的全域 i18n module, 預設 en
block.i18n.change-language \zh-TW

mgr.init!
  .then -> bd.init!
  .then ->
    view := new ldview do
      root: document.body
      action:
        click:
          clear: -> bd.clear-filter!
          mode: -> dmode.toggle!
          "open-def": -> ui <<< {open: true, sync: true, msg: ''}; view.render!
          "close-def": -> ui.open = false; view.render!
          apply: -> apply!
          reset: -> ui <<< {sync: true, msg: ''}; view.render!
      text:
        hint: ->
          g = group-of ui.group
          if g.path => "對應 def.#{g.path.join '.'} - 這是 JS 物件字面量, 可以放 function"
          else "這一組沒有獨立位置, 寫在每個 panel 裡. 以下是寫法範例"
        msg: -> ui.msg
      handler:
        mode: ({node}) -> node.textContent = "#{dmode.icon!} #{dmode.label!}"
        defv: ({node}) -> node.classList.toggle \show, !!ui.open
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        # 每個 chip 是一筆 ( panel + 維度 ) 的篩選, 點 ✕ 只收掉那一筆.
        # 一個 chip 一個 function: 在迴圈裡寫 closure 的話, LiveScript 會把它提成
        # 一個具名函式, 每個 chip 關到的都是迴圈結束後的那一筆
        chips: ({node}) ->
          mk = (f) ->
            v = if f.type == \range => f.values.join ' – '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            chip = document.createElement \span
            chip.className = \n2-chip
            chip.innerHTML = """<span class="k"></span><span class="v"></span><span class="x">✕</span>"""
            chip.querySelector('.k').textContent = f.field
            chip.querySelector('.v').textContent = v
            chip.querySelector('.x').addEventListener \click, -> bd.set-filter f.owner, null, f.dim
            chip
          node.innerHTML = ''
          for id, f of bd.filters => node.appendChild mk f
        desc: ({node}) -> node.textContent = (group-of ui.group).desc or ''
        editor: ({node}) ->
          if !ui.sync => return
          ui.sync = false
          node.value = text-of group-of(ui.group)
          node.readOnly = !(group-of ui.group).path
        apply: ({node}) -> node.style.display = if (group-of ui.group).path => '' else \none
        reset: ({node}) -> node.style.display = if (group-of ui.group).path => '' else \none
        group:
          list: -> dash.spec
          key: -> it.key
          view:
            action: click: "@": ({ctx}) -> switch-group ctx.key
            text:
              label: ({ctx}) -> ctx.title
              path: ({ctx}) -> if ctx.path => "def.#{ctx.path.join '.'}" else "說明"
            handler: "@": ({node, ctx}) -> node.classList.toggle \active, (ctx.key == ui.group)
        field:
          list: -> (group-of ui.group).fields or []
          key: -> it.key
          view: text:
            key: ({ctx}) -> ctx.key
            type: ({ctx}) -> ctx.type
            fdesc: ({ctx}) -> ctx.desc
    window.bd = bd
    window.def = def
  .catch (e) -> console.error e
