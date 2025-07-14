############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("navtriggers")
#endregion

############################################################
import * as nav from "navhandler"

############################################################
export toSummary = ->
    return nav.toRoot()

export toCurrencytrend = ->
    return nav.toBase("currencytrend")