# KPI 磚 ( 主控台版 ).
#
# 跟 desk 的那一份差別只有一處, 但那一處就是這個設計:
# 「選中了全體的多少」不是一條 CSS 畫的色條, 是一串字元 ████░░░░.
#
# 理由是整個畫面上沒有別的東西是圖形 - 一條色條會變成唯一不是字的元素.
# 代價是解析度只有 12 格, 看不出 61% 與 64% 的差別; 這一版接受這個代價,
# 因為旁邊就寫著百分比.
#
# def 的欄位跟其他設計完全一樣 ( unit / accent / note ) - accent 這一版用不到,
# 整個畫面只有一個強調色
num-fmt = (n) ->
  if Math.abs(n) >= 1000 => Math.round(n).toLocaleString \en-US
  else (Math.round(n * 10) / 10).toLocaleString \en-US

cells = 12

module.exports =
  pkg: {name: \kpi, version: \0.0.1}

  init: ({root, data}) ->
    @def = def = data.def
    @board = data.board
    @n = Object.from-entries <[num unit label note fill]>.map ->
      [it, root.querySelector("[ld=#it]")]
    @n.label.textContent = def.title or def.id
    @n.unit.textContent = def.unit or ''
    @render!
    @

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

    @n.note.className = \tm-kpi-note
    if !live => @n.note.textContent = 'ALL'
    else if @def.note == \delta =>
      d = if total => (sub - total) / total else 0
      @n.note.className = "tm-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = "#{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}% vs ALL"
    else @n.note.textContent = "#{(ratio * 100).toFixed 1}% of ALL"

    # delta 模式的比例不是「佔全體多少」, 畫成進度條會騙人, 所以維持滿格
    r = if @def.note == \delta => 1 else ratio
    on-n = Math.round(r * cells)
    @n.fill.textContent = '█'.repeat(on-n) + '░'.repeat(cells - on-n)
    @n.num.textContent = num-fmt v

  interface: -> @
