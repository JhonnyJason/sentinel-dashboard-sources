############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("utilsmodule")
#endregion

############################################################
#region year/leap year helpers
export FEB29 = 59
export FEB28 = 58

############################################################
export isLeapYear = (year) ->
    return false unless (year % 4) == 0
    if (year % 100) == 0 and (year % 400) != 0 then return false
    return true

export getDaysOfYear = (year) ->
    if isLeapYear(year) then 366 else 365

############################################################
# Index Conventions:
#   nonLeapNorm (0-364): Jan1=0, Feb28=58, Mar1=59. No Feb29.
#   leapNorm (0-365): Jan1=0, Feb28=58, Feb29=59, Mar1=60.
#   real: actual day-of-year. NonLeap 0-364, Leap 0-365.

export leapNormToRealIdx = (normed, isLeap) ->
    return normed if isLeap                # leap real == leap norm
    return normed if normed < FEB29        # 0-58 unchanged
    return FEB28 if normed == FEB29        # Feb29 → Feb28
    return normed - 1                      # 60+ shift down

export nonLeapNormToRealIdx = (normed, isLeap) ->
    return normed unless isLeap            # nonLeap real == nonLeap norm
    return normed if normed < FEB29        # 0-58 (through Feb28) unchanged
    return normed + 1                      # 59+ (Mar1+) shift forward for Feb29

export realToLeapNormIdx = (real, isLeap) ->
    return real if isLeap                  # leap real == leap norm
    return real if real < FEB29            # 0-58 unchanged
    return real + 1                        # 59+ shift (skip Feb29 slot)

export realToNonLeapNormIdx = (real, isLeap) ->
    return real unless isLeap              # nonLeap real == nonLeap norm
    return real if real < FEB29            # 0-58 unchanged
    return FEB28 if real == FEB29          # Feb29 → Feb28
    return real - 1                        # 60+ shift down

#endregion

############################################################
#region factor array helpers
export toLogFactorsArray = (data) ->
    factorsLen = data.length - 1
    factors = new Array(factorsLen)
    for i in [0...factorsLen]
        factors[i] = Math.log(data[i+1] / data[i])
    return factors

export toFactorsArray = (data) ->
    factorsLen = data.length - 1
    factors = new Array(factorsLen)
    for i in [0...factorsLen]
        factors[i] = data[i+1] / data[i]
    return factors

export fromFactorsForward = (factors, startVal = 100) ->
    result = new Array(factors.length + 1)
    result[0] = startVal
    (result[i+1] = result[i] * f) for f,i in factors
    return result

export fromFactorsBackward = (factors, endVal = 100) ->
    result = new Array(factors.length + 1)
    lastIndex = factors.length
    result[lastIndex] = endVal
    for i in [lastIndex..1]
        result[i - 1] = result[i] / factors[i - 1]
    return result


export dataArrayFromFactors = (factors, startValue = 100, forward = true) ->
    result = new Array(factors.length + 1)
    if forward
        result[0] = startValue
        (result[i+1] = result[i] * f) for f,i in factors
        return result
    else
        lastIndex = factors.length
        result[lastIndex] = startValue
        for i in [lastIndex..1]
            result[i - 1] = result[i] / factors[i - 1]
        return result

export dataArrayFromLogFactors = (factors) ->
    result = new Array(factors.length + 1)
    result[0] = 100 # normalized 100%
    (result[i+1] = result[i] * Math.exp(f)) for f,i in factors
    return result

#endregion

############################################################
#region date calculation helpers
export dateDifDays = (date1, date2) ->
    msDif = (date2.getTime() - date1.getTime())
    daysDif = msDif / 86_400_000 # = 1000 * 60 * 60 * 24
    return Math.round(daysDif)

export getDayOfYear = (date) ->
    startOfYear = new Date(date.getFullYear(), 0, 1, 12, 0, 0)
    return dateDifDays(startOfYear, date)

#endregion

############################################################
#region date creation helpers
export getJan1Date = (date) ->
    date = new Date() unless date?
    date.setMilliseconds(0)
    date.setSeconds(0)
    date.setMinutes(0)
    date.setHours(20)
    date.setDate(1)
    date.setMonth(0)
    return date

