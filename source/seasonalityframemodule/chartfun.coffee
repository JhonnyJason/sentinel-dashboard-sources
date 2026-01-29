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

############################################################
# Legend state
legendContainer = null
legendTimestampEl = null
legendSeriesEls = null

############################################################
monthNames = {
    MMMM:["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    MMM:["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    MM: ["Ja", "Fe", "Mä", "Ap", "Ma", "Ju", "Ju", "Au", "Se", "Ok", "No", "De"]
    M: ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
}

############################################################
# Legend date formatting - easily swappable
formatLegendDate = (ts) ->
    d = new Date(ts * 1000)
    day = d.getDate()
    month = monthNames.MMMM[d.getMonth()]
    year = d.getFullYear()
    "#{day}. #{month} #{year}"

############################################################
export initLegend = (container) ->
    log "initLegend"
    legendContainer = container
    legendTimestampEl = container.querySelector('.legend-date')
    legendSeriesEls = container.querySelectorAll('.legend-series')

    # Wire up checkboxes for show/hide
    legendSeriesEls.forEach (el) ->
        seriesIdx = parseInt(el.dataset.series)
        checkbox = el.querySelector('input[type="checkbox"]')
        checkbox.addEventListener 'change', (e) ->
            return unless chartHandle?
            chartHandle.setSeries(seriesIdx, { show: e.target.checked })
            el.classList.toggle('series-hidden', !e.target.checked)
    return

############################################################
onCursorMove = (u) ->
    return unless legendContainer?

    idx = u.cursor.idx

    if !idx?
        # Cursor left chart - show placeholder
        legendTimestampEl.textContent = "--. --- ----"
        legendSeriesEls.forEach (el) ->
            el.querySelector('.series-value').textContent = "--%"
        return

    # Update timestamp
    timestamp = u.data[0][idx]
    legendTimestampEl.textContent = formatLegendDate(timestamp)

    # Update series values
    legendSeriesEls.forEach (el) ->
        seriesIdx = parseInt(el.dataset.series)
        val = u.data[seriesIdx]?[idx]
        valueEl = el.querySelector('.series-value')
        valueEl.textContent = if val? then "#{val.toFixed(1)}%" else "--%"
    return

############################################################
export resetChart = (container) ->
    log "resetChart"
    if chartHandle? then chartHandle.destroy()
    container.innerHTML = ""
    chartHandle = null
    chartContainer = container
    # Reset legend state
    legendContainer = null
    legendTimestampEl = null
    legendSeriesEls = null
    return

############################################################
timestampToAxisName = (val) ->
    dateObj = new Date(val)
    date = date.getDate()
    month = monthNames.MMM[date.getMonth()]
    return month+" "+date

############################################################
onSetSelect = (u) ->
    log "onSetSelect"
    if u.select.width > 0
        log "Use Selection now!"
        startIndex = u.posToIdx(u.select.left);
        endIndex = u.posToIdx(u.select.left + u.select.width);

        log startIndex
        log endIndex
        ## TODO implement

    return false

############################################################
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

onInit = (u) ->
    xAxisEl = u.root.getElementsByClassName('u-axis')[0]
    xAxisEl.classList.add("movable")
    wrappedMouseDownListener = (evnt) -> xAxisMouseDown(evnt, u)
    xAxisEl.addEventListener("mousedown", wrappedMouseDownListener)
    return

validateChartData = (xAxisData, seasonalityData, latestData) ->
    log "validateChartData"
    allValid = true

    # Check each array for freak values
    allValid = utl.scanForFreakValues(xAxisData, "xAxisData") and allValid
    allValid = utl.scanForFreakValues(seasonalityData, "seasonalityData") and allValid
    if latestData?
        allValid = utl.scanForFreakValues(latestData, "latestData") and allValid

    # Check length consistency
    xLen = xAxisData?.length ? 0
    sLen = seasonalityData?.length ? 0
    lLen = latestData?.length ? 0

    console.log "[chartfun] Data lengths - xAxis: #{xLen}, seasonality: #{sLen}, latest: #{lLen}"

    if xLen != sLen
        console.warn "[chartfun] LENGTH MISMATCH: xAxisData (#{xLen}) != seasonalityData (#{sLen})"
        allValid = false

    if latestData? and xLen != lLen
        console.warn "[chartfun] LENGTH MISMATCH: xAxisData (#{xLen}) != latestData (#{lLen})"
        allValid = false

    return allValid

############################################################
export drawChart = (container, xAxisData, seasonalityData, latestData) ->
    log "drawChart"
    chartContainer = container

    # Validate data before drawing
    validateChartData(xAxisData, seasonalityData, latestData)

    rect = container.getBoundingClientRect();
    width = Math.floor(rect.width)
    height = Math.floor(rect.height)

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
        series: [
            {},
            {
                label: "Seasonality Composite 10J",
                stroke: "#ffffff",
            },
            {
                label: "Neuester Verlauf",
                stroke: "#faba01",
            },
        ],
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
            init: [onInit]
            setSelect: [onSetSelect]
            setCursor: [onCursorMove]
        },
        cursor: {
            drag: {
                setScale: false,
                x: true,
                y: false,
            }
        }
    }

    data = []
    if seasonalityData?
        data.push(xAxisData)
        data.push(seasonalityData)
        data.push(latestData) if latestData?

    chartHandle = new uPlot(options, data, container);
    return
