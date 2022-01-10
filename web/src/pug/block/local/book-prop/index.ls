module.exports =
  meta: ->
    title: "前一百名出貨書量佔比", chart: {name: "percent-list"}
    cfg:
      legend: enabled: false
      yaxis: show-caption: false
      xaxis: show-caption: false
  bind: (data) ->
    hash = {}
    data.map (o) -> hash[o["書名"]] = (hash[o["書名"]] or 0) + +o["季出貨量"]
    data = [{k,v} for k,v of hash].filter -> it.v
    data.sort (a,b) -> b.v - a.v
    data = data.splice 0, 100
    return raw: data, binding: {value: {key: "v"}, name: {key: "k"}}
