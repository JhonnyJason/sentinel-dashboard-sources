############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("datamodule")
#endregion

############################################################
import * as cfg from "./configmodule.js"
import * as summary from "./summaryframemodule.js"
import * as accM from "./accountmodule.js"

############################################################
socket = null
setSocketReady = null
readySocket = new Promise((rslv) -> setSocketReady = rslv)

############################################################
pendingRequests = Object.create(null)
firstLoad = false

############################################################
heartbeatMS = 60_000 # 60 s
COMMAND_TIMEOUT_MS = 20_000 # 10 s

############################################################
export initialize = ->
    log "initialize"
    createSocket()
    return

############################################################
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
sendCommand = (command, payload, expectedResponseType) ->
    new Promise (resolve, reject) ->
        try await readySocket
        catch err then reject(new Error("Socket not connected"))
        
        authCode = accM.getAuthCode()
        reject(new Error("We are not logged in!")) unless authCode?
        
        if payload? and typeof payload == "string"
            socket.send("#{command} #{authCode} #{payload}")
        else if payload?
            socket.send("#{command} #{authCode} #{JSON.stringify(payload)}")
        else
            socket.send("#{command} #{authCode}")
        
        requestTimedOut = ->
            if pendingRequests[expectedResponseType]?
                delete pendingRequests[expectedResponseType]
                reject(new Error("Timeout waiting for #{expectedResponseType}"))
            return

        timer = setTimeout(requestTimedOut, COMMAND_TIMEOUT_MS) 

        # overwriting previous requests is fine if we clear the previous timeout
        if pendingRequests[expectedResponseType]?
            clearTimeout(pendingRequests[expectedResponseType].timer)
        pendingRequests[expectedResponseType] = { resolve, reject, timer }
        return

############################################################
export heartbeat = ->
    log "heartbeat"
    if !socket? then return createSocket()
    
    if socket.readyState == WebSocket.OPEN
        executeFirstLoad() ## TODO remove this and listen on updates instead...
        # sendCommand("ping", null, "pong")
        return

    if socket.readyState == WebSocket.socketClosed
        destroySocket()
        return
    return

############################################################
socketOpened = (evnt) ->
    log "socketOpened"
    setSocketReady()
    if !firstLoad then executeFirstLoad()
    return

receiveData = (evnt) ->
    log "receiveData"
    try
        data = JSON.parse(evnt.data)
        olog data
        if(data == "Unauthorized!") then accM.assertAuthorization()
        
        ## TODO listen specifically on data updates
        
        # Compatibility with older version ;-)
        if !data.type? and typeof data == "object" and 
        pendingRequests["allData"]?
            pending = pendingRequests["allData"]
            delete pendingRequests["allData"]
            clearTimeout(pending.timer)
            pending.resolve(data)

        # Check pending promise-based requests first
        if data.type? and pendingRequests[data.type]?
            pending = pendingRequests[data.type]
            delete pendingRequests[data.type]
            clearTimeout(pending.timer)
            pending.resolve(data.data)
            return

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
    readySocket =  new Promise((rslv) -> setSocketReady = rslv)
    return

############################################################
executeFirstLoad = ->
    log "executeFirstLoad"
    try
        data = await sendCommand("getAllData", null, "allData")
        ## TODO upgrade to more sophisticated update mechanism
        summary.updateData(data)
        firstLoad = true
    catch err then log "@executeFirstLoad: "+err.messages
    return

############################################################
export startHeartbeat = -> setInterval(heartbeat, cfg.heartbeatMS)

############################################################
export getEventList = ->
    log "getEventSummary"
    return await sendCommand("getEventList", null, "eventList")

export getEventDates = (id) ->
    log "getEventDates"
    return await sendCommand("getEventDates", id, "eventDates:#{id}")
