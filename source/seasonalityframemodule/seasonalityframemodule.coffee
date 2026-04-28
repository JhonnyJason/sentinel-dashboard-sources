############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"

############################################################
import { SymbolSelect } from "./symbolselectmodule.js"

############################################################
import * as backtesting from "./seasonalitybacktestingmodule.js"
import * as charting from "./seasonalitychartmodule.js"

############################################################
symbolSelect = null

############################################################
#region State
selectedSymbol = null
selectedRangeY = null

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
    
    timeframeSelect.addEventListener("change", timeframeSelected)
    selectedRangeY = timeframeSelect.value

    closeChartButton.addEventListener("click", onCloseChart)

    # Wire up tab buttons
    componentsButton.addEventListener("click", onComponentsButtonClick)
    backtestingButton.addEventListener("click", onBacktestingButtonClick)

    # notice updates in backtestingRegion Selection
    charting.setOnRangeSelectListener(updateBacktestingRegion)
    backtesting.setOnRangeChangeListener(updateBacktestingRegion)
    return

############################################################
#region Event Listeners
onStockSelected = (symbol) ->
    log "onStockSelected"
    backtestingRegion = null
    charting.reset()
    selectedSymbol = symbol
    selectedSymbolDisplay.textContent = ""+selectedSymbol
    setStateLoading()
    try
        await loadDataAndRenderChart()
        setChartActive()
    catch err
        console.error(err)
        symbolSelect.setError("Fehler in der Datenanfrage für #{selectedSymbol}!")
        clearSelection()
    return

timeframeSelected = ->
    log "timeframeSelected"
    selectedRangeY = timeframeSelect.value
    # charting.reset()
    setStateLoading()
    try
        if !selectedSymbol? then throw new Error("No Symbol Selected!")
        await loadDataAndRenderChart()

        if backtestingRegion?
            await runAndDisplayBacktesting()
            setBacktestingActive()
        else setChartActive()
    catch err
        console.error(err)
        symbolSelect.setError("Fehler in der Datenanfrage für #{selectedSymbol}!")
        clearSelection()
    return


onCloseChart = ->
    log "onCloseChart"
    clearSelection()
    symbolSelect.resetSearch()
    chartData = null
    charting.reset()
    backtestingRegion = null
    backtesting.reset()
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

setChartInactive = ->
    log "setChartInactive"
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
    { startIdx, endIdx } = getNormalizedSelectionIndices()
    # olog {startIdx, endIdx}

    symbol = selectedSymbol
    years = parseInt(selectedRangeY)

    hlcData = await mData.getHistoryHLC(symbol, years)
    tradingDays = await mData.getHistoricTradingDays(symbol, years)
    metaData = mData.getCurrentMetaData(symbol)

    backtesting.run(hlcData, metaData, startIdx, endIdx, tradingDays)
    return

############################################################
loadDataAndRenderChart = ->
    log "loadDataAndRenderChart"
    chartData = await retrieveRelevantData()
    updateYearsOptions() ## only here this may change

    charting.prepareData(chartData)
    charting.render(backtestingRegion)
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
    timeframeSelect.innerHTML = ""
    optionEl = document.createElement("option")
    optionEl.value = "5"
    optionEl.textContent = "5 Jahre"
    optionEl.selected = true
    timeframeSelect.appendChild(optionEl)
    return

############################################################
updateYearsOptions = ->
    log "updateYearsOptions"
    allOptions = [ 5, 10, 15, 20, 25, 30 ]

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
    timeframeSelect.innerHTML = ""
    for opt in actualOptions
        optionEl = document.createElement("option")
        optionEl.value = opt
        optionEl.textContent = "#{opt} Jahre"
        if opt == currentYears then optionEl.selected = true
        timeframeSelect.appendChild(optionEl)
    return
    
############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    symbol = selectedSymbol
    years = parseInt(selectedRangeY)

    rawLatest = await mData.getLatestData(symbol)
    rawAdr = await mData.getSeasonalityComposite(symbol, years, 0)
    if !rawAdr? then throw new Error("No ADR data returned!")

    # log "ADR data length: " + rawAdr.length
    return { rawLatest, rawAdr, years }


############################################################
# Converts raw chart indices to nonLeapNorm indices (0-364)
# Chart layout: [...lastYearData, ...currentYearData]
#
# startIdx will be negative on year overlap
getNormalizedSelectionIndices = ->
    return unless backtestingRegion? # no selection, nothing to do
    cfg = utl.getLeapYearConfig()
    lastYearDays = cfg.lastYearDays
    { startIdx, endIdx } = backtestingRegion

    startInLastYear = startIdx < lastYearDays
    endInLastYear = endIdx < lastYearDays

    if startInLastYear
        startIdx = utl.realToNonLeapNormIdx(startIdx, cfg.lastYearIsLeap)
    else
        startIdx = utl.realToNonLeapNormIdx(startIdx - lastYearDays, cfg.currentYearIsLeap)

    if endInLastYear
        endIdx = utl.realToNonLeapNormIdx(endIdx, cfg.lastYearIsLeap)
    else
        endIdx = utl.realToNonLeapNormIdx(endIdx - lastYearDays, cfg.currentYearIsLeap)

    # Only make startIdx negative when selection overlaps years
    if startInLastYear and !endInLastYear
        startIdx = startIdx - 365

    return { startIdx, endIdx }
