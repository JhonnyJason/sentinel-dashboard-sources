############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonality")
#endregion

############################################################
import * as utl from "./utilsmodule.js"
# import FFT from "fft.js" # Fourier is deferred

############################################################
#region Interface
# isIncluded(k): keep chunk k (by age, 0 = newest), null = all chunks
# returns null if no sample remains
export calculateSeasonalityComposite = (data, method, isIncluded = null) ->
    # data: equally sized close arrays, newest first - data[0] is the
    # unfinished current chunk, shown separately as "latest"
    if method == 0 # Average Daily Return
        # filter after the factor step: a chunk's first return links to the previous chunk's close
        factorArrays = (f for f, k in toLogFactorArrays(data) when k > 0 and (!isIncluded? or isIncluded(k)))
        return null unless factorArrays.some((f) -> f.some(Number.isFinite))
        return averageDailyReturn(factorArrays)

    if method == 1 # Fourier Regression - deferred
        console.error("Fourier Regression is currently disabled")
        return
    
    console.error("Unknown Method: #{method}")
    return

#endregion

############################################################
# factorArrays: equally sized log factor arrays
# per index only finite factors are averaged, null / undefined don't count
# an index without samples stays neutral (log factor 0)
# returns the cumulative curve with factorArrays[0].length + 1 points
export averageDailyReturn = (factorArrays) ->
    log "averageDailyReturn"
    len = factorArrays[0]?.length ? 0
    for factors in factorArrays when factors.length != len
        throw new Error("averageDailyReturn: factor arrays differ in length (#{factors.length} != #{len})")

    averagedFactors = new Array(len)
    for i in [0...len]
        sum = 0
        count = 0
        for factors in factorArrays when Number.isFinite(factors[i])
            sum += factors[i]
            count++
        averagedFactors[i] = if count then sum / count else 0
        
    return utl.dataArrayFromLogFactors(averagedFactors)

############################################################
# Fourier Regression - deferred, see plan/deferred.md
# needs rework for null / undefined slots and monthly / weekly chunks
# fourierRegression = (data) ->
#     log "fourierRegression"
#     # Normalize all years to 366 days (direct price data)
#     normalizedYears = (normalizeYearData(d) for d in data)
    
#     # Concatenate into one long sequence
#     sequence = []
#     for i in [(data.length - 1)..0] # iterate from the oldest to the newset
#         for d in normalizedYears[i]
#             sequence.push(d)
#     seqLen = sequence.length

#     # Calculate and remove linear gradient (detrend)
#     startVal = sequence[0]
#     endVal = sequence[seqLen - 1]
#     gradient = (endVal - startVal) / seqLen

#     minVal = Infinity
#     maxVal = -Infinity
#     detrended = new Array(seqLen)
#     for val, i in sequence
#         val = (val - (startVal + gradient * i))
#         detrended[i] =  val
#         if val < minVal then minVal = val
#         if val > maxVal then maxVal = val

#     center = 0.5 * (maxVal - minVal)
#     detrended[i] -= center for val,i in detrended
    
#     # Apply FFT
#     # FFT size must cover full sequence (power of 2)
#     fftSize = 1
#     fftSize *= 2 while fftSize < seqLen

#     # Pad input to fftSize
#     paddedInput = new Array(fftSize)
#     paddedInput.fill(0)
#     paddedInput[i] = d for d, i in detrended

#     fftK = new FFT(fftSize)
#     fftOutput = fftK.createComplexArray()
#     fftSmoothed = fftK.createComplexArray()

#     fftK.realTransform(fftOutput, paddedInput)

#     ##Filter
#     filterHarmonics(data.length, fftOutput)
#     lowPass(Math.floor(seqLen / 7), fftOutput)

#     # Inverse FFT
#     fftK.inverseTransform(fftSmoothed, fftOutput)

#     # Extract real parts from complex array, then slice 1 year
#     realValues = new Array(seqLen)
#     realValues[i] = fftSmoothed[2 * i] for i in [0...seqLen]

