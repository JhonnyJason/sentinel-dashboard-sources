############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("forexscreeningengine")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
import * as mData from "./marketdatamodule.js"
import * as dataC from "./datacache.js"
import { shownCurrencyPairLabels as allForexSymbols } from "./configmodule.js"

############################################################
export resultStructure = [
    { label: "FX Paar", key: "symbol", sort: on }
    { label: "Signal", key: "signal", sort: on}
    { label: "Startdatum", key: "entryDate", sort: off }
    { label: "Enddatum", key: "exitDate", sort: off }
    { label: "Einstiegskurs", key: "entryPrice", sort: off }
    { label: "SL", key: "stoploss", sort: off }
    { label: "TP1", key: "takeprofit1", sort: off }
    { label: "TP2", key: "takeprofit2", sort: off }
    { label: "Scoring", key: "score", sort: on }
    { label: "TQ 10J", key: "seasonality10P", sort: on }
    { label: "TQ 15J", key: "seasonality15P", sort: on }
]

############################################################
symbolToInfo = Object.create(null)
symbolToScore = Object.create(null)
symbolToSaisonality10J = Object.create(null)
symbolToSaisonality15J = Object.create(null)
# relevantSymbols = []
latestForexPairList = null
############################################################
maxBusyTimeMS = 5

############################################################
currentYear = (new Date()).getFullYear()
currentYearIsLeap = utl.isLeapYear(currentYear)

############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));
    
############################################################
pending = []

############################################################
isScreening = false
restartScreening = false

############################################################
setResultsReady = null
resultsReady = new Promise((rslv) -> setResultsReady = rslv)

############################################################
export startScreening = (forexPairsWithScore) ->
    log "doScreening"
    return unless Array.isArray(forexPairsWithScore)

    latestForexPairList = forexPairsWithScore
    
    if !setResultsReady? # instanciate new Promise if the last one had been resolved already.
        resultsReady = new Promise((rslv) -> setResultsReady = rslv)

    if isScreening # protect from simultaneous runs
        restartScreening = true
        return

    isScreening = true    
    currentYear = (new Date()).getFullYear()
    currentYearIsLeap = utl.isLeapYear(currentYear)
    
    ## Get current score for fxPair sym
    for el in latestForexPairList
        symbol = el[0]
        score = el[1]
        symbolToScore[symbol] = score
    
    try
        ## Get Saisonality Composite for fxPair sym
        await getRelevantSaisonalityComposites()
        
        start = performance.now()
        for sym,i in allForexSymbols
            log "evaluating #{sym} @#{i}"
            sc15 = symbolToSaisonality15J[sym]
            sc10 = symbolToSaisonality10J[sym]
            if !sc10? or !sc15?
                symbolToInfo[sym] = Object.create(null)
                log "This symbol seems not to be relevant... continue!"
                continue
            
            score = symbolToScore[sym]
            if score > 0 then isLong = true
            else isLong = false

            range = getSeasonalBestFitRangeFromToday(sc15, isLong, 90)
            if !range?
                symbolToInfo[sym] = Object.create(null)
                log "This symbol has no matching seasonal pattern... continue!"
                continue 

            entryDate = utl.leapNormToYYYYMMDD(range.startIdx, currentYear)
            exitDate = utl.leapNormToYYYYMMDD(range.endIdx, currentYear)

            hlc = await dataC.getHistoryHLC(sym, 1)
            # olog hlc
            if hlc.length == 2 then hlc = [...hlc[0], ...hlc[1]]
            else throw new Error("retrieved HLC data per year was not for 2 years! Shiould be for this and the year before.")
            # olog hlc

            ## calc ATR14
            atr14 = getATR14(hlc)
            
            lastHLC = hlc[hlc.length - 1]
            lastC = lastHLC[lastHLC.length - 1]
            if typeof lastC == "string" then lastC = parseFloat(lastC)

            if isLong then f = 1.0
            else f = -1.0

            entryPrice = lastC

            ## calc SL
            stoploss = lastC - f * atr14
            ## calc TP1
            takeprofit1 = lastC + f * 1.5 * atr14
            ## calc TP2
            takeprofit2 = lastC + f * 3.0 * atr14

            if isLong then signal = "Long"
            else signal = "Short"
            
            ## TODO implement get success rates...
            # seasonality10P = 90.0
            # seasonality15P = 93.3

            seasonality10P = 0.0
            seasonality15P = 0.0

            symbolToInfo[sym] = { signal, stoploss, entryPrice, takeprofit1, takeprofit2, entryDate, exitDate, score, seasonality10P, seasonality15P }
            
            ## DONOT freeze the UI Thread if calculation takes too much time...
            if performance.now() - start > maxBusyTimeMS
                await letMainThreadRun()
                log "hit calculation barrier @#{i}!"
                if restartScreening
                    log "restarting the screening Process!"
                    isScreening = false
                    restartScreening = false
                    startScreening(latestForexPairList)
                    return
                start = performance.now()

    catch err then log err

    log "Finished Forex Screening"
    olog symbolToInfo
    
    isScreening = false
    restartScreening = false
    setResultsReady()
    setResultsReady = null
    return 


