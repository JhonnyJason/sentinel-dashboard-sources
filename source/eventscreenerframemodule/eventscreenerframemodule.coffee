############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreenerframemodule")
#endregion

############################################################
import * as dCache from "./datacache.js"
import * as utl from "./utilsmodule.js"
import * as S from "./statemodule.js"


############################################################
import { SymbolSelect } from "./symbolselectmodule.js"
############################################################
import * as eventsChoice from "./eventschoicetable.js"
import * as resultTable from "./eventscreenerresults.js"
import * as filterState from "./resultfilterstate.js"

############################################################
symbolSelect = null

############################################################
storedChoices = null
CHOICES_KEY = "eventscreener-symbol-choices"
############################################################
chosenSymbols = new Set()
symbolToData = Object.create(null)

############################################################
screenedDataStrings = Object.create(null)
newDataStrings = Object.create(null)

############################################################
chosenEvents = []

############################################################
symbolChoiceRowTemplate = document.getElementById("symbol-choice-row-template")

############################################################
isProcessing = false
processOnceMore = false

############################################################
activated = false

############################################################
export initialize = ->
    log "initialize"
    runTest()
    return
    filterState.initialize()
    filterState.setOnChangeListener(onFilterUpdate)

    closeDetailsButton.addEventListener("click", () -> setUIState("nodetails"))
    eventscreenerScreenButton.addEventListener("click", screenButtonClicked)

    container = symbolSelectEventscreener # symbolSelectEventscreener.
    optionsLimit = 70

    symbolSelect = new SymbolSelect({ container, optionsLimit })
    symbolSelect.setOnSelectListener(onSymbolSelected)
    
    storedChoices = S.get(CHOICES_KEY) # retrieve from regular state
    olog storedChoices
    if !Array.isArray(storedChoices) then storedChoices = []
    S.setChangeDetectionFunction(CHOICES_KEY, () -> true)
    return

############################################################
export activate = ->
    return
    return if activated
    eventsChoice.initialize(onEventChoiceUpdate)
    setUIState("nodetails")
    generateScreeningResult()
    activated = true
    return

############################################################
export setUIState = (state) ->
    log "setUIState"
    switch state
        when "processing"
            eventscreenerframe.classList.remove("no-result")
            eventscreenerframe.classList.remove("result")
            eventscreenerframe.classList.add("processing")
        when "result"
            eventscreenerframe.classList.remove("processing")
            eventscreenerframe.classList.remove("no-result")
            eventscreenerframe.classList.add("result")
        when "no-result"
            eventscreenerframe.classList.remove("processing")
            eventscreenerframe.classList.remove("result")
            eventscreenerframe.classList.add("no-result")
        when "details"
            eventscreenerframe.classList.add("details")
        when "nodetails"
            eventscreenerframe.classList.remove("details")
            els = eventscreenerframe.querySelectorAll("tr.chosen")
            el.classList.remove("chosen") for el in els
        else 
            console.error("#{state} is not a know UI state for the eventscreenerframe!")
    return

############################################################
#region Events leading to reScreen

############################################################
screenButtonClicked = ->
    log "screenButtonClicked"
    generateScreeningResult()
    return

############################################################
onSymbolSelected = (symbol, company) ->
    log "onSymbolSelected #{symbol} #{company}"
    if chosenSymbols.has(symbol) then return symbolSelect.resetSearch()

    symbolSelect.freeze()
    try await addSymbolChoice(symbol, company)
    catch err
        console.error(err)
        symbolSelect.setError("Fehler in der Datenanfrage für #{symbol}!")
        return # no change on symbol options to update
    finally symbolSelect.unfreeze()

    symbolSelect.resetSearch()
    updateSymbolOptions()
    return

############################################################
deleteSymbolChoiceClicked = (evnt) ->
    log "deleteSymbolChoiceClicked"
    symbol = evnt.target.dataset.symbol
    log "removing #{symbol}"
    return unless symbol?

    chosenSymbols.delete(symbol)
    delete symbolToData[symbol]

    newChoices = []
    newChoices.push(ch) for ch in storedChoices when ch.symbol != symbol
    storedChoices = newChoices
    S.save(CHOICES_KEY, storedChoices)

    updateSymbolOptions()
    return

############################################################
onEventChoiceUpdate = (events) ->
    log "onEventChoiceUpdate"
    if !events? then chosenEvents = []
    else chosenEvents = events
    newDataStrings.events = JSON.stringify(chosenEvents) 
    onScreenDataUpdate()
    return

