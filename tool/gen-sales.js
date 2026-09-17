#!/usr/bin/env node
//
// 產生 web/src/raw/assets/data/sales.json ( 12 月 × 6 地區 × 4 書系 × 3 通路 = 864 列 )。
//
// 重點是各維度之間要「有關聯」: 每個地區的通路結構不同、每個通路的書系結構也不同。
// 三個維度互相獨立的話, 對比模式下每一塊被選中的比例都會長得一樣, 看起來像壞掉。
//
//   node tool/gen-sales.js
//
const fs = require('fs'), path = require('path')

const months = Array.from({length: 12}, (_, i) => `2024/${String(i + 1).padStart(2, '0')}`)
const regions = ['臺北市', '新北市', '臺中市', '臺南市', '高雄市', '花蓮縣']
const categories = ['文學', '人文社科', '藝術設計', '生活風格']
const channels = ['門市', '網路', '寄售']

// 地區規模
const scale = {臺北市: 1.00, 新北市: 0.70, 臺中市: 0.55, 臺南市: 0.45, 高雄市: 0.45, 花蓮縣: 0.20}

// 通路結構: 都會區網路強, 花蓮以寄售為主
const chMix = {
  臺北市: {門市: 0.42, 網路: 0.48, 寄售: 0.10},
  新北市: {門市: 0.45, 網路: 0.45, 寄售: 0.10},
  臺中市: {門市: 0.55, 網路: 0.34, 寄售: 0.11},
  臺南市: {門市: 0.62, 網路: 0.25, 寄售: 0.13},
  高雄市: {門市: 0.58, 網路: 0.29, 寄售: 0.13},
  花蓮縣: {門市: 0.40, 網路: 0.18, 寄售: 0.42},
}

// 書系結構: 依通路而不同 - 藝術設計偏網路, 生活風格偏寄售
const catMix = {
  門市: {文學: 0.38, 人文社科: 0.26, 藝術設計: 0.12, 生活風格: 0.24},
  網路: {文學: 0.27, 人文社科: 0.22, 藝術設計: 0.33, 生活風格: 0.18},
  寄售: {文學: 0.30, 人文社科: 0.14, 藝術設計: 0.10, 生活風格: 0.46},
}

// 單價: 藝術設計貴, 人文社科次之
const price = {文學: 320, 人文社科: 380, 藝術設計: 560, 生活風格: 300}

// 季節性: 年初書展、年中緩、年末禮物季
const season = [1.18, 1.05, 1.22, 1.10, 1.04, 0.96, 0.92, 0.88, 0.82, 0.86, 0.94, 1.12]

// 固定 seed, 產出可重現
let seed = 20240101
const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648

const base = 2600   // 每月每地區的基準冊數
const rows = []
for (let m = 0; m < months.length; m++) {
  for (const region of regions) {
    for (const channel of channels) {
      for (const category of categories) {
        const share = scale[region] * chMix[region][channel] * catMix[channel][category]
        const qty = Math.round(base * share * season[m] * (0.85 + 0.3 * rnd()))
        if (!qty) continue
        const p = price[category] * (0.9 + 0.2 * rnd()) * (channel === '網路' ? 0.88 : 1)
        rows.push({
          month: months[m], region, category, channel,
          qty,
          amount: Math.round(qty * p),
          stores: Math.max(1, Math.round(scale[region] * 14 * (channel === '門市' ? 1 : 0.4))),
        })
      }
    }
  }
}

const out = path.join(__dirname, '..', 'web/src/raw/assets/data/sales.json')
fs.writeFileSync(out, JSON.stringify(rows))
console.error(`${rows.length} rows -> ${path.relative(process.cwd(), out)}`)
