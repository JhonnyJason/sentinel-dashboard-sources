############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonality")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
import * as FFT from "fft.js"

############################################################
#region Interface
export calculateSeasonalityComposite = (data, method) ->
    if method == 0 # Average Daily Return
        return averageDailyReturn(data)

    if method == 1 # Fourier Regression
        return fourierRegression(data)
    
    console.error("Unknown Method: #{method}")
    return

#endregion

############################################################
averageDailyReturn = (data) ->
    log "averageDailyReturn"
    historicData = data.slice(1) # Exclude current incomplete year
    return getAverageDynamicOfYearlyData(historicData)

fourierRegression = (data) ->
    log "fourierRegression"
    historicData = data.slice(1) # Exclude current incomplete year

    # Normalize all years to 366 days (direct price data)
    normalizedYears = (normalizeYearData(d) for d in historicData)
    
    # Concatenate into one long sequence
    sequence = []
    for i in [(historicData.length - 1)..0] # iterate from the oldest to the newset
        for d in normalizedYears[i]
            sequence.push(d)
    seqLen = sequence.length

    # Calculate and remove linear gradient (detrend)
    startVal = sequence[0]
    endVal = sequence[seqLen - 1]
    gradient = (endVal - startVal) / seqLen

    minVal = Infinity
    maxVal = -Infinity
    detrended = new Array(seqLen)
    for val, i in sequence
        val = (val - (startVal + gradient * i))
        detrended[i] =  val
        if val < minVal then minVal = val
        if val > maxVal then maxVal = val

    center = 0.5 * (maxVal - minVal)
    detrended[i] -= center for val,i in detrended
    
    # Apply FFT
    # FFT size must cover full sequence (power of 2)
    fftSize = 1
    fftSize *= 2 while fftSize < seqLen

    # Pad input to fftSize
    paddedInput = new Array(fftSize)
    paddedInput.fill(0)
    paddedInput[i] = d for d, i in detrended

    fftK = new FFT(fftSize)
    fftOutput = fftK.createComplexArray()
    fftSmoothed = fftK.createComplexArray()

    fftK.realTransform(fftOutput, paddedInput)

    ##Filter
    filterHarmonics(historicData.length, fftOutput)
    lowPass(Math.floor(seqLen / 7), fftOutput)

    # Inverse FFT
    fftK.inverseTransform(fftSmoothed, fftOutput)

    # Extract real parts from complex array, then slice 1 year
    realValues = new Array(seqLen)
    realValues[i] = fftSmoothed[2 * i] for i in [0...seqLen]


    # smoothedYear = realValues.slice(0, 366)
    # smoothedYear = realValues.slice(366, 732)
    smoothedYear = realValues.slice(Math.floor(seqLen / 2) - 183, Math.floor(seqLen / 2) + 183)

    # retrend
    startValF = smoothedYear[0]
    endValF = smoothedYear[smoothedYear.length - 1]
    gradientF = (endValF - startValF) / smoothedYear.length

    minValF = Infinity
    maxValF = -Infinity
    # detrend our result to get rid off any accidentally introduced trend...
    detrendedF = new Array(smoothedYear.length)
    for val, i in smoothedYear
        val = (val - (startValF + gradientF * i))
        detrendedF[i] =  val
        if val < minValF then minValF = val
        if val > maxValF then maxValF = val

    # retrend to have the average yearly trend - now we also should have purely positive values
    for val, i in detrendedF
        smoothedYear[i] = val - minValF + (startVal + gradient * i)

    factors = utl.toFactorsArray(smoothedYear)
    result = utl.fromFactorsForward(factors)
    return result
    # return smoothedYear


smoothAverage = (input, size) ->
    ## TODO implement
    return input

highPass = (cutOff, complexArray) ->
    max = complexArray.length / 2
    if cutOff > max then cutOff = max
    for i in [0...cutOff]
        complexArray[2*i] = 0
        complexArray[2*i + 1] = 0
    return

