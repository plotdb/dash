<-(->it.apply {}) _

dashboard = (opt = {}) ->
  @root = if typeof(opt.root) == \string => document.querySelector(opt.root) else opt.root
  @mgr = opt.manager
  @cfg = opt.cfg
  @data = opt.data
  @evt-handler = {}
  @

dashboard.prototype = Object.create(Object.prototype) <<< do
  on: (n, cb) -> (if Array.isArray(n) => n else [n]).map (n) ~> @evt-handler.[][n].push cb
  fire: (n, ...v) -> for cb in (@evt-handler[n] or []) => cb.apply @, v
  init: ->
    cfg = @cfg
    mgr.get({name: "panel", version: "0.0.1"})
      .then (bc) ~>
        @bc = bc
        @view = view = new ldview do
          root: @root
          handler:
            dash: ({node}) -> node.style.gridTemplate = "repeat(#{cfg.dim.row}) repeat(#{cfg.dim.col})"
            panel:
              list: ~> cfg.panels
              view:
                init: ->
                handler: "@": ({node, ctx, local}) ~>
                  p = if !local.bi =>
                    @bc.create!then (bi) ~>
                      local.bi = bi
                      bi.attach {root: node, data: {meta: ctx, data: @data}}
                        .then -> bi.interface!
                        .then (itf) ~>
                          local.itf = itf
                          itf.on \select, ~> @fire \select, it
                          itf
                  else Promise.resolve!
                  p.then ->
                    node.style <<<
                      gridArea: "#{ctx.y} / #{ctx.x} / span #{ctx.h} / span #{ctx.w}"

  render: ->
    @view.render!


mgr = window.manager = new block.manager registry: ({name, version, path, type}) ->
  if name in <[line pie bar bubble base number bar taiwancounty percent-list]> => return "/assets/chart/#name/#version/#{path or 'index.html'}"
  if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
  if /^local/.exec(name) => return "/block/#name/#{path or 'index.html'}"
  root = if type == \block => '/block' else '/assets/lib'
  "#root/#{name}/#{version}/#{path or (if type == 'block' => 'index.html' else 'index.min.js')}"
mgr.init!
  .then ->
    mgr.get({name: "panel", version: "0.0.1"})
  .then (bc) ~> @bc = bc
  .then ~>
    ld$.fetch "/assets/data/sales.csv", {method: \GET}, {type: \text}
  .then ~>
    data = Papa.parse(it).data
    head = data.splice 0, 1 .0
    data = data.map (b) -> Object.fromEntries head.map (d,i) -> [d,b[i]]
    console.log data

    cfg = {}
    cfg.main =
      dim: col: 8, row: 4
      panels: [
        * x: 1, y: 1, w: 1, h: 1, name: "total-gross"
        * x: 2, y: 1, w: 1, h: 1, name: "sales-count"
        * x: 3, y: 1, w: 1, h: 1, name: "store-count"
        * x: 4, y: 1, w: 5, h: 1, name: "publish-trend"
        * x: 1, y: 2, w: 2, h: 1, name: "ship-hist"
        * x: 1, y: 3, w: 2, h: 1, name: "return-hist"
        * x: 1, y: 4, w: 2, h: 1, name: "order-hist"
        * x: 3, y: 2, w: 3, h: 3, name: "book-prop"
        * x: 6, y: 2, w: 3, h: 3, name: "store-dist"
      ]
    cfg.detail =
      dim: col: 1, row: 2
      panels: [
        * x: 1, y: 1, w: 1, h: 1, name: "book-trend"
        * x: 1, y: 2, w: 1, h: 1, name: "book-trend"
      ]
    view = new ldview do
      root: document.body

    ldcv = new ldcover do
      root: view.get('detail')

    dash = {}
    dash.main = new dashboard do
      root: view.get('dash-main')
      cfg: cfg.main
      data: data

    dash.detail = new dashboard do
      root: view.get('dash-detail')
      cfg: cfg.detail
      data: data

    dash.main.init!
    dash.main.on \select, ->
      ldcv.toggle!
      dash.detail.init!
