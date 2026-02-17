############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("trafficlightframemodule:chart")
#endregion

############################################################
import uPlot from "uplot"

############################################################
SPY = "SPY"

# Semi-transparent state colors for chart background bands
STATE_BG =
    green:  "rgba(46, 204, 113, 1)"
    yellow: "rgba(241, 196, 15, 1)"
    red:    "rgba(231, 76, 60, 1)"
    blue:   "rgba(52, 152, 219, 1)"

############################################################
# Internal chart state
chartHandle = null
currentZoomLevel = "max"
# Stored references for zoom recalculation
storedTimestamps = null

############################################################
export initZoomControl = ->
    zoomLevelSelect.addEventListener("change", onZoomLevelChanged)
    return

export isRendered = -> chartHandle?

############################################################
export renderChart = (timestamps, spyCloses, states) ->
    log "renderChart"
    return unless timestamps?

    container = document.getElementById("trafficlight-chart")
    return unless container?

    rect = container.getBoundingClientRect()
    w = Math.floor(rect.width)
    h = Math.floor(rect.height)
    return unless w > 0 and h > 0

    storedTimestamps = timestamps
    dataMin = timestamps[0]
    dataMax = timestamps[timestamps.length - 1]

    clampRange = (u, min, max) ->
        range = max - min
        if min < dataMin
            min = dataMin
            max = dataMin + range
        if max > dataMax
            max = dataMax
            min = dataMax - range
        [min, max]

    MONTH_NAMES = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    TWO_YEARS = 2 * 365.25 * 86400

    options = {
        width: w - 15
        height: h
        padding: [30, 15, 15, 15]
        plugins: [createStatePlugin(states, timestamps)]
        scales: {
            x: { time: true, range: clampRange }
        }
        series: [
            {}
            { label: SPY, stroke: "#ffffff", width: 2 }
        ]
        axes: [
            {
                space: 100
                stroke: "#ffffff"
                values: (u, splits) ->
                    range = u.scales.x.max - u.scales.x.min
                    if range > TWO_YEARS
                        prev = null
                        splits.map (ts) ->
                            label = String(new Date(ts * 1000).getFullYear())
                            if label == prev then "" else prev = label
                    else
                        prev = null
                        splits.map (ts) ->
                            d = new Date(ts * 1000)
                            label = "#{MONTH_NAMES[d.getMonth()]} #{d.getFullYear()}"
                            if label == prev then "" else prev = label
            }
            {
                show: false
            }
        ]
        hooks: {
            init: [onChartInit]
        }
        cursor: {
            show: false
        }
    }

    if chartHandle?
        chartHandle.destroy()
        container.innerHTML = ""

    chartHandle = new uPlot(options, [timestamps, spyCloses], container)
    applyZoomLevel(currentZoomLevel)
    return

############################################################
#region zoom and pan

onZoomLevelChanged = ->
    currentZoomLevel = zoomLevelSelect.value
    log "zoom level changed: #{currentZoomLevel}"
    applyZoomLevel(currentZoomLevel)
    return

applyZoomLevel = (level) ->
    return unless chartHandle? and storedTimestamps?.length
    max = storedTimestamps[storedTimestamps.length - 1]
    if level == "max"
        min = storedTimestamps[0]
    else
        months = parseInt(level)
        min = max - (months * 30.44 * 86400)
    chartHandle.setScale("x", { min, max })
    return

#endregion

############################################################
#region drag-to-pan on x-axis

onChartInit = (u) ->
    xAxisEl = u.root.getElementsByClassName('u-axis')[0]
    xAxisEl.style.cursor = "grab"
    xAxisEl.addEventListener("mousedown", (evnt) -> xAxisMouseDown(evnt, u))
    return

xAxisMouseDown = (evnt, u) ->
    x0 = evnt.clientX
    scale = u.scales["x"]
    currentMin = scale.min
    currentMax = scale.max
    range = currentMax - currentMin
    unitsPerPx = range / (u.bbox.width / uPlot.pxRatio)

    mousemove = (e) ->
        d = x0 - e.clientX
        shift = d * unitsPerPx
        u.setScale("x", { min: currentMin + shift, max: currentMax + shift })
        return

    mouseup = ->
        document.removeEventListener('mousemove', mousemove)
        document.removeEventListener('mouseup', mouseup)
        return

    document.addEventListener('mousemove', mousemove)
    document.addEventListener('mouseup', mouseup)
    return

#endregion

############################################################
#region uPlot state background plugin

createStatePlugin = (states, timestamps) ->
    drawFn = (u) ->
        ctx = u.ctx
        {top, height} = u.bbox

        i = 0
        while i < states.length
            unless states[i]?
                i++
                continue

            state = states[i]
            start = i
            i++ while i < states.length and states[i] == state

            x0 = u.valToPos(timestamps[start], 'x', true)
            endIdx = if i < timestamps.length then i else i - 1
            x1 = u.valToPos(timestamps[endIdx], 'x', true)

            ctx.fillStyle = STATE_BG[state]
            ctx.fillRect(x0, top, x1 - x0, height)
        return

    return { hooks: { drawAxes: [drawFn] } }

#endregion
