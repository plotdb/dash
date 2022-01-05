<-(->it.apply {}) _

mgr = window.manager = new block.manager registry: ({name, version, path, type}) ->
  if name in <[line pie bar bubble base number bar taiwancounty percent-list]> => return "/assets/chart/#name/#version/#{path or 'index.html'}"
  if /^d3/.exec(name) => return "/assets/lib/#name/main/#path"
  root = if type == \block => '/block' else '/assets/lib'
  "#root/#{name}/#{version}/#{path or (if type == 'block' => 'index.html' else 'index.min.js')}"
mgr.init!
  .then ->
    mgr.get({name: "panel", version: "0.0.1"})
  .then (bc) ~> @bc = bc
  .then ~>

    dashboard =
      dim: col: 8, row: 4
      panels: [
        * x: 1, y: 1, w: 1, h: 1, data: { title: "總毛利", chart: {name: "number"} }
        * x: 2, y: 1, w: 1, h: 1, data: {title: "出貨書目數", chart: {name: "number"}}
        * x: 3, y: 1, w: 1, h: 1, data: {title: "獨立書店總數", chart: {name: "number"}}
        * x: 4, y: 1, w: 5, h: 1,
          data: {
            title: "排行"
            chart: {name: "line"}
            cfg: {
              mode: "streamgraph", show-dot: false, legend: {selectable: false}
              line: \curve
              yaxis: enabled: false
            }
          }
        * x: 1, y: 2, w: 2, h: 1
          data: {
            title: "出貨量分布", chart: {name: "bar"}
            cfg: { legend: enabled: false }
          }
        * x: 1, y: 3, w: 2, h: 1
          data: {
            title: "退貨量分布", chart: {name: "bar"}
            cfg: { legend: enabled: false }
          }
        * x: 1, y: 4, w: 2, h: 1
          data: {
            title: "客訂量分布", chart: {name: "bar"}
            cfg: { legend: enabled: false }
          }
        * x: 3, y: 2, w: 3, h: 3
          data: {
            title: "出貨書量佔比", chart: {name: "percent-list"}
            cfg: { legend: enabled: false }
          }
        * x: 6, y: 2, w: 3, h: 3, data: {title: "熱度地圖", chart: {name: "taiwancounty"}}
      ]

      panels-alt: [
        * x: 1, y: 1, w: 1, h: 1, data: {title: "test title", chart: {name: "number"}}
        * x: 2, y: 1, w: 1, h: 1, data: {title: "test title", chart: {name: "number"}}
        * x: 3, y: 1, w: 1, h: 1, data: {title: "test title", chart: {name: "number"}}
        * x: 4, y: 1, w: 3, h: 1, data: {title: "test title", chart: {name: "line"}}
        * x: 7, y: 1, w: 2, h: 1, data: {}
        * x: 1, y: 2, w: 2, h: 1, data: {}
        * x: 1, y: 3, w: 2, h: 1, data: {}
        * x: 1, y: 4, w: 2, h: 1, data: {}
        * x: 3, y: 2, w: 3, h: 3, data: {}
        * x: 6, y: 2, w: 3, h: 1, data: {}
        * x: 6, y: 3, w: 3, h: 2, data: {}
      ]

    view = new ldview do
      root: document.body
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
                @bc.create!then (bi) ->
                  local.bi = bi
                  bi.attach {root: node, data: ctx}
                    .then -> bi.interface!
                    .then -> local.itf = it
              else Promise.resolve!
              p.then ->
                node.style <<<
                  gridArea: "#{ctx.y} / #{ctx.x} / span #{ctx.h} / span #{ctx.w}"

