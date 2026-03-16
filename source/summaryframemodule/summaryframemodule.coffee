############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("summaryframemodule")
#endregion

############################################################
import { allAreas } from "./economicareasmodule.js"
import { scheduleRankingUpdate } from "./currencytrendframemodule.js"
import { setGlobalParams } from "./scorehelper.js"

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
        # log key
        # olog d
        
        if key == "_params" # digest global params 
            setGlobalParams(d)
            continue

        area = allAreas[key]
        if area? then area.updateData(d) 
        else log("No Economic Area by key: #{key}")
    
    scheduleRankingUpdate()
    return

    ## Reference how the data is created
    # pubShot = paramdata.getPublishedSnapshot()
    # data = getAllMakroData()
    # data.eurozone._params = pubShot.areaParams.eurozone
    # data._params = params.globalParams