export getDec31Date = (date) ->
    date = new Date() unless date?
    date.setMilliseconds(0)
    date.setSeconds(0)
    date.setMinutes(0)
    date.setHours(20)
    date.setMonth(11)
    date.setDate(31)
    return date

#endregion

############################################################
# Convert year + real day-of-year index to "DD.MM.YYYY" display string
dayIndexToDateStr = (year, dayIdx) ->
    jan1 = new Date(year, 0, 1, 12)
    target = new Date(jan1.getTime() + dayIdx * 86_400_000)
    day = target.getDate()
    month = target.getMonth() + 1
    dayStr = if day < 10 then "0#{day}" else "#{day}"
    monthStr = if month < 10 then "0#{month}" else "#{month}"
    return "#{dayStr}.#{monthStr}.#{year}"

############################################################
# Convenience class to handle day of year with associated index values.
# @nIndex: nonLeapNorm index (0-364)
# @rIndex: real day-of-year index (accounts for leap year)
# Whenever we have a specific day as (year + nonLeapNorm index) use this class.
export class Day
    constructor: (@nIndex, @year) ->
        @nIndex = (@nIndex + 2 * 365) % 365 # deal with some overflows
        @isLeap = isLeapYear(@year)
        @rIndex = nonLeapNormToRealIdx(@nIndex, @isLeap)
        @yearIdx = (new Date()).getFullYear() - @year
        @daysOfYear = getDaysOfYear(@year)

    getDayNextYear: => return new Day(@nIndex, (@year + 1))
    getDayPrevYear: => return new Day(@nIndex, (@year - 1))
    
    getNextDay: => return new Day(((@nIndex + 1) % 365), (@year + (@nIndex == 364)))
    getPrevDay: => return new Day(((@nIndex + 364) % 365), (@year - (@nIndex == 0)))
    
    getRelativeDay: (num) => 
        if num > 0 
            return new Day(((@nIndex + num) % 365), (@year + ((@nIndex + num) > 364)))
        else 
            return new Day(((@nIndex + (365 + num)) % 365), (@year - ((@nIndex + num) < 0)))
    
    getDateStr: => return dayIndexToDateStr(@year, @rIndex)
    getYYYYMMDD: => 
        ddmmyyyy =  dayIndexToDateStr(@year, @rIndex)
        tkns = ddmmyyyy.split(".")
        tkns.reverse()
        return tkns.join("-")

    lookupIn: (perYearData) =>
        yearData = perYearData[@yearIdx]
        return null unless yearData?

        if @yearIdx == 0 # current Year might be incomplete to the year end
            if @rIndex >= yearData.length then return null
            else return yearData[@rIndex]

        numMissing = @daysOfYear - yearData.length
        # missing in older years means incomplete from the year start  
        rIndex = @rIndex - numMissing 
        if rIndex < 0 then return null
        return yearData[rIndex] 

############################################################
export createDayFromDate = (dateStr) ->
    date = new Date(dateStr)
    date.setHours(20)
    year = date.getFullYear()
    isLeap = isLeapYear(year)
    rIdx = getDayOfYear(date)
    nIndex = realToNonLeapNormIdx(rIdx, isLeap)
    return new Day(nIndex, year)

############################################################
export scanForFreakValues = (dataArray, label) ->
    if !dataArray?
        console.warn "[chartfun] #{label}: array is null/undefined"
        return false

    if !Array.isArray(dataArray)
        console.warn "[chartfun] #{label}: not an array, got #{typeof dataArray}"
        return false

    nullCount = 0
    undefinedIndices = []
    nanIndices = []

    for val, i in dataArray
        if val == null
            nullCount++
        else if val == undefined
            undefinedIndices.push(i)
        else if typeof val == 'number' and isNaN(val)
            nanIndices.push(i)

    if nullCount > 0
        console.log "[chartfun] #{label}: #{nullCount} null values (legal empty)"

    if undefinedIndices.length > 0
        console.warn "[chartfun] #{label}: UNDEFINED at indices:", undefinedIndices
        return false

    if nanIndices.length > 0
        console.warn "[chartfun] #{label}: NaN at indices:", nanIndices
        return false

    return true