############################################################
export getResults = (sortKey, isAscending) ->
    log "getResults"
    await resultsReady

    sortFunction = getSortFunction(sortKey, isAscending)
    results = []
    for symbol,info of symbolToInfo
        if !info? then results.push({ symbol })
        else results.push({ symbol, ...info })

    # each groupd was added independently -> sort    
    results.sort(sortFunction)
    return results

############################################################
#region Helper Functions
getATR14 = (hlc) -> ## average true range of last 14 hlc
    log "getATR14"
    last14 = []
    last14.push(hlc[hlc.length - i]) for i in [15..1]

    first = last14.shift()
    latestClose = first[first.length - 1]
    sum = 0

    log last14.length
    log last14

    for hlc,i in last14 
        h = hlc[0]
        if hlc.length == 3
            l = hlc[1]
            c = hlc[2]
        else
            l = h
            c = h

        closeLowDelta = Math.abs(l - latestClose)
        closeHighDelta = Math.abs(h - latestClose)
        lowHighDelta = Math.abs(h - l)

        range = Math.max(lowHighDelta, closeHighDelta, closeLowDelta)

        sum += range
        latestClose = c
        
    return sum / 14.0

############################################################
getRelevantSaisonalityComposites = ->
    log "getRelevantSaisonalityComposites"
    symbolToSaisonality10J = Object.create(null)
    symbolToSaisonality15J = Object.create(null)

    relevantSymbols = Object.keys(symbolToScore).filter(
        (el) -> Math.abs(symbolToScore[el]) > 4
    )
    olog relevantSymbols

    proms = relevantSymbols.map(
        (sym) ->
            symbolToSaisonality10J[sym] = await mData.getSeasonalityComposite(sym, 10, 0)
            symbolToSaisonality15J[sym] = await mData.getSeasonalityComposite(sym, 15, 0)
    )
    await Promise.all(proms)
    log "retrieved all relevant Saisonality Composites!"
    return

############################################################
getSeasonalBestFitRangeFromToday = (composite, isLong, maxRange) -> 
    ## Today to index in 366 leap-norm
    todayDate = new Date()
    startIdx = utl.getDayOfYear(todayDate)
    startIdx = utl.realToLeapNormIdx(startIdx, currentYearIsLeap)
    
    # startIdx = 356
    # log startIdx

    # composite = composite.map((el, idx) -> idx)
    # log composite.length
    # log composite.map((el) -> el.toFixed(2))

    if startIdx + maxRange > 365 ## overlapped
        overlap = startIdx - 366 
        lower = utl.toFactorsArray(composite.slice(overlap))
        lower.push(1.0) # unknown new year shift... setting 31.12. = 01.01
        
        overlap = maxRange + overlap # overlap is negative  
        upper = utl.toFactorsArray(composite.slice(0, overlap))

        composite = utl.fromFactorsForward([...lower, ...upper])
    else # no overlap
        composite = composite.slice(startIdx, startIdx + maxRange)
    
    # log composite.length
    # log composite.map((el) -> el.toFixed(2))

    if isLong then range = getBestExitForLong(composite)
    else range = getBestExitForShort(composite)
    return null unless range? # no reliable positive seasonal pattern

    ## shifting up the indices - 0 in the sliced composite is our startIdx
    range.startIdx = range.startIdx + startIdx
    range.endIdx = range.endIdx + startIdx
    ## range.endIdx might be > 366 -> overflow
    return range

