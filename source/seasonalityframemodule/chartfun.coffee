############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("chartfun")
#endregion

############################################################
import uPlot from "uplot"
import * as utl from "./utilsmodule.js"

############################################################
chartHandle = null
chartContainer = null

# Cursor indicator state
cursorIndicatorEl = null
cursorLocationEl = null

# Reset button state
resetButtonEl = null
defaultMax = null  # Store the default rightmost position

# Selection callback
selectionCallback = null

############################################################
monthNames = {
    MMMM:["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    MMM:["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    MM: ["Ja", "Fe", "Mä", "Ap", "Ma", "Ju", "Ju", "Au", "Se", "Ok", "No", "De"]
    M: ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
}

############################################################
export class SeasonalityChart
    constructor: (container) ->
        @handle = null
        @chartEl = container.querySelector('#seasonality-chart')
        @cursorIndicator = container.querySelector('#cursor-indicator')
        @cursorLocation = @cursorIndicator.querySelector('.location')
        @resetButton = container.querySelector('#reset-time-axis-button')
        @onSelect = null
        @onTimeDrag = null
        @timeSeries = null
        @dataSeries = null
        @defaultMax = null

    ##########################################
    #region Series Data manipulation
    setTimeSeries: (series) => 
        @timeSeries = series
        return

    setDataSeries: (allSeries) =>
        @dataSeries = allSeries
        return

    addDataSeries: (series, prefIndex = null) =>
        if !prefIndex? or prefIndex >= @daraSeries.length then @dataSeries.push(series)
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
    setOnTimeDragListener: (listener) => @onTimeDrag = listener

    onInit: (u) =>
        log "Chart.onInit"
        xAxisEl = u.root.getElementsByClassName('u-axis')[0]
        xAxisEl.classList.add("movable")
        wrappedMouseDownListener = (evnt) -> xAxisMouseDown(evnt, u)
        xAxisEl.addEventListener("mousedown", wrappedMouseDownListener)

        # Set inital Scale from @xDrag of we have one
        if @xDrag > 1
            rangeDif = u.scales.x.max - u.scales.x.min
            max = @defaultMax - @xDrag
            min = max - rangeDif
            u.setScale("x", { min, max })

        # Set initial Selection from @selection
        if @selection? and @selection.startIdx? and @selection.endIdx? and 
        @selection.startIdx < @selection.endIdx
            ## TODO implement
            u.setSelect({})
        return

    onSetSelect: (u) => 
        log "Chart:onSetSelect"
        if u.select.width > 0
            startIndex = u.posToIdx(u.select.left)
            endIndex = u.posToIdx(u.select.left + u.select.width)
            log "Selection range: #{startIndex} - #{endIndex}"
            return unless @onSelect?
            @onSelect(startIndex, endIndex)
        return false

    onCursorMove: (u) => 
        log "Chart:onCursorMove"
        idx = u.cursor.idx
        return unless @cursorIndicator?

        if !idx? then @cursorIndicator.classList.remove("shown")
        else
            timestamp = u.data[0][idx]
            @cursorLocation.textContent = formatCursorDate(timestamp)
            @cursorIndicator.classList.add("shown")
        return

    onScaleChange: (u, scaleKey) =>
        log "Chart:onScaleChange"
        return unless scaleKey == "x"
        currentMax = u.scales.x.max
        
        return unless @defaultMax?
        @xDrag = @defaultMax - currentMax
        @onTimeDrag(@xDrag)

        return unless @resetButton?
        # Show button when not at the rightmost (default) position
        # Small tolerance for floating point comparison
        if @xDrag > 1 then @resetButton.classList.add("shown")
        else @resetButton.classList.remove("shown")
        return

    #endregion

    ##########################################
    #region Chart Control
    toggleSeriesVisibility: (seriesIdx, isVisible) => 
        log "Chart.toggleSeriesVisibility", seriesIdx, isVisible
        return unless @handle?
        @handle.setSeries(seriesIdx, { show: isVisible })
        return
    
    resetTimeAxis:  =>
        log "resetTimeAxis"
        return unless @handle? and @defaultMax?
        rangeDif = @handle.scales.x.max - @handle.scales.x.min
        newMax = @defaultMax
        newMin = newMax - rangeDif
        @handle.setScale("x", { min: newMin, max: newMax })
        return
        
    reset: =>
        log "Chart.reset"
        if @handle? then @handle.destroy()
        @handle = null
        
        @chartEl.innerHTML = ""
        @cursorIndicator.classList.remove("shown")
        @cursorLocation.textContent = ""      
        @resetButton.classList.remove("shown")

        @defaultMax = null # what to do here?
        @selection = null
        @xDrag = null

        return
    
    render: (selection, xDrag) =>
        log "Chart.render"
        I = this # save Instance for Callbacks
        @selection = selection
        @xDrag = xDrag

        rect = @chartEl.getBoundingClientRect();
        width = Math.floor(rect.width)
        height = Math.floor(rect.height)

        { absoluteMax, setXRange } = produceRangeSetter()
        @defaultMax = absoluteMax  # Store for reset functionality

        seriesConfig = [{}]  # x-axis placeholder
        seriesConfig.push(series.config) for series in @allSeries # add all series config

        data = []
        if @allSeries? and @allSeries.length > 0
            data.push(@timeSeries)
            data.push(series.data) for series in @allSeries
        
        # seriesConfig.push({ label: "Average Daily Return", stroke: "#ffffff" })
        # if fourierData?
        #     seriesConfig.push({ label: "Fourier Regression", stroke: "#aabbaa" })
        # seriesConfig.push({ label: "Neuester Verlauf", stroke: "#faba01" })

        options = {
            width: width - 15,
            height: height,
            padding: [30,15,15,15]
            scales: {
                x: {
                    time: true,
                    range: setXRange
                }
            },
            series: seriesConfig,
            axes: [
                {
                    space: 80
                    scale: "x"
                    stroke: "#ffffff"
                    values: (u, splits) ->
                        names = if splits.length > 12 then monthNames.MMMM else monthNames.MMM
                        splits.map (ts) ->
                            d = new Date(ts * 1000)
                            names[d.getMonth()]
                },
                {
                    show: true
                    values: (u, vals, space) -> vals.map((v)-> v.toFixed(0) + '%'),
                    space: 50
                    gap: 10
                    size: 65
                    stroke: "#ffffff"
                    grid: {
                        show: true,
                        stroke: "#ffffff22"
                        width: 1,
                        dash: [5,10]
                    },
                    ticks: { show: false}
                },
            ],
            hooks: {
                init: [@onInit]
                setSelect: [@onSetSelect]
                setCursor: [@onCursorMove]
                setScale: [@onScaleChange]
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
produceRangeSetter = ->
    log "produceRangeSetter"
    jan1Latest = utl.getJan1Date()
    jan1Before = new Date(jan1Latest)
    jan1Before.setYear(jan1Latest.getFullYear() - 1)
    dec31Next = utl.getDec31Date()

    min = jan1Latest.getTime() / 1000
    max = dec31Next.getTime() / 1000
    rangeDif = max - min

    absoluteMax = max
    absoluteMin = jan1Before.getTime() / 1000

    setXRange = (u, min, max) ->
        min = max - rangeDif
        dif = min - absoluteMin

        if dif < 0 # we are below absoluteMin
            min -= dif
            max -= dif

        dif = absoluteMax - max
        if dif < 0 # we are above absoluteMax
            min += dif
            max += dif

        return [min, max]

    return { absoluteMax, setXRange }

############################################################
# Cursor indicator date formatting - dd.mm.yyyy
formatCursorDate = (ts) ->
    d = new Date(ts * 1000)
    day = String(d.getDate()).padStart(2, '0')
    month = String(d.getMonth() + 1).padStart(2, '0')
    year = d.getFullYear()
    "#{day}.#{month}.#{year}"


############################################################
#region Manual Selection Interference
xAxisMouseDown = (evnt, u) ->
    y0 = evnt.clientY;
    x0 = evnt.clientX;

    scale = u.scales["x"]
    currentMin = scale.min
    currentMax = scale.max
    dim = u.bbox.width

    range = currentMax - currentMin
    unitsPerPx = range / (dim / uPlot.pxRatio)

    mousemove = (e) ->
        d = x0 - e.clientX
        shiftyBy = d * unitsPerPx;

        min = currentMin + shiftyBy
        max = currentMax + shiftyBy

        cancelSelect(u)
        u.setScale("x", { min, max })
        return

    mouseup = (e) ->
        document.removeEventListener('mousemove', mousemove)
        document.removeEventListener('mousemove', mouseup)

    document.addEventListener('mousemove', mousemove)
    document.addEventListener('mouseup', mouseup)

############################################################
oldMinScale = null
oldMaxScale = null

############################################################
cancelSelect = (u) ->
    log "cancelSelect"
    u.setSelect({width: 0, height: 0}, false)
    ## TODO clear other select
    return

############################################################
plotMouseDown = (evnt, u) ->
    log "plotMouseDown"
    evnt.stopPropagation()
    scaleOnMouseDown = u.scales["x"]
    oldMinScale = scaleOnMouseDown.min
    oldMaxScale = scaleOnMouseDown.max
    return false

plotClick = (evnt, u) ->
    log "plotClick"
    evnt.stopPropagation()
    return false

plotMouseUp = (evnt, u) ->
    log "plotMouseUp"
    evnt.stopPropagation()
    selectObj = u.select
    olog selectObj
    u.setSelect({width: u.select.width, height: u.select.height}, false)
    ## TODO remove selection
    return false


# ############################################################
# export resetChart = (container) ->
#     log "resetChart"
#     if chartHandle? then chartHandle.destroy()
#     container.innerHTML = ""
#     chartHandle = null
#     chartContainer = container
#     # Reset cursor indicator state
#     cursorIndicatorEl?.classList.remove("shown")
#     cursorIndicatorEl = null
#     cursorLocationEl = null
#     # Reset button state
#     resetButtonEl?.classList.remove("shown")
#     resetButtonEl = null
#     defaultMax = null
#     return

# ############################################################
# timestampToAxisName = (val) ->
#     dateObj = new Date(val)
#     date = date.getDate()
#     month = monthNames.MMM[date.getMonth()]
#     return month+" "+date



# validateChartData = (xAxisData, seasonalityData, latestData) ->
#     log "validateChartData"
#     allValid = true

#     # Check each array for freak values
#     allValid = utl.scanForFreakValues(xAxisData, "xAxisData") and allValid
#     allValid = utl.scanForFreakValues(seasonalityData, "seasonalityData") and allValid
#     if latestData?
#         allValid = utl.scanForFreakValues(latestData, "latestData") and allValid

#     # Check length consistency
#     xLen = xAxisData?.length ? 0
#     sLen = seasonalityData?.length ? 0
#     lLen = latestData?.length ? 0

#     console.log "[chartfun] Data lengths - xAxis: #{xLen}, seasonality: #{sLen}, latest: #{lLen}"

#     if xLen != sLen
#         console.warn "[chartfun] LENGTH MISMATCH: xAxisData (#{xLen}) != seasonalityData (#{sLen})"
#         allValid = false

#     if latestData? and xLen != lLen
#         console.warn "[chartfun] LENGTH MISMATCH: xAxisData (#{xLen}) != latestData (#{lLen})"
#         allValid = false

#     return allValid

# ############################################################
# export drawChart = (container, xAxisData, adrData, fourierData, latestData) ->
#     log "drawChart"
#     chartContainer = container

#     # Initialize cursor indicator (sibling in parent #chart-container)
#     cursorIndicatorEl = container.parentElement?.querySelector('#cursor-indicator')
#     cursorLocationEl = cursorIndicatorEl?.querySelector('.location')

#     # Initialize reset button (sibling in parent #chart-container)
#     resetButtonEl = container.parentElement?.querySelector('#reset-time-axis-button')

#     # Validate data before drawing -> for testing only
#     # validateChartData(xAxisData, adrData, latestData)

#     rect = container.getBoundingClientRect();
#     width = Math.floor(rect.width)
#     height = Math.floor(rect.height)

#     jan1Latest = utl.getJan1Date()
#     jan1Before = new Date(jan1Latest)
#     jan1Before.setYear(jan1Latest.getFullYear() - 1)
#     dec31Next = utl.getDec31Date()

#     min = jan1Latest.getTime() / 1000
#     max = dec31Next.getTime() / 1000
#     rangeDif = max - min

#     absoluteMax = max
#     absoluteMin = jan1Before.getTime() / 1000
#     defaultMax = absoluteMax  # Store for reset functionality

#     setXRange = (u, min, max) ->
#         min = max - rangeDif
#         dif = min - absoluteMin

#         if dif < 0 # we are below absoluteMin
#             min -= dif
#             max -= dif

#         dif = absoluteMax - max
#         if dif < 0 # we are above absoluteMax
#             min += dif
#             max += dif

#         return [min, max]

#     # Build series dynamically - latestData always last to be on top
#     seriesConfig = [{}]  # x-axis placeholder
#     seriesConfig.push({ label: "Average Daily Return", stroke: "#ffffff" })
#     if fourierData?
#         seriesConfig.push({ label: "Fourier Regression", stroke: "#aabbaa" })
#     seriesConfig.push({ label: "Neuester Verlauf", stroke: "#faba01" })

#     options = {
#         width: width - 15,
#         height: height,
#         padding: [30,15,15,15]
#         scales: {
#             x: {
#                 time: true,
#                 range: setXRange
#             }
#         },
#         series: seriesConfig,
#         axes: [
#             {
#                 space: 80
#                 scale: "x"
#                 stroke: "#ffffff"
#                 values: (u, splits) ->
#                     names = if splits.length > 12 then monthNames.MMMM else monthNames.MMM
#                     splits.map (ts) ->
#                         d = new Date(ts * 1000)
#                         names[d.getMonth()]
#             },
#             {
#                 show: true
#                 values: (u, vals, space) -> vals.map((v)-> v.toFixed(0) + '%'),
#                 space: 50
#                 gap: 10
#                 size: 65
#                 stroke: "#ffffff"
#                 grid: {
#                     show: true,
#                     stroke: "#ffffff22"
#                     width: 1,
#                     dash: [5,10]
#                 },
#                 ticks: { show: false}
#             },
#         ],
#         hooks: {
#             init: [onInit]
#             setSelect: [onSetSelect]
#             setCursor: [onCursorMove]
#             setScale: [onScaleChange]
#         },
#         cursor: {
#             drag: {
#                 setScale: false,
#                 x: true,
#                 y: false,
#             }
#         }
#     }

#     # Build data array - latestData always last
#     data = []
#     if adrData?
#         data.push(xAxisData)
#         data.push(adrData)
#         data.push(fourierData) if fourierData?
#         data.push(latestData) if latestData?

#     chartHandle = new uPlot(options, data, container);
#     return
