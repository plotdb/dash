# KPI 磚 ( 牆面版 ): 跟 design-1 / design-2 的 kpi 做一樣的事, 畫法不同.
#
# 牆面版的差別是「整塊磚就是這個指標」- 背景直接上 accent 色, 數字佔滿整格.
# 比例不是細細一條進度條, 是磚底那一道夠粗、隔十公尺也看得到的橫條.
#
# def 的欄位跟另外兩版一樣 ( unit / accent / note ), 同一份 def 三版都能跑.

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
    if def.accent => root.querySelector('.wl-kpi').style.set-property \--wl-kpi-accent, def.accent
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

    @n.note.className = \wl-kpi-note
    if !live => @n.note.textContent = '全體'
    else if @def.note == \delta =>
      # 平均值型的指標: 「佔全體 65%」沒有意義, 要看的是比全體高還是低
      d = if total => (sub - total) / total else 0
      @n.note.className = "wl-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = "較全體 #{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}%"
    else @n.note.textContent = "佔全體 #{(ratio * 100).toFixed 1}%"

    # delta 模式的比例不是「佔全體多少」, 拿來當進度條會騙人, 所以維持滿格
    @n.fill.style.width = "#{100 * (if @def.note == \delta => 1 else ratio)}%"
    @tween v

  # 數字用補間而不是直接換. 牆上的螢幕沒有人在操作, 變化本身就是唯一的提示
  tween: (v) ->
    @target = v
    if @timer => return
    step = ~>
      @cur += (@target - @cur) * 0.22
      if Math.abs(@target - @cur) < (Math.abs(@target) * 0.001 >? 0.05) => @cur = @target
      @n.num.textContent = num-fmt @cur
      @timer = if @cur == @target => null else requestAnimationFrame step
    @timer = requestAnimationFrame step

  destroy: -> if @timer => cancelAnimationFrame @timer

  interface: -> @
