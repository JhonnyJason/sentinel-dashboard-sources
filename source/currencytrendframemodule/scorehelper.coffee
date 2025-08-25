############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scorehelper")
#endregion

############################################################
maxScore = 30
minScore = -30
scoreRange = Math.abs(maxScore - minScore)

############################################################
colors = [
    # bright green -> bright red
    # "#00ff00"
    # "#19e600"
    # "#33cc00"
    # "#4cb300"
    # "#669900"
    # "#807f00"
    # "#996600"
    # "#b34c00"
    # "#cc3300"
    # "#e61900"
    # "#ff0000"

    # green -> bluegrey -> orange -> red
    # "#33cc00"
    # "#55d04b"
    # "#79d399"
    # "#9cd7e4"
    # "#b9d1e0"
    # "#d4c5b2"
    # "#eeba85"
    # "#faa55b"
    # "#eb803d"
    # "#db591e"
    # "#cc3300"

    # 6 pick from
    "#33cc00"
    "#55d04b"
    "#79d399"
    "#eb803d"
    "#db591e"
    "#cc3300"
]

############################################################
inflationToScore = (infl) ->
    switch 
        when infl < 0 then return -3 # <0% -3 Pkt (Deflationsgefahr)
        when infl < 1 then return -2 # 0-1% -2 Pkt
        when infl < 1.5 then return -1 # 1-1,5% -1 Pkt
        when infl < 2.5 then return 0 # 1,5%-2,5% 0 Pkt (Normalität)
        when infl < 3 then return 1 # 2,5-3% 1 Pkt
        when infl < 3.5 then return 2 # 3-3,5% 2 Pkt
        when infl < 4 then return 3 # 3,5-4% 3 Pkt
        when infl < 4.5 then return 2 # 4-4,5% 2 Pkt
        when infl < 5 then return 1 # 4,5-5% 1 Pkt
        when infl < 5.5 then return 0 # 5–5,5% 0 Pkt
        else 
            return -Math.ceil((infl - 5.5) * 2)
            # 5,5-6% -1 Pkt
            # 6-6,5% -2 Pkt
            # 6,5-7% -3 Pkt
            # ...

getInflationFactor = (baseInfl, quoteInfl) ->
    log "getInflationFactor"
    dif = Math.abs(baseInfl - quoteInfl)

    switch
        ## Here we have a hole at 2.5 - 3.0
        # when dif <= 0.5 then return 1.5 # A - B 0,5% Faktor 1,5
        # when dif <= 1.0  then return 2 # A - B 1,0% Faktor 2
        # when dif <= 1.5 then return 2.5 # A - B 1,5% Faktor 2,5
        # when dif <= 2.0 then return 3 # A - B 2,0% Faktor 3
        # when dif <= 2.5 then return 3.5 # A - B 2,5% Faktor 3,5
        # when dif > 3 then return 4 # A - B >3% Faktor 4

        when dif < 0.75 then return 1.5 # A - B 0,5% Faktor 1,5
        when dif < 1.25  then return 2 # A - B 1,0% Faktor 2
        when dif < 1.75 then return 2.5 # A - B 1,5% Faktor 2,5
        when dif < 2.25 then return 3 # A - B 2,0% Faktor 3
        when dif < 3 then return 3.5 # A - B 2,5% Faktor 3,5
        when dif > 3 then return 4 # A - B >3% Faktor 4

        else throw new Error("Unexpected dif: #{dif} is of type: #{typeof dif}")
    return

############################################################
export getInterestScore = (baseInterest, quoteInterest) ->
    spread = baseInterest - quoteInterest
    
    if spread < 0 
        spread *= -1
        sign = -1
    else sign = 1

    switch
        when spread < 0.5 then return 0
        when spread < 1.5 then return (sign * 1)
        when spread > 10 then return (sign  * 10)
        else
            num = Math.ceil(spread)
            return (sign * num)
    return 0

export getInflationScore = (baseInflation, quoteInflation) ->
    log "getInflationScore"
    baseScore = inflationToScore(baseInflation)
    log "inflation of #{baseInflation} leads to #{baseScore}"
    quoteScore = inflationToScore(quoteInflation)
    log "inflation of #{quoteInflation} leads to #{quoteScore}"
    fctr = getInflationFactor(baseInflation, quoteInflation)
    
    return baseScore - quoteScore * fctr

# export getGDPComparisonScore = (baseGDPG, quoteGDPG) ->
#     log "getGDPScore"
#     return 0

############################################################
export getColorForScore = (score) ->
    log "getColorForScore #{score}"
    if score > maxScore then return colors[0]
    if score < minScore then return colors[colors.length - 1]

    regionSize = 1.0 * scoreRange / colors.length
    score = 1.0* score - minScore # shift lower end to 0
    region =  Math.floor(score / regionSize)
    region  = Math.min(region, colors.length - 1)
    region = Math.max(region, 0)
    
    region = colors.length - 1 - region # lower region is higher color

    log "Resulting Region: #{region}"
    return colors[region]