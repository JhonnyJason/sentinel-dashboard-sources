############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("currencytrendframemodule")
#endregion

############################################################
import M from "mustache"

currencyPairTemplate = document.getElementById("currency-pair-template").innerHTML
# alert currencyPairTemplate

############################################################
import { allAreas as aA } from "./economicareasmodule.js"
import * as cfg from "./configmodule.js"
import * as scoreHelper from "./scorehelper.js"

############################################################
allCurrencyPairs = {}
shownCurrencyPairs = []

############################################################
nWeights = {
    i: 6
    l: 9
    g: 3
    c: 13
}

n6Weights = {
    i: 7
    l: 11
    g: 5
    c: 7
}

ypWeights = {
    i: 10
    l: 6
    g: 9
    c: 5
}

############################################################
export initialize = ->
    log "initialize"
    for lblB,base of aA
        for lblQ,quote of aA when lblB != lblQ
            pair = new CurrencyPair(base, quote)
            allCurrencyPairs[pair.short] = pair
    
    for label in cfg.shownCurrencyPairLabels
        shownCurrencyPairs.push(allCurrencyPairs[label])

    # setInterval(renderFrame, cfg.uiRerenderMS)
    renderFrame()

    # result = scoreHelper.getInterestScore(2.5, 15.0)
    # log result
    # scoreHelper.getInflationScore(5.500001, 14)
    # scoreHelper.getColorForScore(25)
    return

############################################################
scoreSort = (el1, el2) ->
    score1 = parseFloat(el1.score)
    score2 = parseFloat(el2.score)
    return score2 - score1

############################################################
export renderFrame = ->
    log "renderFrame"
    shownCurrencyPairs.sort(scoreSort)
    ## TODO check if anything has changed and skip rerendering

    currencytrendframe.innerHTML = ""
    for pair in shownCurrencyPairs
        currencytrendframe.appendChild(pair.element)
    return

############################################################
class CurrencyPair

    constructor: (@baseArea, @quoteArea) ->
        @short = @baseArea.currencyShort + @quoteArea.currencyShort
        @score = "N/A"
        @baseArea.addUpdateListener(@updateScore)
        @quoteArea.addUpdateListener(@updateScore)

        cObj = {
            short: @short,
            score: @score,
            colorCode: "#eee"
            rightText: "Keine Daten"

        }

        virtualContainer = document.createElement("v")
        html = M.render(currencyPairTemplate, cObj)
        virtualContainer.innerHTML = html.trim()

        # log html
        @element = virtualContainer.firstChild
        # @colorFrame = @element.getElementsByClassName("color-frame")[0]
        @scoreDisplay = @element.getElementsByClassName("score")[0]
        @trendTextDisplay = @element.getElementsByClassName("trend-text")[0]

        # @inflationEl = p.getElementsByClassName("value")[0]
        # infoButton = p.getElementsByClassName("info-button")[0]
        # infoButton.addEventListener("click", @inflationInfoClicked)

        # p = @element.getElementsByClassName("refinancing-rate")[0]
        # @refinancingEl = p.getElementsByClassName("value")[0]
        # infoButton = p.getElementsByClassName("info-button")[0]
        # infoButton.addEventListener("click", @refinancingInfoClicked)

        # p = @element.getElementsByClassName("gdp-growth")[0]
        # @gdpgrowthEl = p.getElementsByClassName("value")[0]
        # infoButton = p.getElementsByClassName("info-button")[0]
        # infoButton.addEventListener("click", @gdpGrowthInfoClicked)

        # p = @element.getElementsByClassName("info-display")[0]
        # @infoTitleEl = p.getElementsByClassName("info-title")[0]
        # @infoDescriptionEl = p.getElementsByClassName("info-description")[0]

        # closeButton = p.getElementsByClassName("close-button")[0]
        # closeButton.addEventListener("click", @resetInfoDisplay)

    updateScore: =>
        # log "updateScore #{@short}"
        try
            nInfScoreBase = @baseArea.normalizedInflationScore()
            nInfScoreQuote = @quoteArea.normalizedInflationScore()
            diff = nInfScoreBase - nInfScoreQuote
            infScore = scoreHelper.inflationDiffCurve(diff)
            
            nMrrScoreBase = @baseArea.normalizedInterestScore()
            nMrrScoreQuote = @quoteArea.normalizedInterestScore()
            diff = nMrrScoreBase - nMrrScoreQuote
            mrrScore = scoreHelper.interestDiffCurve(diff)

            nGdpScoreBase = @baseArea.normalizedGDPScore()
            nGdpScoreQuote = @quoteArea.normalizedGDPScore()
            diff = nGdpScoreBase - nGdpScoreQuote
            gdpScore = scoreHelper.gdpDiffCurve(diff)

            nCotScoreBase = @baseArea.normalizedCOTScore()
            nCotScoreQuote = @quoteArea.normalizedCOTScore()
            diff = nCotScoreBase - nCotScoreQuote
            cotScore = scoreHelper.cotDiffCurve(diff)
            if !isNaN(infScore)
                log "#{@baseArea.currencyShort}#{@quoteArea.currencyShort}"
                olog {
                    infScore,
                    mrrScore,
                    gdpScore,
                    # nCotScoreBase
                    # nCotScoreQuote
                    # diff
                    cotScore
                }
            ## Top Level combination of individual scores already implemented :-)
            { i, l, g, c } = nWeights
            fullScore = i * infScore + l * mrrScore + g * gdpScore + c * cotScore

            if fullScore > 30 then fullScore = 30
            else if fullScore < -30 then fullScore = -30
            else fullScore = Math.round(fullScore) 
            
            @score = fullScore
            
            trendColor = scoreHelper.getColorForScore(@score)
            trendText = scoreHelper.getTrendTextForScore(@score)

            # log "total score: #{@score}"
            @scoreDisplay.textContent = @score.toFixed(2)
        
            # @colorFrame.style.backgroundColor = trendColor
            @element.style.backgroundColor = trendColor

            @trendTextDisplay.textContent = trendText            

        catch err ## then log err
            log err
            log "Error happened on #{@short}"
        return