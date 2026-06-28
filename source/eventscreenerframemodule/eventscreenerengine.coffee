############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreeningengine")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
import * as dCache from "./datacache.js"

import { SymbolBacktester } from "./hlcbacktestingmodule.js"
import { filterResult } from "./resultfilterstate.js"

############################################################
export resultStructure = [
    { label: "Symbol", key: "symbol", sort: on }
    # { label: "MarketCap", key, "marketcap", sort: on }
    { label: "Ereignis", key: "eventLabel", sort: on}
    { label: "", key: "direction", sort: on }
    { label: "Trefferquote", key: "winrate", sort: on }
    { label: "Profit Dur.", key: "profitAvg", sort: on }
    { label: "Profit Med.", key: "profitMed", sort: on }
    { label: "Max Anstieg (Absolut)", key: "maxRise", sort: on }
    { label: "Max Rückgang (Absolut)", key: "maxDrop", sort: on }
    { label: "Nächstes Ereignis", key: "nextDate", sort: on }
    { label: "Einstieg EoD", key: "entryDate", sort: on }
    { label: "Ausstieg EoD", key: "exitDate", sort: on }
]

############################################################
keyToInfo = Object.create(null)
keyToInfo[d.key] = d for d in resultStructure

############################################################
maxBusyTimeMS = 5

############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));
    
############################################################
allResults = []

############################################################
# grouped by symbol:eventId
groupedResults = []

############################################################
pending = []

############################################################
screeningInputs = null
isScreening = false
restartScreening = false

############################################################
export startScreening = (symbolToData, eventList) ->
    log "doScreening"

    # olog eventList.map((el) -> el.id)
    # eventIdToDates = Object.create(null)
    # eventIdToDates[evnt.id] = evnt.datesToScreen for evnt in eventList
    # screeningInputs = { symbolToData, eventList, eventIdToDates }
    screeningInputs = { symbolToData, eventList }

    if isScreening # protect from simultaneous runs
        restartScreening = true
        # throw new Error("We donot wait for Rerender!")
        promFun = (rslv, rjct) -> pending.push({ rslv, rjct })
        return new Promise(promFun) # still awaitable ;-)
    
    isScreening = true
    trades4D = getTrades4D()
    trades14D = getTrades14D()
    groupedResults = []

    try loop
        start = performance.now()
        allResults = []
        symbols = Object.keys(symbolToData)
        for sym,i in symbols
            # log "evaluating #{sym} @#{i}"
            for evnt,j in eventList when evnt.datesToScreen?
                groupKey ="#{sym}:#{evnt.id}"
                # log "... evaluating #{groupKey} @#{i}:#{j}"
                groupResults = []

                if evnt.isWeekly then trades = trades4D
                else trades = trades14D

                for trade in trades
                    evaluation = await evaluateEventTrades(sym, evnt, trade)
                    result = generateResultSummaryObject(evaluation, evnt)
                    if result?
                        allResults.push(result)
                        groupResults.push(result)
    
                    if performance.now() - start > maxBusyTimeMS
                        await letMainThreadRun()
                        # log "hit calculation barrier @#{i}:#{j}!"
                        if restartScreening then break # restart inner loop
                        if !isScreening then return # stop fully
                        start = performance.now()
                
                groupedResults[groupKey] = groupResults

        if i == symbols.length
            log "we reached the end of the outer loop @#{i}"
            break # the outer loop

    catch err then log err
    finally isScreening = false
    log "Finished Screening, we have #{allResults.length} results."
    waiters = [...pending]
    pending = []
    w.rslv() for w in waiters
    return 

############################################################
export getResults = (limit, sortKey, isAscending) ->
    log "getResults"
    sortFunction = getSortFunction(sortKey, isAscending)
    results = []
    for groupKey, groupResults of groupedResults
        groupResults.sort(sortFunction)
        tmp = groupResults.filter(filterResult)
        bestGroupResult = tmp[0]
        if bestGroupResult? then results.push(bestGroupResult)

    # each groupd was added independently -> sort    
    results.sort(sortFunction)
    
    if limit > results.length then return results
    return results.slice(0, limit)  

