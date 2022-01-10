module.exports =
  meta: ->
    title: "出貨書目數", chart: {name: "number"}
  bind: (data) ->
    gross = data.reduce(((a,b) -> +b["季出貨量"] + a),0)
    return raw: [{value: gross, unit: "本"}], binding: {value: {key: "value"}, unit: {key: "unit"}}
