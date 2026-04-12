############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreeningengine")
#endregion


############################################################
maxBusyTimeMS = 5
############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));


############################################################
export doScreening = (symbolToData, eventList) ->
    log "doScreening"
    try loop
        start = performance.now()
        for i in [0... 1000_000]
            ## TODO implement
            if performance.now() - start > maxBusyTimeMS
                await letMainThreadRun()
                log "hit calculation barrier @#{i}!"
                start = performance.now()

        break
        ## TODO implement
    catch err then log err
    return [
        { symbol: "ASML", eventLabel: "US FOMC", direction: "Long", winrate: "99%", profitAvg: 5, profitMed: 4, maxGain: 77, maxDrop: 12, nextDate: "2026-04-16", entryDate:"2026-04-15", exitDate:"2026-04-23" },
        { symbol: "GOOG", eventLabel: "US FOMC", direction: "Long", winrate: 98, profitAvg: 10, profitMed: 11, maxGain: 50, maxDrop: 7, nextDate: "2026-04-16", entryDate:"2026-04-14", exitDate:"2026-04-23" }
    ]
        