############################################################
export getTradeResultDetails = (tradeKey) ->
    log "getTradeResultDetails"
    log tradeKey
    tkns = tradeKey.split(":")
    if tkns.length != 3 then throw new Error("Invalid TradeKey! #{tradeKey}")
    sym = tkns[0]
    evntId = tkns[1]
    trade = tkns[2]

    evnt = null
    for e in screeningInputs.eventList when e.id == evntId
        evnt = e
        break
    if !evnt? then throw new Error("Could not find the target Event with id #{evntId}")

    evaluation = await evaluateEventTrades(sym, evnt, trade)
    result = generateResultDetailsObject(evaluation, evnt, trade)
    if !result? then throw new Error("Could not evaluateEventTrades for #{tradeKey}")

    return result

############################################################
evaluateEventTrades = (sym, evnt, trade) ->
    try
        key = "#{sym}:#{evnt.id}:#{trade}"
        dates = evnt.datesToScreen

        backtester = new SymbolBacktester(sym, key)
        await backtester.loadData()

        for date in dates
            year = parseInt(date.slice(0,4))
            runKey = key + "@#{date}"
            res = getLeapNormIndicesForTrade(date, trade)
            backtester.addBacktestRun(year, res.startIdxLN, res.endIdxLN, runKey)
        
        return backtester.runEvaluationSync()
    
    catch err then console.error("@eventscreenerengine.evaluateEventTrades: #{err.message}")
    return null

    # backtester.reunEvaluationSync returns: { keyToInfoObjects X,
    #    key, runObjects, avgChangeF, medChangeF, isLong, winrate, totalTrades,
    #    maxRiseObj, maxDropObj 
    # }


############################################################
generateResultDetailsObject = (evaluation, evnt, trade) ->
    log "generateResultDetailsObject"
    log "evaluation.isLong: #{evaluation.isLong}"
    detailsObj = Object.create(null)

    # main summary data
    if evaluation.isLong
        detailsObj.direction = "Long"
        detailsObj.profitAvg = 100.0 * evaluation.avgChangeF
        detailsObj.profitMed = 100.0 * evaluation.medChangeF
    else
        detailsObj.direction = "Short"
        detailsObj.profitAvg = -100.0 * evaluation.avgChangeF
        detailsObj.profitMed = -100.0 * evaluation.medChangeF

    detailsObj.winTrades = evaluation.winTrades
    detailsObj.totalTrades = evaluation.totalTrades

    # avergage daily return pattern
    avgDailyReturnSeq = await getAverageDailyReturnSeq(evaluation.runInfoObjects, evaluation.key)

    # log avgDailyReturnSeq.length 
    # log avgDailyReturnSeq

    detailsObj.avgDailyReturn = avgDailyReturnSeq
    
    # next possible entry for this event
    { nextDate, nextEntryDate, nextExitDate } = getNextTradeDates(trade, evnt)
    detailsObj.nextDate = nextDate
    detailsObj.nextEntryDate = nextEntryDate
    detailsObj.nextExitDate = nextExitDate

    # extremes
    if evaluation.maxDropObj?
        detailsObj.maxDrop = 100.0 * evaluation.maxDropObj.maxDropF
        detailsObj.maxDropAba = evaluation.maxDropObj.entryCba * evaluation.maxDropObj.maxDropF
        detailsObj.maxDropMissingSF = evaluation.maxDropObj.missingSF
    else
        detailsObj.maxDrop = 0.0
        detailsObj.maxDropAba = 0.0
        detailsObj.maxDropMissingSF = 1.0

    if evaluation.maxRiseObj?
        detailsObj.maxRise = 100.0 * evaluation.maxRiseObj.maxRiseF
        detailsObj.maxRiseAba = evaluation.maxRiseObj.entryCba * evaluation.maxRiseObj.maxRiseF
        detailsObj.maxRiseMissingSF = evaluation.maxRiseObj.missingSF
    else
        detailsObj.maxRise = 0.0
        detailsObj.maxRiseAba = 0.0
        detailsObj.maxRiseMissingSF = 1.0

    # all Results
    detailsObj.infoObjects = evaluation.runInfoObjects
    return detailsObj

