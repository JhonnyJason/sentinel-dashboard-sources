 ############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("hlcbacktestingmodule")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
import * as dCache from "./datacache.js"

############################################################
export class SymbolBacktester
    constructor: (@symbol, @key) ->
        @runInfoObjects = []
        @summary = null
        ##
        @currentDateObj = new Date()
        @currentYear = @currentDateObj.getFullYear()
        ##
        @rawData = null
        @metaData = null
        ##
        @ready = false
        @evaluated = false

    ############################################################
    loadData: =>
        if @ready then throw new Error("Symbol Backtester #{@symbol}:#{key} illegal loadData when  being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} illegal loadData in an evaluated state!")

        dataPerYear = await dCache.getHistoryHLC(@symbol, 31) ## ensure data is loaded

        @rawData = dCache.getCurrentRawData(@symbol)
        @metaData = dCache.getCurrentMetaData(@symbol)
        
        sf = @metaData.splitFactors
        if !Array.isArray(sf) then @lastSplitFactor = 1.0
        else if sf[sf.length - 1].applied then @lastSplitFactor = sf[sf.length - 1].f
        else @lastSplitFactor = 1.0

        @ready = true
        return

    ############################################################
    addBacktestRun: (startYear, startIdx, endIdx, key) =>
        # startIdx and endIdx need to be real indices - endIdx might be overflown
        
        if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun when not being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun in an evaluated state!")

        if !key? then key = @runInfoObjects.length
        if typeof key != "string" then key = "#{key}"

        infoObj = Object.create(null)

        ## Get correct start/end date + index 
        entryDate = utl.leapNormToYYYYMMDD(startIdx, startYear)
        entryDateObj = new Date(entryDate + "T12:00:00")
        exitDate = utl.leapNormToYYYYMMDD(endIdx, startYear)
        exitDateObj = new Date(exitDate + "T12:00:00")
        
        zeroDateObj = new Date(@metaData.startDate + "T12:00:00")
        dataStartIdx = utl.dateDifDays(zeroDateObj, entryDateObj)
        dataEndIdx = utl.dateDifDays(zeroDateObj, exitDateObj)

        dataStartIdx = getTradableStartIndex(@rawData, dataStartIdx)
        dataEndIdx = getTradableEndIndex(@rawData, dataEndIdx)

        ## Donot add the Backtest Run if it does not result in a tradable range
        if dataStartIdx < 0 or dataEndIdx < 0 then return 
        if dataEndIdx - dataStartIdx < 1 then return 

        entryDateObj = new Date(zeroDateObj)
        entryDateObj.setDate(entryDateObj.getDate() + dataStartIdx)
        exitDateObj = new Date(zeroDateObj)
        exitDateObj.setDate(exitDateObj.getDate() + dataEndIdx)


        infoObj.seq = @rawData.slice(dataStartIdx, dataEndIdx + 1) # we need to include the exit date
        infoObj.seqLen = infoObj.seq.length
        infoObj.entryDate = entryDateObj.toISOString().slice(0, 10)
        infoObj.entryCv = infoObj.seq[0][2] 
        infoObj.exitDate = exitDateObj.toISOString().slice(0, 10)
        infoObj.entryExitDif = utl.dateDifDays(entryDateObj, exitDateObj)
        infoObj.key = key
        # infoObj.intendedStartYear = startYear

        ## add split info
        lastSF = @lastSplitFactor
        if !(lastSF > 1.0) then corrSF = 1.0
        else corrSF = getSplitCorrectionFactor(@metaData.splitFactors, infoObj.entryDate)

        # olog { lastSF, corrSF }
    
        # after a split by fx: Cpre -> Cpost = Cpre / fx
        # We track a virtual close Cv which grows continuously
        # Cv = Cr(=Cpost) * fx (Cr = real close at that time = Cpost)
        # our raw data is all virtual values in this way (forward adjusted)
        # get the real value: Cr(=Cpost) = Cv / fx
        # other plattforms use backwards adjusted values: Cba = Cpre / fx
        # TODO document actual formuals being used here to graps the logic

        infoObj.corrSF = corrSF
        infoObj.missingSF = 1.0 * lastSF / corrSF 
        infoObj.entryCr = infoObj.entryCv / corrSF
        infoObj.entryCba = infoObj.entryCv / lastSF

        @runInfoObjects.push(infoObj)
        return

    ############################################################
    runEvaluationSync: =>
        # log "runEvaluationSync"
        if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot runEvaluationSync when not being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot runEvaluationSync in an evaluated state!")
        
        if @runInfoObjects.length == 0 then return null
        
        # olog @runInfoObjects
        evaluateBacktestRun(infoObj) for infoObj in @runInfoObjects

        keyToRunObjects = Object.create(null)
        keyToRunObjects[infoObj.key] = infoObj for infoObj in @runInfoObjects

        @summary = Object.create(null)
        @summary.key = @key
        @summary.keyToRunObjects = keyToRunObjects

        res = getAverageAndMedianChanges(@runInfoObjects)
        @summary.avgChangeF = res.avgChangeF
        @summary.isLong  = res.avgChangeF > 0.0
        @summary.medChangeF = res.medChangeF
        
        res = countTradeResults(@runInfoObjects, @summary.isLong)
        @summary.winTrades = res.winTrades
        @summary.totalTrades = res.totalTrades

        res = getMaxRiseAndMaxDrop(@runInfoObjects)
        @summary.maxRiseObj = res.maxRiseEl
        @summary.maxDropObj = res.maxDropEl

        @evaluated = true
        return @summary

    
    ############################################################
    destroy: =>
        @summary = null
        @runInfoObjects = null
        @rawData = null
        @metaData = null
        return

    # ############################################################
    # getResults: () => ## maybe add filter and sort options for result?
    #     if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot getResults when not being in ready state!")
    #     if !@evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot getResults when not being in evaluated state!")

    #     resultObj = Object.create(null)
    #     ## TODO compile results?        
    #     return resultObj


    # ############################################################
    # backtestSync: =>
    #     log "backtestSync"
    #     @runEvaluationSync()
    #     return @getResults()


