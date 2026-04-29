############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("backtesting")
#endregion

############################################################
import * as utl from "./utilsmodule.js"

############################################################
#region Backtesting + Evaluations

############################################################
export runBacktesting = (args) ->
    log "runBacktesting"
    # {dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear} = args
    { dataPerYear, startIdx, endIdx } = args
    # All indices passed to this module are nonLeapNorm (0-364)
    # dataPerYear index 0 = current year (incomplete) 
    # dataPerYear index n-1 = oldest (might be incomplete)

    if startIdx < 0 ## negative startIdx means it was in the previous year
        sequences = getAllOverappedSequences(dataPerYear, startIdx, endIdx)
    else ## positive startIdx means startIdx and endIdx are in same year
        sequences = getAllNonOverlapSequences(dataPerYear, startIdx, endIdx)
    
    return evaluate(sequences, args)

############################################################
evaluate = (sequences, opts) ->
    log "evaluate"
    results = sequences.map((seq) -> backtestSequence(seq))
    splits = opts.metaData?.splitFactors
    addSplitsInfo(results, splits, opts.startIdx, opts.endIdx)
    return evaluateResults(results, opts)

############################################################
evaluateResults = (results, opts) ->
    log "evaluateResults"
    { startIdx, endIdx, tradingDaysPerYear } = opts
    { avgChangeF, medChangeF } = getAverageAndMedianChanges(results)
    { maxDropF, maxDropP, maxDropA, maxDropAba, maxDropMissingF, maxRiseF, maxRiseP, maxRiseA, maxRiseAba, maxRiseMissingF } = getMaxRiseAndMaxDrop(results)

    isLong = avgChangeF > 1
    { winTrades, totalTrades } = countTradeResults(results, isLong)
    
    warn = false
    yearlyResults = []
    currentYear = (new Date()).getFullYear()

    for el, i in results
        year = currentYear - i
        continue unless el?

        warn = warn or el.warn

        result = evaluateYearsResult(el, year)
        # Compute effective trading dates (use positive nonLeapNorm index for prev year)
        sDay = new utl.Day(startIdx, year) # Day class handles potential overlap
        result.entryDate = utl.effectiveStartDate(sDay, tradingDaysPerYear)
        eDay = new utl.Day(endIdx, year)
        result.exitDate = utl.effectiveEndDate(eDay, tradingDaysPerYear)
    
        yearlyResults.push(result)


    profitF = 100.0
    if !isLong then profitF = -100.0

    return {
        startIdx, endIdx,
        yearlyResults, warn, isLong
        winTrades, totalTrades
        
        entryDate: indexToDate(startIdx)
        exitDate: indexToDate(endIdx)
        daysInTrade: (endIdx - startIdx) % 365
        
        maxDropF, maxDropP, maxDropA, maxDropAba, maxDropMissingF
        maxRiseF, maxRiseP, maxRiseA, maxRiseAba, maxRiseMissingF 

        averageProfit: profitF * (avgChangeF - 1)
        medianProfit: profitF * (medChangeF - 1)
    }


############################################################
evaluateYearsResult = (result, year) ->
    log "evaluateYearsResult"
    { 
        startA, startAr, startAba, changeF, maxRiseF, maxRiseIdx, 
        maxDropF, maxDropIdx, corrF, missingF, lastF, warn 
    } = result

    changeP = (changeF - 1) * 100
    maxRiseP = (maxRiseF - 1) * 100
    maxDropP = (maxDropF - 1) * 100
    ## TODO other necessary transformations
    
    return { 
        year, changeF, changeP, maxRiseF, maxRiseP, maxDropF, maxDropP, 
        startA, startAr, startAba, corrF, missingF, lastF, warn 
    }

#endregion


############################################################
#region Split Factor Correction

