# @plotdb/dash - 儀表板組裝框架 ( 概念驗證 )
#
# 拆成三塊, 彼此不互相依賴:
#
#  - dash.driver  資料源 -> rows ( plain object 陣列 )
#  - dash.query   rows -> chart raw ( 宣告式聚合 ). 同時產出 meta 供自動 binding 用
#  - dash.board   依 def 產生版面、掛 panel/chart、協調 crossfilter
#
# def 本身是純資料 ( 除了少數可選的 function hook ), 所以可以被存下來、傳輸、
# 或由另一個 UI 產生 - 這是「儀表板可組裝」的前提.

dash = {}


# ------------------------------------------------------------------ driver
#
# driver 只負責把資料變成 rows. 之後的欄位運算全部交給 query,
# 因此換資料源 ( json / csv / api ) 不影響 def 的其他部分.

dash.drivers = drivers = {}

drivers.inline = (opt = {}) ->
  load: -> Promise.resolve(opt.rows or [])

drivers.json = (opt = {}) ->
  load: -> ld$.fetch opt.url, {method: \GET}, {type: \json}

drivers.csv = (opt = {}) ->
  load: ->
    ld$.fetch opt.url, {method: \GET}, {type: \text}
      .then (text) -> Papa.parse(text.trim!, {header: true, skipEmptyLines: true}).data

# def.data 可以是 {type, ...} 設定、已建好的 driver 物件, 或直接一個 function
dash.driver = (o = {}) ->
  if typeof(o) == \function => return load: -> Promise.resolve(o!)
  if o.load => return o
  if !(f = drivers[o.type or \json]) => throw new Error("[dash] unknown data driver: #{o.type}")
  d = f o
  if !o.parse => return d
  # parse 讓 driver 產出的原始結構 ( 例如 {head, body} ) 轉成 rows
  load: -> d.load!then -> o.parse it


# ------------------------------------------------------------------- query
#
# 一個 panel 的「資料對應」= 從共用 rows 聚合出這張圖要的 raw.
# 用宣告式描述 ( groupby / series / measures / sort / limit ),
# 需要更複雜的算法時 groupby 與 measure.op 都可以直接給 function.

dash.agg = agg =
  count: (rows) -> rows.length
  sum: (rows, f) -> rows.reduce ((a, b) -> a + (+b[f] or 0)), 0
  avg: (rows, f) -> if !rows.length => 0 else agg.sum(rows, f) / rows.length
  max: (rows, f) -> rows.reduce ((a, b) -> Math.max(a, +b[f] or 0)), -Infinity
  min: (rows, f) -> rows.reduce ((a, b) -> Math.min(a, +b[f] or 0)), Infinity
  distinct: (rows, f) -> (new Set(rows.map -> it[f])).size

# 具名運算的註冊表.
#
# op 與 groupby 本來可以直接塞 function. 寫在程式裡的 def 這樣最短, 但 def 就不能
# 純 JSON 化 - 而「存進資料庫再讀回來執行」等於把儲存的內容當程式跑. 所以 def 要能
# 儲存、傳輸、或由另一個 UI 產生的場合, 一律用具名運算: 名字存在 def 裡, 實作註冊
# 在程式裡.
#
#   dash.op \unit-price, (rows, field, m) -> ...
#   measures: [{name: "單價", op: \unit-price, field: \amount}]
#
# 額外參數寫在 measure 自己身上 ( 第三個參數拿得到整個 measure ), 不另外包一層 -
# measure 本來就帶著 field 了, 參數再包一層只是多一個位置要記.
dash.ops = ops = {}
dash.op = (name, fn) -> ops[name] = fn; dash.op

# 比值. 「平均單價」是 sum(amount) / sum(qty), 不是 avg(unit_price) -
# 後者是每一筆單價的平均, 賣一本的小單會跟賣五百本的大單一樣重
ops.ratio = (rows, field, m = {}) ->
  d = agg.sum rows, (m.by or m.denominator)
  if d => (agg.sum rows, field) / d else 0

# 分組用的具名 key function, 跟 ops 同一個道理.
#
#   groupby: "region"                                   欄位名
#   groupby: {op: \bucket, field: \amount, size: 1000}   具名運算
dash.keys = keys = {}
dash.key = (name, fn) -> keys[name] = fn; dash.key

