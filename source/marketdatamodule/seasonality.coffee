############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonality")
#endregion

############################################################
export FEB29 = 59
export FEB28 = 58

############################################################
export isLeapYear = (year) ->
    return false unless (year % 4) == 0
    if (year % 100) == 0 and (year % 400) != 0 then return false
    return true

############################################################
normalizeIncomplete = (incomplete, year) ->
    if !isLeapYear(year) then return incomplete
    if incomplete.length < FEB29 then return incomplete

    result = new Array(incomplete.length + 1)
    for i in [0...FEB29]
        result[i] = incomplete[i]
    
    result[FEB29] = incomplete[FEB28]
    for i in [FEB28...incomplete.length]
        result[i+1] = incomplete[i]

    return result

############################################################
# We calculate the factors of change where
# factor[0] = yearData[0] / yearData[1]
# This way we may do this later:
# start with a starting point of 100
# normalizedDynamic[0] = 100
# normalizedDynamic[1] = normalizedDynamic[0] * factor[0]
getLogFactorsForYearData = (yearData) ->
    yearData = normalizeYearData(yearData)
    return toLogFactorsArray(yearData) 
    

############################################################
export addYearToAverage = (newYear, oldResult, oldWeight) ->
    newYearFactors = getLogFactorsForYearData(newYear)
    oldFactors = toLogFactorsArray(oldResult)
    divisor = oldWeight + 1

    factors = new Array(oldFactors.length)
    for f,i in oldFactors
        factors[i] = f * oldWeight
        factors[i] += newYearFactors[i]
        factors[i] /= divisor

    return dataArrayFromLogFactors(factors)


export addCurrrentToAverage = (incomplete, oldResult, oldWeight) ->
    today = new Date()
    incomplete = normalizeIncomplete(incomplete, today.getFullYear())
    incompleteFactors = toLogFactorsArray(incomplete)
    oldFactors = toLogFactorsArray(oldResult)
    
    factors = new Array(oldFactors.length)
    factors[i] = f for f,i in oldFactors
    for iF, i in incompleteFactors
        factors[i] *= oldWeight
        factors[i] += iF
        factors[i] /= oldWeight + 1

    return dataArrayFromLogFactors(factors)

############################################################
export getAverageDynamicOfYearlyData = (data) ->
    log "getAverageDynamicOfYearlyData"
    factorArrays = new Array(data.length)
    
    for d,i in data
        factorArrays[i] = getLogFactorsForYearData(d)
    
    dLen = data.length # how many hitoric years
    averagedFactors = new Array(365) # factors of 366 days are always 365 
    averagedFactors.fill(0)

    for i in [0...365]
        (averagedFactors[i] += factorArrays[j][i]) for j in[0...dLen]
        averagedFactors[i] /= dLen
        
    return dataArrayFromLogFactors(averagedFactors)

export getDynamicsOfCurrentYear = (data) ->
    today = new Date()
    normed = normalizeIncomplete(data, today.getFullYear())
    factors = toLogFactorsArray(normed)
    return dataArrayFromLogFactors(factors)

############################################################
# We "normalize" every year to become 366 days
# for that we simply copy FEB28 to become 
# a fictitious FEB29 ;-)
export normalizeYearData = (data) ->
    if data.length == 366 then return data
    
    missingFeb29 = data
    yearData = new Array(366)
    # construct year of 366 days with double Feb28
    for i in [0...FEB29]
        yearData[i] = missingFeb29[i]
    
    yearData[FEB29] = missingFeb29[FEB28]
    for i in [FEB28...missingFeb29.length]
        yearData[i+1] = missingFeb29[i]

    return yearData

############################################################
export toLogFactorsArray = (data) ->
    factorsLen = data.length - 1
    factors = new Array(factorsLen)
    for i in [0...factorsLen]
        factors[i] = Math.log(data[i] / data[i+1])
    return factors     

export toFactorsArray = (data) ->
    factorsLen = data.length - 1
    factors = new Array(factorsLen)
    for i in [0...factorsLen]
        factors[i] = data[i] / data[i+1]
    return factors     

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
            result[i - 1] = result[i] / factors[i]
        return result
        

export dataArrayFromLogFactors = (factors) ->
    result = new Array(factors.length + 1)
    result[0] = 100 # normalized 100%

    (result[i+1] = result[i] * Math.exp(f)) for f,i in factors
    return result

