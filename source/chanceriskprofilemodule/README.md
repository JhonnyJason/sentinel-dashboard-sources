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
- Renders only while visible (ResizeObserver, like `equityperformancemodule`); a resize re-renders, so the width-dependent labels follow.

## Bell curve (σ indicator)
- `chanceriskbell.coffee` (pure, unit-tested): `bellFit(sorted, dir)` on `binProfile(...).values` (the same trade-day values the bars count, independent of the bin width). Robust against outlier trades: center = median, σ = 1.4826 · MAD. Returns `{ center, sigma, loss, profit }` - the actual shares of the values on that side of the center within 1σ / 2σ / 3σ - or `null` for σ = 0 (no curve, no lines, legend hidden). `bellCount(fit, n, w, x)`: curve height in counts (area = n) → rescales with the bin width; the y range includes its peak.
- Drawn in the draw hook after the bars: the curve (`#bbbbbb`, one point per device pixel) and dashed verticals for the center (`#e0e0e0`) and ±1/2/3σ; lines outside the x range are skipped.
- Direction: the colours follow the trade (red towards the loss: left for longs, right for shorts), the sign follows the bell curve ("−" always left, "+" right). For shorts the "Verlustseite" box sits right (`.short` on `#chanceriskprofile-legend`, CSS `order`).
- Labels above each line (extra top padding `labelsTop`): name over the position, σ positions always signed (`signedPct`), in the line's colour. By chart width: < 500px no position, < 450px "Mittelwert" → "M", < 250px the rows alternate (center, ±2σ on top; ±σ, ±3σ below).
- Legend: "Verlustseite" / "Gewinnseite" boxes right of the bin width select, one line per σ: "**−σ:** Zwischen **−1.05%** und **0.12%** liegen **61%**". A share < 99.95% never shows 100% (capped at 99%). Responsive: the boxes (min 220px each) wrap beneath the select, then beneath each other.
- `reset.styl` strips `b` (font: inherit) → the legend sets `font-weight bold` itself.