# 數值分組. 這是「不能用欄位名表達」的典型 - 它算的是 row 上沒有的那一欄.
# 組是半開區間 [v, v + size), 跟 board 的 range filter 用 closed: left 對得上
keys.bucket = (r, o = {}) ->
  size = (+o.size) or 1
  v = +r[o.field]
  if !isFinite(v) => null else Math.floor(v / size) * size

# op 算完之後的常數換算. 「元 -> 萬元」不值得為它各寫一個 op, 而這是最常見的需求之一.
# scale 乘、div 除 - 兩個都留著是因為同一件事寫哪一個清楚得看情況
# ( 萬元是 div: 10000, 百分比是 scale: 100, 反過來寫都要想一下 )
post-op = (v, m) ->
  if m.scale? => v *= m.scale
  if m.div? => v /= m.div
  if !m.round? => return v
  if m.round == true => return Math.round v
  p = Math.pow 10, m.round
  (Math.round (v * p)) / p

# 名字 -> 實作. 認不出來就報錯: 原本是 agg[op] 查不到就 undefined, 要等到呼叫
# 的時候才炸 "f is not a function", 看不出是哪個 op 拼錯
op-of = (op) ->
  if typeof(op) == \function => return op
  if !op => return agg.sum
  if agg[op] => return agg[op]
  if ops[op] => return ops[op]
  throw new Error("[dash] unknown measure op: #op")

# 回傳 {raw, meta}. meta.key 是 group 欄位名, meta.fields 是各數值欄位,
# 兩者一起餵給 dash.binding 就能自動接上圖表的 dimension.
dash.query = (rows = [], def = {}) ->
  keyname = def.key or \key
  # 原始列模式: 不聚合, 直接把 rows 當 raw.
  # 自己分組的圖 ( 例如 bar 打開 cfg.bin 的直方圖 ) 要的是原始列 - 聚合過就沒有東西
  # 可以分組了. 這種 raw 沒有 meta.fields, 所以 binding 要在 panel 裡明寫.
  if def.raw => return {raw: rows, meta: {key: null, fields: [], raw: true}}
  measures = def.measures or [{name: \value, op: \count}]
  keyfn = if typeof(def.groupby) == \function => def.groupby
  else if def.groupby and typeof(def.groupby) == \object => do ->
    o = def.groupby
    if !(f = keys[o.op]) => throw new Error("[dash] unknown groupby op: #{o.op}")
    (r) -> f r, o
  else if def.groupby => (r) -> r[def.groupby]
  else -> \all

  groups = {}
  order = []
  rows.map (r) ->
    k = keyfn r
    if !groups[k] =>
      groups[k] = []
      order.push k
    groups[k].push r

  run = (sub, m) ->
    f = op-of m.op
    post-op (f sub, m.field, m), m

  # series: 把某欄位的每個值展開成獨立數值欄 ( 多線折線圖、堆疊長條圖用 )
  fields = if def.series =>
    m = measures.0
    vs = Array.from(new Set(rows.map -> it[def.series]))
    vs.map (v) -> {name: v, unit: m.unit, _series: v, _measure: m}
  else measures.map (m) -> {name: m.name or m.field, unit: m.unit, _measure: m}

  raw = order.map (k) ->
    sub = groups[k]
    ret = {} <<< (def.const or {})   # 常數欄: 例如給 number 圖的單位
    ret[keyname] = k
    fields.map (f) ->
      ret[f.name] = if f._series?
        run (sub.filter (r) -> r[def.series] == f._series), f._measure
      else run sub, f._measure
    ret._count = sub.length
    ret

  if def.sort =>
    by-key = def.sort.by or keyname
    dir = if def.sort.dir == \desc => -1 else 1
    raw.sort (a, b) ->
      [x, y] = [a[by-key], b[by-key]]
      dir * (if x > y => 1 else if x < y => -1 else 0)
  if def.limit => raw.splice def.limit, raw.length

  {raw, meta: {key: keyname, fields: fields.map (f) -> f{name, unit}}}

