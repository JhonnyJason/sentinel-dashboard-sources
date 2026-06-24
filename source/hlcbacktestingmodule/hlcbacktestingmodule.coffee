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
    addBacktestRun: (startYear, startIdxLN, endIdxLN, key) =>
        # startIdxLN and endIdxLN need to be leap Norm indices - endIdxLN might be overflown
        # olog { startYear, startIdxLN, endIdxLN, key }

        # (= addBacktestRun[startYear, startIdxLN, endIdxLN, key] # definition
        # res =(addBacktestRun[startYear, startIdxLN, endIdxLN, key] # execution
        
        maxSeqLen = endIdxLN - startIdxLN + 1

        if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun when not being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun in an evaluated state!")

        endYear = startYear
        count = 4
        while startIdxLN < 0
            startIdxLN += 366
            startYear--
            count--
            throw new Error("Index Adjustment.Illegal overflow!(>=4 years)") if count == 0
        
        count = 4
        while endIdxLN > 366
            endIdxLN -= 366
            endYear++
            count--
            throw new Error("Index Adjustment.Illegal overflow!(>=4 years)") if count == 0

        if !key? then key = @runInfoObjects.length
        if typeof key != "string" then key = "#{key}"

        # olog {startYear, startIdxLN, endYear, endIdxLN, maxSeqLen}

        infoObj = Object.create(null)
        @runInfoObjects.push(infoObj)
        
        infoObj.key = key

        ## targeted start/end dates  
        entryDate = utl.leapNormToYYYYMMDD(startIdxLN, startYear)
        entryDateObj = new Date(entryDate + "T12:00:00")
        exitDate = utl.leapNormToYYYYMMDD(endIdxLN, endYear)
        exitDateObj = new Date(exitDate + "T12:00:00")
        # olog { entryDate, exitDate }

        ## get effectively tradable start/end index
        zeroDateObj = new Date(@metaData.startDate + "T12:00:00")
        # log zeroDateObj.toISOString()
        dataStartIdx = utl.dateDifDays(zeroDateObj, entryDateObj) # real index
        dataEndIdx = utl.dateDifDays(zeroDateObj, exitDateObj) # real index
        # olog { dataStartIdx, dataEndIdx }
        dataStartIdx = getTradableStartIndex(@rawData, dataStartIdx) # real index
        dataEndIdx = getTradableEndIndex(@rawData, dataEndIdx) # real index
        # olog { dataStartIdx, dataEndIdx }
        
        ## Donot add the Backtest Run if it does not result in a tradable range
        tradable = true
        if dataStartIdx < 0 or dataEndIdx < 0 then tradable = false
        if dataEndIdx - dataStartIdx < 1 then tradable = false
        
        infoObj.tradable = tradable
        if !infoObj.tradable then return

        # exctract traded sequence
        infoObj.seq = @rawData.slice(dataStartIdx, dataEndIdx + 1) # including exit data point
        infoObj.seqLen = infoObj.seq.length
        infoObj.maxSeqLen = maxSeqLen

        if infoObj.seqLen > maxSeqLen then throw new Error("infoObj.seqLen (#{infoObj.seqLen}) > maxSeqLen (#{maxSeqLen})")


        ## get the effectively tradable start/end dates
        entryDateObj = new Date(zeroDateObj)
        entryDateObj.setDate(zeroDateObj.getDate() + dataStartIdx)
        exitDateObj = new Date(zeroDateObj)
        exitDateObj.setDate(zeroDateObj.getDate() + dataEndIdx)

        infoObj.entryDate = entryDateObj.toISOString().slice(0, 10)
        infoObj.exitDate = exitDateObj.toISOString().slice(0, 10)
        # entryExitDif = seqLen - 1
        # infoObj.entryExitDif = utl.dateDifDays(entryDateObj, exitDateObj)

        infoObj.effEntryIdx = utl.getDayOfYear(entryDateObj) # real index of effective entryDate
        # effExitIdx = effEntryIdx + seqLen - 1

        ## save other indices to know how much we are off target in real or leap normed terms
        infoObj.startIdxLN = startIdxLN # leap-normed start index (target)
        infoObj.endIdxLN = endIdxLN # leap-normed end index (target)
        
        isLeap = utl.isLeapYear(startYear)
        infoObj.startIdxR = utl.leapNormToRealIdx(startIdxLN, isLeap) # real start index (target)
        infoObj.startYear = startYear
        
        isLeap = utl.isLeapYear(endYear)
        infoObj.endIdxR = utl.leapNormToRealIdx(endIdxLN, isLeap) # real end index (target)
        infoObj.endYear = endYear
        
        ## Absolute virtual entry close -> reference for all absolute values
        infoObj.entryCv = infoObj.seq[0][2] 
        
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
        
        # olog infoObj
        # alert("Stoping Execution -> debug!")
        # # throw new Error("Death on Purpose!")
        return

    ############################################################
    runEvaluationSync: =>
        # log "runEvaluationSync"
        if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot runEvaluationSync when not being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot runEvaluationSync in an evaluated state!")
                
        # olog @runInfoObjects
        runObjects = @runInfoObjects.filter((el) -> el.tradable)
        evaluateTradableRun(obj) for obj in runObjects

        # keyToRunObjects = Object.create(null)
        # keyToRunObjects[infoObj.key] = infoObj for infoObj in @runInfoObjects

        @summary = Object.create(null)
        @summary.key = @key
        # @summary.keyToRunObjects = keyToRunObjects
        @summary.runInfoObjects = @runInfoObjects 
        
        if runObjects.length > 0
            res = getAverageAndMedianChanges(runObjects)
            @summary.avgChangeF = res.avgChangeF
            @summary.medChangeF = res.medChangeF
            @summary.isLong  = res.avgChangeF > 0.0
            
            res = countTradeResults(runObjects, @summary.isLong)
            @summary.winTrades = res.winTrades
            @summary.totalTrades = res.totalTrades

            res = getMaxRiseAndMaxDrop(runObjects)
            @summary.maxRiseObj = res.maxRiseEl
            @summary.maxDropObj = res.maxDropEl
        else
            @summary.noTrades = true
            @summary.avgChangeF = 0.0
            @summary.medChangeF = 0.0
            @summary.isLong  = false
        
            @summary.winTrades = 0
            @summary.totalTrades = 0

            @summary.maxRiseObj = null
            @summary.maxDropObj = null

        @evaluated = true
        return @summary

    
    ############################################################
    destroy: =>
        @summary = null
        @runInfoObjects = null
        @rawData = null
        @metaData = null
        return


############################################################
countTradeResults = (infoObjs, isLong, ignoreWithWarning = true) ->
    winTrades = 0
    totalTrades = 0
    for el in infoObjs
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
    for el,i in infoObjs
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
    maxRiseEl = { maxRiseF: -0.1 }
    maxDropEl = { maxDropF: 0.1 }

    for el in infoObjs
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
evaluateTradableRun = (runObj) ->
    # log "evaluateTradableRun"

    seq = runObj.seq

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
    runObj.deltaF = (1.0 * endA / startA) - 1.0
    runObj.maxRiseF = (1.0 * maxRiseA / startA) - 1.0
    runObj.maxDropF = (1.0 * maxDropA / startA) - 1.0
    
    runObj.warn = warn
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