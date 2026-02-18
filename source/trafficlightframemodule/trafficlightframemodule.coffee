############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("trafficlightframemodule")
#endregion

############################################################
import { getEodData } from "./scimodule.js"
import { getAuthCode } from "./accountmodule.js"
import { calculateEMA, calculateStates } from "./emacalc.js"
import * as chart from "./chartrendering.js"
import * as live from "./livedata.js"

############################################################
# SPY = S&P 500 ETF
# HYG = iShares iBoxx $ High Yield Corporate Bond ETF
SPY = "SPY"
HYG = "HYG"
START_YEAR = 2019
EMA_PERIOD = 20

############################################################
# Cached data (populated by fetchData, used by chart)
cachedTimestamps = null
cachedSpyCloses = null
cachedStates = null
currentState = null
lastFetch = null

############################################################
export initialize = ->
    chart.initZoomControl()
    return

############################################################
# Public: fetch data silently, compute state, update indicators
# Can be called early (e.g. on login) without rendering the chart
export fetchData = ->
    log "fetchData"
    return if cachedStates? and dataIsRecent()

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
        lastFetch = Date.now()
        processData(spyResult, hygResult)
    catch err
        log "fetch error: #{err.message}"
    return

############################################################
# Public: activate frame — fetch if needed, then render chart
export activate = ->
    log "activate"
    unless cachedStates? and dataIsRecent()
        await fetchData()
    unless chart.isRendered()
        chart.renderChart(cachedTimestamps, cachedSpyCloses, cachedStates)
    return


dataIsRecent = ->
    return false if !lastFetch?
    now = Date.now()
    return (now - lastFetch) < (2 * 60 * 60 * 1000) # less than 2 hours ago


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

    # Find current state and last valid EMA
    lastState = null
    lastEmaValue = null
    j = states.length - 1
    while j >= 0
        if states[j]?
            lastState = states[j] unless lastState?
        if ema[j]?
            lastEmaValue = ema[j] unless lastEmaValue?
        break if lastState? and lastEmaValue?
        j--

    # Cache results
    cachedTimestamps = timestamps
    cachedSpyCloses = spyCloses
    cachedStates = states
    currentState = lastState

    # Update indicators
    updateNavIndicator(currentState)
    updateSidePanel(currentState)

    # Start live HYG subscription for real-time state updates
    live.start
        lastEma: lastEmaValue
        emaK: 2 / (EMA_PERIOD + 1)
        currentState: currentState
        onStateChange: onLiveStateChange
    return

############################################################
onLiveStateChange = (newState) ->
    return if newState == currentState
    log "live state change: #{currentState} -> #{newState}"
    currentState = newState
    updateNavIndicator(currentState)
    updateSidePanel(currentState)
    return

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