############################################################
generateResultSummaryObject = (evaluation, evnt) ->
    # log "generateResultObject"

    result = Object.create(null)
    # evaluation:
    # { key, isLong, avgChangeF, medChangeF, winTrades, totalTrades, maxRiseObj, maxDropObj }

    tkns = evaluation.key.split(":")
    symbol = tkns[0]
    evntId = tkns[1]
    trade = tkns[2]
    
    { nextDate, nextEntryDate, nextExitDate } = getNextTradeDates(trade, evnt)
    # if !nextDate? then throw new Error("getNextTradeDates failed to return nextDate!") 
    if !nextDate? then return null # we possibly had impossible exit and entry dates... 

    if evaluation.isLong
        direction = "Long"
        profitF = 100.0
    else
        direction = "Short"
        profitF = -100.0
    
    result.symbol = symbol 
    # result.marketcap = # donot use for now  
    result.eventLabel = evnt.label
    result.direction = direction
    
    if evaluation.totalTrades == 0 then result.winrate = 0
    else result.winrate = 100.0 * evaluation.winTrades / evaluation.totalTrades 
    
    result.profitAvg = profitF * evaluation.avgChangeF
    result.profitMed = profitF * evaluation.medChangeF

    # extremes
    if evaluation.maxRiseObj?
        result.maxRise = 100.0 * evaluation.maxRiseObj.maxRiseF
        result.maxRiseAba = evaluation.maxRiseObj.entryCba * evaluation.maxRiseObj.maxRiseF
        result.maxRiseMissingSF = evaluation.maxRiseObj.missingSF
    else
        result.maxRise = 0.0
        result.maxRiseAba = 0.0
        result.maxRiseMissingSF = 1.0

    if evaluation.maxDropObj?
        result.maxDrop = 100.0 * evaluation.maxDropObj.maxDropF
        result.maxDropAba = evaluation.maxDropObj.entryCba * evaluation.maxDropObj.maxDropF
        result.maxDropMissingSF = evaluation.maxDropObj.missingSF
    else
        result.maxDrop = 0.0
        result.maxDropAba = 0.0
        result.maxDropMissingSF = 1.0

    # if !evaluation.maxRiseObj? then result.maxRise = 0.0
    # else result.maxRise =  100.0 * evaluation.maxRiseObj.maxRiseF
    
    # if !evaluation.maxDropObj? then result.maxDrop = 0.0
    # else result.maxDrop =  100.0 * evaluation.maxDropObj.maxDropF
    
    result.nextDate = nextDate
    result.entryDate = nextEntryDate
    result.exitDate = nextExitDate
    result.tradeKey = evaluation.key
    # log "result object ready"
    return result


############################################################
#region general Helper Functions
getTrades14D = ->
    #idx 0 = 14th day before
    #idx 28 = 14th day after
    result = []
    for i in [0..27]
        for j in[(i+1)..28]
            result.push("#{i}-#{j}-14")
    return result

getTrades4D = ->
    #idx 0 = 4th day before
    #idx 8 = 4th day after
    result = []
    for i in [0..7]
        for j in[(i+1)..8]
            result.push("#{i}-#{j}-4")
    return result

############################################################
getLeapNormIndicesForTrade = (date, trade) ->
    tkns = trade.split("-")
    entrIdx = parseInt(tkns[0])
    exitIdx = parseInt(tkns[1])
    evntIdx = parseInt(tkns[2])
    
    relEntry = entrIdx - evntIdx
    relExit = exitIdx - evntIdx

    tradeDate = new Date(date+"T12:00:00")
    isLeap = utl.isLeapYear(tradeDate.getFullYear())
    idxR = utl.getDayOfYear(tradeDate) # real index of trade date
    idxLN = utl.realToLeapNormIdx(idxR, isLeap) # Leap normed index of trade date
    
    result = Object.create(null)

    # We need to return Leap Normed Indices for the backtester.addBacktestRun()
    result.startIdxLN = idxLN + relEntry
    result.endIdxLN = idxLN + relExit
    return result

############################################################
getNextTradeDates = (trade, evnt) ->
    # log "getNextTradeDates"

    ## TODO introduce options to adjust behaviour...
    #    - case 0: neither exit nor entry date is a weekend -> next date in future
    #    - case 1: either exit or entry is on a weekend
    #    - case 1.a: trade becomes non-tradable -> next date
    #    - case 1.b: filter is set with mintraduduration and it falls short -> next date?
    #    - case 1.c: filter is set to ignore dates that fall on Weekends -> next date 

    tkns = trade.split("-")
    entrIdx = parseInt(tkns[0])
    exitIdx = parseInt(tkns[1])
    evntIdx = parseInt(tkns[2])
    
    relEntry = entrIdx - evntIdx
    relExit = exitIdx - evntIdx

    result = Object.create(null)

    try
        # olog evnt.nextDates
        dates = evnt.nextDates
        todayDate = (new Date()).toISOString().slice(0, 10)
        for date in dates # dates are YYYY-MM-DD strings
            dateObj = new Date(date+"T12:00:00")
            idxR = utl.getDayOfYear(dateObj)
            entryIdxR = idxR + relEntry
            exitIdxR = idxR + relExit

            targetEntry = utl.realIdxToYYYYMMDD(dateObj.getFullYear(), entryIdxR)
            targetExit = utl.realIdxToYYYYMMDD(dateObj.getFullYear(), exitIdxR)

            effEntry = utl.nextWeekdayAfter(targetEntry)
            effExit = utl.lastWeekdayBefore(targetExit)
            # log "attempt af effEntry: #{effEntry}"
            if effEntry < todayDate then continue ## our entry is not in the future
            if effEntry == effExit or effEntry > effExit then continue ## not tradable
    
            ## results are also YYYY-MM-DD strings
            result.nextDate = date 
            result.nextEntryDate = effEntry
            result.nextExitDate = effExit
            # olog result
            return result
    catch err
        log err
        olog { trade, dates }
        return result

    return result