############################################################
addSplitsInfo = (results, splitFactors, startIdx, endIdx) ->
    return unless splitFactors?.length
    hasApplied = splitFactors.some((sf) -> sf.applied)
    return unless hasApplied

    # results[0] is always element for this year and might be null
    day = new utl.Day(startIdx, (new Date()).getFullYear())
    # lastF = splitFactors[splitFactors.length - 1].f

    if splitFactors[splitFactors.length - 1].applied
        lastF = splitFactors[splitFactors.length - 1].f
    else 
        lastF = 1.0

    for el in results when el?
        el.lastF = lastF ## kind if redundant but handy later
        corrF = getSplitCorrectionFactor(splitFactors, day.getYYYYMMDD())
        el.corrF = corrF
        el.startAr = el.startA / corrF
        el.startAba = el.startA / lastF
        el.missingF = 1.0 * lastF / corrF
        day = day.getDayPrevYear() # for further iteration
    return

############################################################
getSplitCorrectionFactor = (splitFactors, dateYYYYMMDD) ->
    return 1 unless splitFactors?.length
    # splitFactors = [{f, applied, end: "YYYY-MM-DD"}, ...]

    for sf in splitFactors when dateYYYYMMDD <= sf.end or !sf.end?
        # our date is within range of this splitFactor
        if sf.applied then return sf.f 
        else return 1
    return 1

#endregion

############################################################
#region Helper Functions

############################################################
# Actual backtesting for a sequence
backtestSequence = (seq) ->
    log "backtestSequence"
    return null unless seq?
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
        else 
            close = seq[i][0]
            low = close
            high = close
        
        if high > maxRiseA
            maxRiseA = high
            maxRiseIdx = i
        if low < maxDropA
            maxDropA = low
            maxDropIdx = i

        # add a warning if any day to day difference is too much (+42.9% or -30%)
        closeDelta = close - lastClose
        closeDeltaF = 1.0 * closeDelta / lastClose
        warn = (warn or closeDeltaF > 0.429 or closeDeltaF < -0.3)   
        lastClose = close

    # Calculate facors to easily get the percentages
    changeF = 1.0 * endA / startA
    maxRiseF = 1.0 * maxRiseA / startA
    maxDropF = 1.0 * maxDropA / startA

    return { startA, changeF, maxRiseF, maxRiseIdx, maxDropF, maxDropIdx, warn }

############################################################
#region summarizing results
getAverageAndMedianChanges = (results, ignoreWithWarning = true) ->
    log "getAverageAndMedianChanges"
    changeSum = 0
    factors = []
    num = 0
    for el,i in results when el?
        if ignoreWithWarning and el.warn then continue
        changeSum += el.changeF
        factors.push(el.changeF)
        num++

    # default to 1, 1 if we donot have a valid year
    if num == 0 then return { avgChangeF: 1, medChangeF: 1 } 

    avgChangeF = 1.0 * changeSum / num 

    factors.sort((a, b) -> a - b) # sort ascending for median
    if (num % 2) # odd case
        idx = (num - 1) / 2
        medChangeF = factors[idx]
    else # even case
        idx = num / 2
        medChangeF = 0.5 * (factors[idx] + factors[idx - 1])

    return { avgChangeF, medChangeF }

getMaxRiseAndMaxDrop = (results, ignoreWithWarning = true) ->
    log "getMaxRiseAndMaxDrop"
    maxRiseEl = { maxRiseF: -Infinity }
    maxDropEl = { maxDropF: Infinity }

    for el in results when el?
        if ignoreWithWarning and el.warn then continue        
        if el.maxRiseF > maxRiseEl.maxRiseF then maxRiseEl = el
        if el.maxDropF < maxDropEl.maxDropF then maxDropEl = el

    ## get relevant props from maxDropEl
    maxDropF = maxDropEl.maxDropF
    maxDropP = (maxDropF - 1) * 100
    maxDropA = maxDropEl.startA * (maxDropEl.maxDropF - 1)
    maxDropAba = maxDropEl.startAba * (maxDropEl.maxDropF - 1)
    maxDropMissingF = maxDropEl.missingF
    
    ## get relevant props from maxRiseEl
    maxRiseF = maxRiseEl.maxRiseF
    maxRiseP = (maxRiseF - 1) * 100
    maxRiseA = maxRiseEl.startA * (maxRiseEl.maxRiseF - 1)
    maxRiseAba = maxRiseEl.startAba * (maxRiseEl.maxRiseF - 1)
    maxRiseMissingF = maxRiseEl.missingF

    return { 
        maxDropF, maxDropP, maxDropA, maxDropAba, maxDropMissingF,
        maxRiseF, maxRiseP, maxRiseA, maxRiseAba, maxRiseMissingF 
    }

