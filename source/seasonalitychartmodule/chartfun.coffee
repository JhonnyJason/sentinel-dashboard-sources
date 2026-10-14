############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("chartfun")
#endregion

############################################################
import uPlot from "uplot"

############################################################
monthNames = {
    MMMM:["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    MMM:["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    MM: ["Ja", "Fe", "Mä", "Ap", "Ma", "Ju", "Ju", "Au", "Se", "Ok", "No", "De"]
    M: ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
}
weekdayNames = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

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
    setTimeSeries: (series, backStartIdx = 0) => 
        @timeSeries = series
        @backStartIdx = backStartIdx
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
    setOnTimeDragListener: (listener) => @onTimeDrag = listener

    onInit: (u) =>
        log "Chart.onInit"
        xAxisEl = u.root.getElementsByClassName('u-axis')[0]
        xAxisEl.classList.add("movable")
        attachAxisDrag(u, xAxisEl)
        attachTouchSelect(u)

        # Set inital Scale from @xDrag if we have one
        if @xDrag? and @xDrag > 1
            log "We should apply stored xDrag"
            rangeDif = u.scales.x.max - u.scales.x.min
            max = @defaultMax - @xDrag
            min = max - rangeDif
            u.setScale("x", { min, max })
        
        log "applied xDrag or not^^..."
        return

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
        log "spplied selection or not^^..."
        return

    onSetSelect: (u) =>
        log "Chart:onSetSelect"
        if u.select.width > 0
            startIndex = u.posToIdx(u.select.left)
            endIndex = u.posToIdx(u.select.left + u.select.width)
            log "Selection range: #{startIndex} - #{endIndex}"
            ## Seems @selection is null here despite having set int on render - how could it be?
            ## maybe when any redraw calls reset()
            if @selection? and @selection.startIdx == startIndex and @selection.endIdx == endIndex
                log "Range did not change - we skip doing anything :-)"
                return

            # remembered here too - without a re-render @selection would stay the old range
            @selection = { startIdx: startIndex, endIdx: endIndex }
            return unless @onSelect?
            @onSelect(startIndex, endIndex)
        return false

    onCursorMove: (u) =>
        # log "Chart:onCursorMove"
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
        @onTimeDrag(@xDrag) if @onTimeDrag?

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
        cancelSelect(@handle)
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

        { absoluteMax, setXRange } = produceRangeSetter(@timeSeries, @backStartIdx)
        @defaultMax = absoluteMax  # Store for reset functionality

        seriesConfig = [{}]  # x-axis placeholder
        seriesConfig.push(series.config) for series in @dataSeries # add all series config

        data = []
        if @dataSeries? and @dataSeries.length > 0
            data.push(@timeSeries)
            data.push(series.data) for series in @dataSeries
        
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
                        span = u.scales.x.max - u.scales.x.min
                        # weekly: weekday + day, sub-day splits would repeat the label
                        if span < 10 * 86_400
                            prev = null
                            return splits.map (ts) ->
                                d = new Date(ts * 1000)
                                label = weekdayNames[d.getDay()] + " " + d.getDate() + "."
                                if label == prev then return ""
                                prev = label
                                return label
                        # short spans (monthly) show the day, quarters day + month, long ones the month
                        if span < 40 * 86_400
                            return splits.map (ts) -> new Date(ts * 1000).getDate() + "."
                        if span < 200 * 86_400
                            return splits.map (ts) ->
                                d = new Date(ts * 1000)
                                d.getDate() + ". " + monthNames.MMM[d.getMonth()]
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
                ready: [@onReady]
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
# visible range = span of the current period, draggable over the whole axis
produceRangeSetter = (timeSeries, backStartIdx) ->
    log "produceRangeSetter"
    absoluteMin = timeSeries[0]
    absoluteMax = timeSeries[timeSeries.length - 1]
    rangeDif = absoluteMax - timeSeries[backStartIdx]

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
# drag on the x axis shifts the visible range - pointer events, so mouse, touch and pen alike
# pointer capture: moves and the release still arrive when the pointer leaves the axis
attachAxisDrag = (u, axisEl) ->
    drag = null # only the first pointer drags

    axisEl.addEventListener "pointerdown", (e) ->
        return if drag?
        e.preventDefault()
        axisEl.setPointerCapture(e.pointerId)
        { min, max } = u.scales.x
        unitsPerPx = (max - min) / (u.bbox.width / uPlot.pxRatio)
        drag = { id: e.pointerId, x0: e.clientX, min, max, unitsPerPx }
        return

    axisEl.addEventListener "pointermove", (e) ->
        return unless drag?.id == e.pointerId
        shift = (drag.x0 - e.clientX) * drag.unitsPerPx
        cancelSelect(u)
        u.setScale("x", { min: drag.min + shift, max: drag.max + shift })
        return

    end = (e) -> drag = null if drag?.id == e.pointerId
    axisEl.addEventListener(type, end) for type in ["pointerup", "pointercancel", "lostpointercapture"]
    return

# uPlot only handles mouse events, so touch and pen select the range here, through its API.
# Only a release commits (fires setSelect -> backtest); a cancel (browser scroll, second finger,
# chart rebuilt) restores the previous selection. A move below minDragPx is a tap: date only.
minDragPx = 10
attachTouchSelect = (u) ->
    over = u.over
    drag = null # only the first finger selects

    toPos = (e) ->
        rect = over.getBoundingClientRect()
        clamp = (v, max) -> Math.min(Math.max(v, 0), max)
        { x: clamp(e.clientX - rect.left, rect.width), y: clamp(e.clientY - rect.top, rect.height) }

    showSelect = (x0, x1, fire) ->
        height = u.bbox.height / uPlot.pxRatio
        u.setSelect({ left: Math.min(x0, x1), width: Math.abs(x1 - x0), top: 0, height }, fire)
        return

    over.addEventListener "pointerdown", (e) ->
        return if e.pointerType == "mouse" or drag?
        e.preventDefault() # no emulated mouse events -> uPlot would clear the selection on a tap
        over.setPointerCapture(e.pointerId)
        { x, y } = toPos(e)
        { left, width, top, height } = u.select
        drag = { id: e.pointerId, x0: x, prev: { left, width, top, height }, moved: false }
        u.setCursor({ left: x, top: y })
        return

    over.addEventListener "pointermove", (e) ->
        return unless drag?.id == e.pointerId
        { x, y } = toPos(e)
        drag.moved = drag.moved or Math.abs(x - drag.x0) >= minDragPx
        u.setCursor({ left: x, top: y })
        showSelect(drag.x0, x, false) if drag.moved
        return

    end = (e, commit) ->
        return unless drag?.id == e.pointerId
        if commit and drag.moved then showSelect(drag.x0, toPos(e).x, true)
        else u.setSelect(drag.prev, false)
        u.setCursor({ left: -10, top: -10 }) # no hover on touch -> hide cursor + date
        drag = null
        return

    over.addEventListener("pointerup", (e) -> end(e, true))
    over.addEventListener(type, (e) -> end(e, false)) for type in ["pointercancel", "lostpointercapture"]
    return

############################################################
cancelSelect = (u) ->
    log "cancelSelect"
    u.setSelect({width: 0, height: 0}, false)
    ## TODO clear other select
    return

