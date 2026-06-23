############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventtradedetailsmodule")
#endregion

############################################################
import * as engine from "./eventscreenerengine.js"
import * as charting from "./eventtradechartmodule.js"

############################################################
_tradeKey = ""
_eventLabel = ""

############################################################
_symbol = ""
_eventId = ""
_trade = ""

############################################################
_direction = ""
_allResults = null

############################################################
# DOM Cache
tradedetailsSymbol = document.getElementById("tradedetails-symbol")
tradedetailsEventLabel = document.getElementById("tradedetails-event-label")
tradedetailsDirection = document.getElementById("tradedetails-direction")

# Tradedetails Table
tradedetailsTable = document.getElementById("tradedetails-table")

# Date Elements
nextEventDateDisplay = document.querySelector("#tradedetails-next-date .value")
nextEntryDateDisplay = document.querySelector("#tradedetails-next-entry .value")
nextExitDateDisplay = document.querySelector("#tradedetails-next-exit .value")

entryIdxDisplay = null
exitIdxDisplay = null

# Win Rate 
winRateNumberDisplay = document.getElementById("tradedetails-winrate-percent")
tradedetailsLossCircle = document.getElementById("tradedetails-loss-circle")
winVsLoseDisplay = document.getElementById("tradedetails-win-vs-lose")

# Summary Grid
averageProfitDisplay = document.querySelector("#tradedetails-average-change .value")
medianProfitDisplay = document.querySelector("#tradedetails-median-change .value")
maxRiseDisplay = document.querySelector("#tradedetails-max-rise .value")
maxDropDisplay = document.querySelector("#tradedetails-max-drop .value")
absMaxRiseDisplay = document.querySelector("#tradedetails-max-rise-abs .value")
absMaxDropDisplay = document.querySelector("#tradedetails-max-drop-abs .value")
daysInTradeDisplay = document.querySelector("#tradedetails-days-in-trade .value")

############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));


############################################################
export initialize = ->
    log "initialize"

    # Chart
    charting.setOnRangeSelectListener(updateTradeRegion)

    # Range Selection Elements
    el = document.getElementById("tradedetails-entry-idx")
    btn = el.querySelector(".minus")
    btn.addEventListener("click", entryIdxMinusClicked)

    btn = el.querySelector(".plus")
    btn.addEventListener("click", entryIdxPlusClicked)
    entryIdxDisplay = el.querySelector(".date")

    if !entryIdxDisplay? then throw new Error("Elemen for entryIdxDisplay not found!")

    el = document.getElementById("tradedetails-exit-idx")
    btn = el.querySelector(".minus")
    btn.addEventListener("click", exitIdxMinusClicked)

    btn = el.querySelector(".plus")
    btn.addEventListener("click", exitIdxPlusClicked)
    exitIdxDisplay = el.querySelector(".date")

    if !exitIdxDisplay? then throw new Error("Elemen for entryIdxDisplay not found!")
    
    ## TODO wire up EventListeners
    ## Initialize chart

    return

############################################################
entryIdxMinusClicked = (evnt) ->
    log "entryIdxMinusClicked"
    charting.setSelectedRegion({
        isDelta: true
        startIdx: -1
    })
    return

entryIdxPlusClicked = (evnt) ->
    log "entryIdxPlusClicked"
    charting.setSelectedRegion({
        isDelta: true
        startIdx: +1
    })
    return

exitIdxMinusClicked = (evnt) -> 
    log "exitIdxMinusClicked"
    charting.setSelectedRegion({
        isDelta: true
        endIdx: -1
    })
    return

exitIdxPlusClicked = (evnt) ->
    log "exitIdxPlusClicked"
    charting.setSelectedRegion({
        isDelta: true
        endIdx: +1
    })
    return


############################################################
setNewTrade = (newTrade) ->
    log "setNewTrade"
    return unless _trade != newTrade

    _trade = newTrade
    tkns = _tradeKey.split(":")
    tkns[2] = _trade
    _tradeKey = tkns.join(":")
    evaluateAndRenderTradeDetails()
    return

############################################################
updateTradeRegion = (region) ->
    log "updateTradeRegion"
    olog region

    if !region? then throw new Error("@updateTradeRegion: No new region provided!")
    if !region.startIdx? or !region.endIdx? then throw new Error("@updateTradeRegion:: No valid indices provided!")

    tkns = _trade.split("-")
    tkns[0] = region.startIdx
    tkns[1] = region.endIdx
    setNewTrade(tkns.join("-"))
    return

