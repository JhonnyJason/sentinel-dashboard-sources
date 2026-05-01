############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("livedata")
#endregion

############################################################
import { getAuthCode } from "./accountmodule.js"
import * as cfg from "./configmodule.js"

############################################################
HYG = "HYG"
############################################################
RECONNECT_DELAY = 5000

############################################################
socket = null
active = false

############################################################
onPriceUpdate = null

############################################################
export connectAndSubscribe = ->
    log "connectAndSubscribe"
    authCode = getAuthCode()
    connect() unless !authCode?
    return

############################################################
export setOnLiveUpdateListener = (listener) -> onPriceUpdate = listener

############################################################
connect = ->
    log "connecting"
    try
        return if active and socket?
        active = true
        socket = new WebSocket(cfg.urlDatahub)
        socket.addEventListener("open", onOpen)
        socket.addEventListener("message", onMessage)
        socket.addEventListener("error", onError)
        socket.addEventListener("close", onClose)
    catch err
        log "connect error: #{err.message}"
    return

############################################################
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

############################################################
onMessage = (evnt) ->
    parts = evnt.data.split(" ")
    switch parts[0]
        when "liveDataUpdate"
            if parts[1] == HYG
                price = parseFloat(parts[2])
                onPriceUpdate(price) unless !onPriceUpdate? or isNaN(price)
        when "subscribe"
            if parts[1] == "success"
                log "subscribed to #{parts[2]}"
            else if parts[1] == "error"
                log "subscription error: #{parts[2]}"
    return

############################################################
onError = (err) ->
    log "socket error"
    console.error(err)
    return

############################################################
onClose = ->
    log "socket closed"
    destroySocket()
    if active then setTimeout(connect, RECONNECT_DELAY)
    return
