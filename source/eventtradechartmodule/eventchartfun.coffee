############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("chartfun")
#endregion

############################################################
import uPlot from "uplot"
import * as utl from "./utilsmodule.js"

############################################################
export class EventTradeChart
    constructor: (container) ->
        @handle = null
        @chartEl = container.querySelector('#tradedetails-chart')
        @onSelect = null
        @timeSeries = null
        @dataSeries = null

    ##########################################
    #region Series Data manipulation
    setTimeSeries: (series) => 
        @timeSeries = series
        return

    setDataSeries: (allSeries) =>
        @dataSeries = allSeries
        return

    addDataSeries: (series, prefIndex = null) =>
        if !prefIndex? or prefIndex >= @dataSeries.length 
            @dataSeries.push(series)
            return
            
        newArray = []
        for ser,i in @dataSeries
            if i == prefIndex then newArray.push(series)
            newArray.push(ser)
        @dataSeries = newArray
        return

    removeDataSeries: (name) =>
        newArray = []
        for series,i in @dataSeries when series.name != name
            newArray.push(series)
        @dataSeries = newArray
        return

    #endregion

    ##########################################
    #region Event Listeners
    setOnSelectListener: (listener) => @onSelect = listener

    onReady: (u) =>
        log "Chart.onReady"
        # Restore selection from previous state (no hook fire to avoid re-triggering backtesting)
        if @selection? and @selection.startIdx? and @selection.endIdx? and
        @selection.startIdx < @selection.endIdx and @timeSeries?
            startTime = u.data[0][@selection.startIdx]
            endTime = u.data[0][@selection.endIdx]
            if startTime? and endTime?
                log "We do have startTime and endTime"
                left = u.valToPos(startTime, 'x')
                right = u.valToPos(endTime, 'x')
                height = u.bbox.height / uPlot.pxRatio
                u.setSelect({ left, width: right - left, top: 0, height }, false)
        log "applied selection or not^^..."
        return

    onSetSelect: (u) =>
        log "Chart:onSetSelect"
        if u.select.width > 0
            startIndex = u.posToIdx(u.select.left)
            endIndex = u.posToIdx(u.select.left + u.select.width)
            log "Selection range: #{startIndex} - #{endIndex}"
            ## Seems @selection is null here despite having set int on render - how could it be?
            ## maybe when any redraw calls reset()
            if @selection? and @selection.startIndex == startIndex and @selection.endIndex == endIndex
                log "Range did not change - we skip doing anything :-)"
                return

            return unless @onSelect?
            @onSelect(startIndex, endIndex)
        return false

    #endregion

    ##########################################
    #region Chart Control
    reset: =>
        log "Chart.reset"
        if @handle? then @handle.destroy()
        @handle = null
        @chartEl.innerHTML = ""
        @selection = null
        return
    
    render: (selection) =>
        log "Chart.render"
        I = this # save Instance for Callbacks
        @selection = selection

        rect = @chartEl.getBoundingClientRect()
        width = Math.floor(rect.width) || 200
        height = Math.floor(rect.height) || 90

        seriesConfig = [{}]  # x-axis placeholder
        seriesConfig.push(series.config) for series in @dataSeries # add all series config

        data = []
        if @dataSeries? and @dataSeries.length > 0
            data.push(@timeSeries)
            data.push(series.data) for series in @dataSeries
        
        log data

        dataMin = @timeSeries[0]
        dataMax = @timeSeries[@timeSeries.length - 1]

        clampRange = (u, min, max) ->
            range = max - min
            if min < dataMin
                min = dataMin
                max = dataMin + range
            if max > dataMax
                max = dataMax
                min = dataMax - range
            return [min, max]

        options = {
            width: width,
            height: height,
            padding: [0,0,0,0]
            scales: {
                x: {
                    time: true,
                    range: clampRange
                }
            },
            series: seriesConfig,
            axes: [
                { show: false
                    # space: 80
                    # scale: "x"
                    # stroke: "#ffffff"
                    # values: (u, splits) ->
                    #     names = if splits.length > 12 then monthNames.MMMM else monthNames.MMM
                    #     splits.map (ts) ->
                    #         d = new Date(ts * 1000)
                    #         names[d.getMonth()]
                },
                {
                    show: false
                    # values: (u, vals, space) -> vals.map((v)-> v.toFixed(0) + '%'),
                    # space: 50
                    # gap: 10
                    # size: 65
                    # stroke: "#ffffff"
                    # grid: {
                    #     show: true,
                    #     stroke: "#ffffff22"
                    #     width: 1,
                    #     dash: [5,10]
                    # },
                    # ticks: { show: false}
                },
            ],
            hooks: {
                ready: [@onReady]
                setSelect: [@onSetSelect]
            },
            cursor: {
                drag: {
                    setScale: false,
                    x: true,
                    y: false,
                }
            }
        }

        @handle = new uPlot(options, data, @chartEl);
        return
    #endregion


############################################################
cancelSelect = (u) ->
    log "cancelSelect"
    u.setSelect({width: 0, height: 0}, false)
    ## TODO clear other select
    return

