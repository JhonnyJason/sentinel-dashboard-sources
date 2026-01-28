############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("marketdatamodule")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
import { 
    getHistoricCloseData, getLatestCloseData, getHistoricDepth 
} from "./datacache.js"
import { calculateSeasonalityComposite } from "./seasonality.js"

############################################################
export { getHistoricDepth }

############################################################
export getSeasonalityComposite = (symbol, years, method) ->
    allCloses = await getHistoricCloseData(symbol, years)
    for yearCloses,i in allCloses
        log "@#{i}: "+yearCloses.length
        utl.scanForFreakValues(yearCloses)

    return calculateSeasonalityComposite(allCloses, method)

############################################################
export getLatestData = (symbol) ->
    return await getLatestCloseData(symbol)