############################################################
onFilterUpdate = (filters) ->
    log "onFilterUpdate"
    newDataStrings.filters = JSON.stringify(filters)
    onScreenDataUpdate()
    return

############################################################
onScreenDataUpdate = ->
    log "onScreenDataUpdate"
    dataChanged  = screenedDataStrings.filters != newDataStrings.filters
    dataChanged = dataChanged || screenedDataStrings.symbols != newDataStrings.symbols
    dataChanged = dataChanged || screenedDataStrings.events != newDataStrings.events

    if !dataChanged or newDataStrings.symbols == "[]" or newDataStrings.events == "[]"
        eventscreenerScreenButton.classList.add("not-screenable")
    else 
        eventscreenerScreenButton.classList.remove("not-screenable")
    return

#endregion

############################################################
#region Helper Functions
addSymbolChoice = (symbol, company) ->
    log "addSymbolChoice"
    storedChoices.push({symbol, company})
    S.save(CHOICES_KEY, storedChoices)
    olog storedChoices

    hlc = await dCache.getHistoryHLC(symbol, 31)
    tDays = await dCache.getHistoricTradingDays(symbol, 31)

    if !symbolToData[symbol]? then symbolToData[symbol] = { hlc, tDays, company }
    else
        symbolToData[symbol].hlc = hlc
        symbolToData[symbol].tDays = tDays
        symbolToData[symbol].company = company

    chosenSymbols.add(symbol) 
    return

############################################################
updateSymbolOptions = ->
    log "updateSymbolOptions"
    symbolChoiceList.innerHTML = ""

    chosen = Array.from(chosenSymbols)
    chosen.sort()

    for val in chosen
        log "val: #{val}"
        company = symbolToData[val].company
        el = document.importNode(symbolChoiceRowTemplate.content, true)
        el.querySelector('[data-symbol="c"]').textContent = val
        el.querySelector('[data-name="c"]').textContent = company
        el.querySelector('[data-symbol="i"]').dataset.symbol = val
        el.querySelector('.delete').addEventListener("click", deleteSymbolChoiceClicked)
        symbolChoiceList.appendChild(el)
    
    newDataStrings.symbols = JSON.stringify(chosen)
    onScreenDataUpdate()
    return

#endregion

############################################################
retrieveMissingSymbolData = ->
    log "retrieveMissingSymbolData"
    
    retrieveMissingData = (choice) ->
        { symbol, company } = choice
        if symbolToData[symbol]? then return choice
        
        try
            hlc = await dCache.getHistoryHLC(symbol, 31)
            tDays = await dCache.getHistoricTradingDays(symbol, 31)
            symbolToData[symbol] = { hlc, tDays, company }
            chosenSymbols.add(symbol)
            return choice
        catch err then console.error err
        return null


    proms = storedChoices.map(retrieveMissingData)
    validChoices = await Promise.all(proms)

    storedChoices = validChoices.filter((el) -> el?)
    olog storedChoices
    olog Array.from(chosenSymbols)
    S.save(CHOICES_KEY, storedChoices)
    updateSymbolOptions()
    return

############################################################
generateScreeningResult = ->
    log "generateScreeningResult"
    # always sync screening Data state and deactivate screenButton
    screenedDataStrings.filters = newDataStrings.filters
    screenedDataStrings.symbols = newDataStrings.symbols
    screenedDataStrings.events = newDataStrings.events
    eventscreenerScreenButton.classList.add("not-screenable")

    # guarding from multiple simultaneous runs 
    if isProcessing and processOnceMore then return
    if isProcessing then return processOnceMore = true
    
    isProcessing  = true

    try await retrieveMissingSymbolData()
    catch err then log err
    try await resultTable.screenAndRender(chosenEvents, symbolToData)
    catch err then log err
    isProcessing = false
    
    if processOnceMore
        processOnceMore = false
        generateScreeningResult(chosenEvents)
    return


