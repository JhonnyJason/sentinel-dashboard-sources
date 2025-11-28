############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("marketdatamodule")
#endregion

############################################################
import { getMarketHistory } from "./sampledata.js"

############################################################
import * as seasonality from "./seasonality.js"

############################################################
cleanAverage = null
dirtyAllAverage = null
currentData = null

############################################################
export initialize = ->
    log "initialize"
    symbol = "GOOG"
    years = 10 ##years
    data = getMarketHistory(symbol, years)
    # olog data
    # log data.length
    pureHistoric = data.slice(1)
    # log pureHistoric.length
    historicAverage = seasonality.getAverageDynamicOfYearlyData(pureHistoric)
    # log historicAverage
    thisYear = seasonality.getDynamicsOfCurrentYear(data[0])
    historicAveragePlus = seasonality.addCurrrentToAverage(thisYear, historicAverage, 10)

    cleanAverage = historicAverage
    dirtyAllAverage = historicAveragePlus
    currentData = thisYear

    log "CleanAverage: "+cleanAverage[0]+","+cleanAverage[1]+","+cleanAverage[2]
    log "currentData: "+currentData[0]+","+currentData[1]+","+currentData[2]
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




