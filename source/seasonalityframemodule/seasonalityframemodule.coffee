############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"
import { Combobox } from "./comboboxfun.js"
import { drawChart, resetChart, toggleSeriesVisibility, onRangeSelected, resetTimeAxis } from "./chartfun.js"
import { runBacktesting } from "./backtesting.js"

############################################################
## Re-export for symboloptions callback

############################################################
#region DOM cache for the cases where the implicit-dom-connect fails
aggregationYearsIndicator = document.getElementById("aggregation-years-indicator")
backtestingDirection = document.getElementById("backtesting-direction")
backtestingTimeframe = document.getElementById("backtesting-timeframe")
winRateNumber = document.getElementById("win-rate-number")
lossCircle = document.getElementById("loss-circle")

maxRiseValue = document.querySelector('#max-rise .value')
maxDropValue = document.querySelector('#max-drop .value')
averageChangeValue = document.querySelector('#average-change .value')
medianChangeValue = document.querySelector('#median-change .value')
daysInTradeValue = document.querySelector('#days-in-trade .value')

backtestingDetailsTable = document.getElementById("backtesting-details-table")
backtestingWarning = document.querySelector('#backtesting-details-container .warning')

# Table sorting state
currentYearlyResults = null
currentIsShort = false
sortColumn = "year"  # "year", "profit", "maxRise", "maxDrop"
sortAscending = false  # default: newest year first
#endregion

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

# Series visibility configuration (persists until chart closed)
seriesVisibility = {
    latestData: true   # default visible
    adr: true          # default visible
    fourier: false     # default hidden (experimental)
}
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

    # Wire up chart selection callback
    onRangeSelected(onChartRangeSelected)

    # Wire up tab buttons
    componentsButton.addEventListener("click", onComponentsButtonClick)
    backtestingButton.addEventListener("click", onBacktestingButtonClick)

    # Wire up reset time axis button
    resetTimeAxisButton.addEventListener("click", resetTimeAxis)
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

onChartRangeSelected = (startIdx, endIdx) ->
    log "onChartRangeSelected"
    pickedStartIdx = startIdx # the local State
    pickedEndIdx = endIdx # the local State

    olog { pickedStartIdx, pickedEndIdx }
    { startIdx, endIdx } = normalizeSelectionIndices(pickedStartIdx, pickedEndIdx)
    olog {startIdx, endIdx}

    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)

    backtestingData = await mData.getHistoryHLC(symbol, years)
    # Run backtesting (stub for now)
    results = runBacktesting(backtestingData, startIdx, endIdx)

    # Update backtesting UI
    updateBacktestingUI(results)

    # Transition to backtesting state
    setBacktestingActive()
    return

onComponentsButtonClick = ->
    log "onComponentsButtonClick"
    setChartActive()  # Returns to analysing state
    return

onBacktestingButtonClick = ->
    log "onBacktestingButtonClick"
    # Only switch if we have a selection
    if pickedStartIdx? and pickedEndIdx?
        setBacktestingActive()
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
    seriesKey = el.getAttribute('series-key')

    # Persist visibility state
    if seriesKey and seriesVisibility.hasOwnProperty(seriesKey)
        seriesVisibility[seriesKey] = isVisible

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

updateSeriesIndices = ->
    # latestData is always drawn last; its index depends on whether Fourier is visible
    latestEl = document.querySelector('#chart-components-tab .legend-series[series-index]')
    latestIdx = if seriesVisibility.fourier then 3 else 2
    # Update the first legend-series element (latestData) with correct index
    document.querySelector('#chart-components-tab .legend-series:first-child')?.setAttribute('series-index', latestIdx)
    return

syncLegendVisibility = ->
    # Sync DOM legend classes with seriesVisibility state
    legendSeriesEls = document.querySelectorAll('#chart-components-tab .legend-series')
    legendSeriesEls.forEach (el) ->
        seriesKey = el.getAttribute('series-key')
        if seriesKey and seriesVisibility.hasOwnProperty(seriesKey)
            if seriesVisibility[seriesKey]
                el.classList.add('visible')
            else
                el.classList.remove('visible')
    return

applySeriesVisibility = ->
    # Apply stored visibility to chart series after redraw
    log "applySeriesVisibility"
    frVisible = seriesVisibility.fourier

    # Series indices: 1=ADR, 2=Fourier(if visible)/latestData, 3=latestData(if Fourier visible)
    adrIdx = 1
    latestIdx = if frVisible then 3 else 2

    toggleSeriesVisibility(adrIdx, seriesVisibility.adr)
    toggleSeriesVisibility(latestIdx, seriesVisibility.latestData)
    return

redrawChart = ->
    log "redrawChart"
    return unless adrAggregation?
    resetChart(seasonalityChart)

    # Draw with Fourier if visibility state says so AND data is available
    if seriesVisibility.fourier and frAggregation?
        drawChart(seasonalityChart, xAxisData, adrAggregation, frAggregation, latestData)
    else
        drawChart(seasonalityChart, xAxisData, adrAggregation, null, latestData)

    # Restore series visibility after chart is drawn
    updateSeriesIndices()
    applySeriesVisibility()
    return

