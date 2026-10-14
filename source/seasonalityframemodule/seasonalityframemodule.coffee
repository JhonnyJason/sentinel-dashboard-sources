############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"

############################################################
import { SymbolSelect } from "./symbolselectmodule.js"

############################################################
import * as backtesting from "./seasonalitybacktestingmodule.js"
import * as charting from "./seasonalitychartmodule.js"
import * as cycles from "./seasonalitycyclesmodule.js"
import { todayYmd, ymdOf, includedChunkFn, isFullCycle, displayAges, showsLatest } from "./cyclemath.js"

############################################################
# the cycle unit follows the chart timeframe
timeframeToUnit = { yearly: "years", quarterly: "quarters", monthly: "months", weekly: "weeks" }

############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));

############################################################
symbolSelect = null

############################################################
#region State
selectedSymbol = null
selectedRangeY = null
chartTimeframe = null
selectedCycle = null

backtestingRegion = null
chartData = null

#endregion

############################################################
export initialize = (c) ->
    log "initialize"
    container = symbolSelectSeasonality # symbolSelectSeasonality.
    optionsLimit = 70

    symbolSelect = new SymbolSelect({ container, optionsLimit })
    symbolSelect.setOnSelectListener(onStockSelected)
    
    historyTimeframeSelect.addEventListener("change", timeframeSelected)
    selectedRangeY = historyTimeframeSelect.value

    chartTimeframeSelect.addEventListener("change", chartTimeframeChanged)
    chartTimeframe = chartTimeframeSelect.value

    closeChartButton.addEventListener("click", onCloseChart)

    # Wire up tab buttons
    componentsButton.addEventListener("click", onComponentsButtonClick)
    backtestingButton.addEventListener("click", onBacktestingButtonClick)

    # notice updates in backtestingRegion Selection
    charting.setOnRangeSelectListener(updateBacktestingRegion)
    backtesting.setOnRangeChangeListener(updateBacktestingRegion)

    # seasonalitycyclesmodule is initialized before us (allmodules order)
    cycles.setOnChangeListener(onCycleChanged)
    cycles.setUnit(timeframeToUnit[chartTimeframe])
    updateCyclesRange()
    return

############################################################
#region Event Listeners
onStockSelected = (symbol) ->
    log "onStockSelected"
    resetSelection()
    selectedSymbol = symbol
    selectedSymbolDisplay.textContent = ""+selectedSymbol
    await reload()
    return

timeframeSelected = ->
    log "timeframeSelected"
    selectedRangeY = historyTimeframeSelect.value
    await reload()
    return

chartTimeframeChanged = ->
    log "chartTimeframeChanged"
    chartTimeframe = chartTimeframeSelect.value
    setCycleUnit(timeframeToUnit[chartTimeframe])
    await reload()
    return

onCycleChanged = (cycle) ->
    log "onCycleChanged"
    # skips the echo of setCycleUnit and edits without effect on the setting
    return if JSON.stringify(cycle) == JSON.stringify(selectedCycle)
    selectedCycle = cycle
    await reload()
    return

onCloseChart = ->
    log "onCloseChart"
    clearSelection()
    symbolSelect.resetSearch()
    chartData = null
    resetSelection()
    # backtesting.reset()
    return


onComponentsButtonClick = ->
    log "onComponentsButtonClick"
    setChartActive()  # Returns to analysing state
    return

onBacktestingButtonClick = ->
    log "onBacktestingButtonClick"
    if backtestingRegion? then setBacktestingActive()
    return


updateBacktestingRegion = (region) ->
    log "updateBacktestingRegion"
    olog region

    if !region? then throw new Error("@updateBacktestingRegion: No new region provided!")
    if !region.startIdx? or !region.endIdx? then throw new Error("@updateBacktestingRegion:: No valid indices provided!")

    backtestingRegion = region
    # charting.render()
    await runAndDisplayBacktesting()
    setBacktestingActive()
    return

#endregion

############################################################
#region Set UI States
setStateLoading = ->
    log "setStateLoading"
    seasonalityframe.classList.remove("no-data")
    seasonalityframe.classList.remove("chart-active")
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.remove("chart-inactive")
    seasonalityframe.classList.add("loading-data")
    symbolSelect.freeze()
    return

