############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("currencytrendframemodule")
#endregion

############################################################
import { allAreas as aA } from "./economicareasmodule.js"
import { CurrencyPair } from "./CurrencyPair.js"

############################################################
allCurrencyPairs = {}
shownCurrencyPairs = []

############################################################
stPairs = []
mlPairs = []
ltPairs = []

############################################################
stSummary = ""
mlSummary = ""
ltSummary = ""

############################################################
updatePending = false

############################################################
#region DOM Cache - fix for buggy implicit-dom-connect
shortTermCol = document.getElementById("short-term-col")
stList = shortTermCol.querySelector(".score-list")
mediumLongTermCol = document.getElementById("medium-long-term-col")
mlList = mediumLongTermCol.querySelector(".score-list")
longTermCol = document.getElementById("long-term-col")
ltList = longTermCol.querySelector(".score-list")

#endregion


############################################################
export initialize = (cfg) ->
    log "initialize"
    for lblB,base of aA
        for lblQ,quote of aA when lblB != lblQ
            pair = new CurrencyPair(base, quote)
            allCurrencyPairs[pair.short] = pair
    
    for label in cfg.shownCurrencyPairLabels
        pair = allCurrencyPairs[label]
        shownCurrencyPairs.push(pair)
        stPairs.push(pair)
        mlPairs.push(pair)
        ltPairs.push(pair)
    return


############################################################
stScoreSort = (el1, el2) ->
    score1 = parseFloat(el1.stScore)
    score2 = parseFloat(el2.stScore)
    return score2 - score1

mlScoreSort = (el1, el2) ->
    score1 = parseFloat(el1.mlScore)
    score2 = parseFloat(el2.mlScore)
    return score2 - score1

ltScoreSort = (el1, el2) ->
    score1 = parseFloat(el1.ltScore)
    score2 = parseFloat(el2.ltScore)
    return score2 - score1


############################################################
stListRender = ->
    log "stListRender"
    stPairs.sort(stScoreSort)
    newSummary = ""
    newSummary += pair.short for pair in stPairs
    
    if newSummary == stSummary then return

    log "we rerender the short-term-list..."
    stSummary = newSummary
    stList.innerHTML = ""
    stList.appendChild(pair.stElement) for pair in stPairs
    return

mlListRender = ->
    log "mlListRender"
    mlPairs.sort(mlScoreSort)
    newSummary = ""
    newSummary += pair.short for pair in mlPairs

    if newSummary == mlSummary then return

    log "we rerender the medium-long-term-list..."
    mlSummary = newSummary
    mlList.innerHTML = ""
    mlList.appendChild(pair.mlElement) for pair in mlPairs
    return

ltListRender = ->
    log "ltListRender"
    ltPairs.sort(ltScoreSort)
    newSummary = ""
    newSummary += pair.short for pair in ltPairs

    if newSummary == ltSummary then return

    log "we rerender the long-term-list..."
    ltSummary = newSummary
    ltList.innerHTML = ""
    ltList.appendChild(pair.ltElement) for pair in ltPairs
    return


############################################################
renderFrame = ->
    log "renderFrame"
    stListRender() 
    mlListRender()
    ltListRender()
    return

############################################################
updateRanking = ->
    log "updateRanking"
    pair.updateScore() for pair in shownCurrencyPairs
    renderFrame()
    return


############################################################
export scheduleRankingUpdate = ->
    return if updatePending
    updatePending = true
    requestAnimationFrame ->
        updatePending = false
        updateRanking()
        return
    return