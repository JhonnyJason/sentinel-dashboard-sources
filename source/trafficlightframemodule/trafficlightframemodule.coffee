############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("trafficlightframemodule")
#endregion

############################################################
import * as chart from "./chartrendering.js"
import * as tData from "./trafficlightdata.js"

############################################################
currentState = null

############################################################
export initialize = ->
    chart.initZoomControl()
    tData.initialize()
    tData.setOnStateChangeListener(onLiveStateChange)
    return

############################################################
export activate = ->
    log "activate"
    await tData.heartbeat()
    renderData = tData.getRenderData()
    chart.renderChart(renderData) # will not cause unnecessary rerenders
    return

############################################################
onLiveStateChange = (newState) ->
    return if newState == currentState
    log "live state change: #{currentState} -> #{newState}"
    currentState = newState
    updateNavIndicator(currentState)
    updateSidePanel(currentState)
    return

############################################################
#region UI updates

updateSidePanel = (state) ->
    el = document.getElementById("tl-side-container")
    return unless el?
    el.classList.remove("state-green", "state-yellow", "state-red", "state-blue")
    el.classList.add("state-#{state}") if state
    return

updateNavIndicator = (state) ->
    el = document.getElementById("tl-nav-indicator")
    return unless el?
    el.classList.remove("state-green", "state-yellow", "state-red", "state-blue")
    el.classList.add("state-#{state}") if state
    return

#endregion