############################################################
tDates = [

    "1996-01-01", ## DoY: 0 = real Index = non-Leap Norm = leap Norm
    "1996-01-03", ## DoY: 2 = real Index = non-Leap Norm = leap Norm
    "1996-02-02", ## DoY: 32 = realIndex = non-Leap Norm = leap Norm
    "1996-02-28", ## DoY: 58 = realIndex = non-Leap Norm = leap Norm
    "1996-02-29", ## DoY: 59 = realIndex = leap Norm | not available in non-Leap Norm -> 58
    "1996-03-01", ## DoY: 60 = realIndex = leap Norm | 59 in non-Leap Norm

    "1998-01-01", ## DoY: 0 = real Index = non-Leap Norm = leap Norm
    "1998-01-03", ## DoY: 2 = real Index = non-Leap Norm = leap Norm
    "1998-02-02", ## DoY: 32 = real Index = non-Leap Norm = leap Norm
    "1998-02-28", ## DoY: 58 = real Index = non-Leap Norm = leap Norm
    "1998-03-01", ## DoY: 59 = real Index = non-Leap Norm | 60 in leap Norm

    "1999-01-01", ## DoY: 0 = real Index = non-Leap Norm = leap Norm
    "1999-01-03", ## DoY: 2 = real Index = non-Leap Norm = leap Norm
    "1999-02-02", ## DoY: 32 = real Index = non-Leap Norm = leap Norm
    "1999-02-28", ## DoY: 58 = real Index = non-Leap Norm = leap Norm + 59 in leap Norm
    "1999-03-01", ## DoY: 59 = real Index = non-Leap Norm | 60 in leap Norm

    "2000-01-01", ## DoY: 0 = real Index = non-Leap Norm = leap Norm
    "2000-01-03", ## DoY: 2 = real Index = non-Leap Norm = leap Norm
    "2000-02-02", ## DoY: 32 = real Index = non-Leap Norm = leap Norm
    "2000-02-28", ## DoY: 58 = real Index = non-Leap Norm = leap Norm
    "2000-02-29", ## DoY: 59 = real Index = leap Norm | not available in non-Leap Norm -> 58
    "2000-03-01"  ## DoY: 60 = real Index = leap Norm | 59 in non-Leap Norm
]
############################################################
runTest = ->
    log "runTest"
    todayDate = new Date()
    currentYear = todayDate.getFullYear()
    isLeapYear = utl.isLeapYear(currentYear)
    log "isLeapYear: #{isLeapYear}"

    leapNormIdx = 0 ## 1.1.2026
    date = utl.leapNormToYYYYMMDD(leapNormIdx, currentYear)
    log "leapNormIdx #{leapNormIdx} -> date: #{date}" 
    leapNormIdx = 58 ## 28.2.2026
    date = utl.leapNormToYYYYMMDD(leapNormIdx, currentYear)
    log "leapNormIdx #{leapNormIdx} -> date: #{date}" 
    leapNormIdx = 59 ## 28.2.2026
    date = utl.leapNormToYYYYMMDD(leapNormIdx, currentYear)
    log "leapNormIdx #{leapNormIdx} -> date: #{date}" 
    leapNormIdx = 60 ## 1.3.2026
    date = utl.leapNormToYYYYMMDD(leapNormIdx, currentYear)
    log "leapNormIdx #{leapNormIdx} -> date: #{date}" 
    
    return

    startIdx = utl.getDayOfYear(todayDate)
    log "startIdx (DoY): #{startIdx}"
    startIdx = utl.realToLeapNormIdx(startIdx, isLeapYear)
    log "startIdx (leapNorm): #{startIdx}"

    startYYYYMMDD = utl.leapNormToYYYYMMDD(startIdx, currentYear)
    todayYYYYMMDD = todayDate.toISOString().slice(0,10)

    olog {
        startYYYYMMDD, 
        todayYYYYMMDD
    }
    return

    for dt in tDates
        date = new Date(dt)
        year = date.getFullYear()
        isLeap = utl.isLeapYear(year)

        dayOfYear = utl.getDayOfYear(date)
        leapNorm = utl.realToLeapNormIdx(dayOfYear, isLeap)
        nonLeapNorm = utl.realToNonLeapNormIdx(dayOfYear, isLeap)
        realIdxLN = utl.leapNormToRealIdx(leapNorm, isLeap)
        if realIdxLN != dayOfYear then console.error("@#{dt} realIdx(=#{realIdxLN}) from leapNorm(=#{leapNorm}) is not dayOfYear(=#{dayOfYear})!")
        realIdxNLN = utl.nonLeapNormToRealIdx(nonLeapNorm, isLeap)
        if realIdxNLN != dayOfYear then console.error("@#{dt} realIdxA(=#{realIdxNLN}) from nonLeapNorm(=#{nonLeapNorm}) is not dayOfYear(=#{dayOfYear})!")

        olog { dt, year, isLeap, dayOfYear, leapNorm, nonLeapNorm, realIdxLN, realIdxNLN }
    return