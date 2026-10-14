# seasonalitychartmodule

uPlot chart of the seasonality composite ("Average Daily Return") and the latest data ("Neuester Verlauf"), with range selection for the backtest.

- `chartlayout.coffee`: pure layout (no DOM), tested in `testing/unittests/seasonalitychartmodule/`.
- `chartfun.coffee`: the uPlot wrapper (`SeasonalityChart`).
- `seasonalitychartmodule.coffee`: legend, selection, `prepareData` / `render`.

## Interface
- `prepareData({ composite, chunks, refDate, timeframe, ages })`, then `render()`.
- `indexToDate(idx)` / `dateToIndex(date)`, `setSelectedRegion(region, force)`, `reset()`.

## Display modes
Decided by the cycle only, as a list of displayed chunk ages `ages` (oldest first):

| | continuous | single |
|---|---|---|
| when | no cycle or all positions included (`isIncluded` null) | some positions excluded |
| `ages` | `[1, 0]` | `[d]`, d = newest included age |
| selection | may cross the period border | within the one period |

- **100 point** = start of the last part: earlier parts are built backward ending at 100, the last part forward from 100.
- **Latest data**: chunk `ages[j]` on part `j`, in percent of the last close before the last part (fallback: its first close). E.g. every 2nd year, in a year between → last year's chunk.
  Only shown where unambiguous (`cyclemath.showsLatest`, frame passes `showLatest`): continuous, or exactly one included position at age 0 or 1 (e.g. Q3 in Q4 yes, Q1 in Q4 no, Q1 + Q3 never). Weekly cut-offs never - no fitting cycle. Otherwise the series is all `null`.
- **Slot space**: composite and chunks come in slot space (yearly 366, quarterly 93, monthly 31, weekly 7); `periodPart` only keeps the slots that exist in that calendar period.
- `backStartIdx` = start of the last part (0 in single mode) - the initial visible range.
