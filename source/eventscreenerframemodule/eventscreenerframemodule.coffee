############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreenerframemodule")
#endregion

############################################################
import * as data from "./datamodule.js"
import * as mData from "./marketdatamodule.js"
import * as utl from "./utilsmodule.js"

############################################################
import { SymbolSelect } from "./symbolselectmodule.js"
import { doScreening } from "./eventscreenerengine.js"

############################################################
setEventDataReady = null
readyEventData = new Promise((rslv) -> setEventDataReady = rslv)

############################################################
symbolSelect = null

############################################################
chosenSymbols = new Set()
symbolToData = Object.create(null)

############################################################
eventList = null
idToEvent = Object.create(null)

############################################################
#symbol-choice-row-template
symbolChoiceRowTemplate = document.getElementById("symbol-choice-row-template")
eventChoiceRowTemplate = document.getElementById("event-choice-row-template")


############################################################
defaultEventNr = 12

############################################################
results = null

############################################################
sortFunction = ( ) -> false
sortColumn = "winrate"
sortAscending = false

############################################################
export initialize = ->
    log "initialize"
    container = symbolSelectEventscreener # symbolSelectEventscreener.
    optionsLimit = 70

    symbolSelect = new SymbolSelect({ container, optionsLimit })
    symbolSelect.setOnSelectListener(onSymbolSelected)
    retrieveEventData()

    sortFunction = sortByWinrate
    return

############################################################
retrieveEventData = -> # only once on startup
    log "retrieveEventData"
    try
        eventList = await data.getEventList()
        # olog eventList
        idToEvent[evnt.id] = evnt for evnt in eventList
        
        retrieveAllEventDates()
        updateEventOptions()
    catch err then log err
    return

retrieveAllEventDates = -> # only once on startup
    log "retrieveAllEventDates"
    try
        proms = eventList.map((evnt) -> data.getEventDates(evnt.id))
        datesList = await Promise.all(proms)
        
        for evnt,i in eventList

            dates = datesList[i]
            if !Array.isArray(dates) then throw new Error("Event #{evnt.id} had invalid response!")
            
            evnt.dates = dates
            isWeekly = (evnt.id == "e009") #Jobless Claims is weekly
            evnt.isWeekly = isWeekly
            
            if !evnt.numScreendEvents? then evnt.numScreendEvents = defaultEventNr
            num = evnt.numScreendEvents

            { datesToScreen, nextDates } = extractRelevantDates(num, dates, isWeekly)
            evnt.datesToScreen = datesToScreen
            evnt.nextDates = nextDates

        setEventDataReady()
    catch err then log err
    return
    
############################################################
extractRelevantDates = (num, dates, isWeekly = false) ->
    if dates.length == 0 then return {}

    today = (new Date()).toISOString().slice(0, 10)
    if isWeekly then halfTimeFrameD = 4
    else halfTimeFrameD = 14


    d = new Date()
    d.setDate(d.getDate() - halfTimeFrameD)
    lastRelevantDate = d.toISOString().slice(0, 10) 

    i = 0
    d = dates[i]
    while d < lastRelevantDate
        d = dates[++i]
        if i == dates.length - 1 
            console.error("We donot have newer dates 0!")
            return {}
            
    ## last num relevant dates are screened for
    j = i - num
    if j < 0 then j = 0    
    datesToScreen = dates.slice(j, i)

    while d < today
        d = dates[++i]
        if i == dates.length - 1 
            console.error("We donot have newer dates 1!")
            return {}

    nextDates = dates.slice(i)
    return { datesToScreen, nextDates }

############################################################
onSymbolSelected = (symbol) ->
    log "onSymbolSelected #{symbol}"
    if chosenSymbols.has(symbol) then return symbolSelect.resetSearch()

    symbolSelect.freeze()
    try await addSymbolChoice(symbol)
    catch err then log err
    finally symbolSelect.unfreeze()

    symbolSelect.resetSearch()
    updateSymbolOptions()

    generateScreeningResult()
    return

############################################################
deleteSymbolChoiceClicked = (evnt) ->
    log "deleteSymbolChoiceClicked"
    symbol = evnt.target.dataset.symbol
    log "removing #{symbol}"
    return unless symbol?

    chosenSymbols.delete(evnt.target.dataset.symbol)
    delete symbolToData[symbol]
    updateSymbolOptions()
    return

