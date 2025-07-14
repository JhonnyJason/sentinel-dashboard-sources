############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("summaryframemodule")
#endregion

dataSetterMap = {}


############################################################
export initialize = ->
    log "initialize"
    dataSetterMap = {
        "eurozone": setEuroData,
        "usa": setUSData,
        "japan": setJapanData,
        "switzerland": setSwissData,
        "canada": setCanadaData,
        "australia": setAussieData,
        "newzealand": setZealandData,
        "uk": setUKData
    }
    return


############################################################
export updateData = (data) ->
    log "updateData"
    # keys = Object.keys(data)
    # log keys
    for lbl,d of data
        # log lbl
        # olog d
        if typeof dataSetterMap[lbl] == "function" then dataSetterMap[lbl](d)
        else log "No dataSetterFound for #{lbl}!"
    return


############################################################
setEuroData = (d) ->
    log "setEuroData"
    olog d
    cardEl = eurozone

    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return

setUSData = (d) ->
    log "setUSData"
    olog d
    cardEl = usa
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"

    return

setJapanData = (d) ->
    log "setJapanData"
    olog d
    cardEl = japan
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return


setSwissData = (d) ->
    log "setSwissData"
    olog d
    cardEl = switzerland
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return

setCanadaData = (d) ->
    log "setCanadaData"
    olog d
    cardEl = canada
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return

setAussieData = (d) ->
    log "setAussieData"
    olog d
    cardEl = australia
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return

setZealandData = (d) ->
    log "setZealandData"
    olog d
    cardEl = newzealand
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    return

setUKData = (d) ->
    log "setUKData"
    olog d
    cardEl = uk
    
    inflationOuter = cardEl.getElementsByClassName("inflation-rate")[0]
    inflationValue = inflationOuter.getElementsByClassName("value")[0]
    inflationValue.textContent = "#{d.hicp}"

    refinancingOuter = cardEl.getElementsByClassName("refinancing-rate")[0]
    refinancingValue = refinancingOuter.getElementsByClassName("value")[0]
    refinancingValue.textContent = "#{d.mrr}"

    gdpgrowthOuter = cardEl.getElementsByClassName("gdp-growth")[0]
    gdpgrowthValue = gdpgrowthOuter.getElementsByClassName("value")[0]
    gdpgrowthValue.textContent = "#{d.gdpg}"
    
    return