getSeasonalBestFitRange = (composite, isLong, maxRange) ->
    log "getSeasonalBestFitRange"

    ## Today to index in 366 leap-norm
    todayDate = new Date()
    todayIdx = utl.getDayOfYear(todayDate)
    todayIdx = utl.realToLeapNormIdx(todayIdx, currentYearIsLeap)
    
    ## start checking from tomorrow
    startIdx = todayIdx + 1
    # startIdx = 356
    # log startIdx

    # composite = composite.map((el, idx) -> idx)
    # log composite.length
    log composite.map((el) -> el.toFixed(2))

    if startIdx + maxRange > 365 ## overlapped
        overlap = startIdx - 366 
        lower = utl.toFactorsArray(composite.slice(overlap))
        lower.push(1.0) # unknown new year shift... setting 31.12. = 01.01
        
        overlap = maxRange + overlap # overlap is negative  
        upper = utl.toFactorsArray(composite.slice(0, overlap))

        composite = utl.fromFactorsForward([...lower, ...upper])
    else # no overlap
        composite = composite.slice(startIdx, startIdx + maxRange)
    
    # log composite.length
    # log composite.map((el) -> el.toFixed(2))

    if isLong then range = getBestRangeForLong(composite)
    else range = getBestRangeForShort(composite)
    return null unless range?

    ## shifting up the indices - 0 in the sliced composite is our startIdx
    range.startIdx = range.startIdx + startIdx
    range.endIdx = range.endIdx + startIdx
    ## range.endIdx might be > 366 -> overflow
    return range


############################################################
getBestRangeForLong = (seq) ->
    log "getBestRangeForLong"
    # log seq.map((el) -> el.toFixed(2))

    ## If the full sequence is not positive -> no good range
    if !hasPositiveTrend(seq) then return null

    startIdx = 0
    startP = seq[0]

    deltaMax = 0
    startIdxMax = 0
    endIdxMax = 0

    for p,i in seq

        if p < startP 
            startIdx = i
            startP = p
        else if p - startP > deltaMax
            deltaMax = p - startP
            startPMax = startP
            endIdxMax = i
            startIdxMax = startIdx


    # olog {
    #     startIdx
    #     startP
    #     deltaMax
    #     startIdxMax
    #     endIdxMax
    # }

    return { startIdx: startIdxMax, endIdx: endIdxMax }

getBestRangeForShort = (seq) ->
    log "getBestRangeForShort"
    # log seq.map((el) -> el.toFixed(2))

    ## If the full sequence is not negative -> no good range
    if !hasNegativeTrend(seq) then return null

    startIdx = 0
    startP = seq[0]

    deltaMax = 0
    startIdxMax = 0
    endIdxMax = 0

    for p,i in seq

        if p > startP 
            startIdx = i
            startP = p
        else if startP - p > deltaMax
            deltaMax = startP - p
            startPMax = startP
            endIdxMax = i
            startIdxMax = startIdx


    # olog {
    #     startIdx
    #     startP
    #     deltaMax
    #     startIdxMax
    #     endIdxMax
    # }

    return { startIdx: startIdxMax, endIdx: endIdxMax }
    

