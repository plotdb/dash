# KPI 磚: 不掛任何圖表, 直接把 board 聚合出來的單一數值畫成卡片.
#
# 存在的理由是「panel block 可以換」: 它跟隔壁的 panel block 收到一樣的
# {def, board}, 一樣每次 render 跟 board 要資料, 只是畫法完全不同.
# 1st 這四格是用 @makechart/number 畫的 - 能自動放大數字, 但只有一個數字可說;
# 這裡自己畫, 就能順便講「這個數字是全體的多少」.
#
# def 多兩個欄位:
#  - unit    單位
#  - accent  左緣色條的顏色
#  - note    share ( 佔全體幾 % ) 或 delta ( 較全體 ±幾 % ). 平均值型的指標用 delta,
#            因為「平均單價的 65%」沒有意義, 要看的是比全體高還是低

num-fmt = (n) ->
  if Math.abs(n) >= 1000 => Math.round(n).toLocaleString \en-US
  else (Math.round(n * 10) / 10).toLocaleString \en-US

module.exports =
  pkg: {name: \kpi, version: \0.0.1}

  init: ({root, data}) ->
    @def = def = data.def
    @board = data.board
    @n = Object.from-entries <[num unit label note fill]>.map ->
      [it, root.querySelector("[ld=#it]")]
    @n.label.textContent = def.title or def.id
    @n.unit.textContent = def.unit or ''
    if def.accent => root.querySelector('.n2-kpi').style.set-property \--n2-kpi-accent, def.accent
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
    live = !!Object.keys(@board.filters).length
    v = if live and sub? => sub else total
    ratio = if total and sub? => sub / total else 1

    @n.note.className = \n2-kpi-note
    if !live => @n.note.textContent = '全體'
    else if @def.note == \delta =>
      d = if total => (sub - total) / total else 0
      @n.note.className = "n2-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = "較全體 #{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}%"
    else @n.note.textContent = "佔全體 #{(ratio * 100).toFixed 1}%"

    # delta 模式的比例不是「佔全體多少」, 拿來當進度條會騙人, 所以維持滿格
    @n.fill.style.width = "#{100 * (if @def.note == \delta => 1 else ratio)}%"
    @tween v

  # 數字用補間而不是直接換. 篩選是連續的互動, 直接跳會看不出哪一格變了
  tween: (v) ->
    @target = v
    if @timer => return
    step = ~>
      @cur += (@target - @cur) * 0.25
      if Math.abs(@target - @cur) < (Math.abs(@target) * 0.001 >? 0.05) => @cur = @target
      @n.num.textContent = num-fmt @cur
      @timer = if @cur == @target => null else requestAnimationFrame step
    @timer = requestAnimationFrame step

  destroy: -> if @timer => cancelAnimationFrame @timer

  interface: -> @
