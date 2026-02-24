############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("backtesting")
#endregion

############################################################
import * as utl from "./utilsmodule.js"

############################################################
# Backtesting Module
#
# Purpose: Calculate backtesting statistics for a selected date range
# across all available historic years.
#
# Data Structure:
# - dataPerYear[0] = current year (incomplete), dataPerYear[n-1] = oldest
# - Each year: [[h,l,c], ...] with 365 or 366 entries (real/denormalized indices)
# - All indices passed to this module are nonLeapNorm (0-364)
# - Use utl.nonLeapNormToRealIdx to convert for data access
#
# Direction Detection:
# - Positive average profit → "Long"
# - Negative average profit → "Short"
#
# Profit Calculation:
# - For each historic year: (closeAtEnd - closeAtStart) / closeAtStart * 100
#
#
# Index Normalization (done in seasonalityframemodule.normalizeSelectionIndices):
#
# Chart displays 2 years: [...lastYearData, ...currentYearData]
# Raw selection indices are converted to normalized 365-day year indices.
#
# Three selection cases:
# 1. Both in last year:    startIdx=0-364, endIdx=0-364 → runBacktest
# 2. Overlapping:          startIdx=-365..-1, endIdx=0-364 → runOverlappingBacktest
# 3. Both in current year: startIdx=0-364, endIdx=0-364 → runBacktest
#
# Leap year handling: Feb 29 (index 59) maps to Feb 28, subsequent days shift.
# When accessing actual data, must re-expand indices for leap years.
#


############################################################
#region Top Level Backtesting Implementations
############################################################
# Parameters:
#   - dataPerYear: array of yearly HLC arrays from datacache
#     - index 0 = current year (incomplete), index n-1 = oldest (may be incomplete)
#     - each year has 365 or 366 entries depending on leap year
#   - startIdx: normalized day-of-year (0-364, or negative for overlapping)
#   - endIdx: normalized day-of-year (0-364)
#
# Returns: BacktestingResult object
export runBacktesting = (dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear) ->
    log "runBacktesting"
    if startIdx < 0 then return runOverlappingBacktest(dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear)
    else return runBacktest(dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear)

############################################################
runOverlappingBacktest = (dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear) ->
    log "runOverlappingBacktest"

    sequences = getTradeDaySequencesOverlapped(dataPerYear, startIdx, endIdx)

    backtestResults = sequences.map((seq) -> backtestSequence(seq))
    splitFactors = metaData?.splitFactors
    correctAbsoluteValues(backtestResults, splitFactors, startIdx, endIdx, true)

    { avgChangeF, medChangeF } = getAverageAndMedianChanges(backtestResults)
    { maxRiseF, maxDropF, maxRiseA, maxDropA } = getMaxRiseAndMaxDrop(backtestResults)

    isLong = avgChangeF > 1
    winRate = calculateWinRate(backtestResults, isLong)

    warn = false
    yearlyResults = []
    currentYear = (new Date()).getFullYear()
    prevYearNormIdx = startIdx + 365

    for el, i in backtestResults
        continue unless el?
        # sequences[i]: currYear=currentYear-i, prevYear=currentYear-i-1
        currYear = currentYear - i
        prevYear = currYear - 1

        warn = warn or el.warn
        profitP = (el.changeF - 1) * 100
        maxRiseP = (el.maxRiseF - 1) * 100
        maxDropP = (el.maxDropF - 1) * 100

        # Compute effective trading dates (use positive nonLeapNorm index for prev year)
        sDay = new utl.Day(prevYearNormIdx, prevYear)
        startDate = effectiveStartDate(sDay, tradingDaysPerYear)
        eDay = new utl.Day(endIdx, currYear)
        endDate = effectiveEndDate(eDay, tradingDaysPerYear)
        
        yearlyResults.push({ year: prevYear, startDate, endDate, profitP, maxRiseP, maxDropP, startA: el.startA, warn: el.warn })

    directionString = if isLong then "Long" else "Short"
    timeframeString = "[#{indexToDate(startIdx)} - #{indexToDate(endIdx)}]"
    daysInTrade = (endIdx - startIdx) % 365

    profitF = 100.0
    if !isLong then profitF = -100.0

    return {
        directionString
        timeframeString
        winRate
        maxRise: (maxRiseF - 1) * 100
        maxRiseA
        maxDrop: (maxDropF - 1) * 100
        maxDropA
        averageProfit: profitF * (avgChangeF - 1)
        medianProfit: profitF * (medChangeF - 1)
        daysInTrade
        warn
        yearlyResults
    }

