############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitybacktestingmodule")
#endregion

############################################################
import * as parentFrame from "./seasonalityframemodule.js"
import * as chartModule from "./seasonalitychartmodule.js"

############################################################
# import { runBacktesting } from "./backtesting.js"
import { SymbolBacktester } from "./hlcbacktestingmodule.js"

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
    # val = factorToDeltaPercent(results.maxRiseObj.maxRiseF)
    val = factorToPercent(results.maxRiseObj.maxRiseF)
    maxRiseValue.textContent = "#{val.toFixed(1)}%"

    # val = factorToDeltaPercent(results.maxDropObj.maxDropF)
    val = factorToPercent(results.maxDropObj.maxDropF)
    maxDropValue.textContent = "#{val.toFixed(1)}%"
    
    # val = factorToDeltaPercent(results.avgChangeF)
    val = factorToPercent(results.avgChangeF)
    if !results.isLong then val *= -1.0
    averageChangeValue.textContent = "#{val.toFixed(1)}%"

    # val = factorToDeltaPercent(results.medChangeF)
    val = factorToPercent(results.medChangeF)
    if !results.isLong then val *= -1.0
    medianChangeValue.textContent = "#{val.toFixed(1)}%"
    daysInTradeValue.textContent = "#{results.daysInTrade} Tage"


    missingSF = results.maxRiseObj.missingSF 
    # val = factorToBackwardsAdjustedAbsoluteDeltaValue(results.maxRiseObj.maxRiseF, results.maxRiseObj)
    val = factorToBackwardsAdjustedAbsoluteValue(results.maxRiseObj.maxRiseF, results.maxRiseObj)
    if missingSF > 1
        maxRiseAbsValue.innerHTML = "#{val.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingSF.toFixed(2)}</span>"
    else maxRiseAbsValue.textContent = "#{val.toFixed(2)}"

    missingSF = results.maxDropObj.missingSF
    # val = factorToBackwardsAdjustedAbsoluteDeltaValue(results.maxDropObj.maxDropF, results.maxDropObj)
    val = factorToBackwardsAdjustedAbsoluteValue(results.maxDropObj.maxDropF, results.maxDropObj)
    if  missingSF > 1
        maxDropAbsValue.innerHTML = "#{val.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingSF.toFixed(2)}</span>"
    else maxDropAbsValue.textContent = "#{val.toFixed(2)}"
        
    return

############################################################
export run = (symbol, startIdx, endIdx, years) ->
    log "updateBacktestingUI"
    ## If there is any overlap here then startIdx will be negative
    ## at max we have 1 year overlap...
    olog { startIdx, endIdx }

    if startIdx < 0 # overflow drags last backtest Run to start one year earlier
        lastStartYear = (new Date()).getFullYear() - 1
        years--
        endIdx += 366
        startIdx += 366
    else lastStartYear = (new Date()).getFullYear()

    backtestKey = "#{symbol}:#{years}:#{startIdx}:#{endIdx}"
    backtester = new SymbolBacktester(symbol, backtestKey)
    ## Data should be cached already - still could take time loading an throw Errors
    await backtester.loadData()
    
    startYear = lastStartYear
    while years >= 0
        backtester.addBacktestRun(startYear, startIdx, endIdx, startYear)
        years--
        startYear--
    
    results = backtester.runEvaluationSync()
    
    ## add some data for summary rendering
    results.entryDate = indexToDate(startIdx) # for showing DD.MM. - DD.MM.  
    results.exitDate = indexToDate(endIdx) # for showing DD.MM. - DD.MM.
    results.daysInTrade = (endIdx - startIdx)

    renderSummary(results)
    renderDetails(results)
    return

############################################################
export setOnRangeChangeListener = (listener) -> onRangeChange = listener

############################################################
# Helper to format Leap Norm day index to "DD.MM." string
# Handles negative indices for overlapping selections (-1 = Dec 31)
indexToDate = (dayIdx) ->
    # Normalize negative indices: -1 -> 365, -366 -> 0
    if dayIdx < 0 then dayIdx = 366 + dayIdx

    # Use leap reference year (normalized indices assume 366 days)
    jan1 = new Date(2024, 0, 1, 12)
    targetDate = new Date(jan1.getTime() + dayIdx * 86_400_000)

    day = targetDate.getDate()
    month = targetDate.getMonth() + 1
    dayStr = if day < 10 then "0#{day}" else "#{day}"
    monthStr = if month < 10 then "0#{month}" else "#{month}"
    return "#{dayStr}.#{monthStr}."

############################################################
factorToDeltaPercent = (f) -> 100.0 * (f - 1.0)
factorToPercent = (f) -> 100.0 * f

############################################################
factorToBackwardsAdjustedAbsoluteDeltaValue = (f, infoObj) -> 
    return 1.0 * infoObj.entryCba *  (f - 1.0)
factorToBackwardsAdjustedAbsoluteValue = (f, infoObj) -> 
    return 1.0 * infoObj.entryCba * f
