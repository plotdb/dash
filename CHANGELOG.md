# Change Logs

## v0.0.5

 - theme: `def.theme.tokens` can now be split per mode, the same shape the theme's
   own `tokens` already had — `light` / `dark` are that mode's own, every other key
   is shared by both. merge order, later wins:

       theme tokens.common → theme tokens[mode] → user's shared → user's tokens[mode]

   `mode: 'auto'` resolves through `prefers-color-scheme` first and uses the mode it
   resolved to, re-resolving when the system flips. a def with flat tokens only keeps
   working exactly as before. the point: one palette that lands well on a light
   background does not land well on a dark one — the paper and text colours in
   particular could not be exposed to the user at all until now
 - theme: the resolved theme carries `baseTokens`, the theme's own `tokens` before
   resolution ( still split into `common` / `light` / `dark` ). a UI that recolours a
   theme for the user needs both modes' source values, not just the current mode's
 - note: `light` / `dark` can no longer be used as ordinary token names in
   `def.theme.tokens`. they were never available in a theme's own `tokens` either

## v0.0.4

 - i18n: every UI string in the built-in blocks ( filterbar, panel, kpi ) now goes
   through `@plotdb/block`'s native i18n, with `en` and `zh-TW` tables in each
   block's `pkg.i18n`. keys are the English source text, so a missing translation
   shows English rather than a key
 - new `lng` option on `dash.board`, plus `dash.lng(l)` / `board.setLng(l)`.
   **the default language is `en`** — language is the host's call. a dashboard that
   wants Chinese says so ( dash's own demo pages now pass `lng: 'zh-TW'` )
 - changing the language keeps filters and layout: static text re-translates itself
   ( blocks are attached with `autoTransform: 'i18n'` ), JS-composed text follows a
   `render`, and the filterbar rebuilds its controls because a few of its strings
   are written once at build time
 - `dash.text` without a locale now reads the current language instead of always
   `zh-TW`. hosts that pass a locale explicitly are unaffected

 - theme: rewrite `vanilla`'s `desc`. `desc` / `fit` are read by whoever is picking a
   theme in a host's theme menu, not by a developer, so they say what a theme looks
   like and what it suits — file names and CSS variables belong in the README. if one
   has to be mentioned, it now says plainly that it only matters when embedding
   `@plotdb/dash` yourself

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
