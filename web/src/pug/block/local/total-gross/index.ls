module.exports =
  meta: ->
    title: "總毛利", chart: {name: "number"}
  bind: (data) ->
    gross = data.reduce(((a,b) -> +b["季出貨量"] * 0.2 + a),0)
    return raw: [{value: gross, unit: "千元(估計)"}], binding: {value: {key: "value"}, unit: {key: "unit"}}
