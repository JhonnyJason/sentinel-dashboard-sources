############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"
import { Combobox } from "./comboboxfun.js"
import { drawChart, resetChart, toggleSeriesVisibility } from "./chartfun.js"

############################################################
## Re-export for symboloptions callback

############################################################
aggregationYearsIndicator = document.getElementById("aggregation-years-indicator")

############################################################
#region State
currentSelectedStock = null
currentSelectedTimeframe = null

xAxisData = null
adrAggregation = null  # Average Daily Return - prepared for 2-year display
frAggregation = null   # Fourier Regression - prepared for 2-year display (on-demand)
latestData = null      # prepared for 2-year display
maxHistory = null

pickedStartIdx = null
pickedEndIdx = null
#endregion

############################################################
export initialize = (c) ->
    log "initialize"
    inputEl = symbolInput # symbolInput.
    dropdownEl = symbolDropdown # symbolDropdown.
    optionsLimit = 70

    symbolCombobox = new Combobox({ inputEl, dropdownEl, optionsLimit })
    symbolCombobox.onSelect(onStockSelected)

    timeframeSelect.addEventListener("change", timeframeSelected)
    currentSelectedTimeframe = timeframeSelect.value

    closeChartButton.addEventListener("click", onCloseChart)

    # Wire up legend series click handlers
    wireLegendSeriesHandlers()
    return

############################################################
#region event Listeners
onStockSelected = (symbol) ->
    log "onStockSelected"
    currentSelectedStock = symbol
    olog { currentSelectedStock, currentSelectedTimeframe }
    resetAndRender()
    return

timeframeSelected = ->
    log "timeframeSelected"
    currentSelectedTimeframe = timeframeSelect.value
    olog { currentSelectedStock, currentSelectedTimeframe }
    resetAndRender()
    return

onCloseChart = ->
    log "onCloseChart"
    resetSeasonalityState()
    currentSelectedStock = null
    selectedSymbol.textContent = ""
    symbolInput.value = ""
    resetTimeframeSelect()
    setChartInactive()
    return

#endregion

############################################################
#region Legend Series Wiring
wireLegendSeriesHandlers = ->
    log "wireLegendSeriesHandlers"
    legendSeriesEls = document.querySelectorAll('#chart-components-tab .legend-series')
    legendSeriesEls.forEach (el) ->
        el.addEventListener 'click', -> onLegendSeriesClick(el)
    return

onLegendSeriesClick = (el) ->
    log "onLegendSeriesClick"
    isExperimental = el.classList.contains('experimental')
    isVisible = el.classList.toggle('visible')

    if isExperimental and isVisible
        # Fourier toggled visible - calculate on-demand and redraw
        await ensureFourierData()
        redrawChart()
        updateSeriesIndices()
    else if isExperimental and !isVisible
        # Fourier toggled hidden - redraw without it
        redrawChart()
        updateSeriesIndices()
    else
        # Regular series toggle - just show/hide via uPlot
        seriesIdx = parseInt(el.getAttribute('series-index'))
        toggleSeriesVisibility(seriesIdx, isVisible)
    return

ensureFourierData = ->
    return if frAggregation?  # Already calculated
    log "ensureFourierData - calculating..."
    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)
    rawFr = await mData.getSeasonalityComposite(symbol, years, 1)
    frAggregation = prepareSeasonalityFor2Year(rawFr)
    log "Fourier data ready, length: " + frAggregation.length
    return

isFourierVisible = ->
    frEl = document.querySelector('#chart-components-tab .legend-series.experimental')
    return frEl?.classList.contains('visible') ? false

updateSeriesIndices = ->
    # latestData is always drawn last; its index depends on whether Fourier is visible
    latestEl = document.querySelector('#chart-components-tab .legend-series[series-index]')
    frVisible = isFourierVisible()
    latestIdx = if frVisible then 3 else 2
    # Update the first legend-series element (latestData) with correct index
    document.querySelector('#chart-components-tab .legend-series:first-child')?.setAttribute('series-index', latestIdx)
    return

redrawChart = ->
    log "redrawChart"
    return unless adrAggregation?
    resetChart(seasonalityChart)
    if isFourierVisible() and frAggregation?
        drawChart(seasonalityChart, xAxisData, adrAggregation, frAggregation, latestData)
    else
        drawChart(seasonalityChart, xAxisData, adrAggregation, null, latestData)
    return

updateYearsIndicator = ->
    aggregationYearsIndicator.textContent = currentSelectedTimeframe
    return
#endregion

############################################################
#region Chart State Classes
setChartActive = ->
    seasonalityframe.classList.remove("chart-inactive")
    seasonalityframe.classList.add("chart-active")
    seasonalityframe.classList.add("analysing")
    return

setChartInactive = ->
    seasonalityframe.classList.remove("chart-active")
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.add("chart-inactive")
    return
#endregion

