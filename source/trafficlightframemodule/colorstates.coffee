############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("colorstates")
#endregion

############################################################
# EMA for color states
EMA_PERIOD = 20

############################################################
# Color States:
#   green  = HYG above EMA for 2+ consecutive days (risk on)
#   blue   = single day break above EMA (recovery signal)
#   red    = HYG below EMA for 2+ consecutive days (risk off)
#   yellow = single day break below EMA (caution)

############################################################
closes = null # cached EoD closes for EMA and color states base
states = null # whole array of historic color states
ema = null # locally cached EMA array

############################################################
export initEMA = (data) ->
    log "initEMA"
    return unless Array.isArray(data) and data.length > 0
    log "we also have data to initialize..."
    closes = data
    ema = new Array(data.length).fill(null)

    # SMA seed from first `EMA_PERIOD` valid values
    sum = 0
    count = 0
    seedIdx = -1
    for i in [0...data.length]
        continue unless data[i]?
        sum += data[i]
        count++
        if count == EMA_PERIOD
            seedIdx = i
            ema[i] = sum / EMA_PERIOD
            break

    if seedIdx < 0 then return mapColorStates()

    k = 2 / (EMA_PERIOD + 1)
    for i in [(seedIdx + 1)...data.length]
        prev = ema[i - 1]
        if data[i]? and prev?
            ema[i] = data[i] * k + prev * (1 - k)
        else
            ema[i] = prev

    return mapColorStates()

############################################################
mapColorStates = ->
    log "mapColorStates"
    return unless ema?
    log "we have an ema - good..."

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

    return

############################################################
export getAllColorStates = -> states

############################################################
export getCurrentPriceState = (price) ->
    log "getCurrentPriceState"
    return "" unless ema?
    lastEMA = ema[ema.length - 1]
    lastState = states[states.length - 1]
    lastClose = closes[closes.length - 1]
    olog { lastEMA, lastState, lastClose, price }
    # if price is exactly the same, then it most probably is the last close
    if lastClose == price then return lastState

    # check how the current price adds to the situation and return resulting state
    if price > lastEMA
        if lastState == "green" then return "green"
        if lastState == "blue" then return "green"
        if lastState == "yellow" then return "blue"
        if lastState == "red" then return "blue"        
    else
        if lastState == "red" then return "red"        
        if lastState == "yellow" then return "red"
        if lastState == "blue" then return "yellow"
        if lastState == "green" then return "yellow"

    return