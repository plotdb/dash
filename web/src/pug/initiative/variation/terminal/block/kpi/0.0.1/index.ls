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
  pkg:
    name: \kpi
    version: \0.0.1
    # 這一版的 zh-TW 跟 en 一字不差, 而這是故意的: 主控台的身分就是等寬、單色、
    # 全大寫的英文, 「ALL」在這裡是介面的一部分, 不是一句可以翻的話.
    # 表還是要有 - 要翻的人換掉這幾句就好, 不必改程式
    i18n:
      en:
        'ALL': 'ALL'
        '{d}% vs ALL': '{d}% vs ALL'
        '{p}% of ALL': '{p}% of ALL'
      'zh-TW':
        'ALL': 'ALL'
        '{d}% vs ALL': '{d}% vs ALL'
        '{p}% of ALL': '{p}% of ALL'

  init: ({root, data, t}) ->
    @t = t
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
    if !live => @n.note.textContent = @tr 'ALL'
    else if @def.note == \delta =>
      d = if total => (sub - total) / total else 0
      @n.note.className = "tm-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = @tr '{d}% vs ALL', {d: "#{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}"}
    else @n.note.textContent = @tr '{p}% of ALL', {p: (ratio * 100).toFixed 1}

    # delta 模式的比例不是「佔全體多少」, 畫成進度條會騙人, 所以維持滿格
    r = if @def.note == \delta => 1 else ratio
    on-n = Math.round(r * cells)
    @n.fill.textContent = '█'.repeat(on-n) + '░'.repeat(cells - on-n)
    @n.num.textContent = num-fmt v

  # 翻一句話, 順便把 {name} 換成值.
  #
  # 插值自己做: block 內建的 t 收了第二個參數但不用它, 而宿主換成 i18next 的話
  # 它認的是 {{name}} - 用單括號的話兩種 module 都不會先動手, 兩邊的結果一樣
  tr: (k, vals = {}) ->
    s = if @t => @t k else k
    for n, v of vals => s = s.replace "{#n}", v
    s

  interface: -> @