setChartActive = ->
    log "setChartActive"
    seasonalityframe.classList.remove("chart-inactive")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.remove("loading-data")
    seasonalityframe.classList.add("chart-active")
    seasonalityframe.classList.add("analysing")
    symbolSelect.unfreeze()
    return

setNoData = ->
    log "setNoData"
    seasonalityframe.classList.remove("chart-active")
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.remove("loading-data")
    seasonalityframe.classList.add("no-data")
    symbolSelect.unfreeze()
    return

setChartInactive = ->
    log "setChartInactive"
    seasonalityframe.classList.remove("no-data")
    seasonalityframe.classList.remove("chart-active")
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.remove("loading-data")
    seasonalityframe.classList.add("chart-inactive")
    symbolSelect.unfreeze()
    return

setBacktestingActive = ->
    log "setBacktestingActive"
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.remove("loading-data")
    seasonalityframe.classList.add("chart-active")
    seasonalityframe.classList.add("backtesting")
    symbolSelect.unfreeze()
    return
#endregion

############################################################
runAndDisplayBacktesting = ->
    log "runAndDisplayBacktesting"
    { startIdx, endIdx } = backtestingRegion
    entryDate = charting.indexToDate(startIdx)
    exitDate = charting.indexToDate(endIdx)
    years = parseInt(selectedRangeY)
    { isIncluded, ages, refDate } = chartData
    # single mode: the selection lies in chunk ages[0], run k k periods before it
    isRunIncluded = if isIncluded? then (k) -> isIncluded(ages[0] + k)
    await backtesting.run(selectedSymbol, entryDate, exitDate, years, chartTimeframe, refDate, isRunIncluded)
    return

############################################################
# always back to "Kein Zyklus" (setUnit alone keeps the cycle if the unit is unchanged)
# the caller reloads anyway
setCycleUnit = (unit) ->
    selectedCycle = null
    cycles.setUnit(unit)
    cycles.deactivate()
    return

############################################################
# after a change of symbol, history range, chart timeframe or cycle
reload = ->
    setStateLoading()
    try
        if !selectedSymbol then return clearSelection()
        if !await loadDataAndRenderChart() then return setNoData()

        if backtestingRegion?
            await runAndDisplayBacktesting()
            setBacktestingActive()
        else setChartActive()
    catch err
        console.error(err)
        symbolSelect.setError("Fehler in der Datenanfrage für #{selectedSymbol}!")
        clearSelection()
    return

############################################################
# returns false if the cycle leaves no data in the history range
loadDataAndRenderChart = ->
    log "loadDataAndRenderChart"
    # cap before loading, so a timeframe switch never loads the deeper range
    maxYears = timeframeMaxYears[chartTimeframe]
    if maxYears? and parseInt(selectedRangeY) > maxYears then selectedRangeY = String(maxYears)
    data = await retrieveRelevantData()
    # the selection is index-based - only valid on the axis it was made on
    if layoutKey(data) != layoutKey(chartData) then resetSelection()
    chartData = data
    updateYearsOptions() ## only here this may change
    updateCyclesRange()
    if !chartData.composite? then return false

    charting.prepareData(chartData)
    charting.render(backtestingRegion)
    return true


layoutKey = (data) -> data? and JSON.stringify([data.timeframe, data.ages])

resetSelection = ->
    backtestingRegion = null
    charting.reset()
    return

############################################################
clearSelection = ->
    selectedSymbolDisplay.textContent = ""
    selectedSymbol = ""
    setChartInactive()
    resetTimeframeSelect()
    return

############################################################
resetTimeframeSelect = ->
    log "resetTimeframeSelect"
    selectedRangeY = "5"
    historyTimeframeSelect.innerHTML = ""
    optionEl = document.createElement("option")
    optionEl.value = "5"
    optionEl.textContent = "5 Jahre"
    optionEl.selected = true
    historyTimeframeSelect.appendChild(optionEl)
    updateCyclesRange()
    return

