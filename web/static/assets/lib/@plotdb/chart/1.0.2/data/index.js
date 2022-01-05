(function(){
  var randFname, generate;
  randFname = function(){
    return "...";
  };
  generate = function(count, binding){
    var gen, fields, idx, k, v, u, keys, i$, i, ret, hint, name, value, range;
    gen = {
      raw: [],
      binding: {}
    };
    fields = {};
    idx = 0;
    for (k in binding) {
      v = binding[k];
      u = Array.isArray(v)
        ? v
        : [v];
      keys = u.map(fn$);
      if (Array.isArray(v)) {
        gen.binding[k] = keys.map(fn1$);
      } else {
        gen.binding[k] = {
          key: fields[keys[0]].key
        };
      }
    }
    for (i$ = 0; i$ < count; ++i$) {
      i = i$;
      for (k in fields) {
        v = fields[k];
        ret = {};
        hint = v.hint;
        name = v.key;
        value = "...";
        switch (hint.type) {
        case 'R':
          range = hint.range || [0, 1];
          value = Math.round(Math.random() * (range[1] - range[0]) + range[0]);
          break;
        case 'N':
          value = ['A', 'B', 'C', 'D', 'E'][Math.floor(Math.random() * 5)];
        }
        ret[v.key] = value;
      }
      gen.raw.push(ret);
    }
    return gen;
    function fn$(it){
      fields[idx] = {
        key: randFname(),
        hint: it
      };
      return idx++;
    }
    function fn1$(it){
      return {
        key: fields[it].key
      };
    }
  };
  generate(10, {
    height: [0, 1, 2, 3].map(function(){
      return {
        type: 'R',
        range: [0, 10]
      };
    }),
    name: {
      type: 'N'
    }
  });
}).call(this);
