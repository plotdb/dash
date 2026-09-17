#!/usr/bin/env bash
#
# 把本地改動的 chart 程式碼蓋到 web/static/assets/lib/。
#
# 正式安裝走 fedep ( npm 版本 )，這支只給「改了還沒發版」的開發期用；
# 下一次 npx fedep 會把覆蓋還原回 npm 版。
#
#   ./tool/sync-charts.sh base bar pie      # makechart/charts/<name>
#   ./tool/sync-charts.sh chart             # projects/chart ( @plotdb/chart, 含 utils )
#
set -e
src=${MAKECHART:-../../../makechart/charts}
chartsrc=${PLOTDBCHART:-../chart}
root=$(cd "$(dirname "$0")/.." && pwd)
for n in "$@"; do
  if [ "$n" = "chart" ]; then
    ( cd "$chartsrc" && ./build > /dev/null )
    cp -R "$chartsrc/dist/." "$root/web/static/assets/lib/@plotdb/chart/main/"
    echo "synced @plotdb/chart"
  else
    ( cd "$src/$n" && ./build > /dev/null )
    cp "$src/$n/dist/index.html" "$root/web/static/assets/lib/@makechart/$n/main/index.html"
    echo "synced @makechart/$n"
  fi
done
