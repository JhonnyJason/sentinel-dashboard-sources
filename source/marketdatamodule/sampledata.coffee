############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("sampledata")
#endregion

############################################################
import { getDaysOfYear, dateDifDays, getJan1Date } from "./utilsmodule.js"

############################################################
keyToHistory = Object.create(null)

############################################################
createSampleDataArray = (length) ->
    result = new Array(length)
    idx = 0
    deltaRange = 4
    val = 100
    while idx < length
        result[idx] = val
        delta = (Math.random() - 0.5) * deltaRange
        val += delta
        idx++
    return result

############################################################
createSampleData = (key,  toAge = 30) ->
    today = new Date()
    yearStart = getJan1Date()
    currentYearDays = dateDifDays(yearStart, today)
    log "currentYearDays: "+currentYearDays
    currentYear = today.getFullYear()

    historicDailyCloses = new Array(toAge + 1)

    historicDailyCloses[0] = createSampleDataArray(currentYearDays)
    cnt = 1 

    while cnt < historicDailyCloses.length
        year = currentYear - cnt
        yearDays = getDaysOfYear(year)
        historicDailyCloses[cnt] = createSampleDataArray(yearDays)
        cnt++
    
    keyToHistory[key] = historicDailyCloses
    return

getLatestSampleData = (history, toAge) ->
    result = []
    age = 0
    runLimit = toAge + 1
    while age < runLimit
        if !history[age]? then break
        result.push(history[age]) 
        age++
    return result

############################################################
export getMarketHistory = (key, toAge) ->
    # feb29_2024 = new Date("February 29, 2024 12:00:00")
    # start_2024 = createYearStartDate(new Date("February 29, 2024 12:00:00"))
    # daysFeb29 = getDayDifference(start_2024, feb29_2024)
    # log daysFeb29

    if !keyToHistory[key] then createSampleData(key)    
    return getLatestSampleData(keyToHistory[key], toAge)

############################################################
testYearCalculation = ->
    tests = [
        [1600, 366]
        [1601, 365]
        [1604, 366]
        [1700, 365]
        [1800, 365]
        [1900, 365]
        [2000, 366]
        [2100, 365]        
        [2102, 365]        
        [2103, 365]        
        [2104, 366]        
    ]
    for test in tests
        year = test[0]
        expectedDays = test[1]
        days = getDaysOfYear(year)
        if days != expectedDays then log "Error @year #{year}: had #{days}days and not #{expectedDays}!"
        else log "Success @year #{year}!"



