############################################################
# Histogram of the daily closes of all trades (price change vs. entry as factor), split by the trade's result.
# Bin width: half the Freedman–Diaconis width (FD alone is coarse here), rounded to the nearest nice step; 0 is always an edge.
# Range: min..max (always including 0) snapped to the width - no clipping: with few trades the tails are single real trades.
minBins = 10
maxBins = 100

# 1, 2, 2.5, 5 per decade: 0.0001 .. 50 as factors (0.01% .. 5000%)
niceSteps = []
for k in [-4..1]
    niceSteps.push(m * 10 ** k) for m in [1, 2, 2.5, 5]

############################################################
# trades: simulate(...).trades, sign: -1 for shorts turns their profit space back into price change
# -> { edges, losses, wins } (edges.length = bins + 1)
export binProfile = (trades, sign = 1) ->
    days = [] # [closeF, isWin]
    for t in trades
        days.push([sign * closeF, t.profitF > 0]) for [worstF, closeF] in t.path
    return null unless days.length

    sorted = days.map((d) -> d[0]).sort((a, b) -> a - b)
    min = sorted[0]
    max = sorted[sorted.length - 1]
    fdWidth = 2 * (quantile(sorted, 0.75) - quantile(sorted, 0.25)) * sorted.length ** (-1 / 3)
    target = fdWidth / 2

    # nearest on a log scale; a zero spread starts at the finest step
    idx = 0
    if target > 0
        dist = niceSteps.map((s) -> Math.abs(Math.log(s / target)))
        idx = dist.indexOf(Math.min(dist...))
    layout = (w) ->
        lo = Math.floor(Math.min(min, 0) / w) * w
        hi = Math.ceil(Math.max(max, 0) / w) * w
        count = Math.max(1, Math.round((hi - lo) / w))
        return { w, lo, count }
    { w, lo, count } = layout(niceSteps[idx])
    { w, lo, count } = layout(niceSteps[++idx]) while count > maxBins and idx < niceSteps.length - 1
    { w, lo, count } = layout(niceSteps[--idx]) while count < minBins and idx > 0

    edges = (lo + i * w for i in [0..count])
    losses = (0 for i in [0...count])
    wins = (0 for i in [0...count])
    for [v, isWin] in days
        # small epsilon: a value exactly on an edge must not slip into the lower bin by float error; the max on the top edge -> last bin
        i = Math.min(count - 1, Math.max(0, Math.floor((v - lo) / w + 1e-9)))
        if isWin then wins[i]++ else losses[i]++
    return { edges, losses, wins }

# linear interpolation between the closest ranks
quantile = (sorted, p) ->
    pos = (sorted.length - 1) * p
    i = Math.floor(pos)
    return sorted[i] if i + 1 >= sorted.length
    return sorted[i] + (pos - i) * (sorted[i + 1] - sorted[i])
