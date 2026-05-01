############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("traffliclightdata")
#endregion

############################################################
import { getEodData } from "./scimodule.js"
import { getAuthCode } from "./accountmodule.js"
import * as liveD from "./livedata.js"
import * as colorS from "./colorstates.js"

############################################################
# SPY = S&P 500 ETF
# HYG = iShares iBoxx $ High Yield Corporate Bond ETF
SPY = "SPY"
HYG = "HYG"
############################################################
START_YEAR = 2019

############################################################
# Cached data (populated by fetchData, used by chart)
cachedTimestamps = null
cachedSpyCloses = null
cachedStates = null

############################################################
lastFetch = null

############################################################
onStateChange = null

############################################################
hygLivePrice = null

############################################################
heartbeatMS = 3_600_000 # 6min
initialDelayMS = 15_000 # 15s

############################################################
export initialize = ->
    log "initialize"
    setInterval(heartbeat, heartbeatMS)
    setTimeout(heartbeat, initialDelayMS)
    liveD.setOnLiveUpdateListener(onLiveDataUpdate)
    return

############################################################
export heartbeat = ->
    log "heartbeat"
    try 
        await liveD.connectAndSubscribe()
        await fetchData()
    catch err then console.error(err) # should not throw actually
    return

############################################################
export setOnStateChangeListener = (listener) -> onStateChange = listener

############################################################
export getRenderData = -> { cachedTimestamps, cachedSpyCloses, cachedStates }

############################################################
dataIsRecent = ->
    return false if !lastFetch?
    now = Date.now()
    return (now - lastFetch) < (2 * 60 * 60 * 1000) # less than 2 hours ago

############################################################
onLiveDataUpdate = (price) ->
    log "onLiveDataUpdate"
    newState = colorS.getCurrentPriceState(price)
    onStateChange(newState)
    return

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
        spyCloses[i] = spyData[i][spyData[i].length - 1]
        hygCloses[i] = hygData[i][hygData[i].length - 1]
        d.setDate(d.getDate() + 1)

    # EMA analysis -> color states
    colorS.initEMA(hygCloses)
    states = colorS.getAllColorStates()

    # Cache results and save state
    cachedTimestamps = timestamps
    cachedSpyCloses = spyCloses
    cachedStates = states
    currentState = states[states.length - 1]
    return

############################################################
fetchData = ->
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

        # olog spyResult.meta
        # olog hygResult.meta
        lastFetch = Date.now()
        processData(spyResult, hygResult)
        onStateChange(currentState)
    catch err
        log "fetch error: #{err.message}"
    return

