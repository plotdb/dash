# Change Logs

## master

 - upgrade charts: `@plotdb/chart` ^3.17.1, `bar` ^0.0.16, `line` ^0.0.11,
   `pie` ^0.0.6, `number` ^0.0.5, `taiwan-map` ^0.0.5, `twmapadv` ^0.0.7.
   all of these only add `desc` on config items and `mod.tabinfo` — no default
   or behaviour changed. they are dev / frontend dependencies, so nothing in the
   published package changes; this only affects the demo site

## v0.0.3

 - two more built-in themes: `pocket` and `rail`
 - theme: new `fit`, a sentence saying which layout a theme suits. it is prose for
   a human, not a setting — the board applies nothing from it
 - theme: `desc` and `fit` are now carried through to `board.theme` ( `desc` used
   to be dropped by the resolver, so a host could not show it )
 - `@makechart/pie` ^0.0.4: pie declares `interactions`, so its hints come from the
   declaration instead of a guess

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
