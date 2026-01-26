############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("marketdatamodule")
#endregion

############################################################
import * as datacache from "./datacache.js"
import * as seasonality from "./seasonality.js"
# import { getMarketHistory } from "./sampledata.js" # mock data source

############################################################
cleanAverage = null
dirtyAllAverage = null
currentData = null

############################################################
export initialize = ->
    log "initialize"
    return

############################################################
export getCleanAverage = (symbol, years) -> cleanAverage

export getAllAverage = (symbol, years) -> dirtyAllAverage

export getThisYearData = (symbol) -> currentData

############################################################
export getSeasonalityComposite = (symbol, years, method) ->
    return dirtyAllAverage

export getThisAndLastYearData = (symbol) ->
    return getMarketHistory(symbol, 1)




