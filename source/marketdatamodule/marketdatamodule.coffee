############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("marketdatamodule")
#endregion

############################################################
import { 
    getHistoricCloseData, getLatestCloseData, getHistoricDepth 
} from "./datacache.js"
import { calculateSeasonalityComposite } from "./seasonality.js"

############################################################
export { getHistoricDepth }

############################################################
export getSeasonalityComposite = (symbol, years, method) ->
    allCloses = await getHistoricCloseData(symbol, years)
    return calculateSeasonalityComposite(allCloses, method)

############################################################
export getLatestData = (symbol) ->
    return await getLatestCloseData(symbol)




