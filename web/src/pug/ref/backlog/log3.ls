<-(->it.apply {}) _

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

    dashboard =
      dim: col: 8, row: 4
      panels: [
        * x: 1, y: 1, w: 1, h: 1, name: "total-gross"
        * x: 2, y: 1, w: 1, h: 1, name: "sales-count"
        * x: 3, y: 1, w: 1, h: 1, name: "store-count"
        * x: 4, y: 1, w: 5, h: 1, name: "book-trend"
        * x: 1, y: 2, w: 2, h: 1, name: "ship-hist"
        * x: 1, y: 3, w: 2, h: 1, name: "return-hist"
        * x: 1, y: 4, w: 2, h: 1, name: "order-hist"
        * x: 3, y: 2, w: 3, h: 3, name: "book-prop"
        * x: 6, y: 2, w: 3, h: 3, name: "store-dist"
      ]

    view = new ldview do
      root: document.body
      init: detail: ({node}) ~> @ldcv = new ldcover root: node
      handler:
        dash: ({node}) ->
          dim = dashboard.dim
          node.style <<<
            gridTemplateColumns: "repeat(#{dim.col})"
            gridTemplateRows: "repeat(#{dim.row})"
        panel:
          list: -> dashboard.panels
          view:
            init: ->
            handler: "@": ({node, ctx, local}) ~>
              p = if !local.bi =>
                @bc.create!then (bi) ~>
                  local.bi = bi
                  bi.attach {root: node, data: {meta: ctx, data}}
                    .then -> bi.interface!
                    .then ~>
                      local.itf = it
                      local.itf.on \select, ~> @ldcv.toggle!
              else Promise.resolve!
              p.then ->
                node.style <<<
                  gridArea: "#{ctx.y} / #{ctx.x} / span #{ctx.h} / span #{ctx.w}"

