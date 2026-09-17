module.exports =
  meta: ->
    title: "獨立書店分布", chart: {name: "taiwancounty"}
    cfg:
      palette: colors: <[#000 #09b #9ff]>
      legend: enabled: false
      yaxis: show-caption: false
      xaxis: show-caption: false
  bind: (data) ->
    return
      raw: ["連江縣","宜蘭縣","彰化縣","南投縣","雲林縣","基隆市","臺北市","新北市","臺中市","臺南市","桃園市","苗栗縣",">嘉義市","嘉義縣","金門縣","高雄市","臺東縣","花蓮縣","澎湖縣","新竹市","新竹縣","屏東縣"].map -> {name: it, value: Math.round(Math.random! * 100)}
      binding: {name: {key: "name"}, color: {key: "value"}}
