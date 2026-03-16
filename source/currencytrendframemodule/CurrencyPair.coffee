############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("CurrencyPair")
#endregion

############################################################
import M from "mustache"

############################################################
import * as scoreHelper from "./scorehelper.js"

############################################################
#region DOM cache - fix for buggy implicit-dom-connect
currencyPairTemplate = document.getElementById("currency-pair-template").innerHTML

#endregion

############################################################
export class CurrencyPair

    constructor: (@baseArea, @quoteArea) ->
        @short = @baseArea.currencyShort + @quoteArea.currencyShort
        @score = "N/A"
        @baseArea.addUpdateListener(@updateScore)
        @quoteArea.addUpdateListener(@updateScore)

        ## Short Term Elements
        stObj = {
            short: @short,
            score: @score,
            colorCode: "#eee"
            rightText: "Keine Daten"
        }
        stVirtualContainer = document.createElement("v")
        html = M.render(currencyPairTemplate, stObj)
        stVirtualContainer.innerHTML = html.trim()

        @stElement = stVirtualContainer.firstChild
        @stScoreDisplay = @stElement.getElementsByClassName("score")[0]
        @stTrendTextDisplay = @stElement.getElementsByClassName("trend-text")[0]


        ## Medium Long Term Element
        mlObj = {
            short: @short,
            score: @score,
            colorCode: "#eee"
            rightText: "Keine Daten"

        }
        mlVirtualContainer = document.createElement("v")
        html = M.render(currencyPairTemplate, mlObj)
        mlVirtualContainer.innerHTML = html.trim()

        @mlElement = mlVirtualContainer.firstChild
        @mlScoreDisplay = @mlElement.getElementsByClassName("score")[0]
        @mlTrendTextDisplay = @mlElement.getElementsByClassName("trend-text")[0]

        ## Long Term Element
        ltObj = {
            short: @short,
            score: @score,
            colorCode: "#eee"
            rightText: "Keine Daten"

        }
        ltVirtualContainer = document.createElement("v")
        html = M.render(currencyPairTemplate, ltObj)
        ltVirtualContainer.innerHTML = html.trim()

        @ltElement = ltVirtualContainer.firstChild
        @ltScoreDisplay = @ltElement.getElementsByClassName("score")[0]
        @ltTrendTextDisplay = @ltElement.getElementsByClassName("trend-text")[0]

    updateScore: =>
        # log "updateScore #{@short}"
        try
            nInfScoreBase = @baseArea.normFun.infl()
            nInfScoreQuote = @quoteArea.normFun.infl()
            diff = nInfScoreBase - nInfScoreQuote
            infScore = scoreHelper.inflDiffScore(diff)

            nMrrScoreBase = @baseArea.normFun.mrr()
            nMrrScoreQuote = @quoteArea.normFun.mrr()
            diff = nMrrScoreBase - nMrrScoreQuote
            mrrScore = scoreHelper.mrrDiffScore(diff)

            nGdpScoreBase = @baseArea.normFun.gdpg()
            nGdpScoreQuote = @quoteArea.normFun.gdpg()
            diff = nGdpScoreBase - nGdpScoreQuote
            gdpScore = scoreHelper.gdpgDiffScore(diff)

            nCotScoreBase = @baseArea.normFun.cot()
            nCotScoreQuote = @quoteArea.normFun.cot()
            diff = nCotScoreBase - nCotScoreQuote
            cotScore = scoreHelper.cotDiffScore(diff)

            ## catch the problem if there is something wrong...
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

            ## display Short Term Score
            @stScore = scoreHelper.stScore(infScore, mrrScore, gdpScore, cotScore)
            @stScoreDisplay.textContent = scoreHelper.displayableScore(@stScore)
            trend = scoreHelper.getTrendForScore(@stScore)
            @stElement.style.backgroundColor = trend.color
            @stTrendTextDisplay.textContent = trend.text           
                        
            ## display Medium-Long Term Score
            @mlScore = scoreHelper.mlScore(infScore, mrrScore, gdpScore, cotScore)
            @mlScoreDisplay.textContent = scoreHelper.displayableScore(@mlScore)
            trend = scoreHelper.getTrendForScore(@mlScore)
            @mlElement.style.backgroundColor = trend.color
            @mlTrendTextDisplay.textContent = trend.text

            ## display Long Term Score
            @ltScore = scoreHelper.ltScore(infScore, mrrScore, gdpScore, cotScore)
            @ltScoreDisplay.textContent = scoreHelper.displayableScore(@ltScore)
            trend = scoreHelper.getTrendForScore(@ltScore)
            @ltElement.style.backgroundColor = trend.color
            @ltTrendTextDisplay.textContent = trend.text           

        catch err ## then log err
            log err
            log "Error happened on #{@short}"
        return

