# Change Logs

## v0.0.2

 - add `README.md`, `CHANGELOG.md` and package metadata ( author, repository )
 - add `npm run release`: build, then publish to npm and GitHub release
 - doc: state which two files a host should load, and that `web/static/` is a dev
   server artifact which is neither versioned nor published

## v0.0.1

 - init release
 - `dash.board`: panel lifecycle, crossfilter, grid / split layout
 - `dash.driver` / `dash.query` / `dash.fields` / `dash.spec` / `dash.dump` / `dash.load`
 - themes: `vanilla` / `desk` / `report` / `wall` / `terminal`, with `board.setTheme`
   and `board.setMode`
 - panel cards derive interaction hints from `chart.interactions()`
 - build output moved to `dist/`, flattened to the package root on publish
