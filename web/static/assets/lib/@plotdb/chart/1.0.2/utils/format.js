(function(){
  var format;
  format = {};
  format.auto = function(list){
    var s, intRate, diffs, i, diffAvg, type, size;
    list == null && (list = []);
    return d3.format(".3s");
    list = list.map(function(it){
      return +it;
    }).filter(function(it){
      return !isNaN(it);
    });
    if (!list.length) {
      return d3.format("d");
    }
    list.sort(function(a, b){
      return a - b;
    });
    s = Math.max.apply(Math, list.map(function(it){
      var s, ref$;
      s = 1;
      while (it) {
        if (it % 10) {
          break;
        }
        it = Math.floor(it / 10);
        s++;
      }
      return (ref$ = Math.ceil(Math.log(it || 1) / Math.log(10) - s)) > 0 ? ref$ : 0;
    }));
    intRate = list.filter(function(it){
      return Math.floor(it) === it;
    }).length / list.length;
    diffs = (function(){
      var i$, to$, results$ = [];
      for (i$ = 1, to$ = list.length; i$ < to$; ++i$) {
        i = i$;
        results$.push(Math.abs(list[i] - list[i - 1]));
      }
      return results$;
    }()).map(function(it){
      return Math.log(it ? it : 1) / Math.log(10);
    });
    diffAvg = diffs.reduce(function(a, b){
      return a + b;
    }, 0) / list.length;
    type = intRate > 0.9 ? "s" : "f";
    size = diffAvg >= 0
      ? s > 0 ? s : 0
      : Math.ceil(Math.abs(diffAvg));
    return d3.format("." + size + type);
  };
  format.simple = function(v){
    if (isNaN(v = +v)) {
      return v;
    }
    return v >= 1000000000
      ? (v / 1000000000).toFixed(0) + "G"
      : v >= 1000000
        ? (v / 1000000).toFixed(0) + "M"
        : v >= 1000
          ? (v / 1000).toFixed(0) + "K"
          : Math.floor(v) === v
            ? v.toFixed(0)
            : v.toFixed(2);
  };
  if (typeof chart != 'undefined' && chart !== null) {
    (chart.utils || (chart.utils = {})).format = format;
  }
}).call(this);
