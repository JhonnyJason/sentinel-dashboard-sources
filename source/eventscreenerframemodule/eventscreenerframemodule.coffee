############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventscreenerframemodule")
#endregion

############################################################
import * as dCache from "./datacache.js"
import * as utl from "./utilsmodule.js"

############################################################
import { SymbolSelect } from "./symbolselectmodule.js"
############################################################
import * as eventsChoice from "./eventschoicetable.js"
import * as resultTable from "./eventscreenerresults.js"
import * as filterState from "./resultfilterstate.js"

############################################################
symbolSelect = null

############################################################
chosenSymbols = new Set()
symbolToData = Object.create(null)

############################################################
chosenEvents = []

############################################################
symbolChoiceRowTemplate = document.getElementById("symbol-choice-row-template")

############################################################
isProcessing = false
processOnceMore = false

############################################################
export initialize = ->
    log "initialize"
    filterState.initialize()
    filterState.setOnChangeListener(onFilterUpdate)

    container = symbolSelectEventscreener # symbolSelectEventscreener.
    optionsLimit = 70

    symbolSelect = new SymbolSelect({ container, optionsLimit })
    symbolSelect.setOnSelectListener(onSymbolSelected)
    return

############################################################
export activate = -> 
    # required only once on startup, but after logged in
    # maybe more to be done here?
    eventsChoice.initialize(generateScreeningResult)
    return

############################################################
#region Events leading to reScreen

############################################################
#region FilterRowEvents

#endregion

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

    generateScreeningResult(chosenEvents)
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

    generateScreeningResult(chosenEvents)
    return

############################################################
onFilterUpdate = ->
    log "onFilterUpdate"
    generateScreeningResult(chosenEvents)
    return

#endregion

############################################################
#region Helper Functions
addSymbolChoice = (symbol, company) ->
    log "addSymbolChoice"
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
    for val in chosen
        log "val: #{val}"
        company = symbolToData[val].company
        el = document.importNode(symbolChoiceRowTemplate.content, true)
        el.querySelector('[data-symbol="c"]').textContent = val
        el.querySelector('[data-name="c"]').textContent = company
        el.querySelector('[data-symbol="i"]').dataset.symbol = val
        el.querySelector('.delete').addEventListener("click", deleteSymbolChoiceClicked)
        symbolChoiceList.appendChild(el)
    return

#endregion

############################################################
updateFilterRow = ->
    log "updateFilterRow"
    return

############################################################
generateScreeningResult = (events) ->
    log "generateScreeningResult"
    if !events? then chosenEvents = []
    else chosenEvents = events

    # guarding from multiple simultaneous runs 
    if isProcessing and processOnceMore then return
    if isProcessing then return processOnceMore = true
    
    isProcessing  = true
    try await resultTable.screenAndRender(chosenEvents, symbolToData)
    catch err then log err
    isProcessing = false
    
    if processOnceMore
        processOnceMore = false
        generateScreeningResult(chosenEvents)
    return