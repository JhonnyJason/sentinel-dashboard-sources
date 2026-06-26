############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("livedatamodule")
#endregion

############################################################
import { getAuthCode } from "./accountmodule.js"
import * as cfg from "./configmodule.js"

############################################################
RECONNECT_DELAY = 5000

############################################################
heartbeatMS = 15_000 # 20s
initialDelayMS = 5_000 # 15s

############################################################
socket = null
active = false
connecting = false

############################################################
symToListeners = Object.create(null)


############################################################
onPriceUpdate = null

############################################################
export initialize = ->
    log "initialize"
    setInterval(heartbeat, heartbeatMS)
    setTimeout(heartbeat, initialDelayMS)
    return

############################################################
heartbeat = ->
    log "heartbeat"
    connect() unless connecting or socket? and active
    return

    
############################################################
connectAndSubscribe = ->
    log "connectAndSubscribe"
    authCode = getAuthCode()
    connect() unless !authCode?
    return


############################################################
connect = ->
    log "connecting"
    try
        return if active and socket?
        active = true
        connecting = true
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
    connecting = false
    authCode = getAuthCode()
    unless authCode?
        log "no auth, closing"
        destroySocket()
        return
    
    for sym in Object.keys(symToListeners)
        socket.send("subscribe #{authCode} #{sym}")
    return

############################################################
onMessage = (evnt) ->
    parts = evnt.data.split(" ")
    switch parts[0]
        when "liveDataUpdate"
            if symToListeners[parts[1]]?
                price = parseFloat(parts[2])
                if isNaN(price) then return log "price for #{parts[1]} is NaN!"
                listener(parts[1], price) for listener in symToListeners[parts[1]] 
            else log "no listener for Symbol: #{parts[1]}"

        when "subscribe"
            if parts[1] == "success"
                log "subscribed to #{parts[2]}"
            else if parts[1] == "error"
                log "subscription error: #{parts[2]}"
    return

############################################################
onError = (err) ->
    log "socket error"
    connecting = false
    console.error(err)
    return

############################################################
onClose = ->
    log "socket closed"
    destroySocket()
    connecting = false
    if active then setTimeout(connect, RECONNECT_DELAY)
    return


############################################################
export listenOnSymbolsData = (symbols, listener) ->
    log "listenOnSymbolsData"
    throw new Error("listener is not a function") unless typeof listener == "function"
    log symbols

    for sym in symbols
        if !symToListeners[sym]? then symToListeners[sym] = [listener]
        else symToListeners[sym].push(listener)
    
    authCode = getAuthCode()
    if  active and socket? and authCode? # seems we are connected :-)
        socket.send("subscribe #{authCode} #{sym}") for sym in symbols
    return
