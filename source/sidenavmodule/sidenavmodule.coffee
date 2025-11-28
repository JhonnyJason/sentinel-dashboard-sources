############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("sidenavmodule")
#endregion

############################################################
import * as triggers from "./navtriggers.js"

############################################################
export initialize = ->
    log "initialize"
    summaryBtn.addEventListener("click", triggers.toSummary)
    currencytrendBtn.addEventListener("click", triggers.toCurrencytrend)
    seasonalityBtn.addEventListener("click", triggers.toSeasonality)
    accountBtn.addEventListener("click", triggers.toAccount)
    return


############################################################
export setSummaryState = ->
    log "setSummaryState"
    sidenav.className = "summary"
    return

export setCurrencytrendState = ->
    log "setCurrencytrendState"
    sidenav.className = "currencytrend"
    return

export setSeasonalityState = ->
    log "setSeasonalityState"
    sidenav.className = "seasonality"
    return

export setAccountState = ->
    log "setAccountState"
    sidenav.className = "account"
    return

export hide = ->
    log "hide"
    sidenav.className = "hidden"
    return
