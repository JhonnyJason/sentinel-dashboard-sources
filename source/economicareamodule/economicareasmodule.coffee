############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("economicareasmodule")
#endregion

############################################################
import M from "mustache"

############################################################
import * as scoreHelper from "./scorehelper.js"

############################################################
economicAreaTemplate = document.getElementById("economic-area-template").innerHTML

############################################################
class EconomicArea
    constructor:  (o) ->
        @key = o.key
        @title = o.title
        @currencyName = o.currencyName
        @currencyShort = o.currencyShort
        @updateListeners = []
        @calculateGDPScore = o.gdpScoreFunction

        @metaData = {
            hicp: {}
            mrr: {}
            gdpg: {}
        }
        @data = {
            hicp: "N/A"
            mrr: "N/A"
            gdpg: "N/A"
            cotIndex36: "N/A"
            cotIndex6: "N/A"
        }

        cObj = {
            "icon-href": o["icon-href"]
            "title": o.title
            "inflation": @data.hicp
            "policyRate": @data.mrr
            "gdpg": @data.gdpg
            "cotIndex36": @data.cotIndex36
            "cotIndex6": @data.cotIndex6
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
        @cotIndex6El = p.getElementsByClassName("value")[0]
        
        p = @element.getElementsByClassName("cot-index-36")[0]
        @cotIndex36El = p.getElementsByClassName("value")[0]
        
        p = @element.getElementsByClassName("info-display")[0]
        @infoTitleEl = p.getElementsByClassName("info-title")[0]
        @infoDescriptionEl = p.getElementsByClassName("info-description")[0]
        
        closeButton = p.getElementsByClassName("close-button")[0]
        closeButton.addEventListener("click", @resetInfoDisplay)

    ########################################################
    getHICP: => @data.hicp
    getMRR: => @data.mrr
    getGDPG: => @data.gdpg
    getCOTIndex36: => @data.cotIndex36
    getCOTIndex6: => @data.cotIndex6

    ########################################################
    getElement: => @element

    ########################################################
    updateData: (d) =>
        @metaData.hicp = d.hicpMeta
        @metaData.mrr = d.mrrMeta
        @metaData.gdpg = d.gdpgMeta

        @data.hicp = parseFloat(d.hicp)
        @inflationEl.textContent = "#{d.hicp}"
        
        @data.mrr = parseFloat(d.mrr)
        @refinancingEl.textContent = "#{d.mrr}"

        @data.gdpg = parseFloat(d.gdpg)
        @gdpgrowthEl.textContent = "#{d.gdpg}"

        @data.cotIndex36 = parseFloat(d.cotIndex36)
        @cotIndex36El.textContent = "#{Math.round(@data.cotIndex36)}"

        @data.cotIndex6 = parseFloat(d.cotIndex6)
        @cotIndex6El.textContent = "#{Math.round(@data.cotIndex6)}"

        @gdpScore = @calculateGDPScore(@data.gdpg)

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

        m  = @metaData.hicp
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

############################################################
eurozone = new EconomicArea({ #  351.4 mio Citizens 
    "icon-href": "#svg-europe-icon"
    "title": "Eurozone"
    "key": "eurozone"
    "currencyName": "Euro"
    "currencyShort":"EUR"
    "populationM": 351.4,
    "gdpScoreFunction": (gdpg) -> 
        switch
            when gdpg < 0.8 then return -1.0
            when gdpg < 1.5  then return 0.0
            when gdpg < 2.0 then return 2.0
            when gdpg < 3 then return 1.0
            else return -1.0
})

usa = new EconomicArea({ # 340.1mio Citizens
    "icon-href": "#svg-usa-icon"
    "title": "USA"
    "key": "usa"
    "currencyName": "US-Dollar"
    "currencyShort": "USD"
    "populationM": 340.1,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 1.5 then return -1.0
            when gdpg < 2  then return 0.0
            when gdpg < 2.5 then return 2.0
            when gdpg < 4 then return 1.0
            else return -1.0
})

japan =  new EconomicArea({ # 124mio Citizens
    "icon-href": "#svg-japan-icon"
    "title": "Japan"
    "key": "japan"
    "currencyName": "Yen"
    "currencyShort": "JPY"
    "populationM": 124,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 0.0 then return -1.0
            when gdpg < 1.0  then return 0.0
            when gdpg < 1.5 then return 2.0
            when gdpg < 2.5 then return 1.0
            else return -1.0

})

uk = new EconomicArea({ # 69.2mio Citizens
    "icon-href": "#svg-uk-icon"
    "title": "Großbritannien"
    "key": "uk"
    "currencyName": "Pfund"
    "currencyShort": "GBP"
    "populationM": 69.2,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 0.8 then return -1.0
            when gdpg < 1.5  then return 0.0
            when gdpg < 2.0 then return 2.0
            when gdpg < 3.5 then return 1.0
            else return -1.0

})

canada = new EconomicArea({ # 41.3mio Citizens
    "icon-href": "#svg-canada-icon"
    "title": "Kanada"
    "key": "canada"
    "currencyName": "Canada Dollar"
    "currencyShort": "CAD"
    "populationM": 41.3,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 1 then return -1.0
            when gdpg < 1.8  then return 0.0
            when gdpg < 2.2 then return 2.0
            when gdpg < 3.5 then return 1.0
            else return -1.0

})

australia = new EconomicArea({ # 27.4mio Citizens
    "icon-href": "#svg-australia-icon"
    "title": "Australien"
    "key": "australia"
    "currencyName": "Australia Dollar"
    "currencyShort": "AUD"
    "populationM": 27.4,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 1.5 then return -1.0
            when gdpg < 2.5  then return 0.0
            when gdpg < 3 then return 2.0
            when gdpg < 4 then return 1.0
            else return -1.0
})

switzerland = new EconomicArea({ # 9mio Citizens
    "icon-href": "#svg-switzerland-icon"
    "title": "Schweiz"
    "key": "switzerland"
    "currencyName": "Franken"
    "currencyShort": "CHF"
    "populationM": 9,
    "gdpScoreFunction": (gdpg) ->
        switch
            when gdpg < 0.5 then return -1.0
            when gdpg < 1.5  then return 0.0
            when gdpg < 2.0 then return 2.0
            when gdpg < 3.0 then return 1.0
            else return -1.0
})

newzealand = new EconomicArea({ # 5.4mio Citizens
    "icon-href": "#svg-newzealand-icon"
    "title": "Neuseeland"
    "key": "newzealand"
    "currencyName": "New Zealand Dollar"
    "currencyShort": "NZD"
    "populationM": 5.4,
    "gdpScoreFunction": (gdpg) -> 
        switch
            when gdpg < 1.5 then return -1.0
            when gdpg < 2.5  then return 0.0
            when gdpg < 3.0 then return 2.0
            when gdpg < 4 then return 1.0
            else return -1.0
})


export allAreas = {
    eurozone, usa, japan, uk, canada, australia, switzerland, newzealand
}