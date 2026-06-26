############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("forexscreenerframemodule")
#endregion

############################################################
import * as dCache from "./datacache.js"

############################################################
import * as liveD from "./forexlivedata.js"
import * as resultTable from "./forexscreenerresults.js"

############################################################
relevantPairs = []
symbolToData = Object.create(null)

############################################################
isProcessing = false
processOnceMore = false

############################################################
export initialize = (c) ->
    log "initialize"
    liveD.initialize(c)
    return

############################################################
export activate = ->
    log "activate"
    # required only once on startup, but after logged in
    # maybe more to be done here?
    # setUIState("nodetails")
    generateScreeningResult(relevantPairs)
    return

############################################################
export setUIState = (state) ->
    log "setUIState"
    switch state
        when "processing"
            forexscreenerframe.classList.remove("no-result")
            forexscreenerframe.classList.remove("result")
            forexscreenerframe.classList.add("processing")
        when "result"
            forexscreenerframe.classList.remove("processing")
            forexscreenerframe.classList.remove("no-result")
            forexscreenerframe.classList.add("result")
        when "no-result"
            forexscreenerframe.classList.remove("processing")
            forexscreenerframe.classList.remove("result")
            forexscreenerframe.classList.add("no-result")
        else 
            console.error("#{state} is not a know UI state for the forexscreenerframe!")
    return

############################################################
#region Helper Functions

#endregion

############################################################
retrieveMissingSymbolData = ->
    log "retrieveMissingSymbolData"
    
    retrieveMissingData = (symbol) ->
        if symbolToData[symbol]? then return
        
        try symbolToData[symbol] = await dCache.getHistoryHLC(symbol, 31)
        catch err then console.error err
        return

    await Promise.all(relevantPairs.map(retrieveMissingData))
    return

############################################################
generateScreeningResult = (relevantPairs) ->
    log "generateScreeningResult"

    # guarding from multiple simultaneous runs 
    if isProcessing and processOnceMore then return
    if isProcessing then return processOnceMore = true
    
    isProcessing  = true
    try await retrieveMissingSymbolData()
    catch err then log err
    try await resultTable.screenAndRender(relevantPairs, symbolToData)
    catch err then log err
    isProcessing = false
    
    if processOnceMore
        processOnceMore = false
        generateScreeningResult(relevantPairs)
    return