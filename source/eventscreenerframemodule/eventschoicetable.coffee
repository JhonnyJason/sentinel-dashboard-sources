############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventschoicetable")
#endregion

############################################################
import * as data from "./datamodule.js"
import * as S from "./statemodule.js"

############################################################
navKeys = new Set(['Backspace', 'Delete', 'Tab', 'ArrowLeft', 
'ArrowRight', 'End', 'Home'])
numKeys = new Set(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'])

############################################################
eventList = null
idToEvent = Object.create(null)

############################################################
eventChoiceRowTemplate = document.getElementById("event-choice-row-template")

############################################################
defaultState = {
    globalNumRange: 12
    globalDateRange: null
}

############################################################
localState = null
STATE_KEY = "event-choice-state"

############################################################
onEventChoiceChange = null
firstInitialization = true

############################################################
export initialize = (onChangeListener) ->
    log "initialize"
    if firstInitialization
        onEventChoiceChange = onChangeListener
        chooseEventInput.addEventListener("change", globalChoiceChanged)
        rangeNrInput.addEventListener("change", globalRangeNrChanged)
        rangeNrInput.addEventListener("keydown", numRangeKeyDowned)
        rangeDateInput.addEventListener("change", globalRangeDateChanged)
        rangeNrHead.querySelector(".edit-group").addEventListener("click", editGroupClicked)

        if !localState?
            localState = S.load(STATE_KEY)
            if !localState?
                localState = defaultState
                S.save(STATE_KEY, defaultState)

        S.setChangeDetectionFunction(STATE_KEY, () -> true)
        firstInitialization = false

    if eventList? then return onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    try
        eventList = await data.getEventList()

        # olog eventList
        for evnt in eventList
            idToEvent[evnt.id] = evnt
            eventState = localState[evnt.id]
            
            if !eventState? 
                isChosen = true
                isWeekly = (evnt.id == "e009") #Jobless Claims is weekly
                numRange = evnt.numScreenedEvents || localState.globalNumRange
                dateRange = null
                localState[evnt.id] = { isChosen, isWeekly, numRange, dateRange }
                log "created new EventState"
                olog eventState

        retrieveAllEventDates()
        updateEventOptions()
    catch err then log err
    return


############################################################
globalChoiceChanged = (evnt) ->
    log "globalChoiceChanged"
    isChosen = evnt.target.checked
    # olog { isChosen }
    evnt.isChosen = isChosen for evnt in eventList
    updateEventOptions()
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

globalRangeNrChanged = (evnt) ->
    log "globalRangeNrChanged"
    num = parseInt(this.value)
    if isNaN(num) then return this.value = localState.globalNumRange

    if num > 99 then num = 99
    if num < 3 then num = 3
    this.value = num
    localState.globalNumRange = num

    for evnt in eventList
        eventState = localState[evnt.id]
        eventState.numRange = num
        eventState.dateRange = dateFromNumEvents(num, evnt)
        updateEventDatesToScreen(evnt)

    S.save(STATE_KEY)
    updateEventOptions()
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

globalRangeDateChanged = (evnt) ->
    log "globalRangeDateChanged"
    date = this.value
    try dateObj = new Date(date)
    catch err
        log err
        this.value = localState.globalDateRange
        return

    today = new Date()
    minDate = new Date()
    minDate.setFullYear(minDate.getFullYear() - 31)

    if dateObj.getTime() > today.getTime() then date = today.toISOString().slice(0, 10)
    if dateObj.getTime() < minDate.getTime() then date = minDate.toISOString().slice(0, 10)
    localState.globalDateRange = date

    for evnt in eventList
        eventState = localState[evnt.id]
        thisDate = ""+date # copy date
        num = numEventsFromDate(thisDate, evnt)

        # deal with impossibilities...
        if num < 3
            num = 3
            thisDate = dateFromNumEvents(num, evnt)
        if num > 99 
            num = 99
            thisDate = dateFromNumEvents(num, evnt)

        eventState.numRange = num
        eventState.dateRange = thisDate
        updateEventDatesToScreen(evnt)

    S.save(STATE_KEY)
    updateEventOptions()
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

    ## TODO implement
    return


############################################################
retrieveAllEventDates = ->
    log "retrieveAllEventDates"
    try
        proms = eventList.map((evnt) -> data.getEventDates(evnt.id))
        datesList = await Promise.all(proms)
    catch err then log err
        
    for evnt,i in eventList
        try
            dates = datesList[i]
            if !Array.isArray(dates) then throw new Error("Event #{evnt.id} had invalid response!")
            
            evnt.dates = dates.sort()
            updateEventDatesToScreen(evnt)

        catch err then console.error(err)

    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

############################################################
updateEventDatesToScreen = (evnt) ->
    log "updateEventDatesToScreen"
    eventState = localState[evnt.id]
    if !eventState? then throw new Error("Event with id: #{evnt.id} did not have a localState!")

    isWeekly = eventState.isWeekly
    if eventState.dateRange?
        date = eventState.dateRange
        num = numEventsFromDate(date, evnt)
    else if eventState.numRange? then num = eventState.numRange
    else throw new Error("Event with id: #{evnt.id} did neither have a dateRange nor a numRange!")

    { datesToScreen, nextDates } = extractRelevantDates(num, evnt.dates, isWeekly)
    evnt.datesToScreen = datesToScreen
    evnt.nextDates = nextDates
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
dateFromNumEvents = (num, evnt) ->
    log "dateFromNumEvents"
    todayYYYYMMDD = (new Date()).toISOString().slice(0, 10)

    if !num? or num <= 0 then return todayYYYYMMDD
    if !evnt.dates? or evnt.dates.length == 0 then return todayYYYYMMDD

    i = 0
    while i < evnt.dates.length and evnt.dates[i] < todayYYYYMMDD
        i++

    if i == 0 then return todayYYYYMMDD # all events are in the future

    targetIdx = i - num
    if targetIdx < 0 then targetIdx = 0
    return evnt.dates[targetIdx]

numEventsFromDate = (date, evnt) ->
    log "numEventsFromDate"
    # olog { date, evnt }
    if !date? then return 0
    if !evnt.dates? or evnt.dates.length == 0 then return 0

    todayYYYYMMDD = (new Date()).toISOString().slice(0, 10)
    if date >= todayYYYYMMDD then return 0

    # Find theoretical index of date
    dateIdx = 0
    while dateIdx < evnt.dates.length and evnt.dates[dateIdx] < date
        dateIdx++

    # Find theoretical index of today
    # todayIdx = evnt.dates.length - 1
    # while todayIdx > 0 and evnt.dates[todayIdx] > todayYYYYMMDD
    #     todayIdx--
    todayIdx = 0
    while todayIdx < evnt.dates.length and evnt.dates[todayIdx] < todayYYYYMMDD
        todayIdx++

    num = todayIdx - dateIdx
    if num < 0 then return 0
    return num


############################################################
updateEventOptions = ->
    log "updateEventOptions"
    eventChoiceContent.innerHTML = ""

    rangeNrInput.value = localState.globalNumRange
    rangeDateInput.value = localState.globalDateRange

    for evnt in eventList
        el = createEventChoiceElement(evnt)
        eventChoiceContent.appendChild(el)

    return

############################################################
createEventChoiceElement = (evnt) ->
    log "createEventChoiceElement"
    eventState = localState[evnt.id]
    num = eventState.numRange || numEventsFromDate(eventState.dateRange, evnt)
    date = eventState.dateRange || dateFromNumEvents(eventState.numRange, evnt)

    el = document.importNode(eventChoiceRowTemplate.content, true)
    chosenInput = el.querySelector("input.choose")
    chosenInput.checked = eventState.isChosen
    el.querySelector('[data-name="c"]').textContent = evnt.label

    rangeNrEl = el.querySelector('[data-range-nr="c"]')
    rangeNrEl.value = num
    rangeNrEl.addEventListener("change", eventNumRangeChanged)
    rangeNrEl.addEventListener("keydown", numRangeKeyDowned)

    rangeDateEl = el.querySelector('[data-range-date="c"]')
    rangeDateEl.value = date
    rangeDateEl.addEventListener("change", eventDateRangeChanged)

    el.querySelector('[data-id="i"]').dataset.id = evnt.id
    el.querySelector('.choose').addEventListener("change", eventChoiceChanged)
    el.querySelector('.edit-group').addEventListener("click", editGroupClicked)
    return el.firstElementChild

############################################################
formatDate = (dateYYYYMMDD) ->
    tkns = dateYYYYMMDD.split("-")
    tkns = tkns.reverse()
    return tkns.join(".")

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

    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

############################################################
eventDateRangeChanged = (evnt) ->
    log "eventNumRangeChanged"
    rowEl = this.parentNode.parentNode
    evntId = rowEl.dataset.id
    log evntId
    eventState = localState[evntId]
    
    date = this.value
    try dateObj = new Date(date)
    catch err
        log err
        this.value = eventState.dateRange
        return

    num = numEventsFromDate(date, idToEvent[evntId])
    olog { num, date }

    # deal with impossibilities...
    if num < 3
        num = 3
        date = dateFromNumEvents(num, evnt)
    if num > 99 
        num = 99
        date = dateFromNumEvents(num, evnt)

    this.value = date
    numInput = rowEl.querySelector('[data-range-nr="c"]')
    numInput.value = num

    eventState.dateRange = date
    eventState.numRange = num
    updateEventDatesToScreen(idToEvent[evntId])

    S.save(STATE_KEY)
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

############################################################
eventNumRangeChanged = (evnt) ->
    log "eventNumRangeChanged"
    rowEl = this.parentNode.parentNode.parentNode
    evntId = rowEl.dataset.id
    log evntId
    eventState = localState[evntId]

    num = parseInt(this.value)    
    if isNaN(num) then return this.value = eventState.numRange

    if num > 99 then num = 99
    if num < 3 then num = 3
    
    this.value = num
    date = dateFromNumEvents(num, idToEvent[evntId])
    dateInput = rowEl.querySelector('[data-range-date="c"]')
    dateInput.value = date

    eventState.numRange = num
    eventState.dateRange = date
    updateEventDatesToScreen(idToEvent[evntId])

    S.save(STATE_KEY)
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return

############################################################
getPreviousValueForNumRangeInput = (input) ->
    log "getPreviousValueForNumRangeInput"
    ## TODO implement
    return

############################################################
numRangeKeyDowned = (evnt) ->
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
        input.value = getPreviousValueForNumRangeInput(input)
        input.blur()
        return

    evnt.preventDefault()
    return

############################################################
editGroupClicked = (evnt) ->
    # log "editGroupClicked"
    inputEl = this.querySelector("input")
    if inputEl? then inputEl.focus()
    return