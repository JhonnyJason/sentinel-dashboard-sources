############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventtradechartmodule")
#endregion

############################################################
import * as utl from "./utilsmodule.js"

############################################################
import { EventTradeChart } from "./eventchartfun.js"

############################################################
container = document.getElementById("tradedetails-chart-container")

############################################################
xAxisData = null
adrAggregation = null  # Average Daily Return

############################################################
selection = null

############################################################
onRangeSelect = null

############################################################
chart = null

############################################################
# Series config constants
adrSeriesConfig = { name: "adr", config: { label: "Average Daily Return", stroke: "#ffffff" } }

############################################################
export initialize = ->
    log "initialize"
    if !container? then return console.error("#tradedetails-chart-container did not exist!")
    chart = new EventTradeChart(container)
    chart.setOnSelectListener(onChartRangeSelected)
    return

############################################################
onChartRangeSelected = (startIdx, endIdx) ->
    log "onChartRangeSelected"
    selection = { startIdx, endIdx }
    onRangeSelect(selection) if onRangeSelect?
    return

############################################################
redrawChart = ->
    log "redrawChart"
    return unless adrAggregation?
    chart.reset()

    chart.setTimeSeries(xAxisData)
    series = []
    series.push({ adrSeriesConfig..., data: adrAggregation })
    chart.setDataSeries(series)

    chart.render(selection)
    return


############################################################
export reset = ->
    log "reset"
    chart.reset()
    selection = null
    xAxisData = null
    return

############################################################
export prepareData = (rawAdr, date) ->
    log "prepareData"
    eventDay = utl.createDayFromDate(date)
    
    ## Create time axis
    timeframeLength = rawAdr.length
    olog {
        timeframeLength,
        date
    }

    day0 = eventDay.getRelativeDay(Math.floor(-0.5 * timeframeLength))
    dateDay0 = new Date(day0.getYYYYMMDD())
    dateDay0.setHours(12)
    axisTime = dateDay0.getTime() / 1000

    xAxisData = []
    for i in [0...timeframeLength]
        xAxisData[i] = axisTime
        axisTime += 86_400
    
    adrAggregation = rawAdr

    # log adrAggregation
    # log xAxisData
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
    
    if !selection? and isDelta then throw new Error("Cannot apply delta on empty selection!")
    
    if !selection? then selection = selReg 
    else if !isDelta and selection.startIdx == startIdx and selection.endIdx == endIdx
        return ## nothing to update
    else if !isDelta # at least one new value to set
        selection.startIdx = startIdx
        selection.endIdx = endIdx
    else # apply delta
        if startIdx? then selection.startIdx += startIdx
        if endIdx? then selection.endIdx += endIdx

    ## Readjust invald configurations
    maxIdx = xAxisData.length - 1
    olog { selReg, selection, maxIdx }

    if selection.endIdx > maxIdx then selection.endIdx = maxIdx
    if selection.startIdx >= selection.endIdx then selection.startIdx = selection.endIdx - 1
    if selection.startIdx < 0 then selection.startIdx = 0
    if selection.startIdx == selection.endIdx then selection.endIdx++

    olog selection

    ## communicate change and redraw 
    onRangeSelect(selection) if onRangeSelect?
    redrawChart()
    return

############################################################
export setOnRangeSelectListener = (listener) -> onRangeSelect = listener
