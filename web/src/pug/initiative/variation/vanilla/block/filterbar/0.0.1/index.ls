# 全域篩選列.
#
# 跟其他 panel 的差別只有一個: 它不畫資料, 它問的是「這份 rows 有哪些欄位、各是
# 什麼型別、值域多大」, 答案來自 dash.fields.
#
# 發出去的 filter 帶 scope: \global, board 看到就知道每一張圖都要套用、compare 的
# 分母也要套. 型別就是既有的那三種 ( index / range / exclude ), 所以這一塊沒有自己
# 的篩選機制 - 它只是另一個 filter 的來源, 跟 bar 的 brush 同一個地位.
#
# 這一份在每個設計裡逐字相同: class 的字首從 pug 的 data-pfx 讀進來, 所以換外觀
# 只要換 pug 與 stylus - 跟 panel block 是同一個做法.

num-fmt = (v) ->
  if !isFinite(+v) => return '-'
  v = +v
  if Math.abs(v) >= 10000 => "#{Math.round(v / 1000)}k" else "#{Math.round v}"

mk = (tag, cls, txt) ->
  n = document.createElement tag
  if cls => n.className = cls
  if txt? => n.textContent = txt
  n

module.exports =
  pkg: {name: \filterbar, version: \0.0.1}

  init: ({root, data}) ->
    @root = root
    @def = data.def
    @board = board = data.board
    @id = @def.id or \header
    @labels = @def.labels or {}
    @bar = root.querySelector '[ld=fb]'
    @pfx = @bar.dataset.pfx or \dash
    @items = root.querySelector '[ld=items]'
    @clear = root.querySelector '[ld=clear]'
    @clear.addEventListener \click, ~> @board.clear-panel @id
    # 下拉面板一定會超出自己那一格, 而 .dash 預設是 overflow: hidden.
    # 需要的人自己打開 - 宿主不必知道這件事 ( 見 dash.styl )
    if board.root => board.root.classList.add \dash-overflow
    # 點別的地方就把展開的收起來. 用 capture: 圖表的 svg 會把 click 吃掉,
    # 冒泡階段等不到
    @away = (e) ~> if !@root.contains(e.target) => @shut!
    document.addEventListener \click, @away, true
    @refresh!
    # 欄位清單跟著資料走 - setRows 換一批資料之後, 欄位與值域都可能不一樣
    board.on \rows, ~> @refresh!

  destroy: -> document.removeEventListener \click, @away, true

  k: (n) -> "#{@pfx}-fb-#n"

  refresh: ->
    fs = dash.fields @board.rows, {skip: (@def.skip or [])}
    # def 可以指定要哪幾欄、照什麼順序 - 一份資料的欄位不一定都值得篩
    @fields = if !@def.only => fs
    else @def.only.map((k) -> [f for f in fs when f.key == k].0).filter -> it
    @build!

  build: ->
    @items.innerHTML = ''
    @ctrl = {}
    for f in @fields => @items.appendChild @one f
    @sync!

  shut: -> for k, c of (@ctrl or {}) => c.wrap.classList.remove \open

  # 一個欄位一個控制項. 每一欄獨立一次 method 呼叫, 不在 for 迴圈裡寫 inline
  # closure - LiveScript 會把迴圈裡的 closure 提成同一個具名 function,
  # 每一欄就會共用最後一次的 f
  one: (f) ->
    wrap = mk \div, @k \item
    btn = mk \button, @k \btn
    val = mk \span, @k \val
    btn.appendChild mk \span, (@k \key), (@labels[f.key] or f.key)
    btn.appendChild val
    pop = mk \div, @k \pop
    wrap.appendChild btn
    wrap.appendChild pop
    btn.addEventListener \click, (e) ~>
      e.stop-propagation!
      was = wrap.classList.contains \open
      @shut!
      if !was => wrap.classList.add \open
    c = @ctrl[f.key] = {wrap, val, f, mode: \index}
    if f.type == \cat => @fill-cat f, pop, c else @fill-range f, pop, c
    wrap

  # 類別: 多選. 兩種模式 - 只要這幾項 ( index ) / 除了這幾項以外 ( exclude )
  fill-cat: (f, pop, c) ->
    tabs = mk \div, @k \tabs
    c.tab = {}
    for m in <[index exclude]> => tabs.appendChild (c.tab[m] = @tab f, m)
    pop.appendChild tabs
    head = mk \div, @k \head
    c.all = mk \button, (@k \mini), '全選'
    c.non = mk \button, (@k \mini), '全不選'
    # 「全選」在排除模式是「一項都不排除」, 兩者都是「這一欄沒有篩選」
    c.all.addEventListener \click, ~> @emit f, null
    c.non.addEventListener \click, ~>
      @emit f, {type: @ctrl[f.key].mode, values: (if @ctrl[f.key].mode == \exclude => f.values.slice! else [])}
    head.appendChild c.all
    head.appendChild c.non
    pop.appendChild head
    list = mk \div, @k \list
    c.boxes = f.values.map (v) ~>
      r = @row f, v
      list.appendChild r.node
      r.box
    pop.appendChild list

  tab: (f, mode) ->
    b = mk \button, (@k \tab), (if mode == \exclude => '排除' else '只要')
    # 換模式就清掉這一欄的篩選: 同一份勾選在兩種模式下是相反的意思,
    # 直接換過去的話, 使用者會看到自己沒按過的篩選結果
    b.addEventListener \click, ~>
      c = @ctrl[f.key]
      if c.mode == mode => return
      c.mode = mode
      @emit f, null
      @sync!
    b

  row: (f, v) ->
    lb = mk \label, @k \row
    box = mk \input, @k \box
    box.type = \checkbox
    box.value = v
    box.addEventListener \change, ~> @emit-cat f
    lb.appendChild box
    lb.appendChild mk \span, null, "#v"
    {node: lb, box: box}

  emit-cat: (f) ->
    c = @ctrl[f.key]
    sel = [b.value for b in c.boxes when b.checked]
    if c.mode == \exclude =>
      # 一項都沒勾 = 什麼都不排除 = 沒有篩選
      return @emit f, (if !sel.length => null else {type: \exclude, values: sel})
    # 全選 = 沒有篩選 ( 不是列出所有值 ); 一項都沒選是有效的篩選, 結果為空集合.
    # 兩者混為一談的話「全不選」按下去會彈回全選, 那顆按鈕就沒意義了
    @emit f, (if sel.length == f.values.length => null else {type: \index, values: sel})

  # 數值與日期: 區間. 兩端都可以留空 = 那一端不限
  fill-range: (f, pop, c) ->
    box = mk \div, @k \range
    [c.lo, c.hi] = [(@end f, \0), (@end f, \1)]
    box.appendChild c.lo
    box.appendChild mk \span, (@k \dash), '–'
    box.appendChild c.hi
    pop.appendChild box
    hint = if f.type == \date => "#{f.domain.0} – #{f.domain.1}"
    else "#{num-fmt f.domain.0} – #{num-fmt f.domain.1}"
    pop.appendChild mk \div, (@k \hint), "全部範圍 #hint"

  end: (f, which) ->
    if f.type == \date =>
      n = mk \select, @k \sel
      n.appendChild mk \option, null, '不限'
      n.firstChild.value = ''
      for v in f.values
        o = mk \option, null, "#v"
        o.value = v
        n.appendChild o
    else
      n = mk \input, @k \num
      n.type = \number
      n.placeholder = if which == \0 => "#{f.domain.0}" else "#{f.domain.1}"
    n.addEventListener \change, ~> @emit-range f
    n

  emit-range: (f) ->
    c = @ctrl[f.key]
    cast = (v) -> if v == '' => null else if f.type == \date => v else +v
    [lo, hi] = [cast(c.lo.value), cast(c.hi.value)]
    # 兩端都不限就是沒有篩選. 這裡刻意不幫使用者把顛倒的區間轉正 -
    # 轉正會讓他以為自己打對了, 空結果反而看得出哪裡怪
    @emit f, (if !lo? and !hi? => null else {type: \range, values: [lo, hi]})

  emit: (f, v) ->
    @board.set-filter @id, (if v => {field: f.key, scope: \global} <<< v else null), f.key

  # 真實狀態在 board, 不在這些控制項身上 - 所以每次 render 都從 board 讀回來重寫.
  # 「清除篩選」是別的地方按的, 不這樣做的話勾勾會留在畫面上
  sync: ->
    n = 0
    for f in @fields => n += @sync-one f
    @bar.classList.toggle \filtering, !!n
    # 只寫「清除 n 項」而不是「清除篩選」- 它只清這一列發出的那幾個,
    # 頁首那顆「清除篩選」才是連圖表發出的一起清
    @clear.textContent = if n => "清除 #n 項" else '未篩選'

  sync-one: (f) ->
    c = @ctrl[f.key]
    cur = @board.filter-of @id, f.key
    c.wrap.classList.toggle \on, !!cur
    if f.type != \cat => return @sync-range f, c, cur
    if cur and cur.type => c.mode = (if cur.type == \exclude => \exclude else \index)
    for m, b of c.tab => b.classList.toggle \on, m == c.mode
    ex = c.mode == \exclude
    c.all.textContent = if ex => '不排除' else '全選'
    c.non.textContent = if ex => '全部排除' else '全不選'
    vs = if cur => (cur.values or []) else (if ex => [] else f.values)
    for b in c.boxes => b.checked = !!~vs.indexOf(b.value)
    c.val.textContent = if !cur => '全部'
    else if ex => "排除 #{vs.length} 項"
    else if !vs.length => '無'
    else if vs.length == 1 => "#{vs.0}"
    else "#{vs.length} 項"
    if cur => 1 else 0

  sync-range: (f, c, cur) ->
    [lo, hi] = if cur => cur.values else [null, null]
    c.lo.value = if lo? => lo else ''
    c.hi.value = if hi? => hi else ''
    fmt = (v) -> if !v? => '不限' else if f.type == \date => "#v" else num-fmt v
    c.val.textContent = if !cur => '全部' else "#{fmt lo} – #{fmt hi}"
    if cur => 1 else 0

  render: -> @sync!
  interface: -> @
