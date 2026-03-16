############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("EconomicArea")
#endregion

############################################################
import M from "mustache"

############################################################
import { inflNorm, mrrNorm, gdpgNorm, cotNorm } from "./areanorm.js"

############################################################
economicAreaTemplate = document.getElementById("economic-area-template").innerHTML

############################################################
export class EconomicArea
    constructor:  (o) ->
        @key = o.key
        @title = o.title
        @currencyName = o.currencyName
        @currencyShort = o.currencyShort

        @updateListeners = []

        @metaData = {
            infl: {}
            mrr: {}
            gdpg: {}
        }

        @data = {
            infl: NaN
            mrr: NaN
            gdpg: NaN
            cot36: NaN
            cot6: NaN
        }

        @params = {
            infl: o.inflParams
            mrr: o.mrrParams
            gdpg: o.gdpgParams
            cot: o.cotParams
        }

        @normFun = {
            infl: => inflNorm(@data, @params)
            mrr: => mrrNorm(@data, @params)
            gdpg: => gdpgNorm(@data, @params)
            cot: => cotNorm(@data, @params)
        }
       
        cObj = {
            "icon-href": o["icon-href"]
            title: o.title
            inflation: @data.infl
            policyRate: @data.mrr
            gdpg: @data.gdpg
            cotIndex36: @data.cot36
            cotIndex6: @data.cot6
        }

        virtualContainer = document.createElement("v")
        olog {virtualContainer}
        html = M.render(economicAreaTemplate, cObj)
        virtualContainer.innerHTML = html.trim()
        log html
        @element = virtualContainer.firstChild
        
        p = @element.getElementsByClassName("inflation-rate")[0]
        @inflationEl = p.getElementsByClassName("value")[0]
        infoButton = p.getElementsByClassName("info-button")[0]
        infoButton.addEventListener("click", @inflationInfoClicked)

        p = @element.getElementsByClassName("refinancing-rate")[0]
        @refinancingEl = p.getElementsByClassName("value")[0]
        infoButton = p.getElementsByClassName("info-button")[0]
        infoButton.addEventListener("click", @refinancingInfoClicked)

        p = @element.getElementsByClassName("gdp-growth")[0]
        @gdpgrowthEl = p.getElementsByClassName("value")[0]
        infoButton = p.getElementsByClassName("info-button")[0]
        infoButton.addEventListener("click", @gdpGrowthInfoClicked)

        p = @element.getElementsByClassName("cot-index-6")[0]
        @cot6El = p.getElementsByClassName("value")[0]
        
        p = @element.getElementsByClassName("cot-index-36")[0]
        @cot36El = p.getElementsByClassName("value")[0]
        
        p = @element.getElementsByClassName("info-display")[0]
        @infoTitleEl = p.getElementsByClassName("info-title")[0]
        @infoDescriptionEl = p.getElementsByClassName("info-description")[0]
        
        closeButton = p.getElementsByClassName("close-button")[0]
        closeButton.addEventListener("click", @resetInfoDisplay)

    ########################################################
    getHICP: => @data.infl
    getINFL: => @data.infl
    getMRR: => @data.mrr
    getGDPG: => @data.gdpg
    getCOTIndex36: => @data.cot36
    getCOTIndex6: => @data.cot6
    getCOT36: => @data.cot36
    getCOT6: => @data.cot6

    ########################################################
    getElement: => @element

    ########################################################
    updateData: (d) =>
        # console.log(Object.keys(d))
    
        @metaData.infl = d.inflMeta || d.hicpMeta
        @metaData.mrr = d.mrrMeta
        @metaData.gdpg = d.gdpgMeta

        if d.infl? then infl = d.infl
        else infl = d.hicp
        @data.infl = parseFloat(infl)
        @inflationEl.textContent = "#{infl}"
        
        @data.mrr = parseFloat(d.mrr)
        @refinancingEl.textContent = "#{d.mrr}"

        @data.gdpg = parseFloat(d.gdpg)
        @gdpgrowthEl.textContent = "#{d.gdpg}"

        if d.cot36? then @data.cot36 = parseFloat(d.cot36)
        else @data.cot36 = parseFloat(d.cotIndex36) 
        @cot36El.textContent = "#{Math.round(@data.cot36)}%"
        @cot36El.classList.remove("strong")
        @cot36El.classList.remove("weak")
        if @data.cot36 >= 70 then @cot36El.classList.add("strong")
        if @data.cot36 <= 30 then @cot36El.classList.add("weak")

        if d.cot6? then @data.cot6 = parseFloat(d.cot6)
        else @data.cot6 = parseFloat(d.cotIndex6) 
        @cot6El.textContent = "#{Math.round(@data.cot6)}%"
        @cot6El.classList.remove("strong")
        @cot6El.classList.remove("weak")
        if @data.cot6 >= 70 then @cot6El.classList.add("strong")
        if @data.cot6 <= 30 then @cot6El.classList.add("weak")

        @params = d._params

        f() for f in @updateListeners         
        return

    ########################################################
    addUpdateListener: (fun) =>
        throw new Error("Not a function!") unless typeof fun == "function" 
        @updateListeners.push(fun)
        return

    removeUpdateListener: (fun) =>
        @updateListeners[i] = null for f,i in @updateListeners when f == fun
        @updateListeners = @updateListeners.filter((el) -> el?)
        return

    ########################################################
    inflationInfoClicked: (evnt) =>
        @element.classList.add("show-info")
        @infoTitleEl.textContent = "Inflation (#{@title})"

        m  = @metaData.infl
        @infoDescriptionEl.innerHTML = "<p>#{m.dataSet}<br>Quelle: #{m.source}</p><p class='info-date'>@#{m.date}</p>"
        return
    
    refinancingInfoClicked: (evnt) =>
        @element.classList.add("show-info")
        @infoTitleEl.textContent = "Leitzins (#{@title})"
        
        m  = @metaData.mrr
        @infoDescriptionEl.innerHTML = "<p>#{m.dataSet}<br>Quelle: #{m.source}</p><p class='info-date'>@#{(new Date(m.date)).toLocaleDateString()}</p>"
        return

    gdpGrowthInfoClicked: (evnt) =>
        @element.classList.add("show-info")
        @infoTitleEl.textContent = "GDP Wachstum (#{@title})"
        m  = @metaData.gdpg
        @infoDescriptionEl.innerHTML = "<p>#{m.dataSet}<br>Quelle: #{m.source}</p><p class='info-date'>@#{m.date}</p>"
        return

    resetInfoDisplay: =>
        @element.classList.remove("show-info")
        @infoTitleEl.textContent = ""
        @infoDescriptionEl.textContent = ""
        return
    

