############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("resultfilterstate")
#endregion

############################################################
import * as S from "./statemodule.js"

############################################################
navKeys = new Set(['Backspace', 'Delete', 'Tab', 'ArrowLeft', 
'ArrowRight', 'End', 'Home'])
numKeys = new Set(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'])

############################################################
filters = null
FILTERS_KEY = "eventscreener-result-filter"
############################################################
defaultFilters = {
    winrate: { active: true, value: 69.0 },
    profitAvg: { active: true, value: 1.0 },
    profitMed: { active: false, value: 1.0 },
    maxDuration: {active: false, value: 14 },
    minDuration: {active: true, value: 3 },
    
    ignoreConflicts: { active: false },
    preponeEntry: { active: false },
    postponeEntry: { active: true },
    preponeExit: { active: true},
    postponeExit: { active: false},

    longOnly: {active: false },
    shortOnly: {active: false },
    minMaxRise: { active: false, value: 5.0 },
    maxMaxRise: { active: false, value: 5.0 },
    minMaxDrop: { active: false, value: 5.0 },
    maxMaxDrop: { active: false, value: 5.0 },
}

############################################################
externalonChangeListener = null

############################################################
export initialize = ->
    log "initialize"
    filters = S.load(FILTERS_KEY)
    if !filters?
        filters = defaultFilters
        S.save(FILTERS_KEY, filters)
    S.setChangeDetectionFunction(FILTERS_KEY, () -> true)

    editGroups = filterPropertiesRow.getElementsByClassName("edit-group")
    group.addEventListener("click", editGroupClicked) for group in editGroups

    el = winrateFilter.querySelector("input.prop-active")
    el.addEventListener("change", winrateActiveChanged)
    el = winrateFilter.querySelector("input.prop-value")
    el.addEventListener("change", winrateValueChanged)

    el = profitAvgFilter.querySelector("input.prop-active")
    el.addEventListener("change", profitAvgActiveChanged)
    el = profitAvgFilter.querySelector("input.prop-value")
    el.addEventListener("change", profitAvgValueChanged)

    el = profitMedFilter.querySelector("input.prop-active")
    el.addEventListener("change", profitMedActiveChanged)
    el = profitMedFilter.querySelector("input.prop-value")
    el.addEventListener("change", profitMedValueChanged)

    el = maxDurationFilter.querySelector("input.prop-active")
    el.addEventListener("change", maxDurationActiveChanged)
    el = maxDurationFilter.querySelector("input.prop-value")
    el.addEventListener("change", maxDurationValueChanged)

    el = minDurationFilter.querySelector("input.prop-active")
    el.addEventListener("change", minDurationActiveChanged)
    el = minDurationFilter.querySelector("input.prop-value")
    el.addEventListener("change", minDurationValueChanged)



    el = longOnlyFilter.querySelector("input.prop-active")
    el.addEventListener("change", longOnlyActiveChanged)

    el = shortOnlyFilter.querySelector("input.prop-active")
    el.addEventListener("click", shortOnlyActiveChanged)

    el = minMaxRiseFilter.querySelector("input.prop-active")
    el.addEventListener("change", minMaxRiseActiveChanged)
    el = minMaxRiseFilter.querySelector("input.prop-value")
    el.addEventListener("change", minMaxRiseValueChanged)

    el = maxMaxRiseFilter.querySelector("input.prop-active")
    el.addEventListener("change", maxMaxRiseActiveChanged)
    el = maxMaxRiseFilter.querySelector("input.prop-value")
    el.addEventListener("change", maxMaxRiseValueChanged)

    el = minMaxDropFilter.querySelector("input.prop-active")
    el.addEventListener("change", minMaxDropActiveChanged)
    el = minMaxDropFilter.querySelector("input.prop-value")
    el.addEventListener("change", minMaxDropValueChanged)

    el = maxMaxDropFilter.querySelector("input.prop-active")
    el.addEventListener("change", maxMaxDropActiveChanged)
    el = maxMaxDropFilter.querySelector("input.prop-value")
    el.addEventListener("change", maxMaxDropValueChanged)


    el = ignoreHolidayConflictsFilter.querySelector("input.prop-active")
    el.addEventListener("click", ignoreHolidayConflictsActiveChanged)

    el = preponeHolidayEntryFilter.querySelector("input.prop-active")
    el.addEventListener("click", preponeHolidayEntryActiveChanged)

    el = postponeHolidayEntryFilter.querySelector("input.prop-active")
    el.addEventListener("click", postponeHolidayEntryActiveChanged)

    el = preponeHolidayExitFilter.querySelector("input.prop-active")
    el.addEventListener("click", preponeHolidayExitActiveChanged)

    el = postponeHolidayExitFilter.querySelector("input.prop-active")
    el.addEventListener("click", postponeHolidayExitActiveChanged)

    inputs = filterPropertiesRow.querySelectorAll("input.prop-value")
    el.addEventListener("keydown", inputKeyDowned) for el in inputs

    updateFilterUI()
    return

############################################################
export setOnChangeListener = (listener) -> externalonChangeListener = listener

############################################################
export filterResult = (result) ->
    # log "filterResult"

    if filters.winrate.active and result.winrate < filters.winrate.value
        return false
    if filters.profitAvg.active and result.profitAvg < filters.profitAvg.value
        return false
    if filters.profitMed.active and result.profitMed < filters.profitMed.value
        return false

    if filters.longOnly.active and result.direction == "Short" then return false
    if filters.shortOnly.active and result.direction == "Long" then return false

    if filters.minMaxRise.active and result.maxRise < filters.minMaxRise.value
        return false
    if filters.maxMaxRise.active and result.maxRise > filters.maxMaxRise.value
        return false
    if filters.minMaxDrop.active and -result.maxDrop < filters.minMaxDrop.value
        return false
    if filters.maxMaxDrop.active and -result.maxDrop > filters.maxMaxDrop.value
        return false 

    return true

############################################################
export getTradeDayConfig = ->
    log "getTradeDayConfig"
    tdc = Object.create(null)
    
    if filters.ignoreConflicts? then tdc.ignoreConflicts = filters.ignoreConflicts.active
    else tdc.ignoreConflicts = false
    

    if filters.preponeEntry? then tdc.preponeEntry = filters.preponeEntry.active
    else tdc.preponeEntry = false

    if filters.postponeEntry? then tdc.postponeEntry = filters.postponeEntry.active
    else tdc.postponeEntry = false


    if filters.preponeExit? then tdc.preponeExit = filters.preponeExit.active
    else tdc.preponeExit = false

    if filters.postponeExit? then tdc.postponeExit = filters.postponeExit.active
    else tdc.postponeExit = false

    
    if filters.minDuration? and filters.minDuration.active 
        tdc.minLength = filters.minDuration.value
    
    if filters.maxDuration? and filters.maxDuration.active 
        tdc.maxLength = filters.maxDuration.value
    
    return tdc

############################################################
updateFilterUI = ->
    log "updateFilterUI"

    # winrate: { active: true, value: 69.0 },
    if !filters.winrate? then filters.winrate = { active: true, value: 69.0 } # set default
    if filters.winrate.active then winrateFilter.classList.add("active")
    else winrateFilter.classList.remove("active")
    activeEl = winrateFilter.querySelector("input.prop-active")
    activeEl.checked = filters.winrate.active
    valueEl = winrateFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.winrate.value.toFixed(1))

    # profitAvg: { active: true, value: 1.0 },
    if !filters.profitAvg? then filters.profitAvg = { active: true, value: 1.0 } # set default
    if filters.profitAvg.active then profitAvgFilter.classList.add("active")
    else profitAvgFilter.classList.remove("active")
    activeEl = profitAvgFilter.querySelector("input.prop-active")
    activeEl.checked = filters.profitAvg.active
    valueEl = profitAvgFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.profitAvg.value.toFixed(1))

    # profitMed: { active: true, value: 1.0 },
    if !filters.profitMed? then filters.profitMed = { active: true, value: 1.0 } # set default
    if filters.profitMed.active then profitMedFilter.classList.add("active")
    else profitMedFilter.classList.remove("active")
    activeEl = profitMedFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.profitMed.active
    valueEl = profitMedFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.profitMed.value.toFixed(1))

    # maxDuration: { active: false, value: 14 },
    if !filters.maxDuration? then filters.maxDuration = { active: false, value: 14 } # set default
    else maxDurationFilter.classList.remove("active")
    activeEl = maxDurationFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.maxDuration.active
    valueEl = maxDurationFilter.querySelector("input.prop-value")
    valueEl.value = parseInt(filters.maxDuration.value.toFixed(0))

    # minDuration: { active: true, value: 3 },
    if !filters.minDuration? then filters.minDuration = { active: true, value: 3 } # set default
    if filters.minDuration.active then minDurationFilter.classList.add("active")
    else minDurationFilter.classList.remove("active")
    activeEl = minDurationFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.minDuration.active
    valueEl = minDurationFilter.querySelector("input.prop-value")
    valueEl.value = parseInt(filters.minDuration.value.toFixed(0))


    # longOnly: {active: false },
    if !filters.longOnly? then filters.longOnly = { active: false } # set default
    if filters.longOnly.active 
        longOnlyFilter.classList.add("active")
        filterPropertiesRow.classList.add("long-only")
    else
        longOnlyFilter.classList.remove("active")
        filterPropertiesRow.classList.remove("long-only")
    activeEl = longOnlyFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.longOnly.active

    # shortOnly: {active: false },
    if !filters.shortOnly? then filters.shortOnly = { active: false } # set default
    if filters.shortOnly.active
        shortOnlyFilter.classList.add("active")
        filterPropertiesRow.classList.add("short-only")
    else 
        shortOnlyFilter.classList.remove("active")
        filterPropertiesRow.classList.remove("short-only")
    activeEl = shortOnlyFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.shortOnly.active

    # minMaxRise: { active: false, value: 5.0 },
    if !filters.minMaxRise? then filters.minMaxRise = { active: false, value: 5.0 } # set default
    if filters.minMaxRise.active then minMaxRiseFilter.classList.add("active")
    else minMaxRiseFilter.classList.remove("active")
    activeEl = minMaxRiseFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.minMaxRise.active
    valueEl = minMaxRiseFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.minMaxRise.value.toFixed(1))

    # maxMaxRise: { active: false, value: 5.0 },
    if !filters.maxMaxRise? then filters.maxMaxRise = { active: false, value: 5.0 } # set default
    if filters.maxMaxRise.active then maxMaxRiseFilter.classList.add("active")
    else maxMaxRiseFilter.classList.remove("active")
    activeEl = maxMaxRiseFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.maxMaxRise.active
    valueEl = maxMaxRiseFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.maxMaxRise.value.toFixed(1))

    # minMaxDrop: { active: false, value: 5.0 },
    if !filters.minMaxDrop? then filters.minMaxDrop = { active: false, value: 5.0 } # set default
    if filters.minMaxDrop.active then minMaxDropFilter.classList.add("active")
    else minMaxDropFilter.classList.remove("active")
    activeEl = minMaxDropFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.minMaxDrop.active
    valueEl = minMaxDropFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.minMaxDrop.value.toFixed(1))

    # maxMaxDrop: { active: false, value: 5.0 },
    if !filters.maxMaxDrop? then filters.maxMaxDrop = { active: false, value: 5.0 } # set default
    if filters.maxMaxDrop.active then maxMaxDropFilter.classList.add("active")
    else maxMaxDropFilter.classList.remove("active")
    activeEl = maxMaxDropFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.maxMaxDrop.active
    valueEl = maxMaxDropFilter.querySelector("input.prop-value")
    valueEl.value = parseFloat(filters.maxMaxDrop.value.toFixed(1))

    

    # ignoreConflicts: {active: false }, #ignore-holiday-conflicts-filter
    if !filters.ignoreConflicts? then filters.ignoreConflicts = { active: false } # set default
    if filters.ignoreConflicts.active 
        ignoreHolidayConflictsFilter.classList.add("active")
    else
        ignoreHolidayConflictsFilter.classList.remove("active")
    activeEl = ignoreHolidayConflictsFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.ignoreConflicts.active

    # preponeEntry: {active: false }, #prepone-holiday-entry-filter
    if !filters.preponeEntry? then filters.preponeEntry = { active: false } # set default
    if filters.preponeEntry.active 
        preponeHolidayEntryFilter.classList.add("active")
    else
        preponeHolidayEntryFilter.classList.remove("active")
    activeEl = preponeHolidayEntryFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.preponeEntry.active

    # postponeEntry: {active: true }, #postpone-holiday-entry-filter
    if !filters.postponeEntry? then filters.postponeEntry = { active: true} # set default
    if filters.postponeEntry.active 
        postponeHolidayEntryFilter.classList.add("active")
    else
        postponeHolidayEntryFilter.classList.remove("active")
    activeEl = postponeHolidayEntryFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.postponeEntry.active

    # preponeExit: {active: true }, #prepone-holiday-entry-filter
    if !filters.preponeExit? then filters.preponeExit = { active: true} # set default
    if filters.preponeExit.active 
        preponeHolidayExitFilter.classList.add("active")
    else
        preponeHolidayExitFilter.classList.remove("active")
    activeEl = preponeHolidayExitFilter.querySelector("input.prop-active")
    activeEl.checked = filters.preponeExit.active

    # postponeExit: {active: false }, #postpone-holiday-exit-filter
    if !filters.postponeExit? then filters.postponeExit = { active: false} # set default
    if filters.postponeExit.active 
        postponeHolidayExitFilter.classList.add("active")
    else
        postponeHolidayExitFilter.classList.remove("active")
    activeEl = postponeHolidayExitFilter.querySelector("input.prop-active")
    activeEl.checked =  filters.postponeExit.active

    return

