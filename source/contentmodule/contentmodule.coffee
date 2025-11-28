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

export setAccountState = ->
    log "setAccountState"
    content.className = "account"
    return

export hide = ->
    log "hide"
    content.className = "hidden"
    return