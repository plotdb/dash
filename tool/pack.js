// 把示範頁底下的兩樣東西編成套件要發出去的檔案:
//
//   web/src/styl/dash.styl                                  -> index.css / index.min.css
//   .../variation/vanilla/block/panel/0.0.1/index.pug       -> block/panel/index.html
//   .../variation/vanilla/block/filterbar/0.0.1/index.pug   -> block/filterbar/index.html
//
// 為什麼來源在示範頁底下: 這兩樣本來就是示範頁在用的那一份, 不是另外抄一份給套件.
// vanilla 的 panel block 是七個設計的共同起點 ( 其餘六份逐字相同, 只差一個 class 名 ),
// 所以它就是預設的 panel block - 複製一份當「套件版」只會變成兩份會各自長歪的東西.
//
// filter 的定義跟 @plotdb/srcbuild 的 pug builder 一致 ( dist/ext/pug.js ), 所以
// build 出來的跟 dev server 服務的是同一個東西.
const fs = require('fs');
const path = require('path');
const pug = require('pug');
const stylus = require('stylus');
const livescript = require('livescript');
const uglifyjs = require('uglify-js');
const uglifycss = require('uglifycss');

const root = path.join(__dirname, '..');
const p = (...xs) => path.join(root, ...xs);

const minjs = (code) => {
  const r = uglifyjs.minify(code, {compress: false});
  if (r.error) throw r.error;
  return r.code;
};

const styl = (text) => stylus(text)
  .set('filename', 'inline')
  .define('index', (a, b) => {
    a = (a.string || a.val).split(' ');
    return new stylus.nodes.Unit(a.indexOf(b.val));
  })
  .render();

const filters = {
  lsc: (text) => minjs(livescript.compile(text, {bare: true, header: false})),
  lson: (text) => livescript.compile(text, {bare: true, header: false, json: true}),
  stylus: (text) => uglifycss.processString(styl(text)),
};

// ---- index.css / index.min.css
const css = styl(fs.readFileSync(p('web/src/styl/dash.styl'), 'utf8'));
fs.writeFileSync(p('index.css'), css);
fs.writeFileSync(p('index.min.css'), uglifycss.processString(css));

// ---- block/*/index.html
//
// 取 vanilla 的那幾份: 它們的顏色只用 dash.css 的 --dash-* ( 其他設計各有自己的
// 一組變數 ), 所以宿主載了 index.css 就會長對, 不必再給一組變數.
const blocks = ['panel', 'filterbar'];
for (const b of blocks) {
  const src = p('web/src/pug/initiative/variation/vanilla/block', b, '0.0.1/index.pug');
  fs.mkdirSync(p('block', b), {recursive: true});
  fs.writeFileSync(p('block', b, 'index.html'), pug.renderFile(src, {filters, pretty: false}));
}

for (const f of ['index.css', 'index.min.css', ...blocks.map(b => `block/${b}/index.html`)]) {
  console.log(String(f).padEnd(24) + String(fs.statSync(p(f)).size).padStart(7) + ' bytes');
}
