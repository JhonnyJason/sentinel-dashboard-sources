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
    accountBtn.addEventListener("click", triggers.toAccount)
    return


############################################################
export setSummaryState = ->
    log "setSummaryState"
    sidenav.className = "summary"
    return

export setCurrencytrendState = ->
    log "etCurrencytrendState"
    sidenav.className = "currencytrend"
    return

export setAccountState = ->
    log "setAccountState"
    sidenav.className = "account"
    return