############################################################
runBacktest = (dataPerYear, metaData, startIdx, endIdx, tradingDaysPerYear) ->
    log "runBacktest"

    sequences = getTradeDaySequences(dataPerYear, startIdx, endIdx)

    backtestResults = sequences.map((seq) -> backtestSequence(seq))
    splitFactors = metaData?.splitFactors
    correctAbsoluteValues(backtestResults, splitFactors, startIdx, endIdx, false)

    { avgChangeF, medChangeF } = getAverageAndMedianChanges(backtestResults)
    { maxRiseF, maxDropF, maxRiseA, maxDropA } = getMaxRiseAndMaxDrop(backtestResults)

    isLong = avgChangeF > 1
    winRate = calculateWinRate(backtestResults, isLong)

    warn = false
    yearlyResults = []
    currentYear = (new Date()).getFullYear()

    for el, i in backtestResults
        continue unless el?
        year = currentYear - i
        warn = warn or el.warn
        profitP = (el.changeF - 1) * 100
        maxRiseP = (el.maxRiseF - 1) * 100
        maxDropP = (el.maxDropF - 1) * 100

        # Compute effective trading dates
        sDay = new utl.Day(startIdx, year)
        startDate = effectiveStartDate(sDay, tradingDaysPerYear)
        eDay = new utl.Day(endIdx, year)
        endDate = effectiveEndDate(eDay, tradingDaysPerYear)


        yearlyResults.push({ year, startDate, endDate, profitP, maxRiseP, maxDropP, startA: el.startA, warn: el.warn })

    directionString = if isLong then "Long" else "Short"
    timeframeString = "[#{indexToDate(startIdx)} - #{indexToDate(endIdx)}]"
    daysInTrade = endIdx - startIdx

    profitF = 100.0
    if !isLong then profitF = -100.0

    return {
        directionString
        timeframeString
        winRate
        maxRise: (maxRiseF - 1) * 100
        maxRiseA
        maxDrop: (maxDropF - 1) * 100
        maxDropA
        averageProfit: profitF * (avgChangeF - 1)
        medianProfit: profitF * (medChangeF - 1)
        daysInTrade
        warn
        yearlyResults
    }

#endregion

############################################################
#region Split Factor Correction

############################################################
# Correct absolute values (startA) on each backtestResult using split factors.
# splitFactors: [{f, end, applied}, ...] from metaData, sorted by end date
# A factor f is valid from the previous factor's end date to its own end date.
# If applied: true, the data has been divided by f — multiply to get real price.
# Uses the trade start date to determine the applicable factor for the whole sequence.
correctAbsoluteValues = (backtestResults, splitFactors, startIdx, endIdx, isOverlapping) ->
    return unless splitFactors?.length
    hasApplied = splitFactors.some((sf) -> sf.applied)
    return unless hasApplied
    log "correctAbsoluteValues - - - - - - - - --> "
    olog splitFactors

    if isOverlapping
        year = (new Date()).getFullYear() - 1
    else
        year = (new Date()).getFullYear()

    for el in backtestResults when el?
        dateStr = normalizedIdxToDateStr(year, startIdx)
        corrF = getSplitCorrectionFactor(splitFactors, dateStr)
        log "startA before correction: " + el.startA
        el.startA = el.startA / corrF
        log "startA after correction: " + el.startA

        year--
    return

############################################################
# Get the correction multiplier for a given date.
# Returns f if the date falls within an applied split range, 1 otherwise.
getSplitCorrectionFactor = (splitFactors, dateStr) ->
    return 1 unless splitFactors?.length
    # lastEl = splitFactors[splitFactors.length - 1]
    # if lastEl.end? then console.error("Unexpected! Last entry of SplitFactors did also have an end date!")

    # lastEl.end = (new Date()).toISOString().slice(0, 10) # set fictional End date of today.

    for sf,i in splitFactors
        if dateStr <= sf.end or !sf.end?
            if sf.applied then return sf.f 
            else return 1
    return 1

############################################################
# Convert year + nonLeapNorm day index (0-364 or negative) to "YYYY-MM-DD"
normalizedIdxToDateStr = (year, dayIdx) ->
    if dayIdx < 0
        year = year - 1
        dayIdx = 365 + dayIdx
    realIdx = utl.nonLeapNormToRealIdx(dayIdx, utl.isLeapYear(year))
    jan1 = new Date(year, 0, 1, 12)
    target = new Date(jan1.getTime() + realIdx * 86_400_000)
    return target.toISOString().slice(0, 10)

#endregion

############################################################
#region Helper Functions

