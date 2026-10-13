############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("datacache")
#endregion

############################################################
import { getEodData } from "./scimodule.js"
import * as utl from "./utilsmodule.js"

############################################################
keyToHistory = Object.create(null)
keyToHistoryMonths = Object.create(null)
keyToHistoryWeeks = Object.create(null)
keyToHistoryQuarters = Object.create(null)
keyToHistoryOf = { yearly: keyToHistory, quarterly: keyToHistoryQuarters, monthly: keyToHistoryMonths, weekly: keyToHistoryWeeks }

############################################################
keyToRawData = Object.create(null)
keyToMetaData = Object.create(null)
keyToNewestDate = Object.create(null)

############################################################
#region Interface
export getCurrentMetaData = (dataKey) -> keyToMetaData[dataKey]
export getCurrentRawData = (dataKey) -> keyToRawData[dataKey]

############################################################
# @params dataKey (e.g. symbol of stock)
# @params toAge the oldest year to retrieve
# @returns array of daily booleans of the last `toAge` years
export getHistoricTradingDays = (dataKey, toAge) ->
    dataPerYear = await getHistoryHLC(dataKey, toAge)

    result = []

    for yearData in dataPerYear
        yearResult = []
        yearResult[i] = (d.length == 3) for d,i in yearData when d?
        result.push(yearResult)

    return result

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params timeframe "yearly" | "quarterly" | "monthly" | "weekly"
# @params toAge the oldest chunk age to retrieve
# @returns daily close chunks, newest first, full length - missing days stay undefined
#   yearly 365 / 366 (real day of year), quarterly 93 (monthInQuarter * 31 + day - 1),
#   monthly 31, weekly 7 (Monday = 0)
export getHistoricCloseChunks = (dataKey, timeframe, toAge) ->
    if !keyToHistory[dataKey] then await retrieveFullHistory(dataKey)
    history = keyToHistoryOf[timeframe][dataKey]
    for chunk in extractRelevantHistory(history, toAge)
        closes = new Array(chunk.length)
        closes[i] = d[d.length - 1] for d,i in chunk when d?
        closes

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params toAge the oldest year to retrieve
# @returns all daily high/low data of the last `toAge` years 
# export getHistoricHighLowData = (dataKey, toAge) ->
#     dataPerYear = await getHistoryHLC(dataKey, toAge)

#     result = []
    
#     for yearData in dataPerYear
#         yearResult = [] 
#         for d,i in yearData when d?
#             if d.length >= 2 then yearResult[i] = [d[0], d[1]]
#             else yearResult[i] = [d[0], d[0]]

#         result.push(yearResult)
        
#     return result


############################################################
##
# @params dataKey (e.g. symbol of stock)
# @returns data of the current and the last year for said dataKey
export getHistoryHLC = (dataKey, toAge) ->
    # feb29_2024 = new Date("February 29, 2024 12:00:00")
    # start_2024 = createYearStartDate(new Date("February 29, 2024 12:00:00"))
    # daysFeb29 = getDayDifference(start_2024, feb29_2024)
    # log daysFeb29

    if !keyToHistory[dataKey] then await retrieveFullHistory(dataKey)
    return extractRelevantHistory(keyToHistory[dataKey], toAge)

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params toAge (numbers of months to retrieve 0 means only current month)
# @returns list of arrays each array is the monthly data and has a size of 31
export getMonthlyHistoryHLC = (dataKey, toAge) ->
    if !keyToHistoryMonths[dataKey] then await retrieveFullHistory(dataKey)
    return extractRelevantHistory(keyToHistoryMonths[dataKey], toAge)

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params toAge (numbers of weeks to retrieve 0 means only current week)
# @returns list of arrays each array is the weekly data (Monday = 0 ... Sunday = 6) and has a size of 7
export getWeeklyHistoryHLC = (dataKey, toAge) ->
    if !keyToHistoryWeeks[dataKey] then await retrieveFullHistory(dataKey)
    return extractRelevantHistory(keyToHistoryWeeks[dataKey], toAge)

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @returns number of years of available history
export getHistoricDepth = (dataKey) ->
    return 0 unless keyToHistory[dataKey]?
    return keyToHistory[dataKey].length

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @returns date of the newest datapoint - chunk age 0 is the period of this date
export getNewestDate = (dataKey) ->
    if !keyToHistory[dataKey] then await retrieveFullHistory(dataKey)
    return keyToNewestDate[dataKey]

#endregion

############################################################
retrieveFullHistory = (dataKey) ->
    log "retrieveFullHistory #{dataKey}"
    startMS = performance.now()
    result = await getEodData(dataKey, 31)
    olog result.meta
    timeMS = performance.now() - startMS
    log "received #{result.data.length} datapoints - request took #{timeMS}ms"
    digestRemoteData(dataKey, result)
    return