############################################################
countTradeResults = (results, isLong, ignoreWithWarning = true) ->
    winTrades = 0
    totalTrades = 0
    for el in results when el?
        if ignoreWithWarning and el.warn then continue
        totalTrades++
        if isLong and el.changeF > 1 then winTrades++
        else if not isLong and el.changeF < 1 then winTrades++
    return { winTrades, totalTrades } 

#endregion

############################################################
#region Sequence Extraction

############################################################
# Extract HLC sequence from a single year
# returns null in the case of an incomplete sequence
extractSequence = (yearData, startIdx, endIdx, isLeapYear) ->
    log "extractSequence"
    actualStart = utl.nonLeapNormToRealIdx(startIdx, isLeapYear)
    actualEnd = utl.nonLeapNormToRealIdx(endIdx, isLeapYear)
    sequence = yearData.slice(actualStart, actualEnd + 1)
    if sequence[0]? and sequence[sequence.length - 1]?
        return sequence
    else return null

############################################################
# Extract HLC sequence across year boundary (overlapping case)
# startIdx is negative (-365 to -1), endIdx is positive (0-364)
# returns null in the case of an incomplete sequence
extractOverlappingSequence = (prevYearData, currYearData, startIdx, endIdx, year) ->
    log "extractOverlappingSequence"
    # Convert negative startIdx to previous year's normalized index
    currIsLeap = utl.isLeapYear(year)
    prevIsLeap = utl.isLeapYear(year - 1)
    prevYearNormalizedIdx = startIdx + 365
    prevActualStart = utl.nonLeapNormToRealIdx(prevYearNormalizedIdx, prevIsLeap)

    currActualEnd = utl.nonLeapNormToRealIdx(endIdx, currIsLeap)

    prevPart = prevYearData.slice(prevActualStart)  # to end of prev year
    currPart = currYearData.slice(0, currActualEnd + 1)  # from start of curr year

    sequence =  [...prevPart, ...currPart]

    if sequence[0]? and sequence[sequence.length - 1]?
        return sequence
    else return null

#endregion

############################################################
#region Extract the sequence of relevant DataPoint
getAllOverappedSequences = (dataPerYear, startIdx, endIdx) ->
    log "getAllOverappedSequences"
    year = (new Date()).getFullYear()
    sequences = [null] # sequence thisYear - nextYear cannot be checked -> null

    # 0 is current year - higher index is older
    # CoffeeScript: .. is inclusive, ... is exclusive (0..3 = [0,1,2,3], 0...3 = [0,1,2])
    for i in [0..dataPerYear.length - 2] # stop at length-2: need i+1 for prevYear
        yearD = dataPerYear[i]
        prevYearD = dataPerYear[i+1]
        sequences.push(extractOverlappingSequence(prevYearD, yearD, startIdx, endIdx, year))
        year-- # next iteration is about the next older year

    return sequences


############################################################
getAllNonOverlapSequences = (dataPerYear, startIdx, endIdx) ->
    log "getAllNonOverlapSequences"
    year = (new Date()).getFullYear()
    sequences = []
    for yearD, i in dataPerYear
        isLeapYear = utl.isLeapYear(year)
        sequences.push(extractSequence(yearD, startIdx, endIdx, isLeapYear))
        year--
    return sequences

#endregion

############################################################
# Helper to format nonLeapNorm day index to "DD.MM." string
# Handles negative indices for overlapping selections (-1 = Dec 31)
# Input: nonLeapNorm index (0-364 or negative)
indexToDate = (dayIdx) ->
    # Normalize negative indices: -1 → 364, -365 → 0
    if dayIdx < 0 then dayIdx = 365 + dayIdx

    # Use non-leap reference year (normalized indices assume 365 days)
    jan1 = new Date(2023, 0, 1, 12)
    targetDate = new Date(jan1.getTime() + dayIdx * 86_400_000)

    day = targetDate.getDate()
    month = targetDate.getMonth() + 1
    dayStr = if day < 10 then "0#{day}" else "#{day}"
    monthStr = if month < 10 then "0#{month}" else "#{month}"
    return "#{dayStr}.#{monthStr}."

#endregion