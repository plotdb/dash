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

# vanilla 從 KPI 那一列底下開始裁: 它的 KPI 是 @makechart/number, 數字會從 0
# 跑上來, 而 headless 只畫得出兩三格 frame, 截到的會是一個跑到一半的數字.
# ( 真的瀏覽器裡 0.5 秒就跑完, 所以這只是截圖的問題 ) 底下那四張圖一樣講得完它的風格
BOX = {
    'vanilla':  (0.00, 0.26, 0.60),
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
