############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("summaryframemodule")
#endregion

############################################################
import { allAreas } from "./economicareasmodule.js"
import { renderFrame } from "./currencytrendframemodule.js"

############################################################
export initialize = ->
    log "initialize"
    for key,area of allAreas
        log key
        domNode = area.getElement()
        log domNode
        economicAreas.appendChild(domNode) 
    return

############################################################
export updateData = (data) ->
    log "updateData"
    # keys = Object.keys(data)
    # log keys
    for key,d of data
        # log lbl
        # olog d
        area = allAreas[key]
        if area? then area.updateData(d) 
        else log("No Economic Area by key: #{key}")
    
    try renderFrame()
    catch err then console.error(err)
    return