############################################################
export displayDetails = (result) ->
    log "displayDetails"
    olog result
    { tradeKey, direction, eventLabel } = result
    if !tradeKey? then throw new Error("result for displayDetails has no _tradeKey!")
    
    _tradeKey = tradeKey
    _direction = direction
    _eventLabel = eventLabel

    tkns = tradeKey.split(":")
    if tkns.length != 3  then throw new Error("tradeKey was invalid!")
    _symbol = tkns[0]
    _eventId = tkns[1]
    _trade = tkns[2]
    
    setHeaderInfo()    
    evaluateAndRenderTradeDetails()
    return

############################################################
evaluateAndRenderTradeDetails = ->
    log "evaluateAndRenderTradeDetails"
    try
        log _tradeKey
        result = await engine.getTradeResultDetails(_tradeKey)
        # olog result
        log Object.keys(result)
    catch err
        console.error(err)
        charting.reset()
        return

    if result.profitAvg < 0 # somehow we should be changing direction on this trade...
        if _direction == "Long" then direction = "Short"
        if _direction == "Short" then direction = "Long"
        newResult = { direction, tradeKey:_tradeKey, eventLabel: _eventLabel }
        return displayDetails(newResult)
    

    displaySummary(result)
    await letMainThreadRun()

    _allResults = result.runObjects.map(transformRunObjToDetailsResult)
    # renderDetailsTable()
    
    tkns = _trade.split("-")
    startIdx = parseInt(tkns[0])
    endIdx = parseInt(tkns[1])
    log "after general rendering"
    olog { _tradeKey, _trade }
    olog { startIdx, endIdx }
    
    await letMainThreadRun()
    charting.reset()
    charting.prepareData(result.avgDailyReturn, result.nextDate)
    charting.setSelectedRegion({startIdx, endIdx})
    return

############################################################
setHeaderInfo = ->
    log "setHeaderInfo"
    tradedetailsSymbol.textContent = _symbol
    tradedetailsEventLabel.textContent = _eventLabel
    tradedetailsDirection.textContent = _direction

    if _direction == "Long" then tradedetailsDirection.className = "long"
    if _direction == "Short" then tradedetailsDirection.className = "short"
    return

displaySummary = (summaryResult) ->
    log "displaySummary"
    # olog summaryResult

    nextEventDateDisplay.textContent = formatDate(summaryResult.nextDate)
    nextEntryDateDisplay.textContent = formatDate(summaryResult.nextEntryDate)
    nextExitDateDisplay.textContent = formatDate(summaryResult.nextExitDate)

    entryIdxDisplay.textContent = getEntryIdxForDisplay()
    exitIdxDisplay.textContent = getExitIdxForDisplay()

    total = summaryResult.totalTrades || 0
    if total == 0
        wins = 0.0
        losers = 0.0
        winRate = 0.0
    else
        wins = summaryResult.winTrades || 0
        losers = total - wins
        winRate = 100.0 * wins / total
    
    # Win rate
    winRateNumberDisplay.textContent = "#{winRate.toFixed(1)}%"
    lossRate = 100 - winRate
    strokeDashArray = "#{lossRate * 6.294 / 100} #{6.294}"
    tradedetailsLossCircle.setAttribute("stroke-dasharray", strokeDashArray)

    winVsLoseDisplay.textContent = "#{wins} | #{losers}"

    # Summary stats
    maxRiseDisplay.textContent = formatPercent(summaryResult.maxGain)
    maxDropDisplay.textContent = formatPercent(summaryResult.maxDrop)
    averageProfitDisplay.textContent = formatPercent(summaryResult.profitAvg)
    medianProfitDisplay.textContent = formatPercent(summaryResult.profitMed)
    daysInTradeDisplay.textContent = "#{getNrTradeDays()} Tage"

    absMaxDropDisplay.innerHTML = formatAbsoluteDelta(summaryResult.maxDropAba, summaryResult.maxDropMissingF)
    absMaxRiseDisplay.innerHTML = formatAbsoluteDelta(summaryResult.maxGainAba, summaryResult.maxGainMissingF)
    return

