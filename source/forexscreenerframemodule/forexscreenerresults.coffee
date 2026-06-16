############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("forexscreenerresults")
#endregion

############################################################
import { getTrendForScore } from "./scorehelper.js"

############################################################
import * as screener from "./forexscreenerengine.js"
import { setUIState } from "./forexscreenerframemodule.js"

############################################################
sortColumn = "symbol"
sortAscending = false

############################################################
export screenAndRender =  ->
    log "screenAndRender"
    setUIState("processing")
    try
        results = await screener.getResults(sortColumn, sortAscending)
        olog results
        render(results)
        setUIState("result")
        return
    catch err
        # setUIState("no-result")
        console.error err
    return

############################################################
render = (results) ->
    log "render"
    if !Array.isArray(results) then throw new Error("Results is not an Array!")
    if results.length == 0 then throw new Error("Results is empty Array!")

    forexscreenerResult.innerHTML = ""
    dataStructure = screener.resultStructure

    ########################################################
    # render table head
    thead = document.createElement("thead")
    headerRow = document.createElement("tr")    
    for { label, key, sort } in dataStructure
        th = document.createElement("th")
        if key?
            th.dataset.key = key
            th.classList.add("sortable") if sort 
            if key == sortColumn
                th.classList.add("sorted")
                th.classList.add(if sortAscending then "asc" else "desc")
            th.addEventListener("click", onSortColumnClick) if sort
        th.textContent = label
        headerRow.appendChild(th)
    thead.appendChild(headerRow)
    forexscreenerResult.appendChild(thead)
    
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

            try
                d = result[key]
                if !d? then td.appendChild(getSpan("empty", "-"))
                else switch key
                    when "symbol" then addSymbolSpan(td, result)
                    when "signal" then td.appendChild(getSpan(d.toLowerCase(), d))
                    when "entryDate" then td.appendChild(getSpan("", formatDate(d)))
                    when "exitDate" then td.appendChild(getSpan("", formatDate(d)))
                    when "entryPrice" then td.appendChild(getSpan("", d.toFixed(3)))
                    when "stoploss" then td.appendChild(getSpan("", d.toFixed(3)))
                    when "takeprofit1" then td.appendChild(getSpan("", d.toFixed(3)))
                    when "takeprofit2" then td.appendChild(getSpan("", d.toFixed(3)))
                    when "score" then addScoreSpan(td, d)
                    when "seasonality10P" then td.appendChild(getSpan("winrate", d.toFixed(1)))
                    when "seasonality15P" then td.appendChild(getSpan("winrate", d.toFixed(1)))

                    # when "direction" then td.appendChild(getSpan(d.toLowerCase(), d))
                    # when "winrate" then td.appendChild(getSpan("winrate", d.toFixed(1)))
                    # when "profitAvg" then td.appendChild(getSpan("profit", d.toFixed(1)))
                    # when "profitMed" then td.appendChild(getSpan("profit", d.toFixed(1)))
                    # when "maxGain" then td.appendChild(getSpan("up", d.toFixed(1)))
                    # when "maxDrop" then td.appendChild(getSpan("down", d.toFixed(1)))
                    # when "nextDate" then td.appendChild(getSpan("", formatDate(d)))
                    else console.error("Rendering TableBody: Unexpected key #{key}!")

                row.appendChild(td)
            catch err then console.error("@key #{key}: #{err.message}")

        tbody.appendChild(row)
            
    forexscreenerResult.appendChild(tbody)
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
    forexscreenerframe.scrollTo({top:0, behavior:'smooth'})
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
        
    results = await screener.getResults(sortColumn, sortAscending)
    try render(results)
    catch err then console.error err

    return

############################################################
formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

addSymbolSpan = (td, result) ->
    symbol = result.symbol
    signal = result.signal
    if !symbol? then throw new Error("Result had no symbol defined!")#
    td.appendChild(getSpan("symbol", symbol))
    if !signal? then return 
    
    td.classList.add("sym-#{signal.toLowerCase()}")
    return

addScoreSpan = (td, score) ->    
    if typeof score == "string" then score = parseFloat(score)
    { color, text } = getTrendForScore(score)

    score = Math.round(score)
    if score > 0 then score = "+"+score

    td.classList.add("score")
    td.style.backgroundColor = color    
    
    td.appendChild(getSpan("", "#{text} #{score}"))
    return 

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