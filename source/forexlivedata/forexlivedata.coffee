############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("forexlivedata")
#endregion

############################################################
import { getAuthCode } from "./accountmodule.js"
import * as liveD from "./livedatamodule.js"

############################################################
livePrices = Object.create(null)
updateListeners = Object.create(null)

############################################################
export initialize = (c) ->
    log "initialize"
    symbols = c.shownCurrencyPairLabels
    liveD.listenOnSymbolsData(symbols, onPriceUpdate)
    return


############################################################
onPriceUpdate = (sym, price) ->
    log "onPriceUpdate #{sym} = #{price}"
    livePrices[sym] = price
    if typeof updateListeners[sym] == "function"
        updateListeners[sym]()
    return


############################################################
export getLatestPrice = (sym) -> livePrices[sym]

############################################################
export unsetUpdateListeners = -> updateListeners = Object.create(null)

############################################################
export setUpdateListener = (sym, listener) -> updateListeners[sym] = listener 

