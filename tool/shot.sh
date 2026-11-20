#!/bin/bash
#
# 入口頁 ( /initiative/variation/ ) 的縮圖是真的截圖, 不是 CSS 畫的.
# 這支把七個設計 × light / dark 各拍一張, 裁成 16:10 的一塊 ( 四五個 panel ),
# 存到 web/src/raw/assets/shot/.
#
# 用法: 先把 dev server 跑起來 ( npx server -r web -p 64500 ), 再跑這支.
#   ./tool/shot.sh [port]
#
# 拍完要重開 dev server: 圖是存在 web/src/raw/ 的, 而 raw 是開機時複製到
# web/static/ 的 - 不重開的話頁面上看到的還是上一輪的圖.
#
# 模式用網址的 ?mode=light|dark 指定 ( 見 variation/mode.ls ) - headless chrome
# 沒辦法先寫 localStorage, 也不方便改系統的 prefers-color-scheme.
set -e
PORT="${1:-64500}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="$(cd "$(dirname "$0")/.." && pwd)/web/src/raw/assets/shot"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# name:視窗寬:視窗高  ( pocket 用手機寬度, 它本來就只有一種寬度 )
TARGETS="vanilla:1440:900 desk:1440:900 report:1440:1100 wall:1440:900 pocket:520:900 terminal:1440:900 rail:1440:1100"

for t in $TARGETS; do
  name="${t%%:*}"; rest="${t#*:}"; w="${rest%%:*}"; h="${rest#*:}"
  for mode in light dark; do
    url="http://localhost:$PORT/initiative/variation/$name/?mode=$mode"
    # --force-prefers-reduced-motion: headless 只畫得出兩三格 frame, 進場動畫與
    # 數字補間會被截在半路. 頁面本來就該認這個設定 ( dash.css 與 KPI block 都認 ),
    # 所以這裡不是為了截圖開後門, 是走正門
    "$CHROME" --headless --disable-gpu --hide-scrollbars \
      --force-prefers-reduced-motion \
      --force-device-scale-factor=2 --window-size="$w,$h" \
      --virtual-time-budget=20000 \
      --screenshot="$TMP/$name-$mode.png" "$url" >/dev/null 2>&1
    echo "shot: $name-$mode"
  done
done

python3 "$(dirname "$0")/shot-crop.py" "$TMP" "$OUT"
echo "done -> $OUT"
