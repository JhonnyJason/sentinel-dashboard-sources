############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitychartmodule")
#endregion

############################################################
import { SeasonalityChart } from "./chartfun.js"
import { buildAxis, placeComposite, placeLatest } from "./chartlayout.js"

############################################################
chartContainer = document.getElementById("chart-container")
aggregationYearsIndicator = document.getElementById("aggregation-years-indicator")

############################################################
xAxisData = null
adrAggregation = null  # Average Daily Return on the axis
latestData = null      # the displayed chunks on the axis
backStartIdx = 0       # index in xAxisData where the last part starts

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
redrawChart = ->
    log "redrawChart"
    return unless adrAggregation?
    seasonalityChart.reset()

    seasonalityChart.setTimeSeries(xAxisData, backStartIdx)
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
# data: { composite, chunks, refDate, timeframe, ages } - see chartlayout.coffee
export prepareData = (data) ->
    log "prepareData"
    { composite, chunks, refDate, timeframe, ages } = data
    axis = buildAxis(timeframe, refDate, ages)
    adrAggregation = placeComposite(axis, composite)
    latestData = placeLatest(axis, chunks)
    { xAxisData, backStartIdx } = axis
    return

############################################################
export render = ->
    log "render"
    redrawChart()
    return

############################################################
export setSelectedRegion = (selReg, force) ->
    log "setSelectedRegion"
    return unless selReg? 
    if !force then return unless selection?
    if !selection? then selection = Object.create(null)

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
export indexToDate = (idx) -> new Date(xAxisData[idx] * 1000)
# -1 when the date is not on the current chart axis
export dateToIndex = (date) -> xAxisData.findIndex((ts) -> new Date(ts * 1000).toDateString() == date.toDateString())

############################################################
export setOnRangeSelectListener = (listener) -> onRangeSelect = listener
