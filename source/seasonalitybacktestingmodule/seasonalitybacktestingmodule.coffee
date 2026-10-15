############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitybacktestingmodule")
#endregion

############################################################
import * as parentFrame from "./seasonalityframemodule.js"
import * as chartModule from "./seasonalitychartmodule.js"
import * as equityPerformance from "./equityperformancemodule.js"
import * as chanceRiskProfile from "./chanceriskprofilemodule.js"

############################################################
# import { runBacktesting } from "./backtesting.js"
import { SymbolBacktester } from "./hlcbacktestingmodule.js"
import * as utl from "./utilsmodule.js"

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

    backtestingDetailsTabs.addEventListener("click", onDetailsTabClicked)
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
    
    # val = factorToDeltaPercent(results.avgChangeF)
    val = factorToPercent(results.avgChangeF)
    if !results.isLong then val *= -1.0
    averageChangeValue.textContent = "#{val.toFixed(1)}%"

    # val = factorToDeltaPercent(results.medChangeF)
    val = factorToPercent(results.medChangeF)
    if !results.isLong then val *= -1.0
    medianChangeValue.textContent = "#{val.toFixed(1)}%"
    daysInTradeValue.textContent = "#{results.daysInTrade} Tage"


    if !results.maxRiseObj? or !results.maxDropObj? 
        # protect from acessing null.maxRiseF etc. 
        maxRiseValue.textContent = "0.0%"
        maxDropValue.textContent = "0.0%"
    else
        val = factorToPercent(results.maxRiseObj.maxRiseF)
        maxRiseValue.textContent = "#{val.toFixed(1)}%"

        val = factorToPercent(results.maxDropObj.maxDropF)
        maxDropValue.textContent = "#{val.toFixed(1)}%"


    if !results.absMaxRiseObj? or !results.absMaxDropObj? 
        # protect from acessing null.maxRiseF etc. 
        maxRiseAbsValue.textContent = "0.00"
        maxDropAbsValue.textContent = "0.00"
        return
    log "maxDropObj:"
    olog results.absMaxDropObj

    missingSF = results.absMaxRiseObj.missingSF 
    val = factorToBackwardsAdjustedAbsoluteValue(results.absMaxRiseObj.maxRiseF, results.absMaxRiseObj)
    if missingSF > 1
        maxRiseAbsValue.innerHTML = "#{val.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingSF.toFixed(2)}</span>"
    else maxRiseAbsValue.textContent = "#{val.toFixed(2)}"

    missingSF = results.absMaxDropObj.missingSF
    val = factorToBackwardsAdjustedAbsoluteValue(results.absMaxDropObj.maxDropF, results.absMaxDropObj)
    if  missingSF > 1
        maxDropAbsValue.innerHTML = "#{val.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingSF.toFixed(2)}</span>"
    else maxDropAbsValue.textContent = "#{val.toFixed(2)}"
        
    return

############################################################
# entryDate / exitDate: the selection in the chart
# one run per period back to Jan 1 of (refDate year - years) - same window as the composite
# isRunIncluded(k): keep run k (k periods before the selection), null = all runs
export run = (symbol, entryDate, exitDate, years, timeframe, refDate, isRunIncluded = null) ->
    log "run"
    olog { entryDate, exitDate, years, timeframe }

    backtestKey = "#{symbol}:#{years}:#{timeframe}:#{toISODate(entryDate)}:#{toISODate(exitDate)}"
    tdc = { postponeEntry: true, preponeExit: true }
    backtester = new SymbolBacktester(symbol, backtestKey, tdc)
    ## Data should be cached already - still could take time loading an throw Errors
    await backtester.loadData()

    windowStart = new Date(refDate.getFullYear() - years, 0, 1, 12)
    k = 0
    loop
        entry = utl.shiftPeriodsBack(entryDate, k, timeframe)
        break if entry < windowStart
        if !isRunIncluded? or isRunIncluded(k)
            entryStr = toISODate(entry)
            backtester.addBacktestRunDates(entryStr, toISODate(utl.shiftPeriodsBack(exitDate, k, timeframe)), entryStr)
        k++
    
    results = backtester.runEvaluationSync()
    
    ## add some data for summary rendering
    results.entryDate = formatLabel(entryDate, timeframe)
    results.exitDate = formatLabel(exitDate, timeframe)
    results.daysInTrade = utl.dateDifDays(entryDate, exitDate)

    renderSummary(results)
    renderDetails(results)
    equityPerformance.setResults(results)
    chanceRiskProfile.setResults(results)
    return

############################################################
onDetailsTabClicked = (evt) ->
    tab = evt.target.dataset.tab
    return unless tab?
    for el in backtestingDetailsContainer.querySelectorAll("[data-tab]")
        el.classList.toggle("active", el.dataset.tab == tab)
    return

############################################################
export setOnRangeChangeListener = (listener) -> onRangeChange = listener

############################################################
toISODate = (date) -> date.toISOString().slice(0, 10)

weekdayNames = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

# summary label: yearly + quarterly "DD.MM.", monthly "DD.", weekly "Mo"
formatLabel = (date, timeframe) ->
    if timeframe == "weekly" then return weekdayNames[date.getDay()]
    day = String(date.getDate()).padStart(2, "0")
    if timeframe == "monthly" then return "#{day}."
    month = String(date.getMonth() + 1).padStart(2, "0")
    return "#{day}.#{month}."

############################################################
factorToDeltaPercent = (f) -> 100.0 * (f - 1.0)
factorToPercent = (f) -> 100.0 * f

############################################################
factorToBackwardsAdjustedAbsoluteDeltaValue = (f, infoObj) -> 
    return 1.0 * infoObj.entryCba *  (f - 1.0)
factorToBackwardsAdjustedAbsoluteValue = (f, infoObj) -> 
    return 1.0 * infoObj.entryCba * f
