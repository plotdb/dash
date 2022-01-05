(function(){
  var tint;
  tint = function(opt){
    opt == null && (opt = {});
    this.isUnique = opt.unique != null ? opt.unique : true;
    this.map = {};
    this.nmap = [];
    this.wm = new WeakMap();
    this.count = 0;
    this.set(opt.palette) || opt.colors;
    return this;
  };
  tint['default'] = ['#e15c64', '#f7b26a', '#f3ed9d', '#a4bd81', '#a0d7d2', '#8db1da', '#daaedb'];
  tint.prototype = import$(Object.create(Object.prototype), {
    set: function(pal, reset){
      var ref$, this$ = this;
      pal == null && (pal = []);
      reset == null && (reset = false);
      this.colors = Array.isArray(pal) && pal.length
        ? pal
        : pal.colors && Array.isArray(pal.colors)
          ? pal.colors
          : tint['default'];
      this.nmap = pal.maps || [];
      this.colors = this.colors.map(function(it){
        return it.value || it;
      });
      if (this.colors.length === 1) {
        this.colors.push(ldcolor.complement(this.colors[0]));
      }
      this.colors = this.colors.map(function(it){
        return ldcolor.hsl(it);
      });
      this.len = (ref$ = this.colors.length) > 2 ? ref$ : 2;
      if (reset) {
        return this.reset();
      } else {
        return this.nmap.map(function(d, i){
          return (Array.isArray(d)
            ? d
            : [d]).map(function(it){
            return this$.get(it, 0, i);
          });
        });
      }
    },
    unique: function(it){
      return it != null
        ? this.isUnique = !!it
        : this.isUnique;
    },
    reset: function(){
      var this$ = this;
      this.map = {};
      this.wm = new WeakMap();
      this.count = 0;
      return (this.nmap || []).map(function(d, i){
        return (Array.isArray(d)
          ? d
          : [d]).map(function(it){
          return this$.get(it, 0, i);
        });
      });
    },
    get: function(data, variant, idx){
      var val, seg, pos, ref$, fz, fm, c1, c2, h, s, l, ret;
      variant == null && (variant = 0);
      if (idx != null) {
        if (this.count < idx) {
          this.count = idx + 1;
        }
        val = idx % this.len;
        if (typeof data === 'object') {
          this.wm.set(data, val);
        } else {
          this.map[data] = val;
        }
      } else {
        if (typeof data === 'object') {
          if ((val = this.wm.get(data)) == null) {
            this.wm.set(data, val = this.count++);
          }
        } else if ((val = this.map[data]) == null) {
          this.map[data] = val = this.count++;
        }
        if (!this.isUnique) {
          val = val % this.len;
        }
      }
      if (val >= this.len) {
        seg = val % (this.len - 1);
        pos = Math.floor(val / (this.len - 1));
        ref$ = [0, 1], fz = ref$[0], fm = ref$[1];
        while (pos > 0) {
          ref$ = [fz * 2, fm * 2], fz = ref$[0], fm = ref$[1];
          if (pos % 2) {
            fz += 1;
          }
          pos = pos >> 1;
        }
        pos = fz / fm;
        ref$ = [this.colors[seg], this.colors[seg + 1]], c1 = ref$[0], c2 = ref$[1];
        ref$ = ['h', 's', 'l'].map(function(k){
          return pos * (c2[k] - c1[k]) + c1[k];
        }), h = ref$[0], s = ref$[1], l = ref$[2];
        ret = {
          h: h,
          s: s,
          l: l
        };
      } else {
        ret = this.colors[val];
      }
      if (variant > 0) {
        ret = ldcolor.lighter(ret, variant);
      } else if (variant < 0) {
        ret = ldcolor.darker(ret, -variant);
      }
      return ldcolor.web(ret);
    },
    text: function(v, opt){
      var hcl;
      opt == null && (opt = {});
      hcl = ldcolor.hcl(this.get(v));
      return ldcolor.web(hcl.l > 50
        ? opt.textDark || '#000'
        : opt.textLight || '#fff');
    }
  });
  if (typeof chart != 'undefined' && chart !== null) {
    (chart.utils || (chart.utils = {})).tint = tint;
  }
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
