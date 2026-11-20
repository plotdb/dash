#!/usr/bin/env node
//
// 產生 web/src/raw/assets/data/sales-town.json
//
// 跟 sales.json 是同一份資料, 只是每一列再拆到鄉鎮 ( 多一個 town 欄位 )。
// 拆法用最大餘數法, 所以**每一個彙總都跟 sales.json 完全一樣**:
// 總銷售額 3,765 萬、總冊數 105,641、各地區 / 書系 / 通路 / 月份的數字都對得上。
// 這樣兩份資料可以交互參照, 示範頁講的數字也不必各講一套。
//
// 鄉鎮名取自 pdmaptw 的 town.map.js ( 與地圖同一個來源, 所以名字一定對得上 ),
// 每個縣市取前六個, 權重固定 - 地圖上的分布才不會每次產生都不一樣。
//
//   node tool/gen-sales-town.js
//
const fs = require('fs'), path = require('path')

const root = path.join(__dirname, '..')
const rows = JSON.parse(fs.readFileSync(path.join(root, 'web/src/raw/assets/data/sales.json')))

// ---- 從 pdmaptw 讀出各縣市的鄉鎮
let topo = null
const pdmaptw = {register: (n, o) => { topo = o }}
eval(fs.readFileSync(path.join(root, 'node_modules/pdmaptw/town.map.js'), 'utf8'))
const names = JSON.parse(fs.readFileSync(path.join(root, 'node_modules/pdmaptw/town.meta.json'))).name
const byCounty = {}
for (const g of topo.topo.objects.pdmaptw.geometries) {
  const c = names[g.properties.c], t = names[g.properties.t]
  ;(byCounty[c] = byCounty[c] || []).push(t)
}

const WEIGHTS = [0.30, 0.22, 0.17, 0.13, 0.10, 0.08]
const towns = {}
for (const c of Object.keys(byCounty)) towns[c] = [...new Set(byCounty[c])].slice(0, WEIGHTS.length)

// 最大餘數法: 分完之後總和一定等於 total
const split = (total, weights) => {
  const raw = weights.map(w => total * w)
  const out = raw.map(Math.floor)
  let rest = total - out.reduce((a, b) => a + b, 0)
  const order = raw.map((v, i) => [v - Math.floor(v), i]).sort((a, b) => b[0] - a[0])
  for (let k = 0; k < rest; k++) out[order[k % order.length][1]]++
  return out
}

const out = []
for (const r of rows) {
  const list = towns[r.region]
  if (!list) { out.push(r); continue }
  const w = WEIGHTS.slice(0, list.length)
  const qty = split(r.qty, w)
  // 金額依分到的冊數再分一次: 冊數是 0 的鄉鎮金額也會是 0, 不會出現「沒賣書卻有營收」
  const sum = qty.reduce((a, b) => a + b, 0)
  const amount = split(r.amount, sum ? qty.map(q => q / sum) : w)
  list.forEach((town, i) => {
    if (!qty[i] && !amount[i]) return
    // full 是「縣市 + 鄉鎮」( 臺北市大安區 ): 地圖認這種寫法, 而且因為它是真的欄位,
    // crossfilter 才接得起來 - 用 groupby function 現算的話, filter 發出來的值
    // 在 rows 裡找不到對應的欄位
    out.push({month: r.month, region: r.region, town, full: r.region + town,
              category: r.category, channel: r.channel, qty: qty[i], amount: amount[i]})
  })
}

const dest = path.join(root, 'web/src/raw/assets/data/sales-town.json')
fs.writeFileSync(dest, JSON.stringify(out))

// ---- 自我檢查: 彙總必須跟 sales.json 一致
const sum = (xs, f) => xs.reduce((a, b) => a + f(b), 0)
const chk = (name, f) => {
  const [a, b] = [sum(rows, f), sum(out, f)]
  console.error(`${name}: ${a} vs ${b} ${a === b ? 'ok' : '不一致!'}`)
  if (a !== b) process.exitCode = 1
}
chk('總冊數', r => r.qty)
chk('總金額', r => r.amount)
for (const g of ['臺北市', '花蓮縣'])
  chk(`${g} 金額`, r => r.region === g ? r.amount : 0)
console.error(`${out.length} rows ( 原本 ${rows.length} ) -> ${path.relative(process.cwd(), dest)}`)