############################################################
onChange = ->
    S.save(FILTERS_KEY)
    updateFilterUI()
    if externalonChangeListener? then externalonChangeListener(filters)
    return

############################################################
getNextFocusableValueInput = (input) ->
    log "getNextFocusableValueInput"
    return null unless input.matches("input.prop-value")
    inputs = filterPropertiesRow.querySelectorAll("input.prop-value")
    for el, index in inputs
        if el == input
            return inputs[index + 1] if index < inputs.length - 1
    return null

getPreviousValueForInput = (input) ->
    log "getPreviousValueForInput"
    return null unless input.matches("input.prop-value")

    parent = input.closest(".filter-element")
    return null unless parent?

    switch parent.id
        when "winrate-filter" then return parseFloat(parseFloat(filters.winrate.value).toFixed(1))
        when "profit-avg-filter" then return parseFloat(parseFloat(filters.profitAvg.value).toFixed(1))
        when "profit-med-filter" then return parseFloat(parseFloat(filters.profitMed.value).toFixed(1))
        when "min-max-rise-filter" then return parseFloat(parseFloat(filters.minMaxRise.value).toFixed(1))
        when "max-max-rise-filter" then return parseFloat(parseFloat(filters.maxMaxRise.value).toFixed(1))
        when "min-max-drop-filter" then return parseFloat(parseFloat(filters.minMaxDrop.value).toFixed(1))
        when "max-max-drop-filter" then return parseFloat(parseFloat(filters.maxMaxDrop.value).toFixed(1))
        else return null

