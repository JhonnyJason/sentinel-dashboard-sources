############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("trafficlightframemodule:live")
#endregion

############################################################
import { getAuthCode } from "./accountmodule.js"
import * as cfg from "./configmodule.js"
import { updateSingle } from "./emacalc.js"

############################################################
HYG = "HYG"
RECONNECT_DELAY = 5000

############################################################
socket = null
active = false

# EMA incremental state
lastEma = null
emaK = null
aboveCount = 0
belowCount = 0

# Callback to orchestrator
stateCallback = null

############################################################
# Start live subscription
# config: { lastEma, emaK, currentState, onStateChange }
export start = (config) ->
    return if active
    log "start"
    lastEma = config.lastEma
    emaK = config.emaK
    stateCallback = config.onStateChange

    # Derive consecutive counts from current state
    # Exact count beyond 2 doesn't affect transitions
    switch config.currentState
        when "green" then aboveCount = 2; belowCount = 0
        when "blue" then aboveCount = 1; belowCount = 0
        when "red" then aboveCount = 0; belowCount = 2
        when "yellow" then aboveCount = 0; belowCount = 1
        else aboveCount = 0; belowCount = 0

    active = true
    connect()
    return

############################################################
export stop = ->
    log "stop"
    active = false
    destroySocket()
    return

############################################################
connect = ->
    log "connecting"
    try
        socket = new WebSocket(cfg.urlDatahub)
        socket.addEventListener("open", onOpen)
        socket.addEventListener("message", onMessage)
        socket.addEventListener("error", onError)
        socket.addEventListener("close", onClose)
    catch err
        log "connect error: #{err.message}"
    return

destroySocket = ->
    return unless socket?
    socket.removeEventListener("open", onOpen)
    socket.removeEventListener("message", onMessage)
    socket.removeEventListener("error", onError)
    socket.removeEventListener("close", onClose)
    try socket.close()
    socket = null
    return

############################################################
onOpen = ->
    log "connected"
    authCode = getAuthCode()
    unless authCode?
        log "no auth, closing"
        destroySocket()
        return
    socket.send("subscribe #{authCode} #{HYG}")
    return

onMessage = (evnt) ->
    parts = evnt.data.split(" ")
    switch parts[0]
        when "liveDataUpdate"
            if parts[1] == HYG
                price = parseFloat(parts[2])
                processLivePrice(price) unless isNaN(price)
        when "subscribe"
            if parts[1] == "success"
                log "subscribed to #{parts[2]}"
            else if parts[1] == "error"
                log "subscription error: #{parts[2]}"
    return

onError = ->
    log "socket error"
    return

onClose = ->
    log "socket closed"
    destroySocket()
    if active
        log "reconnecting in #{RECONNECT_DELAY}ms"
        setTimeout(connect, RECONNECT_DELAY)
    return

############################################################
processLivePrice = (price) ->
    result = updateSingle(price, lastEma, emaK, aboveCount, belowCount)
    lastEma = result.ema
    aboveCount = result.aboveCount
    belowCount = result.belowCount
    if result.state? and stateCallback?
        stateCallback(result.state)
    return