# 對比查詢: 同一個 query 跑兩次, 一次全體、一次套用篩選, 得到 key 相同的兩份結果.
# 圖表拿同一份 binding 解析兩份資料, 就能在同一個色塊裡畫出「多少被選中」.
#
#  - base   分母. 完全沒有篩選的 rows
#  - subset 分子. 套用所有 filter ( 含這張圖自己發出的 ) 的 rows
dash.compare = (opt = {}) ->
  def = opt.def or {}
  b = dash.query opt.base, def
  p = dash.query opt.subset, def
  {raw: b.raw, meta: b.meta, subset: p.raw}

# 依圖表自己宣告的 dimension 自動產生 binding:
#  - 數值型 ( type 含 R ) 的維度接上 measures
#  - 其餘接上 group key
# 圖表若有特殊需求 ( 例如 number 的 unit ), 在 def 裡寫 binding 覆蓋即可.
dash.binding = (dimension = {}, meta = {}) ->
  # 非數值維度只綁 priority 最小的那一個. 圖表常有第二個分類維度 ( 例如 pie 的 category )
  # 是選用的分組, 一併綁上去會多出一整層視覺 - 要用就在 def 裡明寫 binding.
  cats = [k for k, d of dimension when !/R/.exec(d.type or '')]
  cats.sort (a, b) -> ((dimension[a].priority or 0) - (dimension[b].priority or 0))
  ret = {}
  for k, d of dimension
    if /R/.exec(d.type or '') =>
      v = meta.fields.map (f) -> {key: f.name, name: f.name, unit: f.unit}
      ret[k] = if d.multiple => v else v.0
    else if k == cats.0 => ret[k] = {key: meta.key}
  ret


# rows -> 欄位清單.
#
# 全域篩選面板問的問題跟 query 不一樣: query 是「這張圖要什麼」, 這裡是「這份資料
# 有哪些欄位、各是什麼型別、值域多大」- 所以另外一支, 而不是從 query 的 meta 拿
# ( meta 講的是聚合之後的那幾欄 ).
#
# 型別只分三種, 因為篩選控制項只有三種: 類別用多選, 數值與日期用區間.
# 判斷規則刻意簡單 - 數值就是數值, 長得像日期的字串就是日期, 其餘都是類別.
# 不用「相異值少於幾個就當類別」那種啟發式: 它會隨資料變來變去, 同一個欄位這個月
# 是區間、下個月多了幾筆就變多選. 要改就用 opt.types 明寫.
#
# 回傳 [{key, type, count, values, domain}]
#
#  - cat   values 是相異值, 依出現次數由多到少 ( 多選的清單照這個順序排 )
#  - date  values 是排序過的相異值, domain 是 [最小, 最大]. 零補的日期字串
#          ( 2024/01 ) 直接比字串就是對的順序, 所以 range filter 不必轉型
#  - num   domain 是 [最小, 最大]
date-like = /^\d{4}[-\/.]\d{1,2}([-\/.]\d{1,2})?$/

numeric = (v) ->
  if typeof(v) == \number => isFinite v
  else typeof(v) == \string and !!v.trim! and isFinite(+v)

dash.fields = (rows = [], opt = {}) ->
  if !rows.length => return []
  types = opt.types or {}
  skip = opt.skip or []
  # 欄位不一定每一列都有, 所以掃過全部的列, 不是只看第一列
  ks = []
  seen = {}
  for r in rows => for k of r => if !seen[k]
    seen[k] = true
    ks.push k
  ks = ks.filter (k) -> k.substring(0, 1) != '_' and !(k in skip)
  ks.map (k) ->
    vals = []
    counts = {}
    num = true
    for r in rows
      v = r[k]
      # 空值不參與型別判斷也不進清單: 一欄裡有幾個空的不代表它不是數值欄
      if !v? or v == '' => continue
      if num and !numeric(v) => num = false
      if !counts[v]?
        counts[v] = 0
        vals.push v
      counts[v]++
    type = types[k] or
      if num => \num
      else if vals.length and vals.every((v) -> date-like.exec "#v") => \date
      else \cat
    ret = {key: k, type: type, count: vals.length}
    if type == \num =>
      ns = vals.map (v) -> +v
      ret.domain = [(ns.reduce (a, b) -> a <? b), (ns.reduce (a, b) -> a >? b)]
    else if type == \date =>
      vs = vals.slice!sort!
      ret <<< {values: vs, domain: [vs.0, vs[vs.length - 1]]}
    else
      ret.values = vals.slice!sort (a, b) -> counts[b] - counts[a]
    ret