updateYearsIndicator = ->
    aggregationYearsIndicator.textContent = currentSelectedTimeframe
    return
#endregion

############################################################
#region Chart State Classes
setChartActive = ->
    seasonalityframe.classList.remove("chart-inactive")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.add("chart-active")
    seasonalityframe.classList.add("analysing")
    return

setChartInactive = ->
    seasonalityframe.classList.remove("chart-active")
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.remove("backtesting")
    seasonalityframe.classList.add("chart-inactive")
    return

setBacktestingActive = ->
    seasonalityframe.classList.remove("analysing")
    seasonalityframe.classList.add("backtesting")
    return
#endregion

############################################################
#region Backtesting UI Updates
updateBacktestingUI = (results) ->
    log "updateBacktestingUI"
    # olog results

    # Trade description
    backtestingDirection.textContent = results.directionString
    backtestingTimeframe.textContent = results.timeframeString

    # Win rate
    winRateNumber.textContent = "#{results.winRate.toFixed(1)}%"
    lossRate = 100 - results.winRate
    strokeDashArray = "#{lossRate * 6.294 / 100} #{6.294}"
    lossCircle.setAttribute("stroke-dasharray", strokeDashArray)

    # Summary stats
    maxRiseValue.textContent = "#{results.maxRise.toFixed(1)}%"
    maxDropValue.textContent = "#{results.maxDrop.toFixed(1)}%"
    averageChangeValue.textContent = "#{results.averageProfit.toFixed(1)}%"
    medianChangeValue.textContent = "#{results.medianProfit.toFixed(1)}%"
    daysInTradeValue.textContent = "#{results.daysInTrade} Tage"

    # Populate details table (reset sort state for new data)
    currentYearlyResults = results.yearlyResults
    currentIsShort = results.directionString == "Short"
    sortColumn = "year"
    sortAscending = false
    renderBacktestingTable()

    # Show warning if any year had anomalies
    if results.warn
        backtestingWarning.style.display = "block"
    else
        backtestingWarning.style.display = "none"
    return

renderBacktestingTable = ->
    log "renderBacktestingTable"
    return unless currentYearlyResults?

    backtestingDetailsTable.innerHTML = ""

    # Sort data
    sortedResults = sortYearlyResults(currentYearlyResults)

    # Create header row with sort indicators
    thead = document.createElement("thead")
    headerRow = document.createElement("tr")
    headers = [
        { label: "Jahr", key: "year" }
        { label: "Profit", key: "profit" }
        { label: "Profit Abs", key: "profitA" }
        { label: "Max Anstieg", key: "maxRise" }
        { label: "Max Anstieg Abs", key: "maxRiseA" }
        { label: "Max Rückgang", key: "maxDrop" }
        { label: "Max Rückgang Abs", key: "maxDropA" }
    ]
    for { label, key } in headers
        th = document.createElement("th")
        th.dataset.sortKey = key
        th.classList.add("sortable")
        if key == sortColumn
            th.classList.add("sorted")
            th.classList.add(if sortAscending then "asc" else "desc")
        th.textContent = label
        th.addEventListener("click", onSortColumnClick)
        headerRow.appendChild(th)
    thead.appendChild(headerRow)
    backtestingDetailsTable.appendChild(thead)

    # Create body with sorted results
    tbody = document.createElement("tbody")
    for result in sortedResults
        row = document.createElement("tr")
        if result.warn then row.classList.add("warn")

        # Year column
        yearCell = document.createElement("td")
        yearCell.textContent = result.year
        row.appendChild(yearCell)

        # Profit column (flip sign for Short)
        profitCell = document.createElement("td")
        profit = if currentIsShort then -result.profitP else result.profitP
        profitCell.textContent = formatPercent(profit)
        profitCell.classList.add(if profit >= 0 then "positive" else "negative")
        row.appendChild(profitCell)

        # Profit Abs column
        profitAbsCell = document.createElement("td")
        profitAbs = result.startA * profit / 100
        profitAbsCell.textContent = formatAbsolute(profitAbs)
        profitAbsCell.classList.add(if profitAbs >= 0 then "positive" else "negative")
        row.appendChild(profitAbsCell)

        # Max Rise column
        maxRiseCell = document.createElement("td")
        maxRiseCell.textContent = formatPercent(result.maxRiseP)
        row.appendChild(maxRiseCell)

        # Max Rise Abs column
        maxRiseAbsCell = document.createElement("td")
        maxRiseAbs = result.startA * result.maxRiseP / 100
        maxRiseAbsCell.textContent = formatAbsolute(maxRiseAbs)
        row.appendChild(maxRiseAbsCell)

        # Max Drop column
        maxDropCell = document.createElement("td")
        maxDropCell.textContent = formatPercent(result.maxDropP)
        row.appendChild(maxDropCell)

        # Max Drop Abs column
        maxDropAbsCell = document.createElement("td")
        maxDropAbs = result.startA * result.maxDropP / 100
        maxDropAbsCell.textContent = formatAbsolute(maxDropAbs)
        row.appendChild(maxDropAbsCell)

        tbody.appendChild(row)

    backtestingDetailsTable.appendChild(tbody)
    return

