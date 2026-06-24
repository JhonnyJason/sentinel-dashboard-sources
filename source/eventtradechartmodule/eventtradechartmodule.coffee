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
    if !date? 
        date = new Date()
        date.setHours(12)
        date.setDate(date.getDate() + 15) # next date > 14
        date = date.toISOString().slice(0, 10)

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
        if startIdx? then selection.startIdx = startIdx
        if endIdx? then selection.endIdx = endIdx
    else # apply delta
        if startIdx? then selection.startIdx += startIdx
        if endIdx? then selection.endIdx += endIdx

    ## Readjust invald configurations
    maxIdx = xAxisData.length - 1
    # olog { selReg, selection }

    # first radically cut down to the limits
    if selection.endIdx > maxIdx then selection.endIdx = maxIdx
    if selection.startIdx < 0 then selection.startIdx = 0

    # Then resolve potential impossibilities
    if selection.startIdx >= selection.endIdx and selection.endIdx == maxIdx
        # obvious choice when endIdx is at the max
        selection.startIdx = selection.endIdx - 1

    if selection.endIdx <= selection.startIdx and selection.startIdx == 0
        # obvious choice when startIdx is at 0W
        selection.endIdx = selection.startIdx + 1

    if selection.startIdx >= selection.endIdx # either decrease startIdx or increase endIdx
        if isDelta            
            deltaSum = 0
            if startIdx? then deltaSum += startIdx
            if endIdx? then deltaSum += endIdx

            # increase endIdx, when we were moving up - unless we are already at the max
            if deltaSum > 0 and selection.endIdx < maxIdx then selection.endIdx++
            else if deltaSum > 0 and selection.endIdx == maxIdx then selection.startIdx--

            # decrease startIdx, when we were moving down - unless we are at 0
            if deltaSum < 0 and selection.startIdx > 0 then selection.startIdx--
            else if deltaSum < 0 and selection.startIdx == 0 then selection.endIdx++

            # in case of zero - default to decrease startIdx - unless we are at 0
            if deltaSum == 0 and selection.startIdx > 0 then selection.startIdx--
            else if deltaSum == 0 and selection.startIdx == 0 then selection.endIdx++
            
        else
            # The index that has more space to move moves
            startIdxSpace = selection.startIdx
            endIdxSpace = maxIdx - selection.endIdx
            if endIdxSpace > startIdxSpace then selection.endIdx++
            if startIdxSpace > endIdxSpace then selection.startIdx--
            if endIdxSpace == startIdxSpace then selection.startIdx--


    if selection.startIdx < 0 or selection.endIdx > maxIdx or selection.endIdx <= selection.startIdx
        console.error("Adjusting indices went wrong!") 
        olog selection

    ## communicate change and redraw 
    onRangeSelect(selection) if onRangeSelect?
    redrawChart()
    return

############################################################
export setOnRangeSelectListener = (listener) -> onRangeSelect = listener
