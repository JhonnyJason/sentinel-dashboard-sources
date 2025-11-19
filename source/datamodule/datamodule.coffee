############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("datamodule")
#endregion

############################################################
import * as cfg from "./configmodule.js"
import * as summary from "./summaryframemodule.js"
import { getAuthCode } from "./accountmodule.js"

############################################################
socket = null

############################################################
export initialize = ->
    log "initialize"
    createSocket()
    return

createSocket = ->
    log "createSocket"
    try
        socket = new WebSocket(cfg.urlWebsocketBackend)

        socket.addEventListener("open", socketOpened)
        socket.addEventListener("message", receiveData)
        socket.addEventListener("error", receiveError)
        socket.addEventListener("close", socketClosed)

    catch err then log err
    return

############################################################
export heartbeat = ->
    log "heartbeat"
    if !socket? then return createSocket()
    
    if socket.readyState == WebSocket.OPEN
        socket.send("getAllData #{getAuthCode()}")
        return

    if socket.readyState == WebSocket.socketClosed
        destroySocket()
        return
    return

############################################################
socketOpened = (evnt) ->
    log "socketOpened"
    socket.send("getAllData #{getAuthCode()}")
    return

receiveData = (evnt) ->
    log "receiveData"
    try
        # log evnt.data
        data = JSON.parse(evnt.data)
        # olog data
        summary.updateData(data)
        ## Update other parts
    catch err then console.error(err)
    return

receiveError = (evnt) ->
    log "receiveError"
    olog evnt
    return

socketClosed = (evnt) ->
    log "socketClosed"
    log evnt.reason
    destroySocket()
    return

destroySocket = ->
    return unless socket?
    socket.removeEventListener("open", socketOpened)
    socket.removeEventListener("message", receiveData)
    socket.removeEventListener("error", receiveError)
    socket.removeEventListener("close", socketClosed)
    socket = null
    return

############################################################
export startHeartbeat = -> setInterval(heartbeat, cfg.heartbeatMS)
