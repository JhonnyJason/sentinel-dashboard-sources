############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreenerresults")
#endregion

############################################################
import * as screener from "./eventscreenerengine.js"
import { setUIState } from "./eventscreenerframemodule.js"
import { displayDetails } from "./eventtradedetailsmodule.js"

############################################################
sortColumn = "profitAvg"
sortAscending = false
numRows = 50

############################################################
selectedEl = null
selectedResult = null

############################################################
export screenAndRender = (chosenEvents, symbolToData) ->
    log "screenAndRender"
    log "chosenEvents.length: "+chosenEvents.length
    olog chosenEvents.map((el) -> el.id)
    log "Object.keys(symbolToData).length: "+Object.keys(symbolToData).length
    if chosenEvents.length > 0 and Object.keys(symbolToData).length > 0
        setUIState("processing")
        try
            await screener.startScreening(symbolToData, chosenEvents)
            results = screener.getResults(numRows, sortColumn, sortAscending)
            render(results)
            setUIState("result")
            return
        catch err
            setUIState("no-result")
            console.error err
    else setUIState("no-result")
    return

############################################################
render = (results) ->
    log "render"
    if !Array.isArray(results) then throw new Error("Results is not an Array!")
    if results.length == 0 then throw new Error("Results is empty Array!")

    eventscreenerResult.innerHTML = ""
    dataStructure = screener.resultStructure

    ########################################################
    # render table head
    thead = document.createElement("thead")
    headerRow = document.createElement("tr")    
    for { label, key, sort } in dataStructure
        th = document.createElement("th")
        if key?
            th.dataset.key = key
            th.classList.add("sortable") if sort != "none"
            if key == sortColumn
                th.classList.add("sorted")
                th.classList.add(if sortAscending then "asc" else "desc")
            th.addEventListener("click", onSortColumnClick)
        th.innerHTML = label
        headerRow.appendChild(th)
    thead.appendChild(headerRow)
    eventscreenerResult.appendChild(thead)
    
    ########################################################
    # render table body
    tbody = document.createElement("tbody")
    for result in results
        row = document.createElement("tr")
        
        if selectedResult? and selectedResult.groupKey? and result.groupKey == selectedResult.groupKey 
            log "selecting row with groupKey: #{result.groupKey} as selectedGroupKey is: #{selectedResult.groupKey}"
            selectedEl = row
            selectedResult = result
            selectedEl.classList.add("chosen")

        `let lettedResult = result`
        row.addEventListener("click", () -> selectForDetailsView(this, lettedResult))
        for { label, key, sort } in dataStructure
            td = document.createElement("td")

            d = result[key]
            switch key
                when "symbol" then td.appendChild(getSpan("symbol", d))
                # when "eventLabel" then td.appendChild(getSpan("", d+"\n"+result.tradeKey))
                when "eventLabel" then td.appendChild(getSpan("", d))
                when "direction" then td.appendChild(getSpan(d.toLowerCase(), d))
                when "winrate" then td.appendChild(getSpan("winrate", d.toFixed(1)))

                when "profitAvg" then td.appendChild(getSpan("profit", d.toFixed(1)))
                when "profitMed" then td.appendChild(getSpan("profit", d.toFixed(1)))

                when "maxRise" then td.appendChild(getMaxRiseElement(result))
                when "maxDrop" then td.appendChild(getMaxDropElement(result))
               
                
                when "nextDate" then td.appendChild(getSpan("", formatDate(d)))
                when "entryDate" then td.appendChild(getSpan("", formatDate(d)))
                when "exitDate" then td.appendChild(getSpan("", formatDate(d)))
                else console.error("Rendering TableBody: Unexpected key #{key}!")

            row.appendChild(td)
            
        tbody.appendChild(row)
            
    eventscreenerResult.appendChild(tbody)
    return

############################################################
selectForDetailsView = (el, result) ->
    log "selectForDetailsView"
    if selectedEl? then selectedEl.classList.remove("chosen")
    selectedEl = el
    selectedResult = result
    el.classList.add("chosen")
    displayDetails(result)
    setUIState("details")
    eventscreenerframe.scrollTo({top:0, behavior:'smooth'})
    return

############################################################
#region helper functions for table rendering
onSortColumnClick = (evnt) ->
    key = evnt.target.getAttribute("data-key")
    log "onSortColumnClick: #{key}"

    if sortColumn == key
        sortAscending = !sortAscending  # Toggle direction

    else # switch sort column
        sortColumn = key
        sortAscending = false  # New column: start descending
        
    results = screener.getResults(numRows, sortColumn, sortAscending)
    render(results)
    return

############################################################
formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatDate = (value) ->
    date = new Date(value)
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()

    dayStr = if day < 10 then "0#{day}" else "#{day}"
    monthStr = if month < 10 then "0#{month}" else "#{month}"
    return "#{dayStr}.#{monthStr}.#{year}"

formatAbsolutePrice = (value, missingSF) ->
    if missingSF > 1 then return "#{value.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingSF.toFixed(2)}</span>"
    else return "#{value.toFixed(2)}"

############################################################
getSpan = (cls, txt) ->
    span = document.createElement("SPAN")
    span.className = cls
    span.textContent = txt
    return span

getMaxRiseElement = (result) ->
    log "getMaxRiseElement"
    olog result

    abs = result.maxRiseAba 
    p = result.maxRise
    missingSF = result.maxRiseMissingSF
    olog { p, abs, missingSF }

    el = document.createElement("div")
    top = document.createElement("div")
    bottom = document.createElement("div")
    absEl = document.createElement("span")

    bottom.classList.add("absolute")
    absEl.classList.add("abs-up")

    el.appendChild(top)
    el.appendChild(bottom)
    
    top.appendChild(getSpan("up", p.toFixed(1)))
    
    absEl.innerHTML = formatAbsolutePrice(abs, missingSF)
    bottom.appendChild(absEl)
    return el

getMaxDropElement = (result) ->
    log "getMaxDropElement"
    abs = result.maxDropAba 
    p = result.maxDrop
    missingSF = result.maxDropMissingSF
    olog { p, abs, missingSF }

    el = document.createElement("div")
    top = document.createElement("div")
    bottom = document.createElement("div")
    absEl = document.createElement("span")
    
    bottom.classList.add("absolute")
    absEl.classList.add("abs-down")

    el.appendChild(top)
    el.appendChild(bottom)

    top.appendChild(getSpan("down", p.toFixed(1)))
    
    absEl.innerHTML = formatAbsolutePrice(abs, missingSF)
    bottom.appendChild(absEl)
    return el

#
#endregion