############################################################
renderDetailsTable = ->
    log "renderDetailsTable"
    ## Render Table head
    direction = _direction
    results = sortAllResults(_allResults)
    tradedetailsTable.innerHTML = ""
    renderDetailTableHead()

    tbody = document.createElement("tbody")
    for result in results
        tr = document.createElement("tr")

        ## event date: eventD 
        td = document.createElement("td")
        td.textContent = formatDate(result.eventD)
        tr.appendChild(td)

        ## start date: entryD
        td = document.createElement("td")
        td.textContent = formatDate(result.entryD)
        tr.appendChild(td)

        ## start price: entryAr or entryAba
        td = document.createElement("td")
        td.innerHTML = formatAbsolutePrice(result.entryAba, result.missingF)
        tr.appendChild(td)

        ## end price: startPrice * deltaF
        td = document.createElement("td")
        exitAba = result.entryAba * result.deltaF
        td.innerHTML = formatAbsolutePrice(exitAba, result.missingF)
        tr.appendChild(td)

        ## end date: exitD
        td = document.createElement("td")
        td.textContent = formatDate(result.exitD)
        tr.appendChild(td)

        ## profit: profit?
        td = document.createElement("td")
        if direction == "Long" then profit = 100.0 * (result.deltaF - 1.0)
        if direction == "Short" then profit = -100.0 * (result.deltaF - 1.0)
        td.textContent = formatPercent(profit)
        if profit > 0 then cls = "positive"
        if profit < 0 then cls = "negative"
        td.classList.add(cls) unless profit == 0
        tr.appendChild(td)
        
        ## profit abs: profitAr?
        
        ## Max Anstieg: maxGainF -> maxGainP
        td = document.createElement("td")
        maxGainP = 100.0 * (result.maxGainF - 1.0)
        if direction == "Long" and maxGainP > 0 then cls = "positive"
        if direction == "Short" and maxGainP < 0 then cls = "positive"
        if direction == "Long" and maxGainP < 0 then cls = "negative"
        if direction == "Short" and maxGainP > 0 then cls = "negative"
        td.textContent = formatPercent(maxGainP)
        td.classList.add(cls) unless maxGainP == 0
        tr.appendChild(td)

        ## Max Anstieg Abs: maxRiseA?
        # td = document.createElement("td")
        # maxGainAbs = result.entryAba * result.maxGainF
        # td.innerHTML = formatAbsoluteDelta(maxGainAbs, result.missingF)
        # tr.appendChild(td)

        ## Max Rückgang: maxDrop
        td = document.createElement("td")
        maxDropP = 100.0 * (result.maxDropF - 1.0)
        if direction == "Long" and maxDropP > 0 then cls = "positive"
        if direction == "Short" and maxDropP < 0 then cls = "positive"
        if direction == "Long" and maxDropP < 0 then cls = "negative"
        if direction == "Short" and maxDropP > 0 then cls = "negative"
        td.textContent = formatPercent(maxDropP)
        td.classList.add(cls) unless maxDropP == 0
        tr.appendChild(td)
        
        ## Max Rückgang Abs: maxDropA?
        # td = document.createElement("td")
        # maxDropAbs = result.entryAba * result.maxDropF
        # td.innerHTML = formatAbsoluteDelta(maxDropAbs, result.missingF)
        # tr.appendChild(td)

        tbody.appendChild(tr)
    tradedetailsTable.appendChild(tbody)
    return

############################################################
sortColumn = "eventD"
sortAscending = false

############################################################
renderDetailTableHead = ->
    log "renderDetailTableHead"
    thead = document.createElement("thead")
    headerRow = document.createElement("tr")
    headers = [
        { label: "Ereignis", key: "eventD" }
        { label: "Start"} # key: "entryD" 
        { label: "Startkurs"} # key: "entryC"
        { label: "Endkurs"} # key: "exitC"
        { label: "Ende" } # key: "exitD"
        { label: "Profit", key: "profit" }
        # { label: "Profit Abs", key: "profitA" }
        { label: "Max Anstieg", key: "maxRise" }
        # { label: "Max Anstieg Abs", key: "maxRiseA" }
        { label: "Max Rückgang", key: "maxDrop" }
        # { label: "Max Rückgang Abs", key: "maxDropA" }
    ]

    for { label, key } in headers
        th = document.createElement("th")
        if key?
            th.dataset.sortKey = key
            th.classList.add("sortable")
            if key == sortColumn
                th.classList.add("sorted")
                th.classList.add(if sortAscending then "asc" else "desc")
            th.addEventListener("click", onSortColumnClick)
        th.textContent = label
        headerRow.appendChild(th)
    thead.appendChild(headerRow)
    tradedetailsTable.appendChild(thead)    
    return


############################################################
onSortColumnClick = (evnt) ->
    key = evnt.target.getAttribute("data-sort-key")
    log "onSortColumnClick: #{key}"
    if sortColumn == key
        sortAscending = !sortAscending  # Toggle direction
    else
        sortColumn = key
        sortAscending = false  # New column: start descending
    renderDetailsTable()
    return