############################################################
# history range = the selected years before the current one + the current year
updateCyclesRange = ->
    today = todayYmd()
    fromYear = parseInt(today.slice(0, 4)) - parseInt(selectedRangeY)
    cycles.setRange("#{fromYear}-01-01", today)
    return

############################################################
# caps backtests at ~310 runs: weekly 5 years (+ current year), monthly 20 years
timeframeMaxYears = { weekly: 5, monthly: 20 }

updateYearsOptions = ->
    log "updateYearsOptions"
    maxYears = timeframeMaxYears[chartTimeframe] ? Infinity
    allOptions = (opt for opt in [ 5, 10, 15, 20, 25, 30 ] when opt <= maxYears)

    if !selectedSymbol? then return resetTimeframeSelect()
    else ## Determine available options based on maxHistory
        maxHistory = mData.getHistoricDepth(selectedSymbol)
        ## Find first option exceeding available history (+2 buffer)
        cutoffIdx = allOptions.length
        for opt, i in allOptions when maxHistory + 2 < opt
            cutoffIdx = i
            break
        actualOptions = allOptions.slice(0, cutoffIdx)
        ## Ensure at least the first option is available
        if actualOptions.length == 0 then actualOptions = [allOptions[0]]

    ## Adjust currentYears if it exceeds available options
    currentYears = parseInt(selectedRangeY)
    maxAvailable = actualOptions[actualOptions.length - 1]
    if currentYears > maxAvailable
        currentYears = maxAvailable
        selectedRangeY = String(currentYears)

    ## Render options to dropdown
    historyTimeframeSelect.innerHTML = ""
    for opt in actualOptions
        optionEl = document.createElement("option")
        optionEl.value = opt
        optionEl.textContent = "#{opt} Jahre"
        if opt == currentYears then optionEl.selected = true
        historyTimeframeSelect.appendChild(optionEl)
    return
    
############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    years = parseInt(selectedRangeY)
    timeframe = chartTimeframe
    # chunk 0 is the period of the newest data date (refDate), not of today
    { chunks, refDate } = await mData.getCloseChunks(selectedSymbol, timeframe, years)

    # null = continuous: no cycle or a full cycle
    isIncluded = null
    if selectedCycle? and !isFullCycle(selectedCycle) then isIncluded = includedChunkFn(selectedCycle, ymdOf(refDate))
    ages = displayAges(selectedCycle, isIncluded)

    # composite null: no data for the selected cycle in the history range
    composite = mData.calculateSeasonalityComposite(chunks, 0, isIncluded)
    showLatest = ages? and showsLatest(selectedCycle, isIncluded, ages)
    return { composite, chunks, refDate, timeframe, ages, isIncluded, showLatest }


############################################################
getBacktestingRegionFromDates = (startDate, endDate) ->
    log "getBacktestingRegionFromDates"
    if typeof startDate == "string" then startDate = new Date(startDate+"T12:00Z")
    if typeof endDate == "string" then endDate = new Date(endDate+"T12:00Z")

    if startDate.getTime() > endDate.getTime() then throw new Error("Invalid startDate - endDate configuration!")

    startIdx = charting.dateToIndex(startDate)
    endIdx = charting.dateToIndex(endDate)
    if startIdx < 0 then throw new Error("startDate was not within the possible backtesting region!")
    if endIdx < 0 then throw new Error("endDate was not within the possible backtesting region!")
    return { startIdx, endIdx }


############################################################
export setSeasonalityBacktestingState = (symbol, years, startDate, endDate) ->
    log "setSeasonalityBacktestingState"
    try
        symbolSelect.resetSearch()
        # screener ranges are yearly
        chartTimeframeSelect.value = "yearly"
        chartTimeframe = "yearly"
        setCycleUnit("years")
        await onStockSelected(symbol)
        await letMainThreadRun()

        historyTimeframeSelect.value = ""+years
        backtestingRegion = null
        await timeframeSelected()
        await letMainThreadRun()
        
        region = getBacktestingRegionFromDates(startDate, endDate)
        console.log(JSON.stringify(backtestingRegion, null, 4))
        charting.setSelectedRegion(region, true)

    catch err
        console.error(err)
        symbolSelect.setError("Fehler in der Datenanfrage für #{selectedSymbol}!")
        clearSelection()
    return
