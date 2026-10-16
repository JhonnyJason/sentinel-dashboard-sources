# seasonalityblocksmodule

Bar chart below the seasonality chart (`#seasonality-blocks`, the lower 260px of `#chart-container`): average % change per block, min / max as dots.

- `setData(chartData)`: called by the frame after every chart render - the exact data of the composite (`chunks`, `isIncluded`, chunk 0 left out).
- Calculation in `marketdatamodule/seasonality.coffee`: `blockRanges(timeframe, block)` (slot ranges), `calculateBlockReturns` (plain mean of the % returns per chunk; a chunk without a sample in the block doesn't count).
- Blocks per timeframe: yearly / quarterly → Monate | Tage, monthly / weekly → Tage only. Switched by tabs below the chart (`#seasonality-blocks-tabs`, mirrored `#backtesting-details-tabs`: line on top, no own panels); unavailable tabs are hidden, so a single tab just shows the active block. Weeks are deferred (`plan/deferred.md`). The chosen block is kept across timeframe changes where offered.
- Labels: yearly months `Jan`…, yearly days `DD.MM` (366 slot space), quarterly `Monat n` / `DD/Mn`, monthly `DD`, weekly `Mo`…
- Style shared with the trades chart (`barSeries`, `dotSeries`, `drawZeroLine` exported from `equityperformancemodule`): bars max 40px, loss bars light red tinted, min red / max green dots (max 6px, shrunk below the bar width for many bars), zero line, no grid.
- Hidden via opacity (not `display`) like the seasonality chart: it renders during the loading state and needs its size. Rendered on data / block change only - no resize handling, same as the seasonality chart.
