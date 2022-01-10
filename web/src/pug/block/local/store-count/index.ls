module.exports =
  meta: ->
    title: "獨立書店總數", chart: {name: "number"}
  bind: (data) ->
    return raw: [{value:"475", unit: "間"}], binding: {value: {key: "value"}, unit: {key: "unit"}}
