# KPI 條目 ( 報告版 ): 跟 desk 的 kpi block 做一樣的事, 畫法不同.
#
# 兩版的差別只有兩個:
#  - 沒有進度條. 印刷品上一條會跑的長條是突兀的, 比例改成跟在數字後面的一行字
#  - 數字不做補間. 報告是拿來讀的, 不是盯著看的; 會跳動的數字在這個語境下是干擾
#
# def 的欄位跟 desk 一樣 ( unit / accent / note ), 所以同一份 def 兩版都能跑.

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
    @n = Object.from-entries <[num unit label note]>.map ->
      [it, root.querySelector("[ld=#it]")]
    @n.label.textContent = def.title or def.id
    @n.unit.textContent = def.unit or ''
    if def.accent => root.querySelector('.rp-kpi').style.set-property \--rp-kpi-accent, def.accent
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
    @n.num.textContent = num-fmt v

    @n.note.className = \rp-kpi-note
    if !live => @n.note.textContent = @tr 'Whole set'
    else if @def.note == \delta =>
      # 平均值型的指標: 「佔全體 65%」沒有意義, 要看的是比全體高還是低
      d = if total => (sub - total) / total else 0
      @n.note.className = "rp-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = @tr '{d}% vs whole set', {d: "#{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}"}
    else
      ratio = if total => sub / total else 1
      @n.note.textContent = @tr '{p}% of whole set', {p: (ratio * 100).toFixed 1}

  # 翻一句話, 順便把 {name} 換成值.
  #
  # 插值自己做: block 內建的 t 收了第二個參數但不用它, 而宿主換成 i18next 的話
  # 它認的是 {{name}} - 用單括號的話兩種 module 都不會先動手, 兩邊的結果一樣
  tr: (k, vals = {}) ->
    s = if @t => @t k else k
    for n, v of vals => s = s.replace "{#n}", v
    s

  interface: -> @