lowPass = (cutOff, complexArray) ->
    max = complexArray.length / 2
    if cutOff > max then return
    for i in [cutOff...max]
        complexArray[2*i] = 0
        complexArray[2*i + 1] = 0
    return

filterHarmonics = (base, complexArray) ->
    max = complexArray.length / 2
    for i in [0...max] when i % base != 0
        complexArray[2*i] = 0
        complexArray[2*i + 1] = 0
    return


############################################################
historyToSequence = (history) ->
    sequence = []
    for i in [(history.length - 1)..0] # iterate from the oldest to the newset
        log "#{i}"
        for d in history[i]
            sequence.push(d)
    return sequence

    # yearLen = 366
    # seqLen = normalizedYears.length * yearLen
    # sequence = new Array(seqLen)
    # for yearData, yearIdx in normalizedYears
    #     for price, dayIdx in yearData
    #         sequence[yearIdx * yearLen + dayIdx] = price


############################################################
# We calculate the factors of change where
# factor[0] = yearData[0] / yearData[1]
# This way we may do this later:
# start with a starting point of 100
# normalizedDynamic[0] = 100
# normalizedDynamic[1] = normalizedDynamic[0] * factor[0]
getLogFactorsForYearData = (yearData) ->
    yearData = normalizeYearData(yearData)
    return utl.toLogFactorsArray(yearData) 
    

############################################################
export addYearToAverage = (newYear, oldResult, oldWeight) ->
    newYearFactors = getLogFactorsForYearData(newYear)
    oldFactors = utl.toLogFactorsArray(oldResult)
    divisor = oldWeight + 1

    factors = new Array(oldFactors.length)
    for f,i in oldFactors
        factors[i] = f * oldWeight
        factors[i] += newYearFactors[i]
        factors[i] /= divisor

    return utl.dataArrayFromLogFactors(factors)

export addCurrrentToAverage = (incomplete, oldResult, oldWeight) ->
    today = new Date()
    incomplete = normalizeIncomplete(incomplete, today.getFullYear())
    incompleteFactors = utl.toLogFactorsArray(incomplete)
    oldFactors = utl.toLogFactorsArray(oldResult)
    
    factors = new Array(oldFactors.length)
    factors[i] = f for f,i in oldFactors
    for iF, i in incompleteFactors
        factors[i] *= oldWeight
        factors[i] += iF
        factors[i] /= oldWeight + 1

    return utl.dataArrayFromLogFactors(factors)

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
        
    return utl.dataArrayFromLogFactors(averagedFactors)

export getDynamicsOfCurrentYear = (data) ->
    today = new Date()
    normed = normalizeIncomplete(data, today.getFullYear())
    factors = utl.toLogFactorsArray(normed)
    return utl.dataArrayFromLogFactors(factors)

############################################################
# We "normalize" every year to become 366 days
# for that we simply copy FEB28 to become 
# a fictitious FEB29 ;-)
export normalizeYearData = (data) ->
    if data.length == 366 then return data
    
    missingFeb29 = data
    yearData = new Array(366)
    # construct year of 366 days with double Feb28
    for i in [0...utl.FEB29]
        yearData[i] = missingFeb29[i]
    
    yearData[utl.FEB29] = missingFeb29[utl.FEB28]
    for i in [utl.FEB28...missingFeb29.length]
        yearData[i+1] = missingFeb29[i]

    return yearData

############################################################
normalizeIncomplete = (incomplete, year) ->
    if !utl.isLeapYear(year) then return incomplete
    if incomplete.length < utl.FEB29 then return incomplete

    result = new Array(incomplete.length + 1)
    for i in [0...utl.FEB29]
        result[i] = incomplete[i]
    
    result[utl.FEB29] = incomplete[utl.FEB28]
    for i in [utl.FEB28...incomplete.length]
        result[i+1] = incomplete[i]

    return result


