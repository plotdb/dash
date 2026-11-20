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
const out = [];

const pack = (design, b, dst) => {
  const src = p('web/src/pug/initiative/variation', design, 'block', b, '0.0.1/index.pug');
  fs.mkdirSync(path.dirname(p(dst)), {recursive: true});
  fs.writeFileSync(p(dst), pug.renderFile(src, {filters, pretty: false}));
  out.push(dst);
};

for (const b of blocks) pack('vanilla', b, `block/${b}/index.html`);

// ---- 內建主題的 block
//
// 一個主題不只是顏色: 有沒有卡片、是 1px 的框還是 3px 的縫, 是 pug 的結構,
// CSS 變數搆不到. 所以主題要帶自己的 block ( theme/<name>.json 的 blocks 指到
// 這裡 ). vanilla 不在這裡面 - 它用的就是上面那組預設的, 不必出兩份.
const themed = {desk: ['panel', 'kpi', 'filterbar']};
for (const [design, bs] of Object.entries(themed)) {
  for (const b of bs) pack(design, b, `block/${b}/${design}/index.html`);
}

// ---- theme/*.json
//
// 主題的本體也在 web/src 底下 ( web/src/raw/theme/ ): dev server 服務的那一份
// 就是套件發出去的那一份, 示範頁改一個顏色不必再 build 一次.
for (const f of fs.readdirSync(p('web/src/raw/theme'))) {
  if (!f.endsWith('.json')) continue;
  fs.mkdirSync(p('theme'), {recursive: true});
  // 順便驗一次: 壞掉的 JSON 在這裡爆, 比在瀏覽器裡爆容易找
  const text = fs.readFileSync(p('web/src/raw/theme', f), 'utf8');
  JSON.parse(text);
  fs.writeFileSync(p('theme', f), text);
  out.push(`theme/${f}`);
}

for (const f of ['index.css', 'index.min.css', ...out]) {
  console.log(String(f).padEnd(30) + String(fs.statSync(p(f)).size).padStart(7) + ' bytes');
}
