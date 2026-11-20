# 通用 panel: 一個 panel def 對應一張 @plotdb/chart 圖.
#
# panel 不知道自己畫的是什麼圖, 也不知道資料哪裡來:
#  - 圖是 def.chart 指定的 chart block
#  - 資料每次 render 都跟 board 要 ( board 會套用其他 panel 的 filter )
#
# 換句話說, 要換一套 panel 外觀 ( 標題列、選單、放大鈕 ) 只要換這個 block.
#
# 這一份在七個設計裡逐字相同, 只有 pug 裡的外觀與那一個 class 名不同 - 這就是重點:
# 同一份 def、同一套 crossfilter, 換掉 block 就換掉整個儀表板的長相.

module.exports =
  pkg: {name: \panel, version: \0.0.1}

  init: ({root, data, manager}) ->
    @def = def = data.def
    @board = board = data.board
    @manager = manager

    @view = new ldview do
      root: root
      text:
        title: -> def.title or def.id
        sub: -> def.subtitle or ''
      action:
        click: tag: ~> board.clear-panel def.id
      handler:
        "@": ({node}) ~>
          # 留著節點: 圖是非同步建起來的, 提示要等它好了才算得出來 ( 見 draw )
          @node = node
          fs = board.filters-of def.id
          # 用 ld 而不是 class 名: 七個設計的卡片 class 各不相同 ( .dash-panel /
          # .dk-panel / .rp-panel ... ), 寫死 class 的話這一份就不能逐字共用了
          node.querySelector('[ld=panel]')
            .classList.toggle \filtering, !!fs.length
          @paint-hint node
          # 截斷的時候整行 hover 看得到完整的「標題 · 副標題」.
          # 寫在標題列上而不是各寫一個: 使用者看到的是被截掉的那一行, 不是某個元素
          if (t = node.querySelector '[ld=title]') and t.parentNode
            sub = (node.querySelector '[ld=sub]' or {}).textContent or ''
            t.parentNode.setAttribute \title, [(def.title or def.id), sub].filter(-> it).join ' · '
        body: ({node, local}) ~> @draw node, local

  # 每次 render 都重新取資料; chart 已存在就只是 set-raw, 不會重建.
  #
  # local.chart 存的是 promise 而不是建好的圖: 建圖是非同步的, 存結果的話,
  # 第一張還沒建好就來的第二次 render 會看到 local.chart 還是空的, 於是再建一張,
  # 同一格就有兩張圖疊著 ( 慢速網路、或是圖還在載的時候別人發了 filter, 都會中 )
  draw: (node, local) ->
    {def, board} = @
    if !local.chart =>
      local.chart = @chart-class!
        # def.chart.data 是傳給 chart block 的參數 ( 不是資料 ) - 有些圖表要先知道
        # 一件事才畫得出來, 例如 @makechart/twmapadv 要 level 決定載哪一份地圖.
        # 跟 def.data ( 資料對應 ) 是兩回事, 名字像但位置不同
        .then (bc) -> bc.create {data: {delay-render: false} <<< ((def.chart or {}).data or {})}
        .then (bi) ~>
          @_bi = bi
          bi.attach {root: node} .then -> bi.interface!
        .then (chart) ~>
          @chart = chart
          @bind-events chart
          chart
    local.chart.then (chart) ~>
      {raw, meta, subset} = board.data-for def
      binding = def.binding or dash.binding(chart.mod.dimension, meta)
      {@field-map, @group-dim} = @fields-of binding, meta
      if def.cfg => chart.config def.cfg
      # 提示要等這裡才算得出來, 而且一定要在 chart.config 之後: 它看的是
      # field-map 與圖表合併後的 cfg ( brush 有沒有開、圖例能不能篩 ),
      # 早一步問到的是圖表的預設值, 不是這個 panel 真正的設定
      if @node => @paint-hint @node
      # subset 是同一份 binding 解析的子集; 沒有 compare 的 panel 就是 null
      chart.set-raw {raw, binding, subset: (subset or null)}
      # filter 的真實狀態在 board, 而 binding 每次都重建 - 重建後要把選取灌回圖裡,
      # 否則圖自己看到的永遠是「沒有選取」( shift 增刪就會每次從頭開始 ).
      # 不會自己發 filter 的圖也要灌: 它才知道自己身上哪幾項被選中, 可以畫成 dim
      # ( 選取是 board 在管的, 圖自己不會知道 ).
      # internal = false: 這是同步, 不是使用者操作, 不該再發一次事件
      fs = {}
      need = false
      for dim of @field-map =>
        f = board.filter-of def.id, dim
        # closed 跟 type 一樣原樣帶回去 - 直方圖的組是半開區間, 回灌時要認得出來
        fs[dim] = if f and f.values => {type: (f.type or \index), value: f.values, closed: f.closed} else undefined
        # 兩邊都空就不用同步 - 免得每次 render 都去戳圖的選取機制 ( 例如 bar 的 brush ).
        # 「上次灌了什麼」要自己記: binding 每次 render 都重建, 圖身上的 filter 會跟著不見,
        # 所以問圖認不出「剛剛有篩選, 現在被清掉了」- 不記的話別人清空時 bar 的框會留在畫面上
        if fs[dim] or (@pushed or {})[dim] => need = true
      @pushed = fs
      if need => chart.filter fs

  # def.chart 的兩種寫法:
  #
  #  - {name, version}  registry 上已發佈的 chart block. 平常都是這個
  #  - {code}           內嵌定義. 使用者自己寫的圖表不在 registry 上, 整份定義就寫在
  #                     def 裡 ( makechart 的自訂 code 是這種 ). code 裡的 dependency
  #                     仍然由同一個 manager 的 registry 解析, 所以 @makechart/base
  #                     這些不必跟著內嵌進來
  #
  # 內嵌的 code 是程式, 不是資料 - 誰能把 code 放進 def 就等於誰能在這一頁執行程式.
  # 存別人的 def 來畫的場合 ( 例如公開的儀表板 ), 沙箱是宿主的責任, 不是這裡的
  chart-class: ->
    c = @def.chart or {}
    if c.code => Promise.resolve(new block['class'] {code: c.code, manager: @manager})
    else @manager.get ({version: \main} <<< c)

  # 維度 -> 資料欄位的對應.
  #
  # 圖表發 filter 時是以 binding 維度為 key, 但 board 要的是資料欄位. 兩者的橋是
  # binding 自己: 綁到 meta.key ( 也就是 groupby 那一欄 ) 的維度就對應 groupby,
  # 綁到 measures 的維度對應 series ( 那些 measure 本來就是 series 欄位的值展開的 ).
  # def.crossfilter 可以逐維度覆寫.
  fields-of: (binding, meta) ->
    {def} = @
    cf = def.crossfilter
    if cf == false => return {field-map: {}, group-dim: null}
    ret = {}
    group-dim = null
    # 原始列模式 ( data.raw ) 沒有 groupby / series, 每個維度就是它在 binding 裡綁到的
    # 那一欄 - 直方圖這種自己分組的圖走這條
    raw-mode = !!(def.data or {}).raw
    for dim, b of binding =>
      one = if Array.isArray(b) => b.0 else b
      # 綁到 meta.key 的那一維就是「資料點」所在的維度. 每張圖叫法不同 -
      # pie / bar 是 name, line 是 order - 所以用 binding 去認, 不寫死名字
      is-group = !!(one and meta.key? and one.key == meta.key)
      if is-group => group-dim := dim
      f = if raw-mode => (one or {}).key
      else if is-group => def.data?groupby
      else def.data?series
      # 舊寫法 {field: "region"} 指的是資料點選那一維
      if cf? and typeof(cf) == \object =>
        if cf[dim]? => f = cf[dim]
        else if cf.field and is-group => f = cf.field
      if typeof(f) == \string => ret[dim] = f
    {field-map: ret, group-dim}

  # 圖 -> board 的 crossfilter 入口. 兩種來源:
  #  - filter: 圖自己發的選取 ( bar 的 brush、pie 的 wedge、line 的 legend )
  #  - select: 點選單一資料點, 在 board 上做 toggle
  bind-events: (chart) ->
    {def, board} = @
    if def.crossfilter == false => return
    key = def.data?key or \key
    chart.on \filter, (filters) ~>
      # filters 以 binding 維度為 key, 每個維度各自對應一個資料欄位
      for dim, v of (filters or {}) =>
        if !(field = (@field-map or {})[dim]) => continue
        # v 是 undefined = 清掉這一維的篩選; v.value 是空陣列 = 一項都沒選, 是有效的篩選
        # type 原樣帶過去 - index ( 值列表 ) 或 range ( 區間 ).
        # range 還可能帶 closed ( left / right / both ), 直方圖的組是半開區間
        board.set-filter def.id, (if v => {field, type: (v.type or \index), values: (v.value or []), closed: v.closed} else null), dim
    # select 代打只填資料點那一維 ( name ); 圖自己就會發 name filter 的不需要代打,
    # 兩個都接會互相蓋掉. 圖只發別的維度 ( 例如 line 只發 legend ) 則兩者並存
    chart.on \select, (d) ~>
      d = if Array.isArray(d) => d.0 else d
      if !(d and d.data) => return
      if !(dim = @group-dim) => return
      # 圖自己就會發這一維的 filter 就不必代打, 兩個都接會互相蓋掉
      if dim in (if chart.filter-dims => chart.filter-dims! else []) => return
      if !(field = (@field-map or {})[dim]) => return
      v = d.data[key]
      if v? => board.toggle-filter def.id, field, v, dim


  # 操作提示: 這張圖能怎麼篩.
  #
  # 刻意不讓宿主在副標題寫「可點選 / 可框選」- 那是把介面的行為寫進資料, 換一種圖
  # 或改一個設定, 那句話就默默變成錯的說明, 而且沒有人會發現. 這裡問圖表自己,
  # 設定改了提示就跟著改.
  #
  # 來源有兩個, 合起來才是完整的:
  #
  #  - chart.interactions!   圖表自己宣告「哪個操作會發哪幾維的 filter」
  #                          ( @plotdb/chart 3.16.0 起 ). 回 null = 沒宣告 = 不知道
  #  - select 代打           圖自己不發資料點那一維時, 點選是 board 接的
  #                          ( 見 bind-events ). 這一半圖表不知道, 只有這裡知道
  #
  # 為什麼要問圖表: 從外面看不出「會框選的圖點不點得動」. bar 兩種都像, 但它的
  # click 是用來換對齊, 不發 filter; line 的資料點按下去也不發. 猜就會給出一個
  # 按了沒反應的提示, 所以沒宣告的圖 ( ix == null ) 退回原本保守的推法: 只講
  # cfg 看得出來的那幾件, 寧可少說一句.
  hints: ->
    {def} = @
    if def.crossfilter == false => return []
    fm = @field-map or {}
    # 欄位的中文名: 先看這張圖自己的, 再退到整份 def 的. 兩層都沒有就用原始欄位名 -
    # 那是資料的名字, 不是給使用者看的名字, 但至少不會是空的
    all = ((@board or {}).def or {}).labels or {}
    lb = (f) -> (def.labels or {})[f] or all[f] or f
    acts = {}
    add = (k, f) ->
      if !f => return
      if !acts[k] => acts[k] = []
      if f not in acts[k] => acts[k].push f
    ix = if (@chart or {}).interactions => @chart.interactions! else null
    dims = if (@chart or {}).filter-dims => @chart.filter-dims! else []
    g = @group-dim
    gf = if g => fm[g] else null
    # 兩條路要寫成完整的 if / else 區塊: `if ix? => for ...` 接一行 `else` 的話,
    # LiveScript 會把那個 else 當成 for 的 else ( 迴圈一次都沒跑時執行 ),
    # 於是退路只在「有宣告但是空的」才跑, 沒宣告的圖就什麼提示都沒有
    if ix?
      for k, ds of ix => for d in (ds or []) => add k, fm[d]
    else
      # 退路: 圖沒宣告, 從 cfg 推. 判斷的依據只有 dash 真的知道的那幾件
      cfg = (@chart or {}).cfg or def.cfg or {}
      brushy = !!(cfg.brush or {}).enabled
      # 沒宣告的圖只賭一件事: 有框選就講框選, 沒有就賭點得動. 這是舊的推法,
      # 留著是因為它對沒宣告的圖 ( 例如 pie ) 還是比什麼都不說有用
      if gf and brushy => add \brush, gf
      else if gf => add \click, gf
      lg = cfg.legend or {}
      if lg.crossfilter and lg.enabled != false
        # 圖例篩的通常是另一個維度 ( line 的 series ); 沒有別的維度就是跟項目同一個
        other = [d for d in dims when d != g and fm[d]]
        add \legend, (if other.length => fm[other.0] else gf)
    # select 代打的那一維. 擺在兩條路之後, 因為兩種情況都可能有:
    # 圖宣告了 click 就表示它自己發, 這裡的條件 ( 不在 filter-dims 裡 ) 自然不成立
    if gf and g not in dims => add \click, gf
    text =
      click: "點圖上的項目可以篩"
      brush: "橫向框選可以篩"
      legend: "點圖例可以篩"
    out = []
    # 固定順序, 不照 interactions 的 key 順序 - 提示的排列不該隨圖表的宣告而變
    for k in <[click brush legend]> => for f in (acts[k] or []) => out.push "#{text[k]}「#{lb f}」"
    out

  # 提示掛在標題列右側, 跟「篩選中」同一個位置 - 篩選中的時候它讓位,
  # 因為那時候使用者要的是「怎麼取消」, 不是「可以怎麼篩」
  paint-hint: (node) ->
    if !(h = node.querySelector '[ld=hint]') => return
    hs = @hints!
    h.style.display = if hs.length => '' else \none
    if !hs.length => return
    # title 是沒有 hover 樣式時的退路 ( 例如觸控裝置 ), 也給讀螢幕的人
    h.setAttribute \title, hs.join '\n'
    h.setAttribute \aria-label, hs.join '; '
    if !(p = node.querySelector '[ld=hintpop]') => return
    p.innerHTML = ''
    for t in hs
      d = document.createElement \div
      d.textContent = t
      p.appendChild d

  render: -> @view.render!

  # 換圖種 ( board.update-panel 改 def.chart ) 會把這個 panel 整個重建, 所以這裡
  # 要把圖拆乾淨 - 不拆的話, 舊的那張圖還掛著 ResizeObserver 與動畫迴圈
  destroy: ->
    if @_bi => @_bi.detach!
    @_bi = null

  interface: -> @