normalizeFloat = (value) ->
    log "normalizeFloat"
    value = value.replace(',', '.')
    value = value.replace(/[^0-9.\-]/g, '') # remove non-numerics ('.' and '-' allowed)
    value = value.replace(/(?!^)-/g, '') # remove misplaced '-''
    value = value.replace(/(\.\d*)\.+/g, '$1') # remove duplicate dots
    
    value = parseFloat(parseFloat(value).toFixed(1))
    if value > 100 then return 100
    else return value

############################################################
#region Event Listenersadd edit icons for editable elements
inputKeyDowned = (evnt) ->
    # log "inputKeyDowned"
    { key, ctrlKey, metaKey } = evnt
    # value = evnt.target.value
    input = evnt.target

    ## allow numbers, nav and editing
    if ctrlKey || metaKey || navKeys.has(key) || numKeys.has(key) then return

    if key == 'Enter'
        evnt.preventDefault()
        input.blur()
        # next = getNextFocusableValueInput(input)
        # if next? then next.focus()
        # else input.blur()
        return
        
    if key == 'Escape'
        evnt.preventDefault()
        input.value = getPreviousValueForInput(input)
        input.blur()
        return

    if key == ','
        evnt.preventDefault()
        if !input.value.includes('.') then insertAtCursor('.')
        return

    if key == '-'
        evnt.preventDefault();
        if input.selectionStart == 0 && !input.value.startsWith('-') then insertAtCursor('-')
        return

    if key == '.'
        if input.value.includes('.') then evnt.preventDefault()
        return

    evnt.preventDefault()
    return

