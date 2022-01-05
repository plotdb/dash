(function(){
  var tip, ref$;
  tip = function(opt){
    var ref$, this$ = this;
    opt == null && (opt = {});
    this.root = typeof opt.root === 'string'
      ? document.querySelector(opt.root)
      : opt.root;
    this.tip = typeof opt.node === 'string'
      ? this.root.querySelector(opt.node)
      : opt.node;
    this.margin = opt.margin != null ? opt.margin : 10;
    this.type = opt.type === 'over' ? 'over' : 'move';
    this.accessor = opt.accessor;
    this.range = opt.range;
    this.zmgr = opt.zmgr;
    this._z = 0;
    this.enabled = true;
    if (!this.tip) {
      this.tip = document.createElement('div');
      this.tip.innerHTML = "<div ld=\"name\" style=\"font-size:.85em\"></div>\n<div ld=\"value\" style=\"font-weight:bold;font-size:1.1em;line-height:1.2em\"></div>";
      this.root.appendChild(this.tip);
      ref$ = this.tip.style;
      ref$.padding = '.4em .5em';
      ref$.background = '#13171a';
      ref$.color = '#fff';
      ref$.borderRadius = '3px';
      ref$.boxShadow = '0 2px 4px rgba(0,0,0,.3)';
      ref$.lineHeight = '1.2em';
      ref$.fontSize = '.9em';
      ref$.maxWidth = "10em";
      ref$.wordBreak = "break-all";
    }
    ref$ = this.tip.style;
    ref$.position = 'absolute';
    ref$.zIndex = 1;
    ref$.top = 0;
    ref$.left = 0;
    ref$.pointerEvents = 'none';
    ref$.userSelect = 'none';
    ref$.opacity = 0;
    ref$.transition = 'opacity .15s ease-in-out' + (this.type === 'over' ? ', transform .15s ease-in-out' : '');
    this.view = new ldview({
      root: this.tip,
      text: opt.view || {
        name: function(arg$){
          var ctx;
          ctx = arg$.ctx;
          if (ctx) {
            return ctx.name;
          } else {
            return '';
          }
        },
        value: function(arg$){
          var ctx;
          ctx = arg$.ctx;
          if (ctx) {
            return ctx.value;
          } else {
            return '';
          }
        }
      }
    });
    this.hide = debounce(3000, function(){
      this.tip.style.opacity = 0;
      if (this.zmgr) {
        return this.zmgr.remove(this._z);
      }
    });
    this._evthdr = {};
    if (this.accessor) {
      this.root.addEventListener(this.type === 'over' ? 'mouseover' : 'mousemove', this._evthdr.over = function(e){
        var data;
        if (!(e.target && (data = this$.accessor({
          evt: e
        })))) {
          return;
        }
        return this$.render({
          data: data,
          node: e.target,
          evt: e
        });
      });
      this.root.addEventListener('mouseout', this._evthdr.out = function(){
        return this$.hide().now();
      });
    }
    return this;
  };
  tip.prototype = (ref$ = Object.create(Object.prototype), ref$.destroy = function(){
    if (this._evthdr.over) {
      this.root.removeEventListener(this.type === 'over' ? 'mouseover' : 'mousemove', this._evthdr.over);
    }
    if (this._evthdr.out) {
      return this.root.removeEventListener('mouseout', this._evthdr.out);
    }
  }, ref$.toggle = function(it){
    return !(it != null)
      ? this.enabled
      : this.enabled = it;
  }, ref$.render = function(opt){
    var rbox, nbox, ret, tbox, ref$, mx, my, m, nx, ny, tx, ty, rangeBox, ref1$, ref2$;
    opt == null && (opt = {});
    if (!this.enabled) {
      return;
    }
    this.view.setCtx(opt.data);
    this.view.render();
    rbox = this.root.getBoundingClientRect();
    nbox = opt.node != null
      ? (ret = opt.node.getBoundingClientRect(), ret.x = ret.x - rbox.x, ret.y = ret.y - rbox.y, ret)
      : opt.box != null
        ? opt.box
        : {
          x: opt.x,
          y: opt.y,
          width: opt.width,
          height: opt.height
        };
    tbox = this.tip.getBoundingClientRect();
    ref$ = [opt.evt.clientX - rbox.x, opt.evt.clientY - rbox.y], mx = ref$[0], my = ref$[1];
    m = this.margin;
    ref$ = [nbox.x + (nbox.width != null ? nbox.width / 2 : 0), nbox.y + (nbox.height != null ? nbox.height / 2 : 0)], nx = ref$[0], ny = ref$[1];
    ref$ = [mx - tbox.width / 2, my - tbox.height / 2], tx = ref$[0], ty = ref$[1];
    ref$ = [
      tx + (nx < mx
        ? 1
        : -1) * (m + tbox.width / 2), ty + (ny < my
        ? 1
        : -1) * (m + tbox.height / 2)
    ], tx = ref$[0], ty = ref$[1];
    rangeBox = this.range ? rangeBox = this.range() : rbox;
    ref$ = [((ref$ = (tx > (ref2$ = rangeBox.x - rbox.x) ? tx : ref2$) + tbox.width) < (ref1$ = rangeBox.width + rangeBox.x - rbox.x) ? ref$ : ref1$) - tbox.width, ((ref$ = (ty > (ref2$ = rangeBox.y - rbox.y) ? ty : ref2$) + tbox.height) < (ref1$ = rangeBox.height + rangeBox.y - rbox.y) ? ref$ : ref1$) - tbox.height], tx = ref$[0], ty = ref$[1];
    ref$ = this.tip.style;
    ref$.transform = "translate(" + tx + "px," + ty + "px)";
    ref$.opacity = 1;
    ref$.zIndex = this._z = !this.zmgr
      ? 10
      : this.zmgr.add(10);
    return this.hide();
  }, ref$);
  if (typeof chart != 'undefined' && chart !== null) {
    (chart.utils || (chart.utils = {})).tip = tip;
  }
}).call(this);
