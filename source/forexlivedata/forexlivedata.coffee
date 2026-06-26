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
waitingSymbols = new Set()

############################################################
setReady = null
isReady = new Promise((rslv) -> setReady = rslv)

############################################################
export initialize = (c) ->
    log "initialize"
    symbols = c.shownCurrencyPairLabels
    liveD.listenOnSymbolsData(symbols, onPriceUpdate)
    waitingSymbols = new Set(symbols)
    return


############################################################
onPriceUpdate = (sym, price) ->
    log "onPriceUpdate #{sym} = #{price}"
    livePrices[sym] = price
    if typeof updateListeners[sym] == "function"
        updateListeners[sym]()

    waitingSymbols.delete(sym)
    if waitingSymbols.size == 0 then setReady()
    return


############################################################
export pricesReceived = -> isReady

############################################################
export getLatestPrice = (sym) -> livePrices[sym]

############################################################
export unsetUpdateListeners = -> updateListeners = Object.create(null)

############################################################
export setUpdateListener = (sym, listener) -> updateListeners[sym] = listener 

