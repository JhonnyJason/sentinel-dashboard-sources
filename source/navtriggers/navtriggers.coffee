############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("navtriggers")
#endregion

############################################################
import * as nav from "navhandler"

############################################################
export toSummary = ->
    log "toSummary"
    return nav.toBase("summary")

export toCurrencytrend = ->
    log "toCurrencytrend"
    return nav.toBase("currencytrend")

export toSeasonality =->
    log "toCurrencytrend"
    return nav.toBase("seasonality")

export toAccount = ->
    log "toAccount"
    return nav.toBase("account")

export toNoAccount = ->
    log "toNoAccount"
    return nav.toBase("noaccount")