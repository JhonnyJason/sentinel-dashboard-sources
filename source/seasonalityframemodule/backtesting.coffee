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
# - Each year: [[h,l,c], ...] with 365 or 366 entries (leap year)
# - Normalized indices assume 365-day year, must denormalize for leap years
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
export runBacktesting = (dataPerYear, startIdx, endIdx) ->
    log "runBacktesting"
    if startIdx < 0 then return runOverlappingBacktest(dataPerYear, startIdx, endIdx)
    else return runBacktest(dataPerYear, startIdx, endIdx)

############################################################
runOverlappingBacktest = (dataPerYear, startIdx, endIdx) ->
    log "runOverlappingBacktest"
    # olog { startIdx, endIdx, yearsAvailable: dataPerYear.length }

    # For overlapping: we need year pairs (currYear, prevYear)
    # dataPerYear[0] = current, dataPerYear[1] = last year, etc.
    # We combine end of prevYear with start of currYear
    sequences = getTradeDaySequencesOverlapped(dataPerYear, startIdx, endIdx)
    # olog { sequencesLength: sequences.length }
    # olog sequences

    backtestResults = sequences.map((seq) -> backtestSequence(seq))
    { avgChangeF, medChangeF } = getAverageAndMedianChanges(backtestResults)
    { maxRiseF, maxDropF } = getMaxRiseAndMaxDrop(backtestResults)

    isLong = avgChangeF > 1
    winRate = calculateWinRate(backtestResults, isLong)

    warn = false

    yearlyResults = []
    # for overlapp the most recent trade started in last year.
    year = (new Date()).getFullYear() - 1
    for el in backtestResults when el?
        warn = warn or el.warn
        profitP = (el.changeF - 1) * 100
        maxRiseP = (el.maxRiseF - 1) * 100
        maxDropP = (el.maxDropF - 1) * 100
        yearlyResults.push({ year, profitP, maxRiseP, maxDropP, warn: el.warn })
        year--

    directionString = if isLong then "Long" else "Short"
    timeframeString = "[#{indexToDate(startIdx)} - #{indexToDate(endIdx)}]"
    daysInTrade = (endIdx - startIdx) % 365

    return {
        directionString
        timeframeString
        winRate
        maxRise: (maxRiseF - 1) * 100
        maxDrop: (maxDropF - 1) * 100
        averageProfit: (avgChangeF - 1) * 100
        medianProfit: (medChangeF - 1) * 100
        daysInTrade
        warn
        yearlyResults
    }

############################################################
runBacktest = (dataPerYear, startIdx, endIdx) ->
    log "runBacktest"
    # olog { startIdx, endIdx, yearsAvailable: dataPerYear.length }

    sequences = getTradeDaySequences(dataPerYear, startIdx, endIdx)
    # olog { sequencesLength: sequences.length }
    # olog sequences

    backtestResults = sequences.map((seq) -> backtestSequence(seq))
    { avgChangeF, medChangeF } = getAverageAndMedianChanges(backtestResults)
    { maxRiseF, maxDropF } = getMaxRiseAndMaxDrop(backtestResults)

    isLong = avgChangeF > 1
    winRate = calculateWinRate(backtestResults, isLong)

    warn = false

    yearlyResults = []
    # the most recent trade potentially started this year
    year = (new Date()).getFullYear()
    for el in backtestResults when el?
        warn = warn or el.warn
        profitP = (el.changeF - 1) * 100
        maxRiseP = (el.maxRiseF - 1) * 100
        maxDropP = (el.maxDropF - 1) * 100
        yearlyResults.push({ year, profitP, maxRiseP, maxDropP, warn: el.warn })
        year--

    directionString = if isLong then "Long" else "Short"
    timeframeString = "[#{indexToDate(startIdx)} - #{indexToDate(endIdx)}]"
    daysInTrade = endIdx - startIdx

    return {
        directionString
        timeframeString
        winRate
        maxRise: (maxRiseF - 1) * 100
        maxDrop: (maxDropF - 1) * 100
        averageProfit: (avgChangeF - 1) * 100
        medianProfit: (medChangeF - 1) * 100
        daysInTrade
        warn
        yearlyResults
    }

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
    startA = seq[0][2] # start price is the close of day 0
    endA = seq[seq.length - 1][2] # end price is the close of the last day
    changeA = endA - startA
    warn = false
    
    lastClose = startA

    for i in [1...seq.length]
        high = seq[i][0]
        low = seq[i][1]
        if high > maxRiseA then maxRiseA = high
        if low < maxDropA then maxDropA = low

        # add a warning if any day to day difference is too much (+42.9% or -30%)
        close = seq[i][2]
        closeDelta = close - lastClose
        closeDeltaF = 1.0 * closeDelta / lastClose
        warn = (warn or closeDeltaF > 0.429 or closeDeltaF < -0.3)   
        lastClose = close

    # Calculate facors to easily get the percentages
    changeF = 1.0 * endA / startA
    maxRiseF = 1.0 * maxRiseA / startA
    maxDropF = 1.0 * maxDropA / startA

    return { changeF, maxRiseF, maxDropF, warn }

############################################################
#region summarizing results
getAverageAndMedianChanges = (results) ->
    log "getAverageAndMedianChanges"
    changeSum = 0
    factors = []
    num = 0
    for el,i in results when el?
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

getMaxRiseAndMaxDrop = (results) ->
    log "getMaxRiseAndMaxDrop"
    maxDropF = Infinity
    maxRiseF = -Infinity
    for el in results when el?
        if el.maxRiseF > maxRiseF then maxRiseF = el.maxRiseF
        if el.maxDropF < maxDropF then maxDropF = el.maxDropF

    return { maxDropF, maxRiseF }

############################################################
# Calculate win rate: % of years profitable in detected direction
# Long wins when changeF > 1, Short wins when changeF < 1
calculateWinRate = (results, isLong) ->
    log "calculateWinRate"
    wins = 0
    total = 0
    for el in results when el?
        total++
        if isLong and el.changeF > 1 then wins++
        else if not isLong and el.changeF < 1 then wins++

    return if total > 0 then Math.round(100 * wins / total) else 0

#endregion

############################################################
#region Index Denormalization & Sequence Extraction

############################################################
# Denormalize a 365-day index back to actual year index
denormalizeIndex = (normalizedIdx, isLeapYear) ->
    return normalizedIdx unless isLeapYear
    return normalizedIdx if normalizedIdx < utl.FEB28  # Before Feb 28
    return normalizedIdx + 1  # Feb 28+ shifts forward due to Feb 29

############################################################
# Extract HLC sequence from a single year
# returns null in the case of an incomplete sequence
extractSequence = (yearData, startIdx, endIdx, isLeapYear) ->
    log "extractSequence"
    actualStart = denormalizeIndex(startIdx, isLeapYear)
    actualEnd = denormalizeIndex(endIdx, isLeapYear)
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
    prevActualStart = denormalizeIndex(prevYearNormalizedIdx, prevIsLeap)

    currActualEnd = denormalizeIndex(endIdx, currIsLeap)

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
# Helper to format day-of-year index to "DD.MM." string
# Handles negative indices for overlapping selections (-1 = Dec 31)
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