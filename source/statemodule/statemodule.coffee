############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("statemodule")
#endregion

############################################################
import * as cfg from "./configmodule.js"

############################################################
#region Internal Properties
defaultState = Object.create(null)
if cfg.defaultstate? then defaultState[k] = c for k,c of cfg.defaultstate

############################################################
try state = JSON.parse(localStorage.getItem("state"))
if !state? or typeof state != "object" then state = Object.create(null)

############################################################
allStates = Object.create(null)
listeners = Object.create(null)
changeDetectors = Object.create(null)

############################################################
( -> # immediate call function, we need to initialize here

    # normalize state to be { key: { content }, ... } 
    for key,content of state
        if !content? then content = null
        if !content? or !content.content? then state[key] = {content}
        allStates[key] = state[key]

    # also digest defaultState (non-overwritten)
    isVolatile = true # defaultState has no storage yet -> volatile
    for key,content of defaultState when !allStates[key]?
        allStates[key] = {content, isVolatile}
    return
)()

#endregion

############################################################
#region Internal Functions

############################################################
loadDedicated = (key) ->
    log "loadDedicated"
    isDedicated = true
    try content = JSON.parse(localStorage.getItem(key))
    if !content? then content = null    
    allStates[key] = { content, isDedicated }
    return content
    
############################################################
saveDedicatedState = (key) ->
    log "saveDedicatedState"
    # log key
    # olog {allStates}
    content = allStates[key].content
    allStates[key].isDedicated = true
    contentString = JSON.stringify(content)
    localStorage.setItem(key, contentString)    
    return

############################################################
saveRegularState = ->
    log "saveRegularState"
    stateString = JSON.stringify(state)
    localStorage.setItem("state", stateString)
    return

############################################################
allmightySetAndSave = (key, content, isDedicated, silent) ->
    cstt = allStates[key] # current state obj of this key

    isVolatile = (cstt? and cstt.isVolatile)
    # saving in storage makes it non-volatile
    if isVolatile then delete cstt.isVolatile
    
    # print("isDedicated: "+ isDedicated)
    if typeof isDedicated != "boolean"
        isDedicated = (cstt? and (cstt.isDedicated == true))
        ## true when it existed and was isDedicated
        ## false if it did not exist
        ## false if it was not isDedicated

    if cstt?
        if cstt.isDedicated then isDedicatedChanged = (isDedicated != cstt.isDedicated)
        else isDedicatedChanged = isDedicated
        
        contentChanged = changeDetected(key, content)
        typeChanged = isVolatile or isDedicatedChanged
        # without any detected change we donot reflect nor propagate the new content in the state
        return unless contentChanged or typeChanged

        if isDedicated then cstt.isDedicated = true
        if isDedicatedChanged and !isDedicated
            localStorage.removeItem(key)
            delete cstt.isDedicated
        cstt.content = content
        
    else allStates[key] = { content, isDedicated }

    # Execute the saving
    if isDedicated
        saveDedicatedState(key)
        if state[key]?
            delete state[key]
            saveRegularState()
    else
        if !state[key]? then state[key] = allStates[key].content
        saveRegularState()

    if silent then return
    return callOnChangeListeners(key)
    
############################################################
saveAllStates = ->
    log "saveAllStates"
    # olog allStates
    for key,content of allStates when content.isDedicated
        saveDedicatedState(key)
    saveRegularState()
    return


############################################################
allmightySet = (key, content, silent) ->
    isVolatile = true
    return unless changeDetected(key, content)

    try allStates[key].content = content
    catch err then allStates[key] = {content,isVolatile}
    
    if silent then return
    return callOnChangeListeners(key)

############################################################
callOnChangeListeners = (key) ->
    return if !listeners[key]?
    promises = (fun() for fun in listeners[key])
    return await Promise.all(promises)

############################################################
#region State Change Functions 
hasChanged = (oldContent, newContent) -> oldContent != newContent

changeDetected = (key, content) ->
    detector = changeDetectors[key] || hasChanged
    cstt = allStates[key] # current state
    return true if !cstt? or !cstt.content?
    return detector(cstt.content, content)

#endregion

#endregion

############################################################
#region Exposed Functions

export getState = -> allStates

############################################################
#region localStorage Related Functions
export load = (key) ->
    log "load"
    # olog {allStates}
    if allStates[key]? and allStates[key].isVolatile
        # might originate from defaultState -> load defaults
        if defaultState[key]? then allStates[key].content = defaultState[key] 
        return allStates[key].content

    if allStates[key]? and !allStates[key].isDedicated
        # regular state -> load from "state" object
        tmpState = localStorage.getItem("state")
        if !tmpState? then return (allStates[key].content = null)

        tmpState = JSON.parse(tmpState)
        state[key] = tmpState[key]
        if !tmpState[key]? then return (allStates[key].content = null)

        if typeof tmpState[key].content == "object"
            return (allStates[key].content = tmpState[key].content)
        else
            return (allStates[key].content = tmpState[key])
             
    return loadDedicated(key)

############################################################
export save = (key, content, isDedicated) ->
    log "save"
    return unless key?
    if !content? and !isDedicated? then saveDedicatedState(key)
    else return allmightySetAndSave(key, content, isDedicated, false)

############################################################
export saveSilently = (key, content, isDedicated) ->
    log "saveSilently"
    return unless key?
    if !content? and !isDedicated? then saveDedicatedState(key)
    else return allmightySetAndSave(key, content, isDedicated, true)

############################################################
export saveAll = saveAllStates
export saveRegular = saveRegularState

############################################################
export remove = (key) ->
    log "remove"
    return unless key?
    return unless allStates[key]?

    removed = allStates[key]
    delete allStates[key]
    delete listeners[key]

    if removed.isVolatile then return    
    if removed.isDedicated then localStorage.removeItem(key)
    else # regular state
        delete state[key]
        saveRegularState()
    return

#endregion

############################################################
#region Getter + Setter Functions
export get = (key) ->
    return undefined unless allStates[key]? 
    return allStates[key].content

############################################################
export set = (key, content) ->
    log "set"
    allmightySet(key, content, false)
    return

############################################################
export setSilently = (key, content) ->
    log "setSilently"
    allmightySet(key, content, true)
    return

#endregion

############################################################
#region State Change Related Functions
export addOnChangeListener = (key, fun) ->
    log "addOnChangeListener"
    if !listeners[key]? then listeners[key] = []
    listeners[key].push(fun)
    return

############################################################
export removeOnChangeListener = (key, fun) ->
    log "removeOnChangeListener"
    candidates = listeners[key]
    return unless Array.isArray(candidates) and candidates.length > 0
    listeners[key] = []
    listeners[key].push(candy) for candy in candidates when candy != fun
    return

############################################################
export clearOnChangeListeners = (key) ->
    log "clearOnChangeListener"
    listeners[key] = []
    return

############################################################
export callOutChange = (key) -> callOnChangeListeners(key)

############################################################
export setChangeDetectionFunction = (key, fun) ->
    if !fun? then delete changeDetectors[key]
    else changeDetectors[key] = fun
    return

#endregion

#endregion