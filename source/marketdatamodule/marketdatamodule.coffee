############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("marketdatamodule")
#endregion

############################################################
import { getHistoricCloseChunks, getHistoricDepth, getNewestDate } from "./datacache.js"
import { normalizeYearData } from "./seasonality.js"

############################################################
export { getHistoricDepth, getNewestDate }
export { calculateSeasonalityComposite, blockRanges, calculateBlockReturns } from "./seasonality.js"

############################################################
# timeframe: "yearly" | "quarterly" | "monthly" | "weekly"
# returns { chunks, refDate } - close chunks in slot space, newest first, chunk 0 = period of
# refDate (newest data date); window back to Jan 1 of (refDate year - years)
# slots: yearly 366 (FEB29 slot null in non-leap years), quarterly 93, monthly 31, weekly 7
export getCloseChunks = (symbol, timeframe, years) ->
    refDate = await getNewestDate(symbol)
    month = refDate.getMonth()
    toAge = switch timeframe
        when "yearly" then years
        when "quarterly" then Math.floor(month / 3) + years * 4
        when "monthly" then month + years * 12
        # counted by date, as years * 52 drifts ~1 week every 5.5 years
        when "weekly" then Math.floor((refDate - new Date(refDate.getFullYear() - years, 0, 1)) / (7 * 86_400_000))
        else throw new Error("getCloseChunks: unknown timeframe #{timeframe}")

    chunks = await getHistoricCloseChunks(symbol, timeframe, toAge)
    if timeframe == "yearly" then chunks = chunks.map(normalizeYearData)
    return { chunks, refDate }
