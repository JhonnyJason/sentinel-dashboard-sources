############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("appcoremodule")
#endregion

############################################################
import * as nav from "navhandler"
import * as triggers from "./navtriggers.js"
import * as uiState from "./uistatemodule.js"

############################################################
import { appVersion } from "./configmodule.js"

############################################################
defaultBaseState = "summary"

############################################################
appBaseState = "summary"
appUIMod = "none"
appContext = {}

############################################################
validPassphrase = false


############################################################
#region DOM Cache fix
currentVersion = document.getElementById("current-version")

#endregion

############################################################
export initialize = ->
    log "initialize"
    # nav.initialize(setNavState, setNavState, true)
    nav.initialize(setNavState, setNavState)

    currentVersion.textContent = appVersion
    
    ## Do we nbeed a serviceworker?
    if serviceWorker?
        serviceWorker.register("serviceworker.js", {scope: "/"})
        if serviceWorker.controller?
            serviceWorker.controller.postMessage("App is version: #{appVersion}!")
        serviceWorker.addEventListener("message", onServiceWorkerMessage)
        serviceWorker.addEventListener("controllerchange", onServiceWorkerSwitch)
    
    return


# loadAppWithNavState = (navState) ->
#     log "loadAppWithNavState"
#     baseState = navState.base
#     modifier = navState.modifier
#     context = navState.context

#     # S.save("navState", navState)

#     # urlCode = getCodeFromURL()
#     # await startUp()

#     # if urlCode? then return nav.toMod("codeverification")

#     # setUIState(baseState, modifier, context)
    
#     # if appBaseState == "no-code" then triggers.addCode()
#     return

############################################################
setNavState = (navState) ->
    log "setNavState"
    baseState = navState.base
    modifier = navState.modifier
    context = navState.context

    if baseState == "RootState" then baseState = defaultBaseState

    setAppState(baseState, modifier, context)
    # S.save("navState", navState)    
    return


setAppState = (base, mod, ctx) ->
    log "setAppState"
    if base then appBaseState = base
    if mod then appUIMod = mod
    log "#{appBaseState}:#{appUIMod}"

    uiState.applyUIState(appBaseState, appUIMod)
    return
