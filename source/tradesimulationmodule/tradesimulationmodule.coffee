############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("tradesimulationmodule")
#endregion

############################################################
# All values are factors in direction-adjusted profit space (0.05 = +5% for the trade).
# controls = { stopLossF: <= 0 | null, takeProfitF: > 0 | null, feeF: >= 0, reinvest: bool }
startEquity = 100

############################################################
export simulate = (summary, controls = {}) ->
    log "simulate"
    { stopLossF = null, takeProfitF = null, feeF = 0, reinvest = false } = controls
    sign = if summary.isLong then 1 else -1

    runs = summary.runInfoObjects.filter((r) -> r.tradable and !r.warn)
    runs.sort((a, b) -> if a.entryDate < b.entryDate then -1 else 1)
    trades = (simulateTrade(r, sign, stopLossF, takeProfitF, feeF) for r in runs)

    toEquity = (base, f) -> if reinvest then base * (1 + f) else base + startEquity * f

    equity = [startEquity]
    current = startEquity
    peak = startEquity
    realizedPeak = startEquity
    maxDrawdownF = 0
    maxDrawdownRealizedF = 0
    maxDrawdownAbs = 0 # in equity units, tracked separately: the largest abs and % drop can differ
    maxDrawdownRealizedAbs = 0
    for trade in trades
        base = current
        for [worstF, closeF] in trade.path # mark-to-market: troughs vs. peak of daily closes
            maxDrawdownF = Math.min(maxDrawdownF, toEquity(base, worstF) / peak - 1)
            maxDrawdownAbs = Math.min(maxDrawdownAbs, toEquity(base, worstF) - peak)
            peak = Math.max(peak, toEquity(base, closeF))
        current = toEquity(base, trade.profitF)
        peak = Math.max(peak, current)
        realizedPeak = Math.max(realizedPeak, current)
        maxDrawdownRealizedF = Math.min(maxDrawdownRealizedF, current / realizedPeak - 1)
        maxDrawdownRealizedAbs = Math.min(maxDrawdownRealizedAbs, current - realizedPeak)
        equity.push(current)

    wins = trades.filter((t) -> t.profitF > 0).length
    stats = {
        maxDrawdownF, maxDrawdownRealizedF, maxDrawdownAbs, maxDrawdownRealizedAbs
        sumProfitF: current / startEquity - 1
        total: trades.length
        wins
        losses: trades.length - wins
        slHits: trades.filter((t) -> t.exit == "sl").length
        tpHits: trades.filter((t) -> t.exit == "tp").length
    }
    return { trades, equity, stats }

############################################################
# Entry at the close of seq[0]; days without HLC (non-trading) are skipped.
# shortcut: HLC only - a day opening beyond the stop-loss and recovering fills at the stop-loss level (optimistic), see deferred.md
simulateTrade = (run, sign, stopLossF, takeProfitF, feeF) ->
    seq = run.seq
    entry = seq[0][seq[0].length - 1]
    toF = (price) -> sign * (price / entry - 1)

    maxDropF = 0
    maxRiseF = 0
    path = []
    exit = "end"
    exitIdx = seq.length - 1
    profitF = toF(seq[exitIdx][seq[exitIdx].length - 1])

    for i in [1...seq.length] when seq[i].length == 3
        [high, low, close] = seq[i]
        worstF = Math.min(toF(low), toF(high))
        bestF = Math.max(toF(low), toF(high))

        if stopLossF? and worstF <= stopLossF # also on a take-profit day (conservative)
            profitF = Math.min(stopLossF, bestF) # whole day beyond the stop-loss -> best price of that day
            maxDropF = Math.min(maxDropF, profitF)
            path.push([profitF, profitF])
            exit = "sl"
            exitIdx = i
            break

        maxDropF = Math.min(maxDropF, worstF)
        if takeProfitF? and bestF >= takeProfitF
            profitF = takeProfitF
            maxRiseF = Math.max(maxRiseF, takeProfitF)
            path.push([worstF, profitF])
            exit = "tp"
            exitIdx = i
            break

        maxRiseF = Math.max(maxRiseF, bestF)
        path.push([worstF, toF(close)])

    profitF -= feeF
    if path.length then path[path.length - 1][1] = profitF # the realized result closes the path

    exitDate = run.exitDate
    if exit != "end" then exitDate = addDays(run.entryDate, exitIdx)

    return { entryDate: run.entryDate, exitDate, profitF, maxDropF, maxRiseF, exit, path }

############################################################
addDays = (dateStr, days) ->
    d = new Date(dateStr + "T12:00Z")
    d.setUTCDate(d.getUTCDate() + days)
    return d.toISOString().slice(0, 10)