############################################################
getAverageDailyReturnSeq = (infoObjects, key) ->
    # log "getAverageDailyReturnSeq"
    # log key
    tkns = key.split(":")
    sym = tkns[0]
    trade = tkns[2] 
    tkns = trade.split("-")
    centerIdx = parseInt(tkns[2])
    fullLen = 2 * centerIdx + 1

    dataPerYear = await dCache.getHistoryHLC(sym, 31) ## ensure data is loaded
    rawData = dCache.getCurrentRawData(sym)
    metaData = dCache.getCurrentMetaData(sym)

    zeroDateObj = new Date(metaData.startDate + "T12:00:00")
    count = 0
    sums = new Array(fullLen - 1).fill(0)
    # log zeroDateObj

    for obj in infoObjects
        evntDateObj = getCorrespondingDateObj(obj)
        rawStartIdx = utl.dateDifDays(zeroDateObj, evntDateObj) - centerIdx
        # log rawStartIdx
        end = rawStartIdx + fullLen
        # do we have all data available for this event?
        if rawStartIdx < 0 or end >= rawData.length then continue 
        
        count++ # adding another row of factors
        seq = rawData.slice(rawStartIdx, end)
        factorsArray = utl.toFactorsArray(seq.map((el) -> el[el.length - 1]))
        if factorsArray.length != sums.length then alert("unexpected factorsArray length!")
        sums[i] += f for f,i in factorsArray

    cumFactors = []
    cumFactors.push(sum / count) for sum in sums 

    return utl.fromFactorsForward(cumFactors)


############################################################
getCorrespondingDateObj = (runObj) ->
    date = runObj.key.split("@")[1]
    # log date
    return new Date(date + "T12:00:00")
    
#endregion

############################################################
#region Compare Functions + getSortFunction
numberCompare = (a, b, f) -> (b - a) * f
negNumberCompare = (a, b, f) -> ((-b) - (-a)) * f
stringCompare = (a, b, f) ->
    if a > b then return (-1) * f 
    if a < b then return f 
    return 0

############################################################
getSortFunction = (sortKey, isAscending) ->
    log "getSortFunction #{sortKey}, #{isAscending}"
    info = keyToInfo[sortKey]
    
    if isAscending then f = -1
    else f = 1

    switch sortKey
        when "symbol" then return (el1, el2) -> stringCompare(el1.symbol, el2.symbol, f)
        when "marketcap" then return (el1, el2) -> numberCompare(el1.marketcap, el2.marketcap, f)
        when "eventLabel" then return (el1, el2) -> stringCompare(el1.eventLabel, el2.eventLabel, f)
        when "direction" then return (el1, el2) -> stringCompare(el1.direction, el2.direction, f)
        when "winrate" then return (el1, el2) -> numberCompare(el1.winrate, el2.winrate, f)
        when "profitAvg" then return (el1, el2) -> numberCompare(el1.profitAvg, el2.profitAvg, f)
        when "profitMed" then return (el1, el2) -> numberCompare(el1.profitMed, el2.profitMed, f)
        when "maxRise" then return (el1, el2) -> numberCompare(el1.maxRise, el2.maxRise, f)
        when "maxDrop" then return (el1, el2) -> negNumberCompare(el1.maxDrop, el2.maxDrop, f)
        when "nextDate" then return (el1, el2) -> stringCompare(el1.nextDate, el2.nextDate, f)
        when "entryDate" then return (el1, el2) -> stringCompare(el1.entryDate, el2.entryDate, f)
        when "exitDate" then return (el1, el2) -> stringCompare(el1.nextDate, el2.exitDate, f)
        else throw new Error("No sort Function for #{sortKey}!")
    return
        
#endregion