############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("noaccountmodule")
#endregion

############################################################
export initialize = ->
    log "initialize"
    #Implement or Remove :-)
    return


############################################################
## Export UI state modifiers
export hide = ->
    log "hide"
    noaccountframe.className = "hidden"
    return

export noAction = ->
    log "noAction"
    return

export finalizeAction = (ctx) ->
    log "finalizeAction"
    olog ctx
    return