onSortColumnClick = (evnt) ->
    key = evnt.target.getAttribute("data-sort-key")
    log "onSortColumnClick: #{key}"
    if sortColumn == key
        sortAscending = !sortAscending  # Toggle direction
    else
        sortColumn = key
        sortAscending = false  # New column: start descending
    renderBacktestingTable()
    return

sortYearlyResults = (results) ->
    sorted = [...results]  # Copy to avoid mutating original

    compareFn = switch sortColumn
        when "year"
            (a, b) -> a.year - b.year
        when "profit"
            if currentIsShort
                (a, b) -> (-a.profitP) - (-b.profitP)  # Flipped for Short
            else
                (a, b) -> a.profitP - b.profitP
        when "profitA"
            if currentIsShort
                (a, b) -> (-a.startA * a.profitP) - (-b.startA * b.profitP)
            else
                (a, b) -> (a.startA * a.profitP) - (b.startA * b.profitP)
        when "maxRise"
            (a, b) -> a.maxRiseP - b.maxRiseP
        when "maxRiseA"
            (a, b) -> (a.startA * a.maxRiseP) - (b.startA * b.maxRiseP)
        when "maxDrop"
            (a, b) -> (-a.maxDropP) - (-b.maxDropP) # Flipped for max Drops
        when "maxDropA"
            (a, b) -> (-a.startA * a.maxDropP) - (-b.startA * b.maxDropP)
        else
            (a, b) -> 0

    sorted.sort(compareFn)
    unless sortAscending then sorted.reverse()
    return sorted

formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatAbsolute = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(2)}"

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
    resetChartData()
    try
        ## TODO start a preloader to signal data wating :-)
        if currentSelectedStock
            selectedSymbol.textContent = ""+currentSelectedStock
            await retrieveRelevantData()
            # Recalculate Fourier data if it was visible (data was reset but visibility preserved)
            if seriesVisibility.fourier
                await ensureFourierData()
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
# Resets chart data but preserves series visibility configuration
resetChartData = ->
    log "resetChartData"
    resetChart(seasonalityChart)

    xAxisData = null
    adrAggregation = null
    frAggregation = null  # data needs recalc, but visibility state preserved
    latestData = null
    maxHistory = null

    pickedStartIdx = null
    pickedEndIdx = null
    return

############################################################
# Full reset including visibility - called only when chart is closed
resetSeasonalityState = ->
    log "resetSeasonalityState"
    resetChartData()

    # Reset visibility to defaults
    seriesVisibility = {
        latestData: true
        adr: true
        fourier: false
    }
    syncLegendVisibility()
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

############################################################
#region Selection Index Normalization
# Converts raw chart indices (in 2-year display) to normalized indices
# relative to a standard 365-day year.
#
# Chart layout: [...lastYearData, ...currentYearData]
#
# Three selection cases:
# 1. Both in last year: startIdx=0-364, endIdx=0-364 (both positive)
# 2. Overlapping: startIdx=negative, endIdx=0-364 (spans year boundary)
# 3. Both in current year: startIdx=0-364, endIdx=0-364 (both positive)
#
# Feb 29 handling: In leap years, Feb 29 (index 59) maps to Feb 28,
# and subsequent days shift down by 1.
############################################################

normalizeToStandardYear = (dayOfYear, isLeapYear) ->
    return dayOfYear unless isLeapYear
    return dayOfYear if dayOfYear < utl.FEB29
    return utl.FEB28 if dayOfYear == utl.FEB29
    return dayOfYear - 1

normalizeSelectionIndices = (startIdx, endIdx) ->
    cfg = getLeapYearConfig()
    lastYearDays = cfg.lastYearDays

    startInLastYear = startIdx < lastYearDays
    endInLastYear = endIdx < lastYearDays

    if startInLastYear
        startIdx = normalizeToStandardYear(startIdx, cfg.lastYearIsLeap)
    else
        startIdx = normalizeToStandardYear(startIdx - lastYearDays, cfg.currentYearIsLeap)

    if endInLastYear
        endIdx = normalizeToStandardYear(endIdx, cfg.lastYearIsLeap)
    else
        endIdx = normalizeToStandardYear(endIdx - lastYearDays, cfg.currentYearIsLeap)

    # Only make startIdx negative when selection overlaps years
    if startInLastYear and !endInLastYear
        startIdx = startIdx - 365

    return { startIdx, endIdx }
#endregion
