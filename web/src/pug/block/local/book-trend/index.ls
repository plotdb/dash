module.exports =
  meta: ->
    title: "各季出版社出貨量趨勢", chart: {name: "line"}
    cfg: {
      mode: "streamgraph", show-dot: false
      legend: {selectable: false, enabled: false}
      line: \curve
      yaxis: enabled: false
    }
  bind: (data) ->
    order = Array.from(new Set( data.map -> "#{it['年']}/Q#{it['季']}" ))
    hash = {}
    data.map -> it <<< {"時段": "#{it['年']}/Q#{it['季']}"}
    data.map -> hash{}[it["時段"]][][it["出版社"]].push it
    names = []
    tops = []
    for k,v of hash =>
      for p,u of v =>
        names.push p
        v[p] = u.reduce(((a,b) -> a + +b["季出貨量"]),0)
    for k,v of hash =>
      list = [[p,u] for p,u of v]
      list.sort (a,b) -> b.1 - a.1
      list = list.map -> it.0
      tops ++= list.splice(0,1)
    tops = Array.from(new Set(tops))

    names = Array.from(new Set(names))
    data = [{k,v} for k,v of hash].map ({k,v}) -> v <<< {"時段": k}

    return raw: data, binding: {order: {key: "時段"}, value: tops.map(-> {key: it})}
