############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreenerframemodule")
#endregion

############################################################
import * as data from "./datamodule.js"
import * as dCache from "./datacache.js"
import * as utl from "./utilsmodule.js"

############################################################
import { SymbolSelect } from "./symbolselectmodule.js"
import * as screener from "./eventscreenerengine.js"

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
    return

############################################################
retrieveEventData = -> # only once on startup
    log "retrieveEventData"
    try
        eventList = await data.getEventList()
        # olog eventList
        for evnt in eventList
            idToEvent[evnt.id] = evnt
            evnt.isChosen = true
            if !evnt.numScreendEvents? then evnt.numScreendEvents = defaultEventNr
            if !evnt.isWeekly?
                isWeekly = (evnt.id == "e009") #Jobless Claims is weekly
                evnt.isWeekly = isWeekly

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
            
            evnt.dates = dates.sort()
            isWeekly = evnt.isWeekly
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
#region Events leading to reScreen

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

    generateScreeningResult()
    return

############################################################
eventChoiceChanged = (evnt) ->
    log "eventChoiceChanged"
    isChecked = evnt.target.checked
    log "isChecked: #{isChecked}"

    if evnt.target.dataset.id?
        evntId = evnt.target.dataset.id
    else if evnt.target.parentNode.dataset.id?
        evntId = evnt.target.parentNode.dataset.id
    else if evnt.target.parentNode.parentNode.dataset.id?
        evntId = evnt.target.parentNode.parentNode.dataset.id
    else console.error("There was no data-id attribute available!")

    log "evntId: #{evntId}"
    if !idToEvent[evntId]? then console.error("Event with id: #{evntId} did not exist!")
    idToEvent[evntId].isChosen = isChecked

    generateScreeningResult()
    return

############################################################
eventRangeClicked = (evnt) ->
    log "eventRangeClicked"
    ## TODO implement
    generateScreeningResult()
    return

#endregion

############################################################
#region Helper Functions
addSymbolChoice = (symbol) ->
    log "addSymbolChoice"
    symbolToData[symbol] = await dCache.getHistoryHLC(symbol, 30)
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

#endregion

############################################################
generateScreeningResult = ->
    log "generateScreeningResult"
    chosenEvents = eventList.filter((el) -> el.isChosen)

    if chosenSymbols.size  > 0 and chosenEvents.length > 0
        eventscreenerframe.className = "processing"
        try await screener.startScreening(symbolToData, chosenEvents)
        catch err then log err
        renderResults()
    else eventscreenerframe.className = "no-result"



############################################################
renderTableRow = (result) ->
    log "renderTableRow"
    
    return

############################################################
renderResults = ->
    log "renderResults"
    results = screener.getResults(50, sortColumn, sortAscending)
    ## TODO properly deal with result error
    # else eventscreenerframe.className = "error"

    if !results? 
        eventscreenerframe.className = "no-result"
        return

    eventscreenerResult.innerHTML = ""
    dataStructure = screener.resultStructure

    ########################################################
    #region render table head
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
    #endregion

    ########################################################
    #region render table body
    tbody = document.createElement("tbody")
    for result in results
        row = document.createElement("tr")

        for { label, key, sort } in dataStructure
            td = document.createElement("td")

            d = result[key]
            if typeof d == "number" then td.textContent = formatPercent(d)
            else if sort == "date" then td.textContent = formatDate(d)
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
#region helper functions for table rendering
onSortColumnClick = (evnt) ->
    key = evnt.target.getAttribute("data-key")
    log "onSortColumnClick: #{key}"

    if sortColumn == key
        sortAscending = !sortAscending  # Toggle direction

    else # switch sort column
        sortColumn = key
        sortAscending = false  # New column: start descending
        
    renderResults()
    return

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

#endregion