# ------------------------------------------------------------------- board
#
# board 負責版面與 panel 的生命週期, 以及 crossfilter 的協調.
# 它不認識任何一種圖 - 圖都是 chart block, 由 panel block 掛載.

board = dash.board = (opt = {}) ->
  @root = if typeof(opt.root) == \string => document.querySelector(opt.root) else opt.root
  @mgr = opt.manager
  @def = opt.def or {}
  @panel-block = opt.panel or {name: \panel, version: \0.0.1}
  @panels = (@def.panels or []).map (d, i) -> {} <<< d <<< {id: d.id or "panel-#i"}
  @rows = []
  @filters = {}   # panel id -> {field, values}
  @evt-handler = {}
  @

board.prototype = Object.create(Object.prototype) <<<
  constructor: board

  on: (n, cb) -> (if Array.isArray(n) => n else [n]).map (n) ~> @evt-handler.[][n].push cb
  fire: (n, ...v) -> for cb in (@evt-handler[n] or []) => cb.apply @, v

  init: ->
    Promise.resolve!
      .then ~> dash.driver(@def.data).load!
      .then (rows) ~>
        @rows = rows or []
        @layout!
        # 每個 panel 可以自己指定要用哪個 panel block - 同一份 def、同一套 crossfilter,
        # 外觀與呈現方式由 block 決定 ( 例如 KPI 用不掛圖表的卡片 ).
        # 沒指定就用 board 的預設; 同一個 block 只取一次.
        cache = {}
        Promise.all @panels.map (p) ~>
          b = p.panel or @panel-block
          k = JSON.stringify b
          (cache[k] or= @mgr.get b).then (bc) -> p._bc = bc
      .then ~>
        Promise.all @panels.map (p) ~>
          node = document.createElement \div
          node.classList.add \dash-cell
          node.style <<< @_area p
          @root.appendChild node
          p._bc.create {data: {def: p, board: @}}
            .then (bi) -> bi.attach {root: node} .then -> bi.interface!
            .then (itf) -> p.itf = itf
      .then ~> @fire \init
      .then ~> @

  # 版面: 目前只有 grid. 之後要加 flow / free 版面時, def.layout.type 是分支點.
  layout: ->
    l = @def.layout or {}
    @root.classList.add \dash
    @root.style <<<
      gridTemplateColumns: (l.col or <[1fr]>).join(' ')
      gridTemplateRows: (l.row or <[1fr]>).join(' ')
      gap: l.gap or \.8em

  _area: (p) ->
    a = p.area or {}
    ret = {}
    if a.col => ret.gridColumn = "#{a.col.0} / span #{a.col.1 or 1}"
    if a.row => ret.gridRow = "#{a.row.0} / span #{a.row.1 or 1}"
    ret

  # -------------------------------------------------------- crossfilter
  #
  # 一個 panel 可以同時對好幾個欄位發 filter: 圖表的 filter 事件本來就是以
  # binding 維度為 key ( 例如 pie 的 name、多 series line 的 value ), 而不同維度
  # 對應到不同的資料欄位 - name 對應 groupby, measure 維度對應 series.
  #
  # 所以 board 的 filter 以「panel + 維度」為單位存, 每一筆記著 owner 是誰.
  # 慣例的「算某個 panel 時不套用它自己發出的 filter」就是依 owner 排除,
  # 一個 panel 有幾筆就排除幾筆.

  _key: (id, dim = \name) -> "#id:#dim"

  # f = null 才是「清掉篩選」; f.values 是空陣列表示「一項都沒選」, 這是有效的篩選
  # ( 結果為空集合 ). 兩者混為一談的話 legend 的「全不選」按下去會彈回全選
  set-filter: (id, f, dim = \name) ->
    k = @_key id, dim
    if !f or !f.values or !f.field => delete @filters[k]
    else @filters[k] = {owner: id, dim, type: \index} <<< f
    @fire \filter, @filters
    @render!

  # 點選型的 toggle: 取消掉最後一項就是不篩選了 ( 跟 legend 的全不選不同 )
  toggle-filter: (id, field, value, dim = \name) ->
    vs = ((@filter-of id, dim) or {}).values or []
    vs = if value in vs => vs.filter (-> it != value) else vs ++ [value]
    @set-filter id, (if vs.length => {field, values: vs} else null), dim

  clear-filter: ->
    @filters = {}
    @fire \filter, @filters
    @render!

  # 清掉某個 panel 發出的全部 filter ( 一個 panel 可能有好幾個維度 )
  clear-panel: (id) ->
    for k, v of @filters => if v.owner == id => delete @filters[k]
    @fire \filter, @filters
    @render!

  # dim 省略時回傳這個 panel 的第一筆 ( 給只有單一維度的呼叫端 / UI 用 )
  filter-of: (id, dim) ->
    if dim? => return @filters[@_key id, dim]
    [v for k, v of @filters when v.owner == id].0

  filters-of: (id) -> [v for k, v of @filters when v.owner == id]

  # 全域篩選: filter 上帶 scope: \global 就是. 它不屬於任何一張圖, 所以
  #
  #  - 每一張圖都要套用 ( 這一條不必特別做: 排除規則是比對 owner, 而全域篩選的
  #    owner 不是任何 panel 的 id )
  #  - compare 的分母也要套. 這一條要特別做, 見 data-for
  globals: -> [v for k, v of @filters when v.scope == \global]

  # 排除全域篩選之後, 還有沒有篩選.
  #
  # 「佔全體 x%」這種對比在只有全域篩選的時候沒有意義: 分母已經跟著全域篩選走了,
  # 分子分母是同一份, 永遠 100% - 看起來像壞掉. 所以要分得出「有人在篩某幾項」
  # 跟「整份資料的範圍被縮小了」
  locals: -> [v for k, v of @filters when v.scope != \global]

  # filter 的兩種型別:
  #  - index ( 預設 ) 值列表. 點選 / 類別軸的框選都是這種
  #  - range  區間 [lo, hi], 兩端都含. 連續軸 ( 時間、數值 ) 的框選要用這種 -
  #           相異值可能上千個, 列舉不完, 而且新資料一進來清單就失效
  _match: (f, r) ->
    v = r[f.field]
    if f.type == \range =>
      [lo, hi] = f.values
      # closed: left = [lo, hi), right = (lo, hi], both / 沒給 = [lo, hi] ( 原本的行為 ).
      # 分組的區間是半開的 - 兩端都含的話, 相鄰的組會在邊界重複算到
      c = f.closed or \both
      lo-ok = if !(lo?) => true else if c == \right => v > lo else v >= lo
      hi-ok = if !(hi?) => true else if c == \left => v < hi else v <= hi
      lo-ok and hi-ok
    else ~f.values.indexOf(v)

  _apply: (fs) ->
    if !fs.length => return @rows
    @rows.filter (r) ~> fs.every (f) ~> @_match f, r

  # 給 panel 用: 已套用其他 panel filter 的 rows
  rows-for: (panel) -> @_apply [v for k, v of @filters when v.owner != panel.id]

  # 套用全部 filter, 包含 panel 自己發出的那些
  rows-all: -> @_apply [v for k, v of @filters]

  # 給 panel 用: 這個 panel 要畫的 raw / meta
  #
  # compare 模式的分母是「完全沒有篩選」的 rows, 分子預設是「所有 filter 都套用」的 rows -
  # 這樣每一根都能看到總量中被選中的比例, 不管篩選是哪張圖發出的.
  # 一般模式仍照 crossfilter 慣例, 不套用自己發出的 filter.
  #
  # compare: {excludeSelf: true} 則是分子也不套用自己發出的 filter. 圖自己已經把選取
  # 畫出來的時候要用這個 - 例如 line 的 brush: 框外的月份若連分子都被歸零, 整條線會
  # 掉到 0, 反而看不到自己在框什麼. 分母仍是未篩選的全體, 所以 series 一樣不會消失.
  data-for: (panel) ->
    d = panel.data or {}
    if !d.compare => return dash.query (@rows-for panel), d
    sub = if (d.compare or {}).exclude-self => @rows-for panel else @rows-all!
    # 分母是「只套用全域篩選」的 rows, 不是整份資料.
    #
    # 沒有全域篩選時兩者相同, 所以這跟原本的行為一致. 有的時候差很多: 使用者選了
    # 2024 年, 他預期「佔全體 37.8%」的全體是 2024 年的全體, 不是全部年份 -
    # 否則選完之後每個百分比都莫名其妙地小, 看起來像沒反應. partial 模式的色塊
    # 也一樣, 被選中的那一段會縮成一條線
    dash.compare {base: (@_apply @globals!), subset: sub, def: d}


  render: -> @panels.map (p) -> if p.itf => p.itf.render!

  destroy: ->
    @panels.map (p) -> if p.itf and p.itf.destroy => p.itf.destroy!
    @root.innerHTML = ''
    @panels = []

  # 換一批資料, def 與篩選都不動. 給宿主用: 資料源重跑 ( 換時間範圍、flow 重算 )
  # 之後要讓畫面跟上, 但不該重建版面.
  #
  # 刻意不清 filters: 使用者篩選中資料更新把篩選彈掉, 他會以為自己按錯了.
  # 篩的值在新資料裡不存在時結果就是空集合 - 這是對的, 篩選本來就是「要這幾項」,
  # 而且清掉的話畫面會從「空的」變成「全部」, 更難發現資料換了.
  set-rows: (rows) ->
    @rows = rows or []
    @fire \rows, @rows
    @render!
    @

  # 換一份 def 重來. 給編輯器用: 改完 def 直接看結果.
  reload: (def) ->
    @destroy!
    @def = def
    @filters = {}
    @panels = (def.panels or []).map (d, i) -> {} <<< d <<< {id: d.id or "panel-#i"}
    @init!


