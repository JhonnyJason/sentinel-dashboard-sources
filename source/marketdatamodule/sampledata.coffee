############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("sampledata")
#endregion

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
getDaysOfYear = (year) ->
    return 365 unless (year % 4) == 0
    if (year % 100) == 0 and (year % 400) != 0 then return 365
    return 366

getDayDifference = (date1, date2) ->
    msDif = (date2.getTime() - date1.getTime())
    dayDif = msDif / 86_400_000 # 1000 * 60 * 60 * 24 = 86_400_000
    return Math.floor(dayDif)

############################################################
createYearStartDate = (date) ->
    date = new Date() unless date?
    date.setHours(0)
    date.setSeconds(0)
    date.setMinutes(0)
    date.setDate(1)
    date.setMonth(0)
    return date

############################################################
createSampleData = (key,  toAge = 30) ->
    today = new Date()
    yearStart = createYearStartDate()
    currentYearDays = getDayDifference(yearStart, today)
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



