# 主題: 同一份 def, 換一個長相
#
# variation 那七個設計各自把主題寫在頁面裡 ( theme-of(mode, panel) 是個函式 ).
# 這一頁示範的是收進套件之後的版本: 主題是一份 JSON, 跟 def 一樣可以存、可以
# 傳、可以由另一個 UI 產生.
#
# def 裡沒有任何一個顏色. 每張圖只說自己「畫的是哪個維度」( hue ) 與「是什麼
# 角色」( role ), 顏色與 block 由主題那一層給 - 這就是同一份 def 能換長相的條件.

<-(-> it.apply {}) _

# 主題指到的 block 是套件裡的路徑 ( block/panel/desk/index.html ). 套用的專案
# 不必管這件事 - fedep 會把套件放到 /assets/lib/@plotdb/dash/main/ 底下, 預設的
# registry 就指得到.
#
# 這一頁是 dash 自己的示範頁, 套件沒有被 link 進 assets/lib, 所以把那幾個路徑
# 轉回它們的來源 ( 示範頁底下的那一份 ). build 出來的跟這裡服務的是同一個東西,
# 見 tool/pack.js
dash-block = (path) ->
  m = /^block\/([^\/]+)\/(?:([^\/]+)\/)?index\.html$/.exec path
  if !m => return null
  "/initiative/variation/#{m.2 or 'vanilla'}/block/#{m.1}/0.0.1/index.html"

mgr = new block.manager do
  registry: ({url, ns, name, version, path, type}) ->
    if url => return url
    if type == \block =>
      if name == '@plotdb/dash' and (u = dash-block path) => return u
      return "/assets/lib/#name/#{version or 'main'}/#{path or 'index.html'}"
    if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
    "/assets/lib/#name/#{version or 'main'}/#{path or (if type == \css => 'index.min.css' else 'index.min.js')}"

def =
  data: {type: \json, url: "/assets/data/sales.json"}

  # 主題帶了一組建議的版面 ( 欄數、列高、間距 ), layout: true 才套.
  # 這裡故意不寫 def.layout - 換主題就連版面一起換, 看得出差別
  theme: {name: \vanilla, mode: \auto, layout: true}

  panels: [
    * id: \header, role: \filterbar
      area: {col: [1, 4], row: [1, 1]}
      only: <[month region category channel amount]>
      labels: {month: "月份", region: "地區", category: "書系", channel: "通路", amount: "單筆銷售額"}

    # KPI 那四格用的是 @makechart/number, 兩個主題底下都一樣 - 這裡刻意不寫
    # role: \kpi.
    #
    # desk 的主題其實有帶一個 kpi block ( blocks.kpi ), 它不看 chart, 自己畫一張
    # 卡片, 還會寫「佔全體 x%」. 但那張卡片讀的是 compare 的子集, 所以 def 得開
    # compare: true - 一開, raw 就變成未篩選的全體, 而 vanilla 沒有 kpi block,
    # 退回 panel block 之後 @makechart/number 畫的是 raw: 畫面上就是「篩了半天
    # 數字不動」.
    #
    # 這是 role 的一條界線: role 可以讓某個主題換一個 block, 但換上去的 block
    # 如果讀的是 def 的另一個部分, 那份 def 就只對那個主題成立了. 要讓一份 def
    # 在兩個主題底下都讀得對, 要嘛每個主題都備齊那個角色的 block, 要嘛就別用它
    * id: \gross, title: "總銷售額", unit: "萬元", accent: 'var(--dk-acc-1)'
      area: {col: [1, 3], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "萬元"}
        measures: [{name: "銷售額", field: \amount, op: \sum, div: 10000, round: true}]
      binding: {value: {key: "銷售額"}, unit: {key: \unit}}

    * id: \qty, title: "總銷售冊數", unit: "冊", accent: 'var(--dk-acc-2)'
      area: {col: [4, 3], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "冊"}
        measures: [{name: "冊數", field: \qty, op: \sum}]
      binding: {value: {key: "冊數"}, unit: {key: \unit}}

    * id: \price, title: "平均單價", unit: "元 / 冊", accent: 'var(--dk-acc-3)', note: \delta
      area: {col: [7, 3], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "元 / 冊"}
        measures: [{name: "單價", field: \amount, op: \ratio, by: \qty, round: true}]
      binding: {value: {key: "單價"}, unit: {key: \unit}}

    * id: \coverage, title: "涵蓋地區", unit: "縣市", accent: 'var(--dk-acc-4)'
      area: {col: [10, 3], row: [2, 1]}
      chart: {name: "@makechart/number"}
      data:
        const: {unit: "縣市"}
        measures: [{name: "地區數", field: \region, op: \distinct}]
      binding: {value: {key: "地區數"}, unit: {key: \unit}}

    # hue: 這張圖畫的是「書系」這個維度. 書系在這個主題下是什麼顏色, 主題決定.
    # role: ref 是給「有參考線的那一張」用的 - desk 會給它一個線的顏色,
    # vanilla 沒有這一條就什麼都不做
    * id: \trend, title: "月銷售趨勢", subtitle: "依書系 · legend 篩書系, 橫向框選篩月份區間"
      hue: \cat, role: \ref, area: {col: [1, 8], row: [3, 1]}
      chart: {name: "@makechart/line"}
      data:
        groupby: \month
        series: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: \key, dir: \asc}
        compare: {excludeSelf: true}
      cfg:
        mode: \line
        line: \curve
        common: {subset: {mode: \shrink}}
        brush: {enabled: true}
        legend: {crossfilter: true, subset: {mode: \dim}}

    * id: \channel, title: "通路占比", subtitle: "可點選"
      hue: \chn, area: {col: [9, 4], row: [3, 1]}
      chart: {name: "@makechart/pie"}
      data:
        groupby: \channel
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        compare: true
      cfg:
        donut: {percent: 0.72}
        common: {subset: {mode: \partial}}
        legend: {crossfilter: true, subset: {mode: \dim}}

    * id: \region, title: "各地區銷售額", subtitle: "可框選"
      hue: \geo, area: {col: [1, 5], row: [4, 1]}
      chart: {name: "@makechart/bar"}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg: {legend: {enabled: false}, common: {subset: {mode: \partial}}}

    * id: \category, title: "書系排行", subtitle: "可點選"
      hue: \cat-ramp, area: {col: [6, 3], row: [4, 1]}
      chart: {name: "@makechart/percent-list"}
      data:
        groupby: \category
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
        sort: {by: "銷售額", dir: \desc}
        compare: true
      cfg: {common: {subset: {mode: \partial}}}

    * id: \map, title: "地區分布", subtitle: "可點選 · 深淺是銷售額, 灰色是沒有資料"
      hue: \geo-ramp, area: {col: [9, 4], row: [4, 1]}
      chart: {name: "@makechart/twmapadv", data: {level: \town}}
      data:
        groupby: \region
        measures: [{name: "銷售額", field: \amount, op: \sum, unit: "元"}]
      binding:
        town: {key: \key}
        value: {key: "銷售額", name: "銷售額", unit: "元"}
      cfg: {legend: {enabled: true}}
  ]

