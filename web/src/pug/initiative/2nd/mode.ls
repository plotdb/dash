# light / dark 的機制: 六個設計共用這一份.
#
# 會獨立成一個檔案, 是因為「換一個模式」要碰的東西住在三個不同的地方:
#
#  1. 頁面與 block 的 CSS -> 全部走 <html data-mode> 底下的 custom property.
#     換模式就是換一個屬性, CSS 自己會跟著變 - 包括 block 裡的樣式: block 不是
#     shadow DOM, custom property 照樣繼承得進去, 所以 panel 的外觀不必接任何 JS
#  2. 圖表的顏色 -> 在 config 裡, 不吃 CSS. 所以要重算一份 theme 併回每個 panel 的
#     cfg, 再 bd.render! - panel block 每次 render 都會做 chart.config def.cfg,
#     所以「重算 + 重畫」就夠了, 不必 reload def ( reload 會把篩選清掉 )
#  3. 使用者的選擇 -> localStorage. 沒選過的話跟著系統 ( prefers-color-scheme ),
#     而且系統在白天 / 夜晚之間切換時畫面要跟著換, 不是只在開頁面時讀一次
#
# 第 1 點在 <head> 的 inline script 裡就先做掉 ( 見各頁的 pug ). 這一份是 module,
# 會被 defer 到 DOM 之後, 等到這裡才設屬性會先閃一下另一個模式的顏色.

key = \dash-2nd-mode

ls-get = (k) ->
  try
    localStorage.get-item k
  catch e
    null

ls-set = (k, v) ->
  try
    localStorage.set-item k, v
  catch e
    void

# 深拷貝式合併: 兩邊都複製一份, 免得多張圖共用同一個巢狀物件
# ( 圖表會把 config 併進自己的設定, 共用的話一張圖改到另一張 )
deep = (a = {}, b = {}) ->
  clone = (v) -> if v and typeof(v) == \object and !Array.isArray(v) => deep(v) else v
  ret = {}
  for k, v of a => ret[k] = clone v
  for k, v of b =>
    ret[k] = if v and typeof(v) == \object and !Array.isArray(v) => deep (ret[k] or {}), v
    else v
  ret

window.dmode = do ->
  cbs = []
  mq = window.match-media '(prefers-color-scheme: dark)'
  cur = ls-get(key) or (if mq.matches => \dark else \light)

  apply = (m, persist) ->
    cur := m
    document.document-element.dataset.mode = m
    if persist => ls-set key, m
    for cb in cbs => cb m

  # 沒有自己選過就跟著系統走
  mq.add-event-listener \change, (e) -> if !ls-get(key) => apply (if e.matches => \dark else \light), false

  self =
    deep: deep
    get: -> cur
    set: (m) -> apply m, true
    toggle: -> apply (if cur == \dark => \light else \dark), true
    # 切換鈕的字: 寫「要切去哪一個」, 不是「現在是哪一個」
    label: -> if cur == \dark => '淺色' else '深色'
    icon: -> if cur == \dark => '☀' else '☾'
    on: (cb) -> cbs.push cb; cb cur; self

    # 把一組主題綁到一個 board 上.
    #
    # theme-of 收 ( mode, panel ): 回傳的東西會併到那個 panel 的 cfg 底下.
    # 收 panel 是因為有些設定逐 panel 不同但值跟著模式走 ( 例如每張圖用哪一組色票、
    # 地圖的縣市邊界顏色 ) - 寫在 def 的 cfg 裡就得為每個模式各寫一份 def.
    #
    # 每個 panel 原始的 cfg 要另外留一份: 拿已經套過主題的那一份再套一次新主題,
    # 上一個模式的顏色會留在新主題沒覆蓋到的 key 上 ( 例如只在深色底才需要的
    # brush 設定 ). 所以原始的 cfg 收在 p._cfg, 每次都從它重算.
    theme: (bd, theme-of) ->
      retheme = (panels, mode = cur) ->
        for p in (panels or []) =>
          if !p.chart => continue
          if !p._cfg => p._cfg = p.cfg or {}
          p.cfg = deep theme-of(mode, p), p._cfg
      self.retheme = retheme
      self.on (mode) ->
        retheme bd.panels, mode
        # board 還沒 init 的時候只要把 cfg 準備好, 沒有東西可以重畫
        if bd.panels.length and bd.panels.0.itf => bd.render!
      self

  apply cur, false
  self
