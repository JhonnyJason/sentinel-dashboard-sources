############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("datamodule")
#endregion

############################################################
import * as cfg from "./configmodule.js"
import * as summary from "./summaryframemodule.js"

############################################################
socket = null
socketOpen = false

############################################################
export initialize = ->
    log "initialize"
    createSocket()
    return

createSocket = ->
    log "createSocket"
    try
        socket = new WebSocket(cfg.backendWSURL)

        socket.addEventListener("open", socketOpened)
        socket.addEventListener("message", receiveData)
        socket.addEventListener("error", receiveError)
        socket.addEventListener("close", socketClosed)

    catch err then log err
    return

############################################################
heartbeat = ->
    log "heartbeat"
    olog { socketOpen }
    if socketOpen
        socket.send("getAllData")
        log "should only send command 'getAllData'"
    else 
        log "now we create a new Websocket..."
        createSocket()
    return

socketOpened = (evnt) ->
    log "socketOpened"
    socketOpen = true
    socket.send("getAllData")
    return

receiveData = (evnt) ->
    log "receiveData"
    try
        # log evnt.data
        data = JSON.parse(evnt.data)
        # olog data
        summary.updateData(data)
        ## Update other parts
    catch err then log err
    return

receiveError = (evnt) ->
    log "receiveError"
    olog evnt
    return

socketClosed = (evnt) ->
    log "socketClosed"
    log evnt.reason
    socketOpen = false
    socket = null
    return


############################################################
export startHeartbeat = -> setInterval(heartbeat, cfg.heartbeatMS)
