dashboard =
  grid:
    col: <[1fr 1fr 1fr 2fr 1fr 2fr]>
    row: <[2fr 2fr 2fr 2fr]>
  panels: [
    * row: [1,1], col: [1,1]
    * row: [1,1], col: [2,1]
    * row: [1,1], col: [3,1]
    * row: [1,1], col: [4,2]
    * row: [2,1], col: [5,2]
    * row: [3,2], col: [5,2]
    * row: [2,3], col: [3,2]
    * row: [2,1], col: [1,2]
    * row: [3,1], col: [1,2]
    * row: [4,1], col: [1,2]
  ]

view = new ldview do
  root: document.body
  handler:
    dash: ({node}) ->
      grid = dashboard.grid
      node.style <<<
        gridTemplateColumns: grid.col.join(' ')
        gridTemplateRows: grid.row.join(' ')
    panel:
      list: -> dashboard.panels
      view:
        handler: "@": ({node, ctx}) ->
          node.style <<<
            gridColumn: "#{ctx.col.0} / span #{ctx.col.1}"
            gridRow: "#{ctx.row.0} / span #{ctx.row.1}"