# -------------------------------------------------------------------- spec
#
# def 有哪些東西要定義 - 寫成資料, 讓 UI ( 目前是頁面上的 def 檢視器 ) 直接長出來,
# 不必再維護一份說明. 之後要接 @plotdb/konfig 生表單, 這裡就是來源.
#
#  - path     這一組對應到 def 的哪個位置; 沒有 path 的組是純說明
#  - fields   {key, type, desc}. type 用人看得懂的寫法, 不是程式型別

dash.spec = [
  * key: \data
    title: "資料源"
    path: <[data]>
    desc: "把資料源變成 rows ( plain object 陣列 ). driver 不做欄位運算, 所以換資料源不會動到其他部分."
    fields: [
      * key: \type, type: "json | csv | inline", desc: "driver 名稱. 也可以不給這段, 直接放 {load} 物件或 function"
      * key: \url, type: "string", desc: "json / csv driver 的資料位置"
      * key: \rows, type: "array", desc: "inline driver 的資料本體"
      * key: \parse, type: "(raw) -> rows", desc: "原始結構不是 rows 時的轉換, 例如 {head, body} 展開成物件陣列"
    ]

  * key: \layout
    title: "版面"
    path: <[layout]>
    desc: "目前只有 grid 一種. 每個 panel 用 area 指定自己在格線上的位置."
    fields: [
      * key: \col, type: "[css track]", desc: "grid-template-columns, 例如 <[1fr 1fr 1fr 1fr]>"
      * key: \row, type: "[css track]", desc: "grid-template-rows, 例如 <[6.5em 1fr 1fr]>"
      * key: \gap, type: "css length", desc: "格子間距, 預設 .8em"
    ]

  * key: \panel
    title: "圖表清單"
    path: <[panels]>
    desc: "一個 panel 一張圖. 位置、用哪張圖、資料怎麼對應、樣式, 四件事寫在一起."
    fields: [
      * key: \id, type: "string", desc: "panel 識別. 沒給就用 panel-<序號>. crossfilter 以此為 key"
      * key: \title, type: "string", desc: "標題列文字"
      * key: \subtitle, type: "string", desc: "標題右側的小字, 例如操作提示"
      * key: \area, type: "{col: [起點, 跨幅], row: [起點, 跨幅]}", desc: "在 layout 格線上的位置"
      * key: \chart, type: "{name, version} | {code}", desc: "要用哪個 @plotdb/chart block. {name, version} 是 registry 上已發佈的; {code} 是內嵌定義, 給不在 registry 上的自訂圖表用 ( code 裡的 dependency 仍由 manager 的 registry 解析 )"
      * key: \data, type: "query def", desc: "資料對應. 見「資料對應」那組"
      * key: \binding, type: "chart binding", desc: "不給就自動推導. 見「資料綁定」那組"
      * key: \cfg, type: "chart config", desc: "圖的樣式, 原封不動交給 chart.config. lib 層的共用設定在 cfg.common 之下 ( 例如 common.subset.mode )"
      * key: \crossfilter, type: "false | {field}", desc: "見「連動篩選」那組"
    ]

  * key: \query
    title: "資料對應"
    desc: "panel.data. 描述「從共用 rows 聚合出這張圖要的 raw」. 產出的 meta 會拿去自動推導 binding."
    sample: """
    data:
      groupby: "region"              # 欄位名, 或具名運算, 或 (row) -> key
      series: "category"             # 選用. 把該欄位的每個值展開成獨立數值欄
      measures: [
        * name: "銷售額", field: "amount", op: "sum", unit: "元"
        # 換算: 元 -> 萬元. 不必為單位換算各寫一個 op
        * name: "銷售額", field: "amount", op: "sum", div: 10000, unit: "萬元"
        # 比值: sum(amount) / sum(qty). 不是 avg(單價) - 那會讓小單跟大單一樣重
        * name: "單價", field: "amount", op: "ratio", by: "qty", unit: "元 / 冊"
      ]
      sort: {by: "銷售額", dir: "desc"}
      limit: 10
      const: {unit: "萬元"}           # 常數欄, 例如給 number 圖的單位

    # 數值分組: 連續欄位要先切成組才能當分類用
    data: {groupby: {op: "bucket", field: "amount", size: 1000}}
    """
    fields: [
      * key: \groupby, type: "string | {op, ...} | (row) -> key", desc: "分組依據. 不給就全部併成一組 ( number 圖用 ). 字串是欄位名; {op: 名稱} 是 dash.keys 裡的具名運算 ( 內建 bucket: 數值分組, 額外參數寫在同一個物件裡 ); function 彈性最大但 def 就不能純 JSON 化"
      * key: \series, type: "string", desc: "把該欄位的每個值展開成一欄, 給多線折線圖 / 堆疊長條圖用"
      * key: \measures, type: "[{name, field, op, unit, by, scale, div, round}]", desc: "op: sum / count / avg / max / min / distinct / ratio ( sum(field) / sum(by) ), 或 dash.ops 裡的具名運算, 或直接給 (rows, field, measure) -> value ( 但 def 就不能純 JSON 化 ). scale / div / round 是算完之後的常數換算, 例如 div: 10000 把元換成萬元"
      * key: \sort, type: "{by, dir}", desc: "by 是 measure 名稱或 key; dir 是 asc / desc"
      * key: \limit, type: "number", desc: "取前幾筆"
      * key: \const, type: "object", desc: "每一列都補上的常數欄"
      * key: \compare, type: "true | {excludeSelf}", desc: "同一個 query 跑兩次, 額外送出篩選後的子集 ( chart 的 subset ). 配 cfg.common.subset.mode 的 partial / shrink 使用; 分母是未篩選的全體, 分子套用所有 filter. compare: {excludeSelf: true} 則分子不套用自己發出的 filter - 圖自己已經把選取畫出來時要用這個 ( 例如 line 的 brush, 否則框外會整個掉到 0 )"
      * key: \key, type: "string", desc: "產生的分組欄位名稱, 預設 key"
      * key: \raw, type: "true", desc: "原始列模式: 不聚合, 直接把 rows 當 raw. 自己分組的圖 ( 例如 bar 的直方圖 ) 要用這個. 沒有 meta.fields, 所以 binding 要明寫, 例如 {value: {key: \"amount\"}}"
    ]

  * key: \binding
    title: "資料綁定"
    desc: "不寫 binding 時自動推導: 圖表自己宣告的 dimension 中, 數值型 ( type 含 R ) 接 measures, 其餘接分組欄位. 需要精確控制時才在 panel 裡寫 binding 覆蓋整份."
    sample: """
    # number 圖需要把單位綁到特定欄位, 屬於要覆蓋的情況
    binding: {value: {key: "銷售額"}, unit: {key: "unit"}}

    # bar 圖 ( dimension: size 為 R 且 multiple, name 為 NCO ) 自動推成
    binding: {size: [{key: "銷售額", name: "銷售額", unit: "元"}], name: {key: "key"}}
    """
    fields: []

  * key: \crossfilter
    title: "連動篩選"
    desc: "一個 panel 可以同時篩好幾個欄位: 圖表發 filter 時是以 binding 維度為 key, 不同維度對應不同欄位 - 綁到分組欄位的那一維對應 groupby ( 例如 pie 的 name、line 的 order ), 綁到 measures 的那一維對應 series ( 例如多 series line 的 value ). 預設自動推導, 通常不必宣告. 算某個 panel 的資料時不套用它自己發出的 filter ( 有幾維就排除幾維 ), 否則被選中的那張圖會只剩下自己選的那一項. 篩選後要怎麼呈現則是圖的事, 由 cfg.common.subset.mode 決定."
    sample: """
    crossfilter: false               # 這張圖不對外發 filter
    crossfilter: {field: "region"}   # 舊寫法: 指定資料點那一維的欄位

    # 逐維度指定. 沒寫到的維度仍照預設推導
    crossfilter: {name: "region"}                  # pie / bar / map
    crossfilter: {order: "month", value: "category"}   # 多 series 的 line

    # filter 有兩種型別, 由發出的圖決定, def 不必寫:
    #   index  值列表 ( 點選、類別軸的框選 )
    #   range  區間 [lo, hi] ( 連續軸的框選, 例如 line 的 brush ).
    #          可以帶 closed: left = [lo, hi), right = (lo, hi], 沒給就兩端都含.
    #          直方圖的組是半開區間, 兩端都含的話相鄰的組會在邊界重複算到

    # 被篩掉的資料怎麼表現 ( 需要 data.compare 才有子集可比 )
    cfg: common: subset:
      mode: "dim"                    # 整個色塊降透明 ( 預設 )
      mode: "partial"                # 同一個色塊裡切出被選中的那段
      mode: "shrink"                 # 直接拿子集當值畫, 泡泡變小 / 消失

    # legend 的勾選也是一種篩選, 同一套字彙但預設不同 ( 向下相容 )
    cfg: legend:
      subset: {mode: "shrink"}       # 關掉就整個不見 ( 預設 ); dim = 留著位置只降透明
      crossfilter: true              # legend 的勾選同時對外發 filter.
                                     # pie 的 legend 與 wedge 是同一維, 共用同一份狀態;
                                     # line 的 legend 是 value 維, 篩的是 series 欄位.
                                     # 項目是手挑欄位而非資料值時就不該打開
    """
    fields: [
      * key: \field, type: "string", desc: "這張圖發出的 filter 對應到 rows 的哪個欄位"
    ]
]


