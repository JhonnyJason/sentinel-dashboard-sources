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
    log "etCurrencytrendState"
    content.className = "currencytrend"
    return

export setAccountState = ->
    log "setAccountState"
    content.className = "account"
    return