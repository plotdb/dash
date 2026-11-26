# KPI 磚: 不掛任何圖表, 直接把 board 聚合出來的單一數值畫成卡片.
#
# 存在的理由是「panel block 可以換」: 它跟隔壁的 panel block 收到一樣的
# {def, board}, 一樣每次 render 跟 board 要資料, 只是畫法完全不同.
# vanilla 那四格是用 @makechart/number 畫的 - 能自動放大數字, 但只有一個數字可說;
# 這裡自己畫, 就能順便講「這個數字是全體的多少」.
#
# def 多兩個欄位:
#  - unit    單位
#  - accent  左緣色條的顏色
#  - note    share ( 佔全體幾 % ) 或 delta ( 較全體 ±幾 % ). 平均值型的指標用 delta,
#            因為「平均單價的 65%」沒有意義, 要看的是比全體高還是低

still = ->
  try
    window.match-media('(prefers-reduced-motion: reduce)').matches
  catch e
    false

num-fmt = (n) ->
  if Math.abs(n) >= 1000 => Math.round(n).toLocaleString \en-US
  else (Math.round(n * 10) / 10).toLocaleString \en-US

module.exports =
  pkg:
    name: \kpi
    version: \0.0.1
    # key 就是英文原文, 漏翻一句時看到的是英文而不是一個 key.
    # {d} / {p} 由 tr 自己換掉 ( 見那個 method )
    i18n:
      en:
        'Whole set': 'Whole set'
        '{d}% vs whole set': '{d}% vs whole set'
        '{p}% of whole set': '{p}% of whole set'
      'zh-TW':
        'Whole set': '全體'
        '{d}% vs whole set': '較全體 {d}%'
        '{p}% of whole set': '佔全體 {p}%'

  init: ({root, data, t}) ->
    @t = t
    @def = def = data.def
    @board = data.board
    @n = Object.from-entries <[num unit label note fill]>.map ->
      [it, root.querySelector("[ld=#it]")]
    @n.label.textContent = def.title or def.id
    @n.unit.textContent = def.unit or ''
    if def.accent => root.querySelector('.dk-kpi').style.set-property \--dk-kpi-accent, def.accent
    @cur = 0
    @target = 0
    # board 掛完 panel 不會主動 render 一次; 其他 panel 是 ldview 在 attach 時畫的,
    # 這個 block 沒有用 ldview, 所以自己畫
    @render!
    @

  # 分母是未篩選的全體, 分子套用所有 filter - 跟 compare 模式的圖表看到的是同一份東西
  values: ->
    {raw, subset} = @board.data-for @def
    k = ((@def.data or {}).measures or [{}]).0.name or \value
    pick = (rows) -> +((rows or [])[0] or {})[k] or 0
    {total: (pick raw), sub: (if subset => pick subset else null)}

  render: ->
    {total, sub} = @values!
    # locals 而不是 filters: 全域篩選只是把「全體」縮小, 不是「選了其中幾項」-
    # 分子分母會是同一份, 顯示「佔全體 100.0%」看起來像壞掉
    live = !!@board.locals!length
    v = if live and sub? => sub else total
    ratio = if total and sub? => sub / total else 1

    @n.note.className = \dk-kpi-note
    if !live => @n.note.textContent = @tr 'Whole set'
    else if @def.note == \delta =>
      d = if total => (sub - total) / total else 0
      @n.note.className = "dk-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = @tr '{d}% vs whole set', {d: "#{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}"}
    else @n.note.textContent = @tr '{p}% of whole set', {p: (ratio * 100).toFixed 1}

    # delta 模式的比例不是「佔全體多少」, 拿來當進度條會騙人, 所以維持滿格
    @n.fill.style.width = "#{100 * (if @def.note == \delta => 1 else ratio)}%"
    @tween v

  # 數字用補間而不是直接換. 篩選是連續的互動, 直接跳會看不出哪一格變了
  tween: (v) ->
    @target = v
    # 系統裡說了「減少動態」就直接換數字. CSS 那邊 dash.css 已經處理掉動畫與轉場,
    # 這裡是 JS 畫的補間, 得自己看
    if still! =>
      @cur = v
      @n.num.textContent = num-fmt v
      return
    if @timer => return
    # 步長跟著經過的時間走, 不是跟著「跑了幾個 frame」- 120Hz 的螢幕上跑兩倍快
    # 是小事, 但分頁被切到背景、或是 headless 截圖時只畫得出兩三格的時候,
    # 按 frame 算的補間會永遠停在半路, 畫面上就是一個不對的數字
    last = null
    step = (t) ~>
      dt = if last? => t - last else 16
      last := t
      @cur += (@target - @cur) * (1 - Math.pow(1 - 0.25, dt / 16))
      if Math.abs(@target - @cur) < (Math.abs(@target) * 0.001 >? 0.05) => @cur = @target
      @n.num.textContent = num-fmt @cur
      @timer = if @cur == @target => null else requestAnimationFrame step
    @timer = requestAnimationFrame step

  # 翻一句話, 順便把 {name} 換成值.
  #
  # 插值自己做: block 內建的 t 收了第二個參數但不用它, 而宿主換成 i18next 的話
  # 它認的是 {{name}} - 用單括號的話兩種 module 都不會先動手, 兩邊的結果一樣
  tr: (k, vals = {}) ->
    s = if @t => @t k else k
    for n, v of vals => s = s.replace "{#n}", v
    s

  destroy: -> if @timer => cancelAnimationFrame @timer

  interface: -> @
