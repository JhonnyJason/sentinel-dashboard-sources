############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scorehelper")
#endregion

############################################################
import { diffParams as defaultDiffParams, finalWeights as defaultFinalWeights } from "./defaultsnapshot.js"

############################################################
#region Trend Range Definitions
## Notice: minScore and maxScore are 25 on purpose
#      This is to squeeze the range for the colors a bit
maxScore = 25
minScore = -25
scoreRange = Math.abs(maxScore - minScore)

############################################################
globalParams = null

############################################################
colors = [
    # 6 gradient to red and green + grey neutral color
    "#33cc00"
    "#55d04b"
    "#79d399"
    "#ddd"
    "#eb803d"
    "#db591e"
    "#cc3300"
]

trendTexts = [
    # Trend Texts for all 6 gradients
    "Super Bullish" # "#33cc00"
    "Stark Bullish" # "#55d04b"
    "Bullish" # "#79d399"
    "Neutral" # "#ddd"
    "Bearish" # "#eb803d"
    "Stark Bearish" # "#db591e"
    "Super Bearish" # "#cc3300"
]
#endregion

############################################################
#region Local Functions

############################################################
getDiffParams = ->  
    if globalParams? then return globalParams.diffCurves
    else return defaultDiffParams 
getFinalWeights = -> 
    if globalParams? then return globalParams.finalWeights
    else return defaultFinalWeights

############################################################
calcScore = (infl, mrr, gdpg, cot, horizon) ->
    w = getFinalWeights()[horizon]
    weighted = (w.i * infl) + (w.l * mrr) + (w.g * gdpg) + (w.c * cot)
    correctionFactor = (1.0 * w.f) / (w.i + w.l + w.g + w.c)
    return weighted * correctionFactor

#endregion

############################################################
#region Exported Functions

############################################################
export inflDiffScore = (diff) ->
    { b, d } = getDiffParams().infl
    return b * diff + d * diff * diff * diff

export mrrDiffScore = (diff) ->
    { b, d } = getDiffParams().mrr
    return b * diff + d * diff * diff * diff

export gdpgDiffScore = (diff) ->
    { b, d } = getDiffParams().gdpg
    return b * diff + d * diff * diff * diff

export cotDiffScore = (diff) ->
    { b, d } = getDiffParams().cot
    return b * diff + d * diff * diff * diff

############################################################
export stScore = (infl, mrr, gdpg, cot) -> calcScore(infl, mrr, gdpg, cot, "st")
export mlScore = (infl, mrr, gdpg, cot) -> calcScore(infl, mrr, gdpg, cot, "ml")
export ltScore = (infl, mrr, gdpg, cot) -> calcScore(infl, mrr, gdpg, cot, "lt")

############################################################
export displayableScore = (raw) ->
    score = Math.round(raw)
    if score > 30 then score = 30
    if score < -30 then score = -30
    return score

############################################################
export getTrendForScore = (score) ->
    log "getTrendForScore #{score}"
    if score > maxScore then return { color: colors[0], text: trendTexts[0] }
    if score < minScore then return { color: colors[colors.length - 1], text: trendTexts[trendTexts.length - 1] }

    regionSize = 1.0 * scoreRange / colors.length
    score = 1.0 * score - minScore # shift lower end to 0
    region =  Math.floor(score / regionSize)
    region  = Math.min(region, colors.length - 1)
    region = Math.max(region, 0)

    region = colors.length - 1 - region # lower region is higher
    log "Resulting Region: #{region}"
    color = colors[region]
    text = trendTexts[region]
    return { color, text }

############################################################
export setGlobalParams = (params) ->
    log "setGlobalParams"
    globalParams = params
    return
    
#endregion