eventChoiceChanged = (evnt) ->
    log "eventChoiceChanged"
    ## TODO implement
    return

eventRangeClicked = (evnt) ->
    log "eventRangeClicked"
    ## TODO implement
    return

############################################################
addSymbolChoice = (symbol) ->
    log "addSymbolChoice"
    symbolToData[symbol] = await mData.getLatestData(symbol)
    chosenSymbols.add(symbol) 
    return

############################################################
updateSymbolOptions = ->
    log "updateSymbolOptions"
    symbolChoiceList.innerHTML = ""

    chosen = Array.from(chosenSymbols)
    for val in chosen
        log "val: #{val}"
        el = document.importNode(symbolChoiceRowTemplate.content, true)
        el.querySelector('[data-symbol="c"]').textContent = val
        el.querySelector('[data-symbol="i"]').dataset.symbol = val
        el.querySelector('.delete').addEventListener("click", deleteSymbolChoiceClicked)
        symbolChoiceList.appendChild(el)
    return


############################################################
updateEventOptions = ->
    log "updateSymbolOptions"
    updateEventOptions.innerHTML = ""

    for evnt in eventList
        num = evnt.numScreendEvents || defaultEventNr
        evnt.rangeText = "Letzte #{num} Ereignisse"
        el = document.importNode(eventChoiceRowTemplate.content, true)
        el.querySelector('[data-name="c"]').textContent = evnt.label
        el.querySelector('[data-range="c"]').textContent = evnt.rangeText
        el.querySelector('.range').addEventListener("click", eventRangeClicked)
        
        el.querySelector('[data-id="i"]').dataset.id = evnt.id
        el.querySelector('.choose').addEventListener("change", eventChoiceChanged)
        eventChoiceContent.appendChild(el)
    return


############################################################
generateScreeningResult = ->
    log "generateScreeningResult"
    if chosenSymbols.size  > 0         
        eventscreenerframe.className = "processing"
        try results = await doScreening(symbolToData, eventList)
        catch err then log err
        if results? then renderResults(results)
        else 
    else eventscreenerframe.className = "no-result"


############################################################
#region Sort Functions
sortByWinrate = (el1, el2) ->  el2.winrate - el1.winrate
sortByProfitAvg = (el1, el2) ->  el2.profitAvg - el1.profitAvg
sortByProfitMed = (el1, el2) ->  el2.profitMed - el1.profitMed
sortByMaxGain = (el1, el2) ->  el2.maxGain - el1.maxGain
sortByMaxDrop = (el1, el2) ->  el2.maxDrop - el1.maxDrop

sortByNextEntry = (el1, el2) ->  
    if el1.nextEntry > el2.nextEntry then return -1
    if el1.nextEntry < el2.nextEntry then return 1
    return 0
#endregion

############################################################
renderTableRow = (result) ->
    log "renderTableRow"
    
    return