# ---------------------------------------------------------------- runtime
bd = new dash.board do
  root: document.querySelector('[ld=board]')
  manager: mgr
  # 套件根目錄的位置 ( 主題在它底下的 theme/*.json ). 預設是
  # /assets/lib/@plotdb/dash/main/, 同樣因為這一頁是 dash 自己的示範頁才要給 -
  # dev server 服務的就是 build 的來源那一份
  theme-base: '/'
  def: def

window.bd = bd

node = (n) -> document.querySelector "[ld=#n]"

# 使用者覆寫的 token. 它跟主題名字、模式一樣是 def.theme 的一部分,
# 所以存下來就留著 - 「我選了 desk, 但主色要換成紅的」是一份設定, 不是一次操作
custom = {}

say = (t) -> node \msg .textContent = t

apply = (patch) ->
  t = {} <<< (bd.def.theme or {}) <<< patch
  bd.set-theme t .then ->
    paint!
    say "主題 #{bd.theme.name} · #{bd.theme.mode} · 篩選 #{Object.keys(bd.filters).length} 項"

# 自訂面板直接照 schema 長出來: 主題說它開放哪幾個 token、各是什麼型別,
# 宿主就不必為每一個主題各寫一份表單
paint = ->
  wrap = node \tokens
  wrap.innerHTML = ''
  for f in (bd.theme.schema or [])
    wrap.appendChild row f

mk = (tag, cls, txt) ->
  n = document.createElement tag
  if cls => n.className = cls
  if txt? => n.textContent = txt
  n

row = (f) ->
  cur = bd.theme.tokens[f.key]
  wrap = mk \div, \tk
  wrap.appendChild mk \label, \tk-key, (f.label or f.key)
  if Array.isArray cur
    box = mk \div, \tk-colors
    cur.map (c, i) -> box.appendChild swatch f, cur, i
    wrap.appendChild box
  else
    wrap.appendChild one f, cur
  if f.desc => wrap.appendChild mk \div, \tk-desc, f.desc
  wrap

# 色票是一組顏色, 改其中一個就是整組一起送回去
swatch = (f, list, i) ->
  n = mk \input, \tk-color
  n.type = \color
  n.value = norm list[i]
  n.addEventListener \change, ->
    next = list.slice!
    next[i] = n.value
    custom[f.key] = next
    apply {tokens: custom}
  n

one = (f, cur) ->
  if f.type == \color
    n = mk \input, \tk-color
    n.type = \color
    n.value = norm cur
  else
    n = mk \input, \tk-text
    n.type = \text
    n.value = "#{cur or ''}"
  n.addEventListener \change, ->
    custom[f.key] = n.value
    apply {tokens: custom}
  n

# <input type=color> 只吃 #rrggbb. rgba(...) 這種給不了, 就讓它顯示黑的 -
# 使用者改了還是會送出正確的值
norm = (v) ->
  if typeof(v) != \string => return \#000000
  if /^#[0-9a-fA-F]{6}$/.exec(v) => return v
  if (m = /^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/.exec v) => return "##{m.1}#{m.1}#{m.2}#{m.2}#{m.3}#{m.3}"
  \#000000

mk-switch = (name) -> ->
  custom := {}
  apply {name: name, tokens: {}}

for name in <[vanilla desk]>
  b = node "t-#name"
  if b => b.addEventListener \click, mk-switch(name)

node \m-light .addEventListener \click, -> bd.set-mode \light .then -> (paint!; say "模式 light")
node \m-dark .addEventListener \click, -> bd.set-mode \dark .then -> (paint!; say "模式 dark")
node \m-auto .addEventListener \click, -> bd.set-mode \auto .then -> (paint!; say "模式 auto ( 跟著系統 )")

node \dump .addEventListener \click, ->
  node \out .textContent = dash.dump bd.def.theme

bd.on \filter, -> say "篩選 #{Object.keys(bd.filters).length} 項 ( 換主題不會清掉它 )"

bd.init!.then ->
  paint!
  say "主題 #{bd.theme.name} · #{bd.theme.mode}"
