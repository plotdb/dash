module.exports =
  pkg: {}
  init: ({root, data, manager}) ->
    @data = data.data
    manager.get {name: "local/#{data.meta.name}"}
      .then (bc) -> bc.init!then -> bc.interface
      .then (itf) ~>
        meta = itf.meta!
        @view = view = new ldview do
          root: root
          text:
            head: -> meta.title or '-'
          handler:
            body: ({node, local}) ~>
              if !meta.chart => return
              p = if local.chart => Promise.resolve(local.chart)
              else
                manager.get {version: "0.0.1"} <<< meta.chart
                  .then (bc) ->
                    bc.create {data: {delay-render: false}}
                  .then (bi) ->
                    bi.attach {root: node} .then -> bi.interface!
                  .then ->
                    local.chart = it
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
