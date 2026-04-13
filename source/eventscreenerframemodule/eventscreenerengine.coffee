############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreeningengine")
#endregion

############################################################
import { createDayFromDate } from "./utilsmodule.js"

############################################################
export resultStructure = [
    { label: "Symbol", key: "symbol", sort: "none" }
    # { label: "MarketCap", key, "marketcap", sort: true }
    { label: "Ereignis", key: "eventLabel", sort: "none"}
    { label: "", key: "direction", sort: "none" }
    { label: "Trefferquote", key: "winrate", sort: "number" }
    { label: "Profit (Dur.)", key: "profitAvg", sort: "number" }
    { label: "Profit (Med.)", key: "profitMed", sort: "number" }
    { label: "Max Anstieg", key: "maxGain", sort: "number" }
    { label: "Max Rückgang", key: "maxDrop", sort: "number" }
    { label: "Nächstes Ereignis", key: "nextDate", sort: "none" }
    { label: "Einstieg (EoD)", key: "entryDate", sort: "date" }
    { label: "Ausstieg (EoD)", key: "exitDate", sort: "date" }
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
allEvals = []
allResults = []

############################################################
pending = []

############################################################
screeningInputs = null
isScreening = false
restartScreening = false


############################################################
export stopScreening = ->
    log "stopScreening"
    isScreening = false
    restartScreening = false
    return

############################################################
export startScreening = (symbolToData, eventList) ->
    log "doScreening"
    # eventIdToDates = Object.create(null)
    # eventIdToDates[evnt.id] = evnt.datesToScreen for evnt in eventList
    # screeningInputs = { symbolToData, eventList, eventIdToDates }
    screeningInputs = { symbolToData }

    if isScreening
        restartScreening = true
        # throw new Error("We donot wait for Rerender!")
        promFun = (rslv, rjct) -> pending.push({ rslv, rjct })
        return new Promise(promFun)

    isScreening = true
    trades4D = getTrades4D()
    trades14D = getTrades14D()

    try loop
        start = performance.now()
        allEvals = []
        allResults = []
        symbols = Object.keys(symbolToData)
        for sym,i in symbols
            log "evaluating #{sym} @#{i}"
            for evnt,j in eventList when evnt.datesToScreen?
                log "... evaluating #{sym}:#{evnt.id} @#{i}:#{j}"

                if evnt.isWeekly then trades = trades4D
                else trades = trades14D


                for trade in trades
                    evaluation = evaluateEventTrades(sym, evnt, trade)
                    allEvals.push(evaluation)
                    result = generateResultObject(evaluation, evnt)
                    allResults.push(result)
    
                    if performance.now() - start > maxBusyTimeMS
                        await letMainThreadRun()
                        log "hit calculation barrier @#{i}:#{j}!"
                        if restartScreening then break # restart inner loop
                        if !isScreening then return # stop fully
                        start = performance.now()

        if i == symbols.length
            log "we reached the end of the outer loop @#{i}"
            break # the outer loop


    catch err then log err
    finally isScreening = false
    log "Finished Screening, we have #{allEvals.length} evaluations."
    waiters = [...pending]
    pending = []
    w.rslv() for w in waiters
    return 


############################################################
export getResults = (limit, sortKey, isAscending) ->
    log "getResults"
    sortFunction = getSortFunction(sortKey, isAscending)
    allResults.sort(sortFunction)
    if limit > allResults.length then return [...allResults]

    results = []
    results.push(allResults[i]) for i in [0...limit]
    return results

############################################################
getSortFunction = (sortKey, isAscending) ->
    log "getSortFunction #{sortKey}, #{isAscending}"
    info = keyToInfo[sortKey]
    
    if info.sort == "number" and isAscending then return (el1, el2) -> 
        el1[sortKey] - el2[sortKey]
    if info.sort == "number" then return (el1, el2) -> 
        el2[sortKey] - el1[sortKey]

    if info.sort == "date" and isAscending then return (el1, el2) ->
        if el1[sortKey] < el2[sortKey] then return -1
        if el1[sortKey] > el2[sortKey] then return 1
        return 0
    
    if info.sort == "date" then return (el1, el2) ->
        if el1[sortKey] > el2[sortKey] then return -1
        if el1[sortKey] < el2[sortKey] then return 1
        return 0
    
    throw new Error("No Sort Function to be found!")
    return
        

############################################################
evaluateEventTrades = (sym, evnt, trade) ->
    key = "#{sym}:#{evnt.id}:#{trade}"
    dates = evnt.datesToScreen
    # log "#{evnt.id} has #{dates.length} dates to screen!"
    tradeResults = dates.map((date) -> getTradeResult(sym, trade, date))

    direction = ""
    maxGainF = 0.0
    maxDropF = 1.0
    avgDeltaF = 0.0
    medDeltaF = 0.0

    longSuccessCount = 0
    shortSuccessCount = 0

    for result in tradeResults
        # olog result # { deltaF, maxGainF, maxDropF }
        avgDeltaF += result.deltaF
        
        if result.deltaF > 1 then longSuccessCount++
        if result.deltaF < 1 then shortSuccessCount++

        if maxGainF < result.maxGainF then maxGainF = result.maxGainF
        if maxDropF > result.maxDropF then maxDropF = result.maxDropF

    avgDeltaF = avgDeltaF / tradeResults.length

    tradeResults.sort((el1, el2) -> el2.deltaF - el1.deltaF)
    if tradeResults.length % 2 # odd case
        medDeltaF = tradeResults[tradeResults.length / 2].deltaF
    else
        medDeltaF = tradeResults[Math.floor(tradeResults.length / 2)].deltaF
        medDeltaF += tradeResults[Math.floor(tradeResults.length / 2) - 1].deltaF
        medDeltaF *= 0.5

    if avgDeltaF > 1
        direction = "Long"
        profitAvgP = 100.0 * (avgDeltaF - 1.0)
        profitMedP = 100.0 * (medDeltaF - 1.0)
        maxGainP = 100.0 * (maxGainF - 1.0)
        maxDropP = 100.0 * (maxDropF - 1.0)
        winrate = 100.0 * longSuccessCount / tradeResults.length
    else 
        direction = "Short"
        profitAvgP = 100.0 * (1.0 - avgDeltaF)
        profitMedP = 100.0 * (1.0 - medDeltaF)
        maxGainP = 100.0 * (maxGainF - 1.0)
        maxDropP = 100.0 * (maxDropF - 1.0)
        winrate = 100.0 * shortSuccessCount / tradeResults.length
    
    return { key, direction, winrate, profitAvgP, profitMedP, maxGainP, maxDropP }

############################################################
getTradeResult = (sym, trade, date) ->
    # log "getTradeResult #{date}"
    data = screeningInputs.symbolToData[sym]

    tkns = trade.split("-")
    entrIdx = parseInt(tkns[0])
    exitIdx = parseInt(tkns[1])
    evntIdx = parseInt(tkns[2])
    relEntry = entrIdx - evntIdx
    relExit = exitIdx - evntIdx

    eventDay = createDayFromDate(date)
    entryDay = eventDay.getRelativeDay(relEntry)
    exitDay = eventDay.getRelativeDay(relExit)


    entryDP = entryDay.lookupIn(data)
    exitDP = exitDay.lookupIn(data)
    
    # olog { entryDP, exitDP }
    if !entryDP? or !exitDP?
        log "Case without entry or exit DP!"
        entryDate = entryDay.getYYYYMMDD()
        exitDate = exitDay.getYYYYMMDD()

        olog {
            date
            relEntry
            relExit
            entryDate
            exitDate
        }

    return null unless entryDP? and exitDP?

    entryC = entryDP[entryDP.length - 1]
    exitC = exitDP[exitDP.length - 1]
    deltaAbs = exitC - entryC
    deltaF = 1.0 + (1.0 * deltaAbs / entryC)

    maxAbs = entryC
    minAbs = entryC

    day = entryDay.getNextDay()
    count = exitIdx - entrIdx
    while count--
        dayDP = day.lookupIn(data)
        dayHighAbs = dayDP[0]
        ## either we have 3 values [ H,L,C ] or we only have one [ C=H=L ] (non-trading days)
        if dayDP.length == 3 then dayLowAbs = dayDP[1]
        else dayLowAbs = dayHighAbs

        if dayHighAbs > maxAbs then maxAbs = dayHighAbs
        if dayLowAbs < minAbs then minAbs = dayLowAbs
        day = day.getNextDay()

    maxGainF = 1.0 * maxAbs / entryC
    maxDropF = 1.0 * minAbs / entryC

    return { deltaF, maxGainF, maxDropF }

############################################################
getNextTradeDates = (trade, evnt) ->
    # log "getNextTradeDates"
    tkns = trade.split("-")
    entrIdx = parseInt(tkns[0])
    exitIdx = parseInt(tkns[1])
    evntIdx = parseInt(tkns[2])
    
    relEntry = entrIdx - evntIdx
    relExit = exitIdx - evntIdx
    try
        dates = evnt.nextDates
        for date in dates
            eventDay = createDayFromDate(date)
            entryDay = eventDay.getRelativeDay(relEntry)
            exitDay = eventDay.getRelativeDay(relExit)

            entryDate = entryDay.getYYYYMMDD()
            todayDate = (new Date()).toISOString().slice(0, 10)

            if entryDate > todayDate then break

        nextDate = eventDay.getYYYYMMDD()
        nextEntryDate = entryDay.getYYYYMMDD()
        nextExitDate = exitDay.getYYYYMMDD()

    catch err
        log err
        olog { trade, dates }
        return {}

    return { nextDate, nextEntryDate, nextExitDate }

############################################################
generateResultObject = (evaluation, evnt) ->
    # log "generateResultObject"
    result = Object.create(null)
    # { key, direction, profitAvgP, profitMedP, maxGainP, maxDropP } = evaluation
    tkns = evaluation.key.split(":")
    symbol = tkns[0]
    evntId = tkns[1]
    trade = tkns[2]

    { nextDate, nextEntryDate, nextExitDate } = getNextTradeDates(trade, evnt)
    if !nextDate? then throw new Error("getNextTradeDates failed to return nextDate!") 
    #     log 
    #     olog evaluation

    result.symbol = symbol 
    # result.marketcap = # donot use for now  
    result.eventLabel = evnt.label
    result.direction = evaluation.direction
    result.winrate = evaluation.winrate
    result.profitAvg = evaluation.profitAvgP
    result.profitMed = evaluation.profitMedP
    result.maxGain =  evaluation.maxGainP
    result.maxDrop =  evaluation.maxDropP
    result.nextDate = nextDate
    result.entryDate = nextEntryDate
    result.exitDate = nextExitDate

    return result

############################################################
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
