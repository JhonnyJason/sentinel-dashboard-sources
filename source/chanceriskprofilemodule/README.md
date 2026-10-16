# chanceriskprofilemodule

"Chancen-Risiko-Profil" tab (between Performance and Details) of `#backtesting-details-container` (`backtesting-details.pug`): a histogram of where the price stood during the trades.

- `setResults(summary)`: called by `seasonalitybacktestingmodule.run` with the `SymbolBacktester` summary.
- Raw trades via `tradesimulationmodule.simulate(summary)` (no stop-loss / take-profit / fees), so it doesn't depend on the Performance tab controls.
- One value per trade-day: the close's price change vs. the entry, not direction-adjusted - a short's profits sit left of 0, so long vs. short shows in the colours. Counted per bin, split by the trade's result: losing trades red at the bottom, winning trades (`profitF > 0`) green stacked on top (drawn as the total in green, the losing part in red over it).
- "Overshadowed" bars: on the adverse side (left of 0 for longs, right for shorts) a bar with more wins than losses gets a darker red; on the favourable side a bar with more losses than wins gets a darker green. Per-bar colours via uPlot's bars `disp` option. A tie (exactly 50%) is not marked.
- `chanceriskbins.coffee` (pure, unit-tested): bin width = half the Freedman–Diaconis width `IQR·n^(-1/3)`, rounded to the nearest of 1 / 2 / 2.5 / 5 per decade (log scale); range min..max including 0, snapped to the width, so 0 is always an edge. No clipping: with few trades the tails are single real trades (e.g. a gap), clipped into the edge bars they looked like a pile-up. Width stepped until there are 10–100 bins.
  - The days of a trade are correlated, so `n` overstates the independent samples → FD would be cautious anyway, but plain FD rounded up was too coarse (≈ 1% for 200 trades × 12 days).
- Bin width select beneath the chart (`.select-wrapper`, global style): `binProfile` returns the `choices` (every nice width within 10–100 bins, plus the FD width, marked "(Auto)"), the select value is the offset from the FD width. Kept in memory only and reset to Auto by `setResults` (new sample), a resize keeps it. 0 stays an edge for every choice.
- Bars at most 40px wide; a white vertical line marks 0% (drawn over the bars), reaching 10px above the plot area (fixed top padding) and 5px into the x axis, so it stays visible between dense bars.
- x axis: % labels on the bin edges, thinned to every k-th edge (counted from 0) so they stay ≥ 45px apart.
- Renders only while visible (ResizeObserver, like `equityperformancemodule`).