editGroupClicked = (evnt) ->
    # log "editGroupClicked"
    inputEl = this.querySelector("input")
    if inputEl? then inputEl.focus()
    return

############################################################
winrateActiveChanged = (evnt) ->
    log "winrateActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.winrate.active = isActive
    onChange()
    return

winrateValueChanged = (evnt) ->
    log "winrateValueChanged"
    oldValue = filters.winrate.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue 
    else filters.winrate.value = newValue
    evnt.target.value = newValue

    if oldValue != newValue then onChange()
    return

############################################################
profitAvgActiveChanged = (evnt) ->
    log "profitAvgActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.profitAvg.active = isActive
    
    onChange()
    return

profitAvgValueChanged = (evnt) ->
    log "profitAvgValueChanged"
    oldValue = filters.profitAvg.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue 
    else filters.profitAvg.value = newValue
    evnt.target.value = newValue

    if oldValue != newValue then onChange()
    return

############################################################
profitMedActiveChanged = (evnt) ->
    log "profitMedActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.profitMed.active = isActive
    
    onChange()
    return

profitMedValueChanged = (evnt) ->
    log "profitMedValueChanged"
    oldValue = filters.profitMed.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.profitMed.value = newValue
    evnt.target.value = newValue

    if oldValue != newValue then onChange()
    return


