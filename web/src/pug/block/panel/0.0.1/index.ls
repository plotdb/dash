module.exports =
  pkg:
    dependencies: [
      {name: "bootstrap.native", version: "main", path: "dist/bootstrap-native-v4.min.js"}
    ]
      
  init: ({root, data, manager, context}) ->
    @data = data.data
    @evt-handler = {}
    {BSN} = context
    manager.get {name: "local/#{data.meta.name}"}
      .then (bc) -> bc.init!then -> bc.interface
      .then (itf) ~>
        meta = itf.meta!
        @view = view = new ldview do
          root: root
          text:
            head: -> meta.title or '-'
          init:
            dropdown: ({node}) -> new BSN.Dropdown(node)
          handler:
            "diff-root": ({node}) ->
              node.style.display = if meta.chart.name == \number => '' else \none
            diff: ({node}) ->
              v = (10 * Math.random! - 5)
              node.classList.toggle \text-danger, (v < 0)
              node.classList.toggle \text-success, (v > 0)
              node.innerText = (v).toFixed(1) + "%"
            body: ({node, local}) ~>
              if !meta.chart => return
              p = if local.chart => Promise.resolve(local.chart)
              else
                manager.get {version: "0.0.1"} <<< meta.chart
                  .then (bc) -> bc.create {data: {delay-render: false}}
                  .then (bi) -> bi.attach {root: node} .then -> bi.interface!
                  .then (chart) ~>
                    local.chart = chart
                    if itf.init => itf.init {chart, base: @}
                    chart
              p.then (chart) ~>
                if meta.cfg => chart.config meta.cfg
                if meta.raw => chart.set-raw meta{raw, binding}
                else if itf.bind => chart.set-raw itf.bind @data
                chart.parse!
                chart.bind!
                chart.resize!
                chart.render!
  render: ({data}) ->
    @data = data
    @view.render!
  interface: -> @
  on: (n, cb) -> (if Array.isArray(n) => n else [n]).map (n) ~> @evt-handler.[][n].push cb
  fire: (n, ...v) -> for cb in (@evt-handler[n] or []) => cb.apply @, v