############################################################
digestRemoteData = (dataKey, result) ->
    log "digestRemoteData"
    {meta, data} = result
    return unless data?.length

    startDate = new Date(meta.startDate + "T12:00Z")
    endDate = new Date(meta.endDate)
    keyToMetaData[dataKey] = meta
    keyToRawData[dataKey] = data

    ## TODO update parsing logic
    # Parse start date (noon to avoid timezone edge cases)
    currentDate = new Date(meta.startDate + "T12:00Z")

    # Bucket data by year
    yearBuckets = Object.create(null)
    monthBuckets = Object.create(null)
    weekBuckets = Object.create(null)
    quarterBuckets = Object.create(null)
    week = null
    for hlc in data
        ## "workaround" for corrupted Data...
        # hlc = repairHLC(hlc) unless hlc.length == 1
    
        year = currentDate.getFullYear()
        month = 100 * year + (currentDate.getMonth() + 1)
        quarter = 10 * year + Math.floor(currentDate.getMonth() / 3)
        
        monthDayIndex = currentDate.getDate() - 1
        weekDayIndex = (currentDate.getDay() + 6) % 7 # Monday = 0 ... Sunday = 6
        quarterDayIndex = (currentDate.getMonth() % 3) * 31 + monthDayIndex
        dayIndex = utl.getDayOfYear(currentDate)

        # week key is the YYYYMMDD of the Monday of this week
        if !week? or weekDayIndex == 0 then week = getWeekKey(currentDate, weekDayIndex)

        # Initialize year bucket if needed
        if !yearBuckets[year]? then yearBuckets[year] = Array(utl.getDaysOfYear(year)).fill(null)
        # Initialize month bucket if needed
        if !monthBuckets[month]? then monthBuckets[month] = Array(31).fill(null)
        # Initialize week bucket if needed
        if !weekBuckets[week]? then weekBuckets[week] = Array(7).fill(null)
        if !quarterBuckets[quarter]? then quarterBuckets[quarter] = Array(93).fill(null)

        weekBuckets[week][weekDayIndex] = hlc
        monthBuckets[month][monthDayIndex] = hlc
        quarterBuckets[quarter][quarterDayIndex] = hlc
        yearBuckets[year][dayIndex] = hlc
        currentDate.setDate(currentDate.getDate() + 1)
    currentDate.setDate(currentDate.getDate() - 1) # back to the last datapoint
    keyToNewestDate[dataKey] = currentDate

    # Convert to array with current year first (descending order)
    years = Object.keys(yearBuckets).map(Number).sort((a, b) -> b - a)
    months = Object.keys(monthBuckets).map(Number).sort((a,b) -> b - a)
    weeks = Object.keys(weekBuckets).map(Number).sort((a,b) -> b - a)
    quarters = Object.keys(quarterBuckets).map(Number).sort((a,b) -> b - a)

    # Log what we stored per year
    # for year in years
    #     bucket = yearBuckets[year]
    #     filledCount = bucket.filter((v) -> v?).length
    #     log "year #{year} has #{filledCount} values."

    for month in months
        bucket = monthBuckets[month]
        filledCount = bucket.filter((v) -> v?).length
        # log "month #{month} has #{filledCount} values."

    keyToHistory[dataKey] = years.map((y) -> yearBuckets[y])
    keyToHistoryMonths[dataKey] = months.map((m) -> monthBuckets[m])
    keyToHistoryWeeks[dataKey] = weeks.map((w) -> weekBuckets[w])
    keyToHistoryQuarters[dataKey] = quarters.map((q) -> quarterBuckets[q])
    return

############################################################
getWeekKey = (date, weekDayIndex) ->
    monday = new Date(date)
    monday.setDate(monday.getDate() - weekDayIndex)
    return 10000 * monday.getFullYear() + 100 * (monday.getMonth() + 1) + monday.getDate()


############################################################
extractRelevantHistory = (history, toAge) ->
    result = []
    age = 0
    runLimit = toAge + 1

    while age < runLimit
        if !history[age]? then break
        result.push(history[age])
        age++
    
    return result

############################################################
repairHLC = (hlc) ->
    switch
        # case we got correct hlc
        when hlc[0] >= hlc[2] and hlc[0] >= hlc[1] and hlc[2] >= hlc[1]
            return hlc
        
        # case we got more something like hcl
        when hlc[0] >= hlc[2] and hlc[0] >= hlc[1] and hlc[1] >= hlc[2]
            return [hlc[0], hlc[2], hlc[1]]

        # case we got more something like lhc
        when hlc[1] >= hlc[2] and hlc[1] >= hlc[0] and hlc[2] >= hlc[0]
            return [hlc[1], hlc[0], hlc[2]]
        # case we got more something like lch
        when hlc[2] >= hlc[1] and hlc[2] >= hlc[0] and hlc[1] >= hlc[0]
            return [hlc[2], hlc[0], hlc[1]]

        # case we got more something like chl
        when hlc[1] >= hlc[2] and hlc[1] >= hlc[0] and hlc[0] >= hlc[2]
            return [hlc[1], hlc[2], hlc[0]]
        # case we got more something like clh
        when hlc[2] >= hlc[1] and hlc[2] >= hlc[0] and hlc[0] >= hlc[1]
            return [hlc[2], hlc[1], hlc[0]]

        else console.error("repairHLC - impossible case for [#{hlc}]")
    return hlc