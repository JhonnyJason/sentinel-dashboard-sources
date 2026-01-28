############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("utilsmodule")
#endregion

############################################################
#region year/leap year helpers
export FEB29 = 59
export FEB28 = 58

export isLeapYear = (year) ->
    return false unless (year % 4) == 0
    if (year % 100) == 0 and (year % 400) != 0 then return false
    return true

export getDaysOfYear = (year) ->
    if isLeapYear(year) then 366 else 365

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