############################################################
# Actual backtesting for a sequence
backtestSequence = (seq) ->
    log "backtestSequence"
    return null unless seq?

    warn = false
    changeA = 0
    maxRiseA = -Infinity
    maxDropA = Infinity

    # We start at end of day of the first trade and we leave at end of day of the last Tradeday
    startA = seq[0][seq[0].length - 1] # start price is close of day 0
    endA = seq[seq.length - 1][seq[seq.length - 1].length - 2] # end price is close of the last day

    changeA = endA - startA
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
            riseEndedIndex = i
        if low < maxDropA
            maxDropA = low
            dropEndedIndex = i

        # add a warning if any day to day difference is too much (+42.9% or -30%)
        closeDelta = close - lastClose
        closeDeltaF = 1.0 * closeDelta / lastClose
        warn = (warn or closeDeltaF > 0.429 or closeDeltaF < -0.3)   
        lastClose = close

    # Calculate facors to easily get the percentages
    changeF = 1.0 * endA / startA
    maxRiseF = 1.0 * maxRiseA / startA
    maxDropF = 1.0 * maxDropA / startA

    return { startA, changeF, maxRiseF, maxDropF, warn, dropEndedIndex, riseEndedIndex }

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
    maxDropF = Infinity
    maxRiseF = -Infinity
    maxRiseStartA = 0
    maxDropStartA = 0
    for el in results when el?
        if ignoreWithWarning and el.warn then continue
        if el.maxRiseF > maxRiseF
            maxRiseF = el.maxRiseF
            maxRiseStartA = el.startA
        if el.maxDropF < maxDropF
            maxDropF = el.maxDropF
            maxDropStartA = el.startA

    maxRiseA = maxRiseStartA * (maxRiseF - 1)
    maxDropA = maxDropStartA * (maxDropF - 1)
    return { maxDropF, maxRiseF, maxRiseA, maxDropA }

############################################################
# Calculate win rate: % of years profitable in detected direction
# Long wins when changeF > 1, Short wins when changeF < 1
calculateWinRate = (results, isLong, ignoreWithWarning = true) ->
    log "calculateWinRate"
    wins = 0
    total = 0
    for el in results when el?
        if ignoreWithWarning and el.warn then continue
        total++
        if isLong and el.changeF > 1 then wins++
        else if not isLong and el.changeF < 1 then wins++

    return if total > 0 then Math.round(100 * wins / total) else 0

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
getTradeDaySequencesOverlapped = (dataPerYear, startIdx, endIdx) ->
    log "getTradeDaySequencesOverlapped"
    year = (new Date()).getFullYear()
    sequences = []
    # 0 is current year - higher index is older
    # CoffeeScript: .. is inclusive, ... is exclusive (0..3 = [0,1,2,3], 0...3 = [0,1,2])
    for i in [0..dataPerYear.length - 2] # stop at length-2: need i+1 for prevYear
        yearD = dataPerYear[i]
        prevYearD = dataPerYear[i+1]
        sequences.push(extractOverlappingSequence(prevYearD, yearD, startIdx, endIdx, year))
        year-- # next iteration is about the next older year

    return sequences


############################################################
getTradeDaySequences = (dataPerYear, startIdx, endIdx) ->
    log "getTradeDaySequences"
    year = (new Date()).getFullYear()
    sequences = []
    for yearD, i in dataPerYear
        isLeapYear = utl.isLeapYear(year)
        sequences.push(extractSequence(yearD, startIdx, endIdx, isLeapYear))
        year--
    return sequences

#endregion


############################################################
effectiveStartDate = (day, tradingDaysPerYear) ->
    log "effectiveStartDate"
    safetyCount = 32
    startDate = day.getDateStr()
    loop
        if --safetyCount < 0 # prevent infinite loops
            console.error("effeciveStartDate reached safety Limit!") 
            return startDate # fallback

        isTradingDay = day.lookupIn(tradingDaysPerYear)
        if isTradingDay then return day.getDateStr() # found tradingDay
        # When we donot find a trading day we have 2 options:
        #    1.) isTradingDay is false - we need check the earlier day
        #    2.) isTradingDay is undefined or null - exeeded bounds -> fallback 
        if isTradingDay != false then return startDate
        day = day.getPrevDay()
    return # for code beauty 

effectiveEndDate = (day, tradingDaysPerYear) ->
    log "effectiveEndDate"
    safetyCount = 32
    startDate = day.getDateStr()
    loop
        if --safetyCount < 0 # prevent infinite loops
            console.error("effeciveEndDate reached safety Limit!") 
            return startDate # fallback

        isTradingDay = day.lookupIn(tradingDaysPerYear)
        if isTradingDay then return day.getDateStr() # found tradingDay
        # When we donot find a trading day we have 2 options:
        #    1.) isTradingDay is false - we need check the next later day
        #    2.) isTradingDay is undefined or null - exeeded bounds -> fallback 
        if isTradingDay != false then return startDate
        day = day.getNextDay()
    return # just for the shape

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