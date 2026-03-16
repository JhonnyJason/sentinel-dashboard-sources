############################################################
# Pure math for normalization parameter conversions.
# No state, no DOM — just conversions between user-friendly
# params (peak/steepness, neutralRate/sensitivity) and
# internal coefficients (a, b, c).

############################################################
# Quadratic: peak + steepness → a, b, c coefficients
# width = BASE_WIDTH / steepness (steepness 1.0 → width 10)
# k = -8/width² ensures f(peak) = 2, output range [0, 2]
# Returns { a, b, c, zeroLow, zeroHigh }
BASE_WIDTH = 10

export peakSteepnessToCoeffs = (peak, steepness) ->
    width = BASE_WIDTH / steepness
    zeroLow = peak - width / 2
    zeroHigh = peak + width / 2
    k = -8 / (width * width)
    c = k
    b = -k * (zeroLow + zeroHigh)
    a = k * zeroLow * zeroHigh
    return { a, b, c, zeroLow, zeroHigh }

############################################################
# Quadratic: a, b, c coefficients → peak + steepness
# Returns { peak, steepness, zeroLow, zeroHigh } or null
export coeffsToPeakSteepness = (a, b, c) ->
    return null if c >= 0
    width = Math.sqrt(-8 / c)
    steepness = BASE_WIDTH / width
    peak = -b / (2 * c)
    zeroLow = peak - width / 2
    zeroHigh = peak + width / 2
    return { peak, steepness, zeroLow, zeroHigh }

############################################################
# Linear: inflation Punishment to param s
#   punishment is 0-100 % scale 
#   s is in [1 - 2] range  where 1 is max and 2 is min
export punishmentToS = (punishment) -> (2 - 0.01 * punishment)
export sToPunishment = (s) -> Math.round((2 - s) * 100)


############################################################
## Amplification calculations
##    ampl is [0, 100] 
##    b and d are the coefficiencs of the cubic polynomial
##    The input output range is bound by [-2, 2] -> [-5, 5]
export amplificationToCoeffs = (ampl) ->
    shape = 0.01 * ampl # push into [0, 1] range
    d = shape * 0.625
    b = 2.5 * (1.0 - shape)
    return { b, d }

export coeffsToAmplification = (b, d) ->
    shape = d / 0.625
    shouldB = 2.5 * (1.0 - shape)
    ## b should fit, if not we cannot do anything here but note it :-(
    if (shouldB - b) >= 0.001 then console.error("b coeff was not appropriate!")
    
    ampl = 100 * shape
    return ampl

############################################################
# Linear: a, b → neutralRate + sensitivity
export coeffsToNeutralSensitivity = (a, b) ->
    sensitivity = b
    neutralRate = if b != 0 then -a / b else 0
    return { neutralRate, sensitivity }

