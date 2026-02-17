############################################################
# Pure EMA and state calculation functions
# No dependencies — used by both historic processing and live updates

############################################################
export calculateEMA = (data, period) ->
    ema = new Array(data.length).fill(null)

    # SMA seed from first `period` valid values
    sum = 0
    count = 0
    seedIdx = -1
    for i in [0...data.length]
        continue unless data[i]?
        sum += data[i]
        count++
        if count == period
            seedIdx = i
            ema[i] = sum / period
            break

    return ema if seedIdx < 0

    k = 2 / (period + 1)
    for i in [(seedIdx + 1)...data.length]
        prev = ema[i - 1]
        if data[i]? and prev?
            ema[i] = data[i] * k + prev * (1 - k)
        else
            ema[i] = prev

    return ema

############################################################
# State logic:
#   green  = HYG above EMA for 2+ consecutive days (risk on)
#   blue   = single day break above EMA (recovery signal)
#   red    = HYG below EMA for 2+ consecutive days (risk off)
#   yellow = single day break below EMA (caution)
export calculateStates = (closes, ema) ->
    states = new Array(closes.length).fill(null)
    aboveCount = 0
    belowCount = 0

    for i in [0...closes.length]
        continue unless closes[i]? and ema[i]?

        if closes[i] > ema[i]
            aboveCount++
            belowCount = 0
            states[i] = if aboveCount >= 2 then "green" else "blue"
        else
            belowCount++
            aboveCount = 0
            states[i] = if belowCount >= 2 then "red" else "yellow"

    return states

############################################################
# Incremental state update for a single new price point
# Returns { ema, state, aboveCount, belowCount }
export updateSingle = (price, prevEma, k, aboveCount, belowCount) ->
    ema = if price? and prevEma? then price * k + prevEma * (1 - k) else prevEma
    state = null

    if price? and ema?
        if price > ema
            aboveCount++
            belowCount = 0
            state = if aboveCount >= 2 then "green" else "blue"
        else
            belowCount++
            aboveCount = 0
            state = if belowCount >= 2 then "red" else "yellow"

    return { ema, state, aboveCount, belowCount }
