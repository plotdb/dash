# design-2「報告」- 同一份 def, 換一套外觀.
#
# design-1 問的是「這些資料怎麼互相篩」, 所以密集、深色、滿版不捲動;
# 這一版問的是「這些資料印出來給人讀是什麼樣子」, 所以:
#
#  - 版面是一份文件: 內容限寬置中, 整頁可以捲, 高度由內容決定而不是由視窗決定
#  - 沒有卡片. 分隔靠一條細線與留白 - 印刷品上沒有陰影與圓角
#  - 襯線字. 圖表的文字 ( svg text ) 吃 CSS 繼承, 所以軸標籤跟標題是同一套字
#  - def 不是抽屜, 是文件最後的「附錄」. 它本來就是這份文件的一部分
#
# def 本身跟 design-1 是同一份東西, 只有 layout 的行高、cfg 的顏色與字級不同.

<-(-> it.apply {}) _

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if ns == \local => return "/initiative/2nd/design-2/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

# ---------------------------------------------------------------- 主題
#
# 色票是印刷的邏輯: 低彩度、每個色相都壓暗, 四色套印那種. 規則跟 design-1 一樣 -
# 色相留給資料, 介面狀態只用深淺 - 只是這裡的「深淺」是在紙上往下壓, 不是往上提亮
paper = \#fbfaf7
ink = \#6b665e              # 軸線文字
line = 'rgba(40,34,24,.16)' # 細線
grid = 'rgba(40,34,24,.10)'

