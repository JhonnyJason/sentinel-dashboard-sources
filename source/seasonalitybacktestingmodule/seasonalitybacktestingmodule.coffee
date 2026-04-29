############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitybacktestingmodule")
#endregion

############################################################
import * as parentFrame from "./seasonalityframemodule.js"
import * as chartModule from "./seasonalitychartmodule.js"

############################################################
import { runBacktesting } from "./backtesting.js"

############################################################
import { render as renderDetails } from "./renderdetails.js"

############################################################
#region DOM cache for the cases where the implicit-dom-connect fails
backtestingDirection = document.getElementById("backtesting-direction")
backtestingTimeframe = document.getElementById("backtesting-timeframe")
winRateNumber = document.getElementById("winrate-percent")
lossCircle = document.getElementById("loss-circle")
winVsLose = document.getElementById("win-vs-lose")

maxRiseValue = document.querySelector('#max-rise .value')
maxDropValue = document.querySelector('#max-drop .value')
maxRiseAbsValue = document.querySelector('#max-rise-abs .value')
maxDropAbsValue = document.querySelector('#max-drop-abs .value')
averageChangeValue = document.querySelector('#average-change .value')
medianChangeValue = document.querySelector('#median-change .value')
daysInTradeValue = document.querySelector('#days-in-trade .value')

entryDateMinusButton = document.querySelector("#backtesting-entry .minus")
entryDatePlusButton = document.querySelector("#backtesting-entry .plus")
exitDateMinusButton = document.querySelector("#backtesting-exit .minus")
exitDatePlusButton = document.querySelector("#backtesting-exit .plus")

entryDateElement = document.querySelector("#backtesting-entry .date")
exitDateElement = document.querySelector("#backtesting-exit .date")

#endregion

############################################################
onRangeChange = null

############################################################
export initialize = ->
    log "initialize"
    entryDateMinusButton.addEventListener("click", onEntryMinusClicked)
    entryDatePlusButton.addEventListener("click", onEntryPlusClicked)
    exitDateMinusButton.addEventListener("click", onExitMinusClicked)
    exitDatePlusButton.addEventListener("click", onExitPlusClicked) 
    return

############################################################
#region EventListeners
onEntryMinusClicked = ->
    log "onStartMinusClicked"
    chartModule.setSelectedRegion({
        isDelta: true
        startIdx: -1
    })
    return

onEntryPlusClicked = ->
    log "onStartPlusClicked"
    chartModule.setSelectedRegion({
        isDelta: true
        startIdx: +1
    })
    return

onExitMinusClicked = -> 
    log "onExitMinusClicked"
    chartModule.setSelectedRegion({
        isDelta: true
        endIdx: -1
    })
    return

onExitPlusClicked = ->
    log "onExitPlusClicked"
    chartModule.setSelectedRegion({
        isDelta: true
        endIdx: +1
    })
    return

#endregion

############################################################
renderSummary = (results) ->
    log "renderSummary"

    olog results

    if results.isLong
        backtestingDirection.textContent = "LONG"
        backtestingDirection.className = "long"
    else
        backtestingDirection.textContent = "SHORT"
        backtestingDirection.className = "short"

    entryDateElement.textContent = results.entryDate
    exitDateElement.textContent = results.exitDate

    total = results.totalTrades
    if total == 0
        wins = 0.0
        losers = 0.0
        winRate = 0.0
    else
        wins = results.winTrades
        losers = total - wins
        winRate = 100.0 * wins / total
    

    # Win rate
    winRateNumber.textContent = "#{winRate.toFixed(1)}%"
    lossRate = 100 - winRate
    strokeDashArray = "#{lossRate * 6.294 / 100} #{6.294}"
    lossCircle.setAttribute("stroke-dasharray", strokeDashArray)

    winVsLose.textContent = "#{wins} | #{losers}"

    # Summary stats
    maxRiseValue.textContent = "#{results.maxRiseP.toFixed(1)}%"
    maxDropValue.textContent = "#{results.maxDropP.toFixed(1)}%"
    averageChangeValue.textContent = "#{results.averageProfit.toFixed(1)}%"
    medianChangeValue.textContent = "#{results.medianProfit.toFixed(1)}%"
    daysInTradeValue.textContent = "#{results.daysInTrade} Tage"

    if results.maxDropMissingF > 1
        maxDropAbsValue.innerHTML = "#{results.maxDropAba.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{results.maxDropMissingF.toFixed(2)}</span>"
    else
        maxDropAbsValue.textContent = "#{results.maxDropAba.toFixed(2)}"

    if results.maxRiseMissingF > 1
        maxRiseAbsValue.innerHTML = "#{results.maxRiseAba.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{results.maxRiseMissingF.toFixed(2)}</span>"
    else
        maxRiseAbsValue.textContent = "#{results.maxRiseAba.toFixed(2)}"
        
    return

############################################################
export run = (hlcData, metaData, startIdx, endIdx, tradingDays) ->
    log "updateBacktestingUI"
    olog { startIdx, endIdx }

    results = runBacktesting({
        dataPerYear: hlcData
        metaData, startIdx, endIdx,
        tradingDaysPerYear: tradingDays
    })

    renderSummary(results)
    renderDetails(results)
    return

############################################################
export setOnRangeChangeListener = (listener) -> onRangeChange = listener
