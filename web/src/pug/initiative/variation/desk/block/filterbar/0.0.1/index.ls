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
  pkg:
    name: \filterbar
    version: \0.0.1
    # key 就是英文原文, 漏翻一句時看到的是英文而不是一個 key.
    # {n} / {range} 由 tr 自己換 - 見那個 method 的說明.
    #
    # 兩個標題都在表裡 ( 「篩選」與「全域篩選」): 那句話是各設計的 pug 自己挑的
    # ( t= 寫在 pug 上 ), 而這一份 JS 在每個設計裡逐字相同, 所以兩句都得收
    i18n:
      en:
        'Filter': 'Filter'
        'Global filter': 'Global filter'
        'Not filtered': 'Not filtered'
        'Clear {n}': 'Clear {n}'
        'Only': 'Only'
        'Exclude': 'Exclude'
        'Select all': 'Select all'
        'Select none': 'Select none'
        'Exclude none': 'Exclude none'
        'Exclude all': 'Exclude all'
        'All': 'All'
        'Nothing': 'Nothing'
        '{n} items': '{n} items'
        'Excluding {n}': 'Excluding {n}'
        'Any': 'Any'
        'Full range {range}': 'Full range {range}'
      'zh-TW':
        'Filter': '篩選'
        'Global filter': '全域篩選'
        'Not filtered': '未篩選'
        'Clear {n}': '清除 {n} 項'
        'Only': '只要'
        'Exclude': '排除'
        'Select all': '全選'
        'Select none': '全不選'
        'Exclude none': '不排除'
        'Exclude all': '全部排除'
        'All': '全部'
        'Nothing': '無'
        '{n} items': '{n} 項'
        'Excluding {n}': '排除 {n} 項'
        'Any': '不限'
        'Full range {range}': '全部範圍 {range}'

  init: ({root, data, t, i18n}) ->
    @t = t
    @i18n = i18n
    @root = root
    @def = data.def
    @board = board = data.board
    @id = @def.id or \header
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

  # 翻一句話, 順便把 {name} 換成值.
  #
  # 插值自己做: block 內建的 t 收了第二個參數但不用它, 而宿主換成 i18next 的話
  # 它認的是 {{name}} - 用單括號的話兩種 module 都不會先動手, 兩邊的結果一樣
  tr: (k, vals = {}) ->
    s = if @t => @t k else k
    for n, v of vals => s = s.replace "{#n}", v
    s

  refresh: ->
    @sig = @_sig!
    @labels = @def.labels or {}
    fs = dash.fields @board.rows, {skip: (@def.skip or [])}
    # def 可以指定要哪幾欄、照什麼順序 - 一份資料的欄位不一定都值得篩
    @fields = if !@def.only => fs
    else @def.only.map((k) -> [f for f in fs when f.key == k].0).filter -> it
    @build!
    @drop-stale!

  lang: -> ((@i18n or {}).language) or ''

  # 欄位的設定 ( 哪幾欄、怎麼稱呼 ) 的指紋. 比字串是因為 labels 是物件,
  # 而這三個值都小, 每次 render 比一次不划算的問題不存在.
  #
  # 語言也算進去: 控制項裡有幾句話是建的時候寫上去就不再動的 ( 分頁的「只要 /
  # 排除」、「全部範圍 …」), sync 不會重寫它們 - 換語言時整組重建最省事,
  # 而這條路本來就在了
  _sig: -> JSON.stringify [(@def.only or null), (@def.skip or null), (@def.labels or null), @lang!]

  # 不再開放的欄位, 它原本發出的篩選要一起清掉.
  #
  # 不清的話那個篩選還在起作用, 但畫面上沒有任何地方看得到它 - 使用者會看到一份
  # 篩過的資料, 卻找不到是哪裡篩的, 也取消不了. ( 清的時機要在 @sig 更新之後:
  # set-filter 會觸發 render, 那時候指紋已經對上了, 不會再重建一次 )
  drop-stale: ->
    live = {}
    for f in @fields => live[f.key] = true
    for f in @board.filters-of(@id) => if !live[f.dim] => @board.set-filter @id, null, f.dim

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
    c.all = mk \button, (@k \mini), (@tr 'Select all')
    c.non = mk \button, (@k \mini), (@tr 'Select none')
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
    b = mk \button, (@k \tab), (@tr (if mode == \exclude => 'Exclude' else 'Only'))
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
    pop.appendChild mk \div, (@k \hint), (@tr 'Full range {range}', {range: hint})

  end: (f, which) ->
    if f.type == \date =>
      n = mk \select, @k \sel
      n.appendChild mk \option, null, (@tr 'Any')
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
    @clear.textContent = if n => (@tr 'Clear {n}', {n}) else @tr 'Not filtered'

  sync-one: (f) ->
    c = @ctrl[f.key]
    cur = @board.filter-of @id, f.key
    c.wrap.classList.toggle \on, !!cur
    if f.type != \cat => return @sync-range f, c, cur
    if cur and cur.type => c.mode = (if cur.type == \exclude => \exclude else \index)
    for m, b of c.tab => b.classList.toggle \on, m == c.mode
    ex = c.mode == \exclude
    c.all.textContent = @tr (if ex => 'Exclude none' else 'Select all')
    c.non.textContent = @tr (if ex => 'Exclude all' else 'Select none')
    vs = if cur => (cur.values or []) else (if ex => [] else f.values)
    for b in c.boxes => b.checked = !!~vs.indexOf(b.value)
    c.val.textContent = if !cur => @tr 'All'
    else if ex => (@tr 'Excluding {n}', {n: vs.length})
    else if !vs.length => @tr 'Nothing'
    else if vs.length == 1 => "#{vs.0}"
    else (@tr '{n} items', {n: vs.length})
    if cur => 1 else 0

  sync-range: (f, c, cur) ->
    [lo, hi] = if cur => cur.values else [null, null]
    c.lo.value = if lo? => lo else ''
    c.hi.value = if hi? => hi else ''
    fmt = (v) ~> if !v? => @tr 'Any' else if f.type == \date => "#v" else num-fmt v
    c.val.textContent = if !cur => @tr 'All' else "#{fmt lo} – #{fmt hi}"
    if cur => 1 else 0

  # def 會被 board.update-panel 改掉 ( 編輯器調整「開放哪些欄位、怎麼稱呼」),
  # 而 panel block 拿到的 def 跟 board 那邊是同一個物件 - 所以不必有人通知,
  # 每次 render 比對一下指紋就知道要不要重建控制項
  render: ->
    if @_sig! != @sig => @refresh! else @sync!

  interface: -> @
