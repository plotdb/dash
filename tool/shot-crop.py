#!/usr/bin/env python3
# 把 tool/shot.sh 拍下來的整頁截圖裁成入口頁用的縮圖.
#
# 每一個設計裁的位置不一樣, 因為它們的版面本來就不一樣: 滿版的那幾個裁左上角,
# 版心置中的 ( report ) 要往中間移, 側欄的 ( rail ) 要連左邊那一欄一起裁.
# 目標是看得到四五個 panel - 夠看出風格, 又不會小到看不清楚.
#
# 參數是 ( x, y, 寬 ) 的比例, 高度由 16:10 推出來.
import sys, os
from PIL import Image

# 每一版從哪裡開始裁都是各自調的: report 是版心置中的, 所以要往中間移;
# pocket 本來就只有一種寬度, 整張拍.
#
# vanilla 一度從 KPI 那一列底下開始裁, 因為 @makechart/number 的數字跑動
# 在套件裡面關不掉, headless 截到的是跑到一半的數字. 0.0.3 之後它認
# prefers-reduced-motion 了, 所以改回從頭拍.
BOX = {
    'vanilla':  (0.00, 0.00, 0.80),
    'desk':     (0.00, 0.00, 0.60),
    'report':   (0.09, 0.05, 0.60),
    'wall':     (0.00, 0.00, 0.58),
    'pocket':   (0.00, 0.00, 1.00),
    'terminal': (0.00, 0.00, 0.60),
    'rail':     (0.00, 0.00, 0.62),
}
WIDTH = 900          # 縮圖在入口頁上最大就是一欄的寬度, 900 夠用也夠小
QUALITY = 80

src, dst = sys.argv[1], sys.argv[2]
for f in sorted(os.listdir(src)):
    if not f.endswith('.png'):
        continue
    name, mode = f[:-4].rsplit('-', 1)
    im = Image.open(os.path.join(src, f)).convert('RGB')
    W, H = im.size
    fx, fy, fw = BOX[name]
    x, y = int(W * fx), int(H * fy)
    w = int(W * fw)
    h = int(w * 10 / 16)
    if y + h > H:                      # 裁不到那麼下面就往上收
        y = max(0, H - h)
    im = im.crop((x, y, x + w, y + h)).resize((WIDTH, WIDTH * 10 // 16), Image.LANCZOS)
    out = os.path.join(dst, '%s-%s.jpg' % (name, mode))
    im.save(out, 'JPEG', quality=QUALITY, optimize=True, progressive=True)
    print('%-18s %5d x %-5d -> %s' % (f, w, h, os.path.basename(out)))
