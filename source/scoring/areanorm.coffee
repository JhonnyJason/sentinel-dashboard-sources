############################################################
# Pure normalization scoring functions.
# Extracted from EconomicArea — each takes (data, params)
# and returns a normalized score in [0, 2].

############################################################
import { coeffsToPeakSteepness } from "./normmath.js"

############################################################
# Quadratic norm for inflation
export inflNorm = (data, params) ->
    { a, b, c } = params.infl
    x = data.infl
    n = a + b * x + c * x * x
    if n < 0 then return 0
    if n > 2 then return 2
    return n

############################################################
# Linear norm for interest rate (MRR) with inflation-punishment coupling
export mrrNorm = (data, params) ->
    { f, n, c, s } = params.mrr
    x = data.mrr
    if x < n
        b = 1.0 / (n - f)
        a = (-b) * f
    else
        b = 1.0 / (c - n)
        a = 1 - (b * n)

    n = a + b * x

    res = coeffsToPeakSteepness(params.infl.a, params.infl.b, params.infl.c)
    inflPeak = res.peak
    inflZeroHigh = res.zeroHigh

    inflPivot = inflPeak * s
    inflCutoff = inflZeroHigh * s
    K = (inflZeroHigh - inflPeak) / s

    p1 = data.mrr - data.infl
    p2 = inflPivot - data.infl
    p3 = data.infl / inflCutoff
    if p3 > 1 then p3 = 1
    if p3 < 0  then p3 = 0

    n -= (p1 * p2 * p3) / K

    if n < 0 then return 0
    if n > 2 then return 2
    return n

############################################################
# Quadratic norm for GDP growth
export gdpgNorm = (data, params) ->
    { a, b, c } = params.gdpg
    x = data.gdpg
    n = a + b * x + c * x * x
    if n < 0 then return 0
    if n > 2 then return 2
    return n

############################################################
# Exponential norm for COT
export cotNorm = (data, params) ->
    n = params.cot.n || 50
    e = params.cot.e || 1

    ## = 2^((cot - n) / 50)      ∈ [0.5, 2.0]
    c6 = Math.pow(2, (0.02 * (data.cot6 - n)))
    c36 = Math.pow(2, (0.02 * (data.cot36 - n)))
    ## = (c6 × c36^e)^(1/(1+e))    ∈ [0.5, 2.0]
    c = Math.pow((c6 * Math.pow(c36, e)), (1.0 / (1 + e)))
    ## map [0.5, 2.0] -> [0, 2.0]
    n = (c - 0.5) * (2.0 / 1.5)

    ## probably unnecessary but will do no harm :-)
    if n < 0 then return 0
    if n > 2 then return 2
    return n