#     # smoothedYear = realValues.slice(0, 366)
#     # smoothedYear = realValues.slice(366, 732)
#     smoothedYear = realValues.slice(Math.floor(seqLen / 2) - 183, Math.floor(seqLen / 2) + 183)

#     # retrend
#     startValF = smoothedYear[0]
#     endValF = smoothedYear[smoothedYear.length - 1]
#     gradientF = (endValF - startValF) / smoothedYear.length

#     minValF = Infinity
#     maxValF = -Infinity
#     # detrend our result to get rid off any accidentally introduced trend...
#     detrendedF = new Array(smoothedYear.length)
#     for val, i in smoothedYear
#         val = (val - (startValF + gradientF * i))
#         detrendedF[i] =  val
#         if val < minValF then minValF = val
#         if val > maxValF then maxValF = val

#     # retrend to have the average yearly trend - now we also should have purely positive values
#     for val, i in detrendedF
#         smoothedYear[i] = val - minValF + (startVal + gradient * i)

#     factors = utl.toFactorsArray(smoothedYear)
#     result = utl.fromFactorsForward(factors)
#     return result
#     # return smoothedYear


# smoothAverage = (input, size) ->
#     ## TODO implement
#     return input

# highPass = (cutOff, complexArray) ->
#     max = complexArray.length / 2
#     if cutOff > max then cutOff = max
#     for i in [0...cutOff]
#         complexArray[2*i] = 0
#         complexArray[2*i + 1] = 0
#     return

# lowPass = (cutOff, complexArray) ->
#     max = complexArray.length / 2
#     if cutOff > max then return
#     for i in [cutOff...max]
#         complexArray[2*i] = 0
#         complexArray[2*i + 1] = 0
#     return

# filterHarmonics = (base, complexArray) ->
#     max = complexArray.length / 2
#     for i in [0...max] when i % base != 0
#         complexArray[2*i] = 0
#         complexArray[2*i + 1] = 0
#     return


# ############################################################
# historyToSequence = (history) ->
#     sequence = []
#     for i in [(history.length - 1)..0] # iterate from the oldest to the newset
#         log "#{i}"
#         for d in history[i]
#             sequence.push(d)
#     return sequence

#     # yearLen = 366
#     # seqLen = normalizedYears.length * yearLen
#     # sequence = new Array(seqLen)
#     # for yearData, yearIdx in normalizedYears
#     #     for price, dayIdx in yearData
#     #         sequence[yearIdx * yearLen + dayIdx] = price


############################################################
# chunks: equally sized close arrays, newest first
# factor[i] = log change *into* slot i, prev is the last number before it,
# also across the boundary into the next-older chunk
# null (non-existent) / undefined (missing) slots stay as they are
# shortcut: prev skips missing slots too - fine as datacache has no gaps
# inside the data range, upgrade if gaps ever appear mid-history
export toLogFactorArrays = (chunks) ->
    result = new Array(chunks.length)
    prev = undefined
    for k in [chunks.length - 1..0] by -1 # oldest to newest
        chunk = chunks[k]
        factors = new Array(chunk.length)
        for v,i in chunk
            if typeof v != "number" then factors[i] = v; continue
            factors[i] = if prev? then Math.log(v / prev) else undefined
            prev = v
        result[k] = factors
    return result

############################################################
# We "normalize" every year to become 366 days
# non-leap years get a non-existent (null) FEB29
export normalizeYearData = (data) ->
    if data.length == 366 then return data
    
    missingFeb29 = data
    yearData = new Array(366)
    # construct year of 366 days with a non-existent Feb29
    for i in [0...utl.FEB29]
        yearData[i] = missingFeb29[i]
    
    yearData[utl.FEB29] = null
    for i in [utl.FEB29...missingFeb29.length] # Mar 1 onwards shifts by one
        yearData[i+1] = missingFeb29[i]

    return yearData


