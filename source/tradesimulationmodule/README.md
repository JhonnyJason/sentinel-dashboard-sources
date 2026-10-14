# tradesimulationmodule

Pure computation (no DOM): turns a `SymbolBacktester` summary into simulated trades, an equity curve and stats.
Works on any backtester summary (seasonality now, event screener later).

```coffee
{ trades, equity, stats } = simulate(summary, { stopLossF, takeProfitF, feeF, reinvest })
```

- All values are factors in direction-adjusted profit space: `0.05` = +5% for the trade, long or short.
  `stopLossF <= 0`, `takeProfitF > 0`, `feeF` per round trip; `null`/missing = off.
- `equity`: starts at 100, one point per trade. Fixed stake (100 per trade, added up) or `reinvest` (compounding).
- `trades[i]`: `{ entryDate, exitDate, profitF, maxDropF, maxRiseF, exit: "end"|"sl"|"tp", path }`, oldest first;
  `warn` runs are excluded. `path` = `[worstF, closeF]` per traded day (used for the drawdown).
- `stats`: `maxDrawdownF` (mark-to-market: daily troughs vs. peak of daily closes), `maxDrawdownRealizedF`, `maxDrawdownAbs` / `maxDrawdownRealizedAbs` (same in equity units, tracked separately)
  (closed trades only), `sumProfitF`, `total`, `wins`, `losses`, `slHits`, `tpHits`.

## Fill rules (HLC only, no open prices)
- Stop-loss hit when the day's worst price reaches it; fill at the stop-loss, or at the day's best price
  if the whole day lies beyond it (gap). A gap that recovers within the day is not detectable → optimistic.
- Take-profit fills at its level. Both on one day → stop-loss.