cat = colors: <[#2f4b7c #b4553f #7d8a4f #a9772b]>   # 書系 ( 類別 )
cat-ramp = colors: <[#ccd3e0 #2f4b7c]>              # 書系 ( 依占比的漸層 )
chn = colors: <[#dba894 #b4553f #70301f]>           # 通路
geo = colors: <[#2f4b7c]>                           # 地區 ( 單色 )
# 低端貼著紙色: 沒有資料的縣市就該看起來像沒印到東西.
# ( design-1 的限制剛好相反 - 深色底上低端太暗, 整座島會消失 )
geo-ramp = colors: <[#ece9e2 #2f4b7c]>              # 地區 ( 漸層 )

kpi-block = {ns: \local, name: \kpi, version: \0.0.1}

axis-theme =
  caption: {show: false}
  label: {format: '.2~s', color: ink, font: {size: \.76em}}
  tick: {color: grid, inner: 4}
  baseline: {color: line}

theme =
  color: ink
  margin: 2
  xaxis: axis-theme
  # 跟 design-1 一樣只開 y 軸的格線, 但這裡畫成虛線 -
  # 紙上的實線太搶, 格線的工作是讓人對得到高度, 不是被看見
  yaxis: {} <<< axis-theme <<<
    grid: {show: true, color: \#282218, opacity: 0.16, dash: '2 3'}
    tick: {color: grid, inner: 0}
    baseline: {show: false}
  common:
    # 未選的那一段往紙色退, 不是往白色退 - 預設的白在米色紙上會浮出來
    subset: {background: paper}
    brush:
      fill: \#2f4b7c
      fillOpacity: 0.07
      stroke: 'rgba(47,75,124,.45)'
      strokeWidth: 1
      handleFill: 'rgba(47,75,124,.3)'

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
    # 行高是絕對值, 不是 fr. 文件的高度由內容決定, 不是把視窗填滿 -
    # 這一行就是「滿版儀表板」與「一份報告」的分界
    row: <[7.6em 19em 24em 15.5em]>
    gap: \26px

  panels: [
    # ---- 開頭四個數字. 報告的摘要段
    * id: \gross, title: "總銷售額", unit: "萬元", accent: \#2f4b7c
      panel: kpi-block, area: {col: [1, 3], row: [1, 1]}
      data:
        measures: [{name: "銷售額", op: (rows) -> dash.agg.sum(rows, \amount) / 10000}]
        compare: true

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: \#7d8a4f
      panel: kpi-block, area: {col: [4, 3], row: [1, 1]}
      data:
        measures: [{name: "冊數", field: \qty, op: \sum}]
        compare: true

    * id: \price, title: "平均單價", unit: "元 / 冊", accent: \#a9772b, note: \delta
      panel: kpi-block, area: {col: [7, 3], row: [1, 1]}
      data:
        measures: [
          * name: "單價"
            op: (rows) ->
              [a, q] = [dash.agg.sum(rows, \amount), dash.agg.sum(rows, \qty)]
              if q => a / q else 0
        ]
        compare: true

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: \#b4553f
      panel: kpi-block, area: {col: [10, 3], row: [1, 1]}
      data:
        measures: [{name: "地區數", field: \region, op: \distinct}]
        compare: true

    # ---- 主圖占滿整個欄寬. 報告只有一張主圖, 其他都是佐證
    * id: \trend, title: "一、月銷售趨勢", subtitle: "依書系 · 點書系名篩選, 橫向拖曳框選月份區間 · 虛線為單書系月均"
      area: {col: [1, 12], row: [2, 1]}
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
        line: {mode: \curve, strokeWidth: 1.6}
        dot: {show: true, size: 2.2}
        brush: {enabled: true}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, mode: \direct}
        common:
          subset: {mode: \shrink}
          annotation:
            color: \#a9772b
            reference: [{axis: \y, value: 784324}]
            notes: [{x: 0.008, y: 0.95, text: "虛線 — 單書系月均 78 萬", align: \start, size: \.7em}]

    * id: \region, title: "二、各地區銷售額", subtitle: "可框選 · 單色, 排序本身就是訊息"
      area: {col: [1, 8], row: [3, 1]}
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg:
        palette: geo
        legend: {enabled: false}
        common: {subset: {mode: \partial}}

    # 窄而高的格子: 臺灣本島加離島的範圍本來就是這個比例
    * id: \map, title: "三、地區分布", subtitle: "深淺是銷售額"
      area: {col: [9, 4], row: [3, 1]}
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        palette: geo-ramp
        legend: {enabled: false}
        border: {color: 'rgba(40,34,24,.2)', width: 0.6}

    * id: \channel, title: "四、通路占比", subtitle: "可點選 · 通路自己一組色階"
      area: {col: [1, 6], row: [4, 1]}
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        palette: chn
        color: \#5f5a52
        donut: {percent: 0.72, padding: 0.012}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}, position: \right, actions: false}

    * id: \category, title: "五、書系占比", subtitle: "可點選 · 依占比深淺上色"
      area: {col: [7, 6], row: [4, 1]}
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        palette: cat-ramp
        color: \#5f5a52
        common: {subset: {mode: \partial}}
  ]

def.panels.map (p) -> if p.chart => p.cfg = deep theme, (p.cfg or {})

# ---------------------------------------------------------------- runtime
view = null
ui = {group: \data, sync: true, msg: ''}

bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  panel: {ns: \local, name: \panel, version: \0.0.1}
  def: def

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
  bd.reload def
    .then -> ui.msg = "已套用"
    .catch (e) -> ui.msg = "重建失敗: #{e.message}"
    .then -> view.render!

block.i18n.change-language \zh-TW

mgr.init!
  .then -> bd.init!
  .then ->
    view := new ldview do
      root: document.body
      action:
        click:
          clear: -> bd.clear-filter!
          apply: -> apply!
          reset: -> ui <<< {sync: true, msg: ''}; view.render!
      text:
        hint: ->
          g = group-of ui.group
          if g.path => "對應 def.#{g.path.join '.'} - 這是 JS 物件字面量, 可以放 function"
          else "這一組沒有獨立位置, 寫在每個 panel 裡. 以下是寫法範例"
        msg: -> ui.msg
      handler:
        clear: ({node}) -> node.classList.toggle \off, !Object.keys(bd.filters).length
        chips: ({node}) ->
          node.innerHTML = ''
          for id, f of bd.filters
            v = if f.type == \range => f.values.join ' – '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            chip = document.createElement \span
            chip.className = \rp-chip
            chip.innerHTML = """<span class="k"></span><span class="v"></span><span class="x">✕</span>"""
            chip.querySelector('.k').textContent = f.field
            chip.querySelector('.v').textContent = v
            chip.querySelector('.x').addEventListener \click, (-> bd.set-filter f.owner, null, f.dim)
            node.appendChild chip
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
            text: label: ({ctx}) -> ctx.title
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