############################################################
resetTimeframeSelect = ->
    log "resetTimeframeSelect"
    currentSelectedTimeframe = "5"
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

    ## Determine available options based on maxHistory
    if !maxHistory?
        actualOptions = allOptions
    else
        ## Find first option exceeding available history (+2 buffer)
        cutoffIdx = allOptions.length
        for opt, i in allOptions when maxHistory + 2 < opt
            cutoffIdx = i
            break
        actualOptions = allOptions.slice(0, cutoffIdx)
        ## Ensure at least the first option is available
        if actualOptions.length == 0 then actualOptions = [allOptions[0]]

    ## Adjust currentYears if it exceeds available options
    currentYears = parseInt(currentSelectedTimeframe)
    maxAvailable = actualOptions[actualOptions.length - 1]
    if currentYears > maxAvailable
        currentYears = maxAvailable
        currentSelectedTimeframe = String(currentYears)

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
resetAndRender = ->
    log "resetAndRender"
    resetSeasonalityState()
    try
        ## TODO start a preloader to signal data wating :-)
        if currentSelectedStock
            selectedSymbol.textContent = ""+currentSelectedStock
            await retrieveRelevantData()
        else
            selectedSymbol.textContent = ""

        updateYearsOptions()
        updateYearsIndicator()
        ## TODO reset preloader -> start rendering ;-)
        # seasonalityChart. <- we need this to trigger implicit-dom-connect sometimes
        redrawChart()
        setChartActive() if currentSelectedStock
    catch err then console.error(err) ## TODO: Maybe signal Error in chart and reset all state?
    # finally: ## TODO reset preloader on if it was not before
    return

############################################################
resetSeasonalityState = ->
    log "resetSeasonalityState"
    resetChart(seasonalityChart)

    xAxisData = null
    adrAggregation = null
    frAggregation = null
    latestData = null
    maxHistory = null

    pickedStartIdx = null
    pickedEndIdx = null

    # Reset Fourier visibility in UI (it will need recalculation for new data)
    frEl = document.querySelector('#chart-components-tab .legend-series.experimental')
    frEl?.classList.remove('visible')
    updateSeriesIndices()
    return


############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)

    rawLatest = await mData.getLatestData(symbol)
    rawAdr = await mData.getSeasonalityComposite(symbol, years, 0)
    maxHistory = mData.getHistoricDepth(symbol)

    if !rawAdr? then throw new Error("No ADR data returned!")
    log "ADR data length: " + rawAdr.length

    prepareChartData(rawAdr, rawLatest)
    return

############################################################
#region Leap Year Config (computed once per year)
leapYearConfig = null

getLeapYearConfig = ->
    return leapYearConfig if leapYearConfig?
    today = new Date()
    currentYear = today.getFullYear()
    lastYear = currentYear - 1
    currentYearIsLeap = utl.isLeapYear(currentYear)
    lastYearIsLeap = utl.isLeapYear(lastYear)
    leapYearConfig = {
        currentYearIsLeap
        lastYearIsLeap
        lastYearDays: if lastYearIsLeap then 366 else 365
        currentYearDays: if currentYearIsLeap then 366 else 365
    }
    return leapYearConfig
#endregion

############################################################
# Prepare raw 366-day seasonality data for 2-year chart display
prepareSeasonalityFor2Year = (rawData) ->
    cfg = getLeapYearConfig()
    factors = utl.toFactorsArray(rawData)
    frontData = utl.fromFactorsBackward(factors)
    backData = utl.fromFactorsForward(factors)

    if !cfg.lastYearIsLeap then frontData = removeFeb29(frontData)
    if !cfg.currentYearIsLeap then backData = removeFeb29(backData)

    return [...frontData, ...backData]

############################################################
prepareChartData = (rawAdr, rawLatest) ->
    log "prepareChartData"
    cfg = getLeapYearConfig()

    ## Prepare ADR aggregation for 2-year display
    adrAggregation = prepareSeasonalityFor2Year(rawAdr)

    ## Prepare latestData for 2-year display
    thisYearsData = rawLatest[0]
    lastYearsData = rawLatest[1]

    factors = utl.toFactorsArray(lastYearsData)
    lastYearsData = utl.fromFactorsBackward(factors)

    factors = utl.toFactorsArray(thisYearsData)
    thisYearsData = utl.fromFactorsForward(factors)

    missingDays = cfg.currentYearDays - thisYearsData.length
    missingData = new Array(missingDays).fill(null)

    latestData = [...lastYearsData, ...thisYearsData, ...missingData]

    ## Create time axis
    jan1 = utl.getJan1Date()
    axisTime = jan1.getTime() / 1000

    currentYearTimeAxis = []
    for i in [0...cfg.currentYearDays]
        currentYearTimeAxis[i] = axisTime
        axisTime += 86_400

    axisTime = jan1.getTime() / 1000 - 86_400
    lastYearTimeAxis = new Array(cfg.lastYearDays)
    i = cfg.lastYearDays
    while i--
        lastYearTimeAxis[i] = axisTime
        axisTime -= 86_400

    xAxisData = [...lastYearTimeAxis, ...currentYearTimeAxis]
    return

############################################################
removeFeb29 = (arr) -> 
    result = []
    for val,i in arr when i != utl.FEB29
        result.push(val)
    return result
