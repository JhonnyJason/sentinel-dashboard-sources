############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitychartmodule")
#endregion

############################################################
import * as utl from "./utilsmodule.js"

############################################################
import { SeasonalityChart } from "./chartfun.js"

############################################################
chartContainer = document.getElementById("chart-container")
aggregationYearsIndicator = document.getElementById("aggregation-years-indicator")

############################################################
xAxisData = null
adrAggregation = null  # Average Daily Return - prepared for 2-year display
latestData = null      # prepared for 2-year display

############################################################
selection = null
xAxisDrag = null

############################################################
# Series visibility configuration (persists until chart closed)
seriesVisibility = {
    latestData: true   # default visible
    adr: true          # default visible

    # adr5: false 
    # adr10: false
    # adr15: false
    # adr20: false
    # adr25: false
    # adr30: false
}

############################################################
onRangeSelect = null

############################################################
seasonalityChart = null

############################################################
# Series config constants
adrSeriesConfig = { name: "adr", config: { label: "Average Daily Return", stroke: "#ffffff" } }
latestSeriesConfig = { name: "latestData", config: { label: "Neuester Verlauf", stroke: "#faba01" } }

############################################################
export initialize = ->
    log "initialize"
    seasonalityChart = new SeasonalityChart(chartContainer)
    seasonalityChart.setOnSelectListener(onChartRangeSelected)
    seasonalityChart.setOnTimeDragListener(onChartTimeDrag)

    # Wire up legend series click handlers
    wireLegendSeriesHandlers()

    # Wire up reset time axis button
    resetTimeAxisButton.addEventListener("click", seasonalityChart.resetTimeAxis)
    return

############################################################
#region Legend Series Wiring
wireLegendSeriesHandlers = ->
    log "wireLegendSeriesHandlers"
    legendSeriesEls = document.querySelectorAll('#chart-components-tab .legend-series')
    legendSeriesEls.forEach((el) -> el.addEventListener('click', -> onLegendSeriesClick(el)))
    return

onLegendSeriesClick = (el) ->
    log "onLegendSeriesClick"
    isVisible = el.classList.toggle('visible')
    seriesKey = el.getAttribute('series-key')

    # Persist visibility state
    if seriesKey and seriesVisibility.hasOwnProperty(seriesKey)
        seriesVisibility[seriesKey] = isVisible

    seriesIdx = parseInt(el.getAttribute('series-index'))
    seasonalityChart.toggleSeriesVisibility(seriesIdx, isVisible)
    syncLegendVisibility()
    return

#endregion

############################################################
onChartRangeSelected = (startIdx, endIdx) ->
    log "onChartRangeSelected"
    selection = { startIdx, endIdx }
    onRangeSelect(selection) if onRangeSelect?
    # redrawChart() ## fix missalignment of selection lines
    # causes race-condition resetting similar selection - how could it be?
    return

onChartTimeDrag = (xDrag) ->
    log "onChartTimeDrag"
    xAxisDrag = xDrag
    return


############################################################
syncLegendVisibility = ->
    legendSeriesEls = document.querySelectorAll('#chart-components-tab .legend-series')
    
    for el in legendSeriesEls
        seriesKey = el.getAttribute('series-key')
        if seriesKey and seriesVisibility.hasOwnProperty(seriesKey)
            if seriesVisibility[seriesKey] then el.classList.add('visible')
            else el.classList.remove('visible')

    return

applySeriesVisibility = ->
    log "applySeriesVisibility"
    seasonalityChart.toggleSeriesVisibility(1, seriesVisibility.adr)
    seasonalityChart.toggleSeriesVisibility(2, seriesVisibility.latestData)
    return

############################################################
# Prepare raw 366-day seasonality data for 2-year chart display
prepareSeasonalityFor2Year = (rawData) ->
    cfg = utl.getLeapYearConfig()
    factors = utl.toFactorsArray(rawData)
    frontData = utl.fromFactorsBackward(factors)
    backData = utl.fromFactorsForward(factors)

    if !cfg.lastYearIsLeap then frontData = removeFeb29(frontData)
    if !cfg.currentYearIsLeap then backData = removeFeb29(backData)

    return [...frontData, ...backData]

############################################################
removeFeb29 = (arr) ->
    result = []
    for val,i in arr when i != utl.FEB29
        result.push(val)
    return result


############################################################
prepareChartData = (rawAdr, rawLatest) ->
    log "prepareChartData"
    cfg = utl.getLeapYearConfig()

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
redrawChart = ->
    log "redrawChart"
    return unless adrAggregation?
    seasonalityChart.reset()

    seasonalityChart.setTimeSeries(xAxisData)
    series = []
    series.push({ adrSeriesConfig..., data: adrAggregation }) ## Adr is 1
    # if seriesVisibility.fourier and frAggregation?
    #     series.push({ frSeriesConfig..., data: frAggregation })
    series.push({ latestSeriesConfig..., data: latestData }) ## latestData is 2
    seasonalityChart.setDataSeries(series)

    seasonalityChart.render(selection, xAxisDrag)

    # Restore series visibility after chart is drawn
    applySeriesVisibility()
    return


############################################################
export reset = ->
    log "reset"
    seasonalityChart.reset()
    selection = null
    xAxisDrag = null
    xAxisData = null
    return

############################################################
export prepareData = (data) ->
    log "prepareData"
    {rawLatest, rawAdr, years} = data
    prepareChartData(rawAdr, rawLatest)
    return

############################################################
export render = ->
    log "render"
    redrawChart()
    return

############################################################
export setSelectedRegion = (selReg) ->
    log "setSelectedRegion"
    return unless selReg? or selection?
    { startIdx, endIdx, isDelta } = selReg

    if !isDelta and selection.startIdx == startIdx and selection.endIdx == endIdx 
        return ## nothing to update
    else if !isDelta # at least one new value to set
        selection.startIdx = startIdx
        selection.endIdx = endIdx
    else # apply delta
        if startIdx? then selection.startIdx += startIdx
        if endIdx? then selection.endIdx += endIdx

    ## Readjust invald configurations
    maxIdx = xAxisData.length - 1
    if selection.endIdx > maxIdx then selection.endIdx = maxIdx
    if selection.startIdx >= selection.endIdx then selection.startIdx = selection.endIdx - 1
    if selection.startIdx < 0 then selection.startIdx = 0
    if selection.startIdx == selection.endIdx then selection.endIdx++

    ## communicate change and redraw chart
    onRangeSelect(selection) if onRangeSelect?
    redrawChart()
    return

############################################################
export setOnRangeSelectListener = (listener) -> onRangeSelect = listener