############################################################
countTradeResults = (infoObjs, isLong, ignoreWithWarning = true) ->
    winTrades = 0
    totalTrades = 0
    for el in infoObjs when el?
        if ignoreWithWarning and el.warn then continue
        totalTrades++
        if isLong and el.deltaF > 0.0 then winTrades++
        else if not isLong and el.deltaF < 0.0 then winTrades++
    return { winTrades, totalTrades }

############################################################
getSplitCorrectionFactor = (splitFactors, dateYYYYMMDD) ->
    return 1 unless splitFactors?.length
    # splitFactors = [{f, applied, end: "YYYY-MM-DD"}, ...]

    for sf in splitFactors when dateYYYYMMDD <= sf.end or !sf.end?
        # our date is within range of this splitFactor
        if sf.applied then return sf.f 
        else return 1
    return 1

############################################################
getAverageAndMedianChanges = (infoObjs, ignoreWithWarning = true) ->
    # log "getAverageAndMedianChanges"
    changeSum = 0
    factors = []
    num = 0
    for el,i in infoObjs when el?
        if ignoreWithWarning and el.warn then continue
        changeSum += el.deltaF
        factors.push(el.deltaF)
        num++

    # default to 1, 1 if we donot have a valid year
    if num == 0 then return { avgChangeF: 1.0, medChangeF: 1.0 } 

    avgChangeF = 1.0 * changeSum / num 

    factors.sort((a, b) -> a - b) # sort ascending for median
    if (num % 2) # odd case
        idx = (num - 1) / 2
        medChangeF = factors[idx]
    else # even case
        idx = num / 2
        medChangeF = 0.5 * (factors[idx] + factors[idx - 1])

    return { avgChangeF, medChangeF }