# ------------------------------------------------------------------ dump
#
# def 裡可以放 function ( measures.op / groupby ), 所以不能用 JSON 來回.
# 這裡輸出的是 JS 物件字面量, 讀回來用 dash.load. 只給編輯器用.

quote-key = (k) -> if /^[A-Za-z_$][A-Za-z0-9_$]*$/.exec(k) => k else JSON.stringify(k)

dash.dump = dump = (o, ind = '') ->
  if o == null or o == undefined => return "#o"
  if typeof(o) == \function => return o.toString!.split('\n').join("\n#ind")
  if Array.isArray o =>
    if !o.length => return '[]'
    # 全是純量的短陣列排成一行, 否則 [1, 1] 這種座標會佔掉六行
    if o.length <= 8 and o.every((v) -> !v or typeof(v) != \object) =>
      return "[#{o.map(-> dump it).join ', '}]"
    items = o.map (v) -> "#ind  #{dump v, "#ind  "}"
    return "[\n#{items.join ',\n'}\n#ind]"
  if typeof(o) == \object =>
    ks = Object.keys(o).filter -> it.substring(0,1) != '_'
    if !ks.length => return '{}'
    items = ks.map (k) -> "#ind  #{quote-key k}: #{dump o[k], "#ind  "}"
    return "{\n#{items.join ',\n'}\n#ind}"
  JSON.stringify o

dash.load = (text) -> (new Function("return (#text)"))!


if window? => window.dash = dash
else if module? => module.exports = dash
