# @plotdb/dash 概念示範
#
# 這一頁的重點不是圖, 而是「一份 def 就是一個儀表板」:
# 資料源、版面、每張圖的資料對應與樣式、crossfilter 動態, 全部寫在 def 裡.

<-(-> it.apply {}) _

# block 名稱 -> URL. chart 走 /assets/chart, dash 自己的 panel 走 /initiative/variation/vanilla/block.
# 沿用 makechart 的統一規則 ( server/module/makechart/registry ):
# block 與 lib 都走 /assets/lib/<name>/<version|main>/, 差別只在預設檔名.
# 本專案自己的 block 用 ns: local, 放在頁面旁邊.
mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url    # block 依賴也可能直接給 URL
    if type == \block =>
      if ns == \local => return "/initiative/variation/vanilla/block/#name/#{version or '0.0.1'}/#{path or 'index.html'}"
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

palette = colors: <[#0b7fab #6ab7d4 #f2a154 #b6c454 #9b8bbd #dd6e6e]>
axis = {caption: {show: false}, label: {format: '.2~s'}}

# ---------------------------------------------------------------- light / dark
#
# 這一版的深色模式是整組裡最便宜的一個, 因為它幾乎沒有自己的樣式:
# 版面與卡片的顏色全走 dash.css 的 custom property ( 見 index.pug ),
# 所以 CSS 那邊換幾個變數就好.
#
# 圖表的顏色不吃 CSS, 還是得給一份, 但也只有四件事非換不可:
#
#  1. 文字與軸線的顏色
#  2. 格線 / 基線的顏色
#  3. common.subset.background - 「沒被選中的那一段」要往哪個顏色退.
#     不設的話程式裡的背景是常數白, 深色底上會冒出一塊亮灰
#  4. 地圖的漸層與縣市邊界 - 低端貼著底色, 所以底色換了它就得換
#
# 上面那六個色的色票兩個模式共用: 它們是中間調的, 白底與深底都還讀得到.
# 真正非換不可的永遠是「貼著底色」的那幾個設定 - 這一點在七個設計裡都一樣.
light =
  fg: \#55585c
  line: \#d8dadd
  face: \#fff                          # 卡片底 ( 未選的那一段往這裡退 )
  geo: colors: <[#e8f2f6 #0b7fab]>
  # 沒資料的縣市底色接近白, 沒有邊線就整個看不見
  border: {color: \#c9ccd4, width: 0.8}

dark =
  fg: \#9aa0a8
  line: \#343a41
  face: \#1d2024
  # 低端換成比卡片亮一點的灰: 貼著底色的規則沒變, 只是底色變深了
  geo: colors: <[#2b3138 #4db6dd]>
  border: {color: \#454c55, width: 0.8}

theme-of = (mode, p) ->
  c = if mode == \dark => dark else light
  ax = {} <<< axis <<< {label: {format: '.2~s', color: c.fg}, tick: {color: c.line}, baseline: {color: c.line}}
  th =
    color: c.fg
    xaxis: ax
    yaxis: ax
    common: subset: {background: c.face}
  if p.id == \map => th <<< {palette: c.geo, border: c.border}
  th

# ------------------------------------------------------------------ def
def =
  # 1. 資料源: 換成 csv / api 只要換這一段, 其他部分不動
  data: {type: \json, url: "/assets/data/sales.json"}

  # 2. 版面
  layout:
    col: <[1fr 1fr 1fr 1fr]>
    # 第一條是篩選列. 絕對高度而不是 fr - 它的內容高度是固定的,
    # 給 fr 會讓它跟著圖表一起長高
    row: <[2.6em 6.5em 1fr 1fr]>
    gap: \.8em

  # 3. 每張圖: 位置 / 圖種 / 資料對應 / 樣式 / crossfilter
  panels: [
    # 全域篩選列. 它不畫資料, 所以既沒有 chart 也沒有 data - 它要的是
    # 「這份 rows 有哪些欄位」, 由 dash.fields 回答.
    # 發出去的 filter 帶 scope: \global, 所以每一張圖都會被它篩到, 而且
    # compare 的分母也跟著走 ( 這一版沒有 compare, 但 desk 那些有 )
    * id: \header, panel: {ns: \local, name: \filterbar, version: \0.0.1}
      area: {col: [1, 4], row: [1, 1]}
      only: <[month region category channel amount]>
      labels:
        month: "月份"
        region: "地區"
        category: "書系"
        channel: "通路"
        amount: "單筆銷售額"

    * id: \gross, title: "總銷售額", area: {col: [1, 1], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "萬元"}
        measures: [{name: "銷售額", field: \amount, op: \sum, div: 10000, round: true}]
      binding: {value: {key: "銷售額"}, unit: {key: \unit}}

    * id: \qty, title: "總銷售冊數", area: {col: [2, 1], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "冊"}
        measures: [{name: "冊數", field: \qty, op: \sum}]
      binding: {value: {key: "冊數"}, unit: {key: \unit}}

    * id: \price, title: "平均單價", area: {col: [3, 1], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "元 / 冊"}
        # ratio 是 sum(amount) / sum(qty), 不是 avg(單價) - 後者每一筆的權重一樣,
        # 賣一本的小單會跟賣五百本的大單一樣重
        measures: [{name: "單價", field: \amount, op: \ratio, by: \qty, round: true}]
      binding: {value: {key: "單價"}, unit: {key: \unit}}

    * id: \coverage, title: "涵蓋地區", area: {col: [4, 1], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "縣市"}
        measures: [{name: "地區數", field: \region, op: \distinct}]
      binding: {value: {key: "地區數"}, unit: {key: \unit}}

    # series 把 category 展開成多條線; binding 由圖表的 dimension 自動推導
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · legend 篩書系, 橫向框選篩月份區間", area: {col: [1, 2], row: [3, 1]}
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        # series 從未篩選的全體取, 別人篩選時不會整條消失;
        # excludeSelf: 自己的 brush 已經把選取畫出來了, 分子再套一次會讓框外掉到 0
        compare: {excludeSelf: true}
      cfg:
        palette: palette
        mode: \line
        line: \curve
        xaxis: axis
        yaxis: axis
        # shrink: 線直接落到子集的值. 多條線時比 partial ( 灰線 + 彩線 ) 乾淨得多,
        # 而且 compare 已經讓 series 不會消失, 「總量多少」旁邊的 bar 已經在講了
        common: {subset: {mode: \shrink}}
        brush: {enabled: true}   # x 軸是月份, 連續的 - 框選發出的是 range
        # legend 的項目是 series ( 書系 ) 的值, 所以可以對外篩 category -
        # 跟這個 panel 的 groupby ( month ) 是不同欄位, board 分兩筆存
        legend: {crossfilter: true, subset: {mode: \dim}}

    # bar 的 brush 會發 filter 事件, board 收到後轉成 region 的篩選
    * id: \region, title: "各地區銷售額", subtitle: "可框選", area: {col: [3, 2], row: [3, 1]}
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true       # 另外送出篩選後的子集
      cfg:
        palette: palette
        legend: {enabled: false}
        common: {subset: {mode: \partial}}   # 同一根裡切出被選中的那段
        xaxis: axis
        yaxis: axis

    * id: \channel, title: "通路占比", subtitle: "可點選", area: {col: [1, 1], row: [4, 1]}
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true       # 另外送出篩選後的子集
      cfg:
        palette: palette
        donut: {percent: 0.72}
        common: {subset: {mode: \partial}}   # wedge 沿半徑切出被選中的那段
        # legend 與 wedge 共用同一份選取, 關掉的項目留著位置只是灰掉
        legend: {crossfilter: true, subset: {mode: \dim}}

    * id: \category, title: "書系排行", subtitle: "可點選", area: {col: [2, 2], row: [4, 1]}
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true       # 占比以未篩選的全體為分母, 別人篩選時項目不會消失或重排
      cfg:
        palette: palette
        common: {subset: {mode: \partial}}   # 每一條沿寬度切出被選中的那段

    * id: \map, title: "地區分布", subtitle: "可點選", area: {col: [4, 1], row: [4, 1]}
      chart: {name: "@makechart/taiwan-map"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      cfg:
        # 色票與邊線交給主題那一層 ( 見上面的 theme-of ): 它們貼著底色,
        # 所以是這一頁唯一跟著 light / dark 換的圖
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

# 主題套到每個有圖的 panel 上, 並且在換模式時重算、重畫 ( 見 ../mode.ls )
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
  dmode.retheme def.panels
  bd.reload def
    .then -> ui.msg = "已套用"
    .catch (e) -> ui.msg = "重建失敗: #{e.message}"
    .then -> view.render!

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
        state: ->
          n = Object.keys(bd.filters).length
          if n => "篩選中 ( #n )" else "尚未篩選"
        hint: ->
          g = group-of ui.group
          if g.path => "對應 def.#{g.path.join '.'} - 這是 JS 物件字面量, 可以放 function"
          else "這一組沒有獨立位置, 寫在每個 panel 裡. 以下是寫法範例"
        msg: -> ui.msg
      handler:
        mode: ({node}) -> node.textContent = "#{dmode.icon!} #{dmode.label!}"
        defv: ({node}) -> node.classList.toggle \show, !!ui.open
        chips: ({node}) ->
          node.innerHTML = ''
          for id, f of bd.filters
            span = document.createElement \span
            span.className = \chip
            # values 是空陣列 = 一項都沒選 ( legend 的「全不選」), 跟沒有篩選不一樣
            v = if f.type == \range => f.values.join ' ~ '
            else if f.values.length => f.values.join ', '
            else '( 無 )'
            span.textContent = "#{f.field}: #v"
            node.appendChild span
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
