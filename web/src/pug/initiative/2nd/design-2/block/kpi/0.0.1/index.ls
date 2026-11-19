# KPI 條目 ( 報告版 ): 跟 design-1 的 kpi block 做一樣的事, 畫法不同.
#
# 兩版的差別只有兩個:
#  - 沒有進度條. 印刷品上一條會跑的長條是突兀的, 比例改成跟在數字後面的一行字
#  - 數字不做補間. 報告是拿來讀的, 不是盯著看的; 會跳動的數字在這個語境下是干擾
#
# def 的欄位跟 design-1 一樣 ( unit / accent / note ), 所以同一份 def 兩版都能跑.

num-fmt = (n) ->
  if Math.abs(n) >= 1000 => Math.round(n).toLocaleString \en-US
  else (Math.round(n * 10) / 10).toLocaleString \en-US

module.exports =
  pkg: {name: \kpi, version: \0.0.1}

  init: ({root, data}) ->
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
    live = !!Object.keys(@board.filters).length
    v = if live and sub? => sub else total
    @n.num.textContent = num-fmt v

    @n.note.className = \rp-kpi-note
    if !live => @n.note.textContent = '全體'
    else if @def.note == \delta =>
      # 平均值型的指標: 「佔全體 65%」沒有意義, 要看的是比全體高還是低
      d = if total => (sub - total) / total else 0
      @n.note.className = "rp-kpi-note #{if d >= 0 => \up else \down}"
      @n.note.textContent = "較全體 #{if d >= 0 => '+' else ''}#{(d * 100).toFixed 1}%"
    else
      ratio = if total => sub / total else 1
      @n.note.textContent = "佔全體 #{(ratio * 100).toFixed 1}%"

  interface: -> @