sortAllResults = (results) ->
    sorted = [...results]  # Copy to avoid mutating original

    compareFn = switch sortColumn
        when "eventD"
            (a, b) -> (new Date(a.eventD)).getTime() - (new Date(b.eventD)).getTime()
        when "profit"
            if _direction == "Short"
                (a, b) -> b.deltaF - a.deltaF
            else
                (a, b) -> a.deltaF - b.deltaF
            # log("sorting profit... while #{_direction}")
            # if _direction == "Long"
            #     log "actually in LONG" # I can see I am here in this branch
            #     (a, b) -> a.deltaF - b.deltaF # must be right - but sorting profit in Long is always wrong
            #     # (a, b) -> b.deltaF - a.deltaF # remarkably swithing things up here does not change the result!
            # if _direction == "Short" 
            #     log "actually in SHORT"
            #     (a, b) -> b.deltaF - a.deltaF
            #     # (a, b) -> a.deltaF - b.deltaF # makes short be wrong... as expected
                
        # when "profitA"
        #     (a, b) -> a.entryAr * a.deltaF - b.entryAr * b.deltaF ## TODO adjust to what we actually have available
        when "maxRise"
            log "sorting maxRise"
            (a, b) -> a.maxGainF - b.maxGainF
        # when "maxRiseA"
        #     (a, b) -> (a.startAr * a.maxRiseP) - (b.startAr * b.maxRiseP)
        when "maxDrop"
            log "sorting maxDrop"
            (a, b) -> (-a.maxDropF) - (-b.maxDropF) # Flipped for max Drops
        # when "maxDropA"
        #     (a, b) -> (-a.startAr * a.maxDropP) - (-b.startAr * b.maxDropP)
        else
            (a, b) -> 0

    sorted.sort(compareFn)
    unless sortAscending then sorted.reverse()
    return sorted


############################################################
transformRunObjToDetailsResult = (runObj) ->
    detailsRes = Object.create(null)
    eventDate = runObj.key.split("@")[1]

    detailsRes.entryD = runObj.entryDate
    detailsRes.eventD = eventDate 
    detailsRes.exitD = runObj.exitDate
    detailsRes.entryC = runObj.entryCba
    detailsRes.exitC = runObj.entryCba * (runObj.deltaF + 1)
    detailsRes.deltaF = runObj.deltaF
    detailsRes.maxGainF = runObj.maxRiseF
    detailsRes.maxDropF = runObj.maxDrop

    return detailsRes


############################################################
formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatAbsoluteDelta = (value, missingF) ->
    sign = if value >= 0 then "+" else ""
    html = formatAbsolutePrice(value, missingF)
    return "#{sign}#{html}"

formatAbsolutePrice = (value, missingF) ->
    if missingF > 1 then return "#{value.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingF.toFixed(2)}</span>"
    else return "#{value.toFixed(2)}"

# formatDate = (value) ->
#     date = new Date(value)
#     day = date.getDate()
#     month = date.getMonth() + 1
#     year = date.getFullYear()

#     dayStr = if day < 10 then "0#{day}" else "#{day}"
#     monthStr = if month < 10 then "0#{month}" else "#{month}"
#     return "#{dayStr}.#{monthStr}.#{year}"


############################################################
getNrTradeDays = ->
    log "getNrTradeDays"
    tkns = _trade.split("-")
    if tkns.length != 3 then throw new Error("invalid _trade!")
    entryIdx = parseInt(tkns[0])
    exitIdx = parseInt(tkns[1])
    return exitIdx - entryIdx

############################################################
getEntryIdxForDisplay = ->
    log "getEntryIdxForDisplay"
    if !_trade? then throw new Error("no _trade available!")
    tkns = _trade.split("-")
    if tkns.length != 3 then throw new Error("invalid _trade!")
    entryIdx = parseInt(tkns[0])
    halfIdx = parseInt(tkns[2])
    idx = entryIdx - halfIdx
    if idx > 0 then return "+"+idx else return ""+idx

############################################################
getExitIdxForDisplay = ->
    log "getEntryIdxForDisplay"
    if !_trade? then throw new Error("no _trade available!")
    tkns = _trade.split("-")
    if tkns.length != 3 then throw new Error("invalid _trade!")
    exitIdx = parseInt(tkns[1])
    halfIdx = parseInt(tkns[2])
    idx = exitIdx - halfIdx
    if idx > 0 then return "+"+idx else return ""+idx

############################################################
formatDate = (YYYYMMDD) -> (YYYYMMDD.split("-")).reverse().join(".")
