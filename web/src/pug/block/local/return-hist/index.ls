module.exports =
  meta: ->
    title: "退貨量分布", chart: {name: "bar"}
    cfg:
      legend: enabled: false
      yaxis: show-caption: false
      xaxis: show-caption: false
  bind: (data) ->
    ships = data.map(-> it["季退貨量"]).filter(->it > 0)
    min = Math.min.apply Math, ships
    max = Math.max.apply Math, ships
    mid = (max + min) / 2
    step = Math.ceil((max - min) / 10)
    steps = [0, 5, 10, 20, 40, 100, 500]
    bins = for i from 0 til steps.length - 1 => {key: steps[i + 1]}
    data.map (d) ->
      if d["季退貨量"] <= 0 => return
      for i from 0 til steps.length - 1=>
        if d["季退貨量"] < steps[i + 1] =>
          bins[i].value = (bins[i].value or 0) + 1
          break
    return raw: bins, binding: {size: [{name: "", key: "value"}], name: {name: "", key: "key"}}
