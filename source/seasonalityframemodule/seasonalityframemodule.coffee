############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"
import { Combobox } from "./comboboxfun.js"
import { drawChart, resetChart } from "./chartfun.js"

############################################################
## Re-export for symboloptions callback

############################################################
#region State
currentSelectedStock = null
currentSelectedTimeframe = null
currentSelectedMethod = null

xAxisData = null
seasonalityData = null
latestData = null

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
    methodSelect.addEventListener("change", methodSelected)

    currentSelectedTimeframe = timeframeSelect.value
    currentSelectedMethod = methodSelect.value
    return

############################################################
onStockSelected = (symbol) ->
    log "onStockSelected"
    currentSelectedStock = symbol
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return

timeframeSelected = ->
    log "timeframeSelected"
    currentSelectedTimeframe = timeframeSelect.value
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return

methodSelected = ->
    log "methodSelected"
    currentSelectedMethod = methodSelect.value
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return

############################################################
resetAndRender = ->
    log "resetAndRender"
    resetSeasonalityState()
    if currentSelectedStock then retrieveRelevantData()
    drawChart(seasonalityChart, xAxisData, seasonalityData, latestData)
    return

############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)
    method = parseInt(currentSelectedMethod)

    ## TODO implement actual dataflow :-)

    # seasonalityData = mData.getSeasonalityComposite(symbol, years, method)
    # latestData = mData.getThisAndLastYearData(symbol)

    # today = new Date()
    # currentYear = today.getFullYear()
    # lastYear = currentYear - 1
    # currentYearIsLeap = utl.isLeapYear(currentYear)
    # lastYearIsLeap = utl.isLeapYear(lastYear)

    # if currentYearIsLeap then return orderDataAsCurrentYearIsLeap()
    # if lastYearIsLeap then return orderDataAsLastYearIsLeap()
    # orderDataWithoutFeb29()
    return

############################################################
orderDataWithoutFeb29 = ->
    log "orderDataWithoutFeb29"
    ## reorder seasonality composite
    compositeWithoutFeb29 = []
    for dp,i in seasonalityData when i != utl.FEB29
        compositeWithoutFeb29.push(dp)

    ## We don't have a factor from the last Element to the first of next year
    ##   So we take it as 1:1
    factors = utl.toFactorsArray(compositeWithoutFeb29)
    frontData = utl.dataArrayFromFactors(factors, compositeWithoutFeb29[0], false)
    log "Array Lengths:"
    log frontData.length
    log compositeWithoutFeb29.length

    seasonalityData = [...frontData, ...compositeWithoutFeb29]
    log seasonalityData.length

    ##Time Axis... TODO

    return

orderDataAsLastYearIsLeap = ->
    log "orderDataAsLastYearIsLeap"
    ## reorder seasonality composite
    olog seasonalityData
    compositeWithoutFeb29 = []
    for dp,i in seasonalityData when (i != utl.FEB29)
        compositeWithoutFeb29.push(dp)

    ## We don't have a factor from the last Element to the first of next year
    ##   So we take it as 1:1
    factors = utl.toFactorsArray(seasonalityData)
    frontData = utl.dataArrayFromFactors(factors, seasonalityData[0], false)

    seasonalityData = [...frontData, ...compositeWithoutFeb29]

    ## reorder latestData
    thisYearsData = latestData[0]
    lastYearsData = latestData[1]
    factors = utl.toFactorsArray(lastYearsData)
    lastYearsData = utl.dataArrayFromFactors(factors, thisYearsData[0], false)

    missingData = new Array(365 - thisYearsData.length)
    missingData.fill(null)

    latestData = [...lastYearsData, ...thisYearsData, ...missingData]

    ## Create Time Axis
    jan1Latest = utl.getJan1Date()
    axisTime = jan1Latest.getTime() / 1000
    currentYearTimeAxis = []
    for i in [0...365]
        currentYearTimeAxis[i] = axisTime
        axisTime += 86_400 # = 60 * 60 * 24

    axisTime = jan1Latest.getTime() / 1000 - 86_400
    lastYearTimeAxis = new Array(366) ## is leap year
    i = 366
    while i--
        lastYearTimeAxis[i] = axisTime
        axisTime -= 86_400

    xAxisData = [...lastYearTimeAxis, ...currentYearTimeAxis]
    return

############################################################
resetSeasonalityState = ->
    log "resetSeasonalityState"
    resetChart(seasonalityChart)

    xAxisData = null
    seasonalityData = null
    latestData = null

    pickedStartIdx = null
    pickedEndIdx = null
    return
