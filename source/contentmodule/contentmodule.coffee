############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("contentmodule")
#endregion

############################################################
export setSummaryState = ->
    log "setSummaryState"
    content.className = "summary"
    return

export setCurrencytrendState = ->
    log "setCurrencytrendState"
    content.className = "currencytrend"
    return

export setSeasonalityState = ->
    log "setSeasonalityState"
    content.className = "seasonality"
    return

export setEventscreenerState = ->
    log "setEventscreenerState"
    content.className = "eventscreener"
    return

export setForexscreenerState = ->
    log "setForexscreenerState"
    content.className = "forexscreener"
    return

export setTrafficlightState = ->
    log "setTrafficlightState"
    content.className = "trafficlight"
    return

export setAccountState = ->
    log "setAccountState"
    content.className = "account"
    return

export hide = ->
    log "hide"
    content.className = "hidden"
    return