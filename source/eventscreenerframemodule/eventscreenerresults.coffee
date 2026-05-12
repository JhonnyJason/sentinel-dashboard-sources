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
        th.textContent = label
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
                when "maxGain" then td.appendChild(getSpan("up", d.toFixed(1)))
                when "maxDrop" then td.appendChild(getSpan("down", d.toFixed(1)))
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

############################################################
getSpan = (cls, txt) ->
    span = document.createElement("SPAN")
    span.className = cls
    span.textContent = txt
    return span


#endregion