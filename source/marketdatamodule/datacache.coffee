############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("datacache")
#endregion

############################################################
import { getEodData } from "./scimodule.js"
import { getDaysOfYear, getDayOfYear } from "./utilsmodule.js"

############################################################
keyToHistory = Object.create(null)


############################################################
#region Interface

##
# @params dataKey (e.g. symbol of stock)
# @returns daily close data of the current and the last year for the dataKey
export  getLatestCloseData = (dataKey) ->
    dataPerYear = await getHistoryHLC(dataKey, 1)
    
    result = []
    
    for yearData in dataPerYear
        yearResult = [] 
        yearResult[i] = d[2] for d,i in yearData when d?
        result.push(yearResult)
        
    return result


############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params toAge the oldest year to retrieve
# @returns all daily close data of the last `toAge` years 
export getHistoricCloseData = (dataKey, toAge) ->
    dataPerYear = await getHistoryHLC(dataKey, toAge)

    result = []
    
    for yearData in dataPerYear
        yearResult = [] 
        yearResult[i] = d[2] for d,i in yearData when d?
        result.push(yearResult)

    return result

############################################################
##
# @params dataKey (e.g. symbol of stock)
# @params toAge the oldest year to retrieve
# @returns all daily high/low data of the last `toAge` years 
export getHistoricHighLowData = (dataKey, toAge) ->
    dataPerYear = await getHistoryHLC(dataKey, toAge)

    result = []
    
    for yearData in dataPerYear
        yearResult = [] 
        yearResult[i] = [d[0], d[1]] for d,i in yearData when d?
        result.push(yearResult)
        
    return result


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
# @returns number of years of available history
export getHistoricDepth = (dataKey) ->
    return 0 unless keyToHistory[dataKey]?
    return keyToHistory[dataKey].length

#endregion


############################################################
export testFetch = (dataKey, yearsBack) ->
    log  "Well we'll always try to retrieve 30 years of history for now :-)"
    yearsBack = 30
    # yearsBack = undefined
    log "testFetch: #{dataKey}, #{yearsBack} years"
    try
        startMS = performance.now()
        result = await getEodData(dataKey, yearsBack)
        olog result.meta
        timeMS = performance.now() - startMS
        log "received #{result.data.length} datapoints - request took #{timeMS}ms"
        return result
    catch err
        log "testFetch error: #{err.message}"
        return null

############################################################
retrieveFullHistory = (dataKey) ->
    log "retrieveFullHistory #{dataKey}"
    try
        startMS = performance.now()
        result = await getEodData(dataKey, 31)
        olog result.meta
        timeMS = performance.now() - startMS
        log "received #{result.data.length} datapoints - request took #{timeMS}ms"
        digestRemoteData(dataKey, result)
    catch err then log "error: #{err.message}"
    return

############################################################
digestRemoteData = (dataKey, result) ->
    log "digestRemoteData"
    {meta, data} = result
    return unless data?.length

    # Parse start date (noon to avoid timezone edge cases)
    currentDate = new Date(meta.startDate + "T12:00:00")

    # Bucket data by year
    yearBuckets = Object.create(null)
    for hlc in data
        year = currentDate.getFullYear()
        dayIndex = getDayOfYear(currentDate)

        # Initialize year bucket if needed
        unless yearBuckets[year]
            yearBuckets[year] = Array(getDaysOfYear(year)).fill(null)

        yearBuckets[year][dayIndex] = hlc
        currentDate.setDate(currentDate.getDate() + 1)

    # Convert to array with current year first (descending order)
    years = Object.keys(yearBuckets).map(Number).sort((a, b) -> b - a)
    keyToHistory[dataKey] = years.map((y) -> yearBuckets[y])
    return

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


