############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("trafficlightframemodule")
#endregion



############################################################
import uPlot from "uplot"
import { getEodData } from "./scimodule.js"
import { getAuthCode } from "./accountmodule.js"

############################################################
# SPY = S&P 500 ETF
# HYG = iShares iBoxx $ High Yield Corporate Bond ETF
SPY = "SPY"
HYG = "HYG"
START_YEAR = 2019
EMA_PERIOD = 20

############################################################
# Semi-transparent state colors for chart background bands
STATE_BG =
    green:  "rgba(46, 204, 113, 1)"
    yellow: "rgba(241, 196, 15, 1)"
    red:    "rgba(231, 76, 60, 1)"
    blue:   "rgba(52, 152, 219, 1)"
    # green:  "rgba(46, 204, 113, 0.15)"
    # yellow: "rgba(241, 196, 15, 0.15)"
    # red:    "rgba(231, 76, 60, 0.15)"
    # blue:   "rgba(52, 152, 219, 0.15)"

############################################################
# Cached data (populated by fetchData, used by renderChart)
chartHandle = null
cachedTimestamps = null
cachedSpyCloses = null
cachedStates = null
currentState = null

############################################################
# Public: fetch data silently, compute state, update indicators
# Can be called early (e.g. on login) without rendering the chart
export fetchData = ->
    log "fetchData"
    return if cachedStates?

    authCode = getAuthCode()
    unless authCode?
        log "not logged in, skipping fetch"
        return

    try
        currentYear = new Date().getFullYear()
        yearsBack = currentYear - START_YEAR

        [spyResult, hygResult] = await Promise.all([
            getEodData(SPY, yearsBack)
            getEodData(HYG, yearsBack)
        ])

        olog spyResult.meta
        olog hygResult.meta
        processData(spyResult, hygResult)
    catch err
        log "fetch error: #{err.message}"
    return

############################################################
# Public: activate frame — fetch if needed, then render chart
export activate = ->
    log "activate"
    unless cachedStates?
        await fetchData()
    unless chartHandle?
        renderChart()
    return

############################################################
#region EMA and state calculation

calculateEMA = (data, period) ->
    ema = new Array(data.length).fill(null)

    # SMA seed from first `period` valid values
    sum = 0
    count = 0
    seedIdx = -1
    for i in [0...data.length]
        continue unless data[i]?
        sum += data[i]
        count++
        if count == period
            seedIdx = i
            ema[i] = sum / period
            break

    return ema if seedIdx < 0

    k = 2 / (period + 1)
    for i in [(seedIdx + 1)...data.length]
        prev = ema[i - 1]
        if data[i]? and prev?
            ema[i] = data[i] * k + prev * (1 - k)
        else
            ema[i] = prev

    return ema

# State logic:
#   green  = HYG above EMA for 2+ consecutive days (risk on)
#   blue   = single day break above EMA (recovery signal)
#   red    = HYG below EMA for 2+ consecutive days (risk off)
#   yellow = single day break below EMA (caution)
calculateStates = (closes, ema) ->
    states = new Array(closes.length).fill(null)
    aboveCount = 0
    belowCount = 0

    for i in [0...closes.length]
        continue unless closes[i]? and ema[i]?

        if closes[i] > ema[i]
            aboveCount++
            belowCount = 0
            states[i] = if aboveCount >= 2 then "green" else "blue"
        else
            belowCount++
            aboveCount = 0
            states[i] = if belowCount >= 2 then "red" else "yellow"

    return states

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

############################################################
#region UI updates

updateSidePanel = (state) ->
    el = document.getElementById("tl-side-container")
    return unless el?
    el.classList.remove("state-green", "state-yellow", "state-red", "state-blue")
    el.classList.add("state-#{state}") if state?
    return

updateNavIndicator = (state) ->
    el = document.getElementById("tl-nav-indicator")
    return unless el?
    el.classList.remove("state-green", "state-yellow", "state-red", "state-blue")
    el.classList.add("state-#{state}") if state?
    return

#endregion

############################################################
processData = (spyResult, hygResult) ->
    log "processData"
    spyData = spyResult.data
    hygData = hygResult.data
    return unless spyData?.length and hygData?.length

    # Align by start date
    spyStart = new Date(spyResult.meta.startDate + "T12:00:00")
    hygStart = new Date(hygResult.meta.startDate + "T12:00:00")

    if hygStart > spyStart
        offset = Math.round((hygStart - spyStart) / 86400000)
        spyData = spyData.slice(offset)
        startDate = hygStart
    else if spyStart > hygStart
        offset = Math.round((spyStart - hygStart) / 86400000)
        hygData = hygData.slice(offset)
        startDate = spyStart
    else
        startDate = spyStart

    len = Math.min(spyData.length, hygData.length)

    # Build aligned arrays
    timestamps = new Array(len)
    spyCloses = new Array(len)
    hygCloses = new Array(len)
    d = new Date(startDate)

    for i in [0...len]
        timestamps[i] = d.getTime() / 1000
        spyCloses[i] = spyData[i][2]
        hygCloses[i] = hygData[i][2]
        d.setDate(d.getDate() + 1)

    # HYG analysis
    ema = calculateEMA(hygCloses, EMA_PERIOD)
    states = calculateStates(hygCloses, ema)

    # Find current state
    lastState = null
    j = states.length - 1
    while j >= 0
        if states[j]?
            lastState = states[j]
            break
        j--

    # Cache results
    cachedTimestamps = timestamps
    cachedSpyCloses = spyCloses
    cachedStates = states
    currentState = lastState

    # Update indicators
    updateNavIndicator(currentState)
    updateSidePanel(currentState)
    return

############################################################
renderChart = ->
    log "renderChart"
    return unless cachedTimestamps?

    container = document.getElementById("trafficlight-chart")
    return unless container?

    rect = container.getBoundingClientRect()
    w = Math.floor(rect.width)
    h = Math.floor(rect.height)
    return unless w > 0 and h > 0

    options = {
        width: w - 15
        height: h
        padding: [30, 15, 15, 15]
        plugins: [createStatePlugin(cachedStates, cachedTimestamps)]
        scales: {
            x: { time: true }
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
                    splits.map (ts) ->
                        d = new Date(ts * 1000)
                        String(d.getFullYear())
            }
            {
                show: false
            }
        ]
        cursor: {
            show: false
        }
    }

    if chartHandle?
        chartHandle.destroy()
        container.innerHTML = ""

    chartHandle = new uPlot(options, [cachedTimestamps, cachedSpyCloses], container)
    return