############################################################
getBestExitForLong = (seq) ->
    log "getBestRangeForLong"
    # log seq.map((el) -> el.toFixed(2))

    ## If the full sequence is not positive -> no good range
    if !hasPositiveTrend(seq) then return null

    startIdx = 0
    startP = seq[0]

    deltaMax = 0
    endIdxMax = 0

    for p,i in seq when (p - startP) > deltaMax
        deltaMax = p - startP
        endIdxMax = i

    return { startIdx, endIdx: endIdxMax }

getBestExitForShort = (seq) ->
    log "getBestRangeForShort"
    # log seq.map((el) -> el.toFixed(2))

    ## If the full sequence is not negative -> no good range
    if !hasNegativeTrend(seq) then return null

    startIdx = 0
    startP = seq[0]

    deltaMax = 0
    endIdxMax = 0

    for p,i in seq when (startP - p) > deltaMax
        deltaMax = startP - p
        endIdxMax = i

    return { startIdx, endIdx: endIdxMax }

############################################################
hasPositiveTrend = (seq) ->
    s0 = seq[0]
    s30 = seq[30]
    s60 = seq[60]
    end = seq[seq.lengt - 1]
    
    ## check general posistive seasonal trends from entry now
    if s0 < s30 then return true 
    if s0 < s60 then return true
    if s0 < end then return true

    ## check general positive seasonal trends from entry in 1 month
    if s30 < s60 then return true
    if s30 < end then return true
    
    return false
 
hasNegativeTrend = (seq) ->
    s0 = seq[0]
    s30 = seq[30]
    s60 = seq[60]
    end = seq[seq.lengt - 1]
    
    ## check general negative seasonal trends from entry now
    if s0 > s30 then return true 
    if s0 > s60 then return true
    if s0 > end then return true

    ## check general negative seasonal trends from entry in 1 month
    if s30 > s60 then return true
    if s30 > end then return true
    
    return false

#endregion

############################################################
# Compare Functions
numberCompare = (a, b, f) ->
    if !a? and b? then return 1
    if !b? and a? then return -1
    if !a? and !b? then return 0

    return (b - a) * f

negNumberCompare = (a, b, f) -> 
    if !a? and b? then return 1
    if !b? and a? then return -1
    if !a? and !b? then return 0

    return ((-b) - (-a)) * f

stringCompare = (a, b, f) -> 
    if !a? and b? then return 1
    if !b? and a? then return -1
    if !a? and !b? then return 0

    if a > b then return (-1) * f 
    if a < b then return f 
    return 0

############################################################
getSortFunction = (sortKey, isAscending) ->
    log "getSortFunction #{sortKey}, #{isAscending}"
    # info = keyToInfo[sortKey] deprecated

    if isAscending then f = -1
    else f = 1

    switch sortKey
        when "symbol" then return (el1, el2) -> stringCompare(el1.symbol, el2.symbol, f)
        when "signal" then return (el1, el2) -> stringCompare(el1.signal, el2.signal, f)
        when "entryDate" then return (el1, el2) -> stringCompare(el1.entryDate, el2.entryDate, f)
        # when "exitDate" then return (el1, el2) -> stringCompare(el1.exitDate, el2.exitDate, f)
        # when "entryPrice" then return (el1, el2) -> numberCompare(el1.entryPrice, el2.entryPrice, f)
        # when "stoploss" then return (el1, el2) -> numberCompare(el1.stoploss, el2.stoploss, f)
        # when "takeprofit1" then return (el1, el2) -> numberCompare(el1.takeprofit1, el2.takeprofit1, f)
        # when "takeprofit2" then return (el1, el2) -> numberCompare(el1.takeprofit2, el2.takeprofit2, f)
        when "score" then return (el1, el2) -> numberCompare(el1.score, el2.score, f)
        when "seasonality10P" then return (el1, el2) -> stringCompare(el1.sasonalityP, el2.sasonality10P, f)
        when "seasonality15P" then return (el1, el2) -> stringCompare(el1.sasonalityP, el2.sasonality10P, f)
        else throw new Error("No sort Function for #{sortKey}!")

    return
        