############################################################
maxDurationActiveChanged = (evnt) ->
    log "maxDurationActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.maxDuration.active = isActive
    
    onChange()
    return

maxDurationValueChanged = (evnt) ->
    log "maxDurationValueChanged"
    oldValue = filters.maxDuration.value
    newValue = parseInt(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.maxDuration.value = newValue
    evnt.target.value = newValue

    if oldValue != newValue then onChange()
    return

############################################################
minDurationActiveChanged = (evnt) ->
    log "minDurationActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.minDuration.active = isActive
    
    onChange()
    return

minDurationValueChanged = (evnt) ->
    log "minDurationValueChanged"
    oldValue = filters.minDuration.value
    newValue = parseInt(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.minDuration.value = newValue
    evnt.target.value = newValue

    if oldValue != newValue then onChange()
    return


############################################################
longOnlyActiveChanged = (evnt) ->
    log "longOnlyActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.longOnly.active = isActive
    if isActive then filters.shortOnly.active = false 
    
    onChange()
    return

shortOnlyActiveChanged = (evnt) ->
    log "shortOnlyActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.shortOnly.active = isActive
    if isActive then filters.longOnly.active = false
    
    onChange()
    return


############################################################
minMaxRiseActiveChanged = (evnt) ->
    log "minMaxRiseActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.minMaxRise.active = isActive
    
    onChange()
    return

minMaxRiseValueChanged = (evnt) ->
    log "minMaxRiseValueChanged"
    oldValue = filters.minMaxRise.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.minMaxRise.value = newValue
    evnt.target.value = newValue
    
    if oldValue != newValue then onChange()
    return

############################################################
maxMaxRiseActiveChanged = (evnt) ->
    log "maxMaxRiseActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.maxMaxRise.active = isActive
    
    onChange()
    return

maxMaxRiseValueChanged = (evnt) ->
    log "maxMaxRiseValueChanged"
    oldValue = filters.maxMaxRise.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.maxMaxRise.value = newValue
    evnt.target.value = newValue
    
    if oldValue != newValue then onChange()
    return

############################################################
minMaxDropActiveChanged = (evnt) ->
    log "minMaxDropActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.minMaxDrop.active = isActive
    
    onChange()
    return

minMaxDropValueChanged = (evnt) ->
    log "minMaxDropValueChanged"
    oldValue = filters.minMaxDrop.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.minMaxDrop.value = newValue
    evnt.target.value = newValue
    
    if oldValue != newValue then onChange()
    return

############################################################
maxMaxDropActiveChanged = (evnt) ->
    log "maxMaxDropActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.maxMaxDrop.active = isActive
    
    onChange()
    return

maxMaxDropValueChanged = (evnt) ->
    log "maxMaxDropValueChanged"
    oldValue = filters.maxMaxDrop.value
    newValue = normalizeFloat(evnt.target.value)
    olog { newValue }
    if isNaN(newValue) then newValue = oldValue
    else filters.maxMaxDrop.value = newValue
    evnt.target.value = newValue
    
    if oldValue != newValue then onChange()
    return


############################################################
ignoreHolidayConflictsActiveChanged = (evnt) ->
    log "ignoreHolidayConflictsActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.ignoreConflicts.active = isActive
    if isActive # disable all adjustments
        filters.preponeEntry.active = false 
        filters.postponeEntry.active = false 
        filters.preponeExit.active = false 
        filters.postponeExit.active = false 
    else    # set to defautl adjustment
        filters.postponeEntry.active = true 
        filters.preponeExit.active = true 
        
    onChange()
    return

############################################################
preponeHolidayEntryActiveChanged = (evnt) ->
    log "preponeHolidayEntryActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.preponeEntry.active = isActive
    if isActive # TODO decide what needs to be done here :-)
        filters.ignoreConflicts.active = false
        # filters.preponeEntry.active = false 
        filters.postponeEntry.active = false 
    # else    
    #     filters.ignoreConflicts.active = false
    #     # filters.preponeEntry.active = false 
    #     filters.postponeEntry.active = false 
    #     filters.preponeExit.active = false 
    #     filters.postponeExit.active = false 
        
    onChange()
    return

############################################################
postponeHolidayEntryActiveChanged = (evnt) ->
    log "postponeHolidayEntryActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.postponeEntry.active = isActive
    if isActive # TODO decide what needs to be done here :-)
        filters.ignoreConflicts.active = false
        filters.preponeEntry.active = false 
        # filters.postponeEntry.active = false 
    # else    
    #     filters.ignoreConflicts.active = false
    #     # filters.preponeEntry.active = false 
    #     filters.postponeEntry.active = false 
    #     filters.preponeExit.active = false 
    #     filters.postponeExit.active = false 
        
    onChange()
    return

############################################################
preponeHolidayExitActiveChanged = (evnt) ->
    log "preponeHolidayExitActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.preponeExit.active = isActive
    if isActive # TODO decide what needs to be done here :-)
        filters.ignoreConflicts.active = false
        # filters.preponeExit.active = false 
        filters.postponeExit.active = false 
    # else    
    #     filters.ignoreConflicts.active = false
    #     # filters.preponeEntry.active = false 
    #     filters.postponeEntry.active = false 
    #     filters.preponeExit.active = false 
    #     filters.postponeExit.active = false 
        
    onChange()
    return

############################################################
postponeHolidayExitActiveChanged = (evnt) ->
    log "postponeHolidayExitActiveChanged"
    isActive = evnt.target.checked
    olog { isActive }
    filters.postponeExit.active = isActive
    if isActive # TODO decide what needs to be done here :-)
        filters.ignoreConflicts.active = false
        filters.preponeExit.active = false 
        # filters.postponeExit.active = false 
    # else    
    #     filters.ignoreConflicts.active = false
    #     # filters.preponeEntry.active = false 
    #     filters.postponeEntry.active = false 
    #     filters.preponeExit.active = false 
    #     filters.postponeExit.active = false 
        
    onChange()
    return


#endregion