############################################################
renderResults = ->
    log "renderResults"
    sorted = [...results]  # Copy to avoid mutating original

    eventscreenerResult.innerHTML = ""
    log "sortAscending: #{sortAscending}"

    sorted.sort(sortFunction) # standard descending sort
    if sortAscending then sorted.reverse() # reverse for ascending

    ########################################################
    #region table header definition
    dataStructure = [
        { label: "Symbol", key: "symbol", sort: false }
        # { label: "MarketCap", key, "marketcap", sort: true }
        { label: "Ereignis", key: "eventLabel", sort: false}
        { label: "", key: "direction", sort: false }
        { label: "Trefferquote", key: "winrate", sort: true }
        { label: "Profit (Dur.)", key: "profitAvg", sort: true }
        { label: "Profit (Med.)", key: "profitMed", sort: true }
        { label: "Max Anstieg", key: "maxGain", sort: true }
        { label: "Max Rückgang", key: "maxDrop", sort: true }
        { label: "Nächstes Ereignis", key: "nextDate", sort: false }
        { label: "Einstieg (EoD)", key: "entryDate", sort: true }
        { label: "Ausstieg (EoD)", key: "exitDate", sort: true }
    ]
    #endregion

    ########################################################
    #region render table head
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
            th.addEventListener("click", onSortColumnClick)
        th.textContent = label
        headerRow.appendChild(th)
    thead.appendChild(headerRow)
    eventscreenerResult.appendChild(thead)
    #endregion

    ########################################################
    #region render table body
    tbody = document.createElement("tbody")
    for result in sorted
        row = document.createElement("tr")

        for { label, key, sort } in dataStructure
            td = document.createElement("td")

            d = result[key]
            if typeof d == "number"
                td.textContent = "#{d.toFixed(0)}%"
            else td.textContent = d
            row.appendChild(td)
            
        tbody.appendChild(row)
            
    eventscreenerResult.appendChild(tbody)

    eventscreenerframe.className = "result"
    return

    # # Start date column
    # startDateCell = document.createElement("td")
    

    # # End date column
    # endDateCell = document.createElement("td")
    # endDateCell.textContent = result.endDate
    # row.appendChild(endDateCell)

    # # Profit column (flip sign for Short)
    # profitCell = document.createElement("td")
    # profit = if currentIsShort then -result.profitP else result.profitP
    # profitCell.textContent = formatPercent(profit)
    # profitCell.classList.add(if profit >= 0 then "positive" else "negative")
    # row.appendChild(profitCell)

    # # Profit Abs column
    # profitAbsCell = document.createElement("td")
    # profitAbs = result.startA * profit / 100
    # profitAbsCell.textContent = formatAbsolute(profitAbs)
    # profitAbsCell.classList.add(if profitAbs >= 0 then "positive" else "negative")
    # row.appendChild(profitAbsCell)

    # # Max Rise column
    # maxRiseCell = document.createElement("td")
    # maxRiseCell.textContent = formatPercent(result.maxRiseP)
    # row.appendChild(maxRiseCell)

    # # Max Rise Abs column
    # maxRiseAbsCell = document.createElement("td")
    # maxRiseAbs = result.startA * result.maxRiseP / 100
    # maxRiseAbsCell.textContent = formatAbsolute(maxRiseAbs)
    # row.appendChild(maxRiseAbsCell)

    # # Max Drop column
    # maxDropCell = document.createElement("td")
    # maxDropCell.textContent = formatPercent(result.maxDropP)
    # row.appendChild(maxDropCell)

    # # Max Drop Abs column
    # maxDropAbsCell = document.createElement("td")
    # maxDropAbs = result.startA * result.maxDropP / 100
    # maxDropAbsCell.textContent = formatAbsolute(maxDropAbs)
    # row.appendChild(maxDropAbsCell)


############################################################
#region Example code for table rendering
onSortColumnClick = (evnt) ->
    key = evnt.target.getAttribute("data-key")
    log "onSortColumnClick: #{key}"

    if sortColumn == key
        sortAscending = !sortAscending  # Toggle direction

    else # switch sort column
        sortColumn = key
        sortAscending = false  # New column: start descending
        
        switch sortColumn
            when "winrate" then sortFunction = sortByWinrate
            when "profitAvg" then sortFunction = sortByProfitAvg
            when "profitMed" then sortFunction = sortByProfitMed
            when "maxGain" then sortFunction = sortByMaxGain
            when "maxDrop" then sortFunction = sortByMaxDrop
            when "nextEntry" then sortFunction = sortByNextEntry
            else console.error("No sort function for key: #{key}")

    renderResults()
    return

sortYearlyResults = (results) ->
    sorted = [...results]  # Copy to avoid mutating original

    compareFn = switch sortColumn
        when "startDate"
            (a, b) -> a.year - b.year
        when "profit"
            if currentIsShort
                (a, b) -> (-a.profitP) - (-b.profitP)  # Flipped for Short
            else
                (a, b) -> a.profitP - b.profitP
        when "profitA"
            if currentIsShort
                (a, b) -> (-a.startA * a.profitP) - (-b.startA * b.profitP)
            else
                (a, b) -> (a.startA * a.profitP) - (b.startA * b.profitP)
        when "maxRise"
            (a, b) -> a.maxRiseP - b.maxRiseP
        when "maxRiseA"
            (a, b) -> (a.startA * a.maxRiseP) - (b.startA * b.maxRiseP)
        when "maxDrop"
            (a, b) -> (-a.maxDropP) - (-b.maxDropP) # Flipped for max Drops
        when "maxDropA"
            (a, b) -> (-a.startA * a.maxDropP) - (-b.startA * b.maxDropP)
        else
            (a, b) -> 0

    sorted.sort(compareFn)
    unless sortAscending then sorted.reverse()
    return sorted

formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatAbsolute = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(2)}"

#endregion