############################################################
getMaxRiseAndMaxDrop = (infoObjs, ignoreWithWarning = true) ->
    # log "getMaxRiseAndMaxDrop"
    maxRiseEl = { maxRiseF: 0.0 }
    maxDropEl = { maxDropF: 0.0 }

    for el in infoObjs when el?
        if ignoreWithWarning and el.warn then continue        
        if el.maxRiseF > maxRiseEl.maxRiseF then maxRiseEl = el
        if el.maxDropF < maxDropEl.maxDropF then maxDropEl = el

    return { maxRiseEl, maxDropEl }

    # ## TODO remove after replacement
    # ## get relevant props from maxDropEl
    # maxDropF = maxDropEl.maxDropF
    # maxDropP = 100.0 * maxDropF
    # maxDropA = maxDropEl.startA * maxDropEl.maxDropF
    # maxDropAba = maxDropEl.startAba * maxDropEl.maxDropF
    # maxDropMissingSF = maxDropEl.missingSF
    
    # ## get relevant props from maxRiseEl
    # maxRiseF = maxRiseEl.maxRiseF
    # maxRiseP = 100.0 * maxRiseF
    # maxRiseA = maxRiseEl.startA * maxRiseEl.maxRiseF
    # maxRiseAba = maxRiseEl.startAba * maxRiseEl.maxRiseF
    # maxRiseMissingSF = maxRiseEl.missingSF

    # return { 
    #     maxDropF, maxDropP, maxDropA, maxDropAba, maxDropMissingSF,
    #     maxRiseF, maxRiseP, maxRiseA, maxRiseAba, maxRiseMissingSF 
    # }

############################################################
evaluateBacktestRun = (infoObj) ->
    # log "evaluate"
    seq = infoObj.seq

    # We start at end of day of the first trade and we leave at end of day of the last Tradeday
    startA = seq[0][seq[0].length - 1] # start price is close of day 0
    endA = seq[seq.length - 1][seq[seq.length - 1].length - 1] # end price is close of the last day

    maxRiseA = startA # day 0 entry as initial maxRise
    maxDropA = startA # day 0 entry as initial maxDrop
    warn = false    
    lastClose = startA

    for i in [1...seq.length]
        if seq[i].length == 3
            high = seq[i][0]
            low = seq[i][1]
            close = seq[i][2]
        else continue # same close no high, no low -> no update
        
        if high > maxRiseA then maxRiseA = high
        if low < maxDropA then maxDropA = low

        # add a warning if any day to day difference is too much (+42.9% or -30%)
        closeDelta = close - lastClose
        closeDeltaF = 1.0 * closeDelta / lastClose
        warn = (warn or closeDeltaF > 0.429 or closeDeltaF < -0.3)   
        lastClose = close

    # Calculate facors to easily get the percentages
    infoObj.deltaF = (1.0 * endA / startA) - 1.0
    infoObj.maxRiseF = (1.0 * maxRiseA / startA) - 1.0
    infoObj.maxDropF = (1.0 * maxDropA / startA) - 1.0
    
    infoObj.warn = warn
    return 


############################################################
getTradableStartIndex = (data, idx) ->
    # log "getTradableStartIndex"
    safetyCount = 32
    loop
        if --safetyCount < 0 # prevent infinite loops
            console.error("getTradableStartIndex reached safety Limit!") 
            return -1
        
        if !Array.isArray(data[idx]) then return -1
        if data[idx].length  > 1 then return idx
        idx++
    
    return -1

############################################################
getTradableEndIndex = (data, idx) ->
    # log "getTradableEndIndex"
    safetyCount = 32
    loop
        if --safetyCount < 0 # prevent infinite loops
            console.error("getTradableEndIndex reached safety Limit!") 
            return idx # fallback

        if !Array.isArray(data[idx]) then return -1
        if data[idx].length  > 1 then return idx
        idx--

    return idx