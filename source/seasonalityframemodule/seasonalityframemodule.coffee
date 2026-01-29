############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"
import { Combobox } from "./comboboxfun.js"
import { drawChart, resetChart, initLegend } from "./chartfun.js"

############################################################
## Re-export for symboloptions callback

############################################################
#region State
currentSelectedStock = null
currentSelectedTimeframe = null

xAxisData = null
seasonalityData = null
latestData = null
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

    # Initialize legend
    legendEl = document.querySelector('#chart-container .chart-legend')
    initLegend(legendEl) if legendEl?
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

#endregion

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
        ## TODO reset preloader -> start rendering ;-)
        # seasonalityChart.
        drawChart(seasonalityChart, xAxisData, seasonalityData, latestData)
    catch err then console.error(err) ## TODO: Maybe signal Error in chart and reset all state?
    # finally: ## TODO reset preloader on if it was not before
    return

############################################################
resetSeasonalityState = ->
    log "resetSeasonalityState"
    resetChart(seasonalityChart)

    xAxisData = null
    seasonalityData = null
    latestData = null
    maxHistory = null

    pickedStartIdx = null
    pickedEndIdx = null
    return


############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)
    method = 0

    latestData = await mData.getLatestData(symbol)
    seasonalityData = await mData.getSeasonalityComposite(symbol, years, method)
    maxHistory = mData.getHistoricDepth(symbol)

    if !seasonalityData? then throw new Error("No seasonalityData returned!")
    log "We have seasonalityData! the length is: "+seasonalityData.length

    prepareChartData()
    return

############################################################
prepareChartData = ->
    log "prepareChartData"

    ## Determine leap year configuration
    today = new Date()
    currentYear = today.getFullYear()
    lastYear = currentYear - 1
    currentYearIsLeap = utl.isLeapYear(currentYear)
    lastYearIsLeap = utl.isLeapYear(lastYear)

    lastYearDays = if lastYearIsLeap then 366 else 365
    currentYearDays = if currentYearIsLeap then 366 else 365

    ## Prepare seasonality composite for 2-year display
    factors = utl.toFactorsArray(seasonalityData)
    frontData = utl.fromFactorsBackward(factors) 
    backData = utl.fromFactorsForward(factors)
    
    if !lastYearIsLeap then frontData = removeFeb29(frontData)
    if !currentYearIsLeap then backData = removeFeb29(backData)
         
    seasonalityData = [...frontData, ...backData]

    ## Prepare latestData for 2-year display
    thisYearsData = latestData[0]
    lastYearsData = latestData[1]

    factors = utl.toFactorsArray(lastYearsData)
    lastYearsData = utl.fromFactorsBackward(factors)

    factors = utl.toFactorsArray(thisYearsData)
    thisYearsData = utl.fromFactorsForward(factors)
    
    missingDays = currentYearDays - thisYearsData.length
    missingData = new Array(missingDays).fill(null)

    latestData = [...lastYearsData, ...thisYearsData, ...missingData]

    ## Create time axis
    jan1 = utl.getJan1Date()
    axisTime = jan1.getTime() / 1000

    currentYearTimeAxis = []
    for i in [0...currentYearDays]
        currentYearTimeAxis[i] = axisTime
        axisTime += 86_400

    axisTime = jan1.getTime() / 1000 - 86_400
    lastYearTimeAxis = new Array(lastYearDays)
    i = lastYearDays
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
