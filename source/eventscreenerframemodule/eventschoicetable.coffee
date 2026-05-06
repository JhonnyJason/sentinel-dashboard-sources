############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("eventschoicetable")
#endregion

############################################################
import * as data from "./datamodule.js"

############################################################
eventList = null
idToEvent = Object.create(null)

############################################################
eventChoiceRowTemplate = document.getElementById("event-choice-row-template")

############################################################
defaultEventNr = 12

############################################################
eventChoiState = null

############################################################
onEventChoiceChange = null

############################################################
export initialize = (onChangeListener) ->
    log "initialize"
    if !onEventChoiceChange?
        # only do this on first initialization
        onEventChoiceChange = onChangeListener
        chooseEventInput.addEventListener("change", globalChoiceChanged)
        rangeNrInput.addEventListener("change", globalRangeNrChanged)
        rangeDateInput.addEventListener("change", globalRangeDateChanged)

    # TODO reflect current choiceState in UI 

    if eventList? then return onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    try
        eventList = await data.getEventList()
        # olog eventList
        for evnt in eventList
            idToEvent[evnt.id] = evnt
            evnt.isChosen = true
            if !evnt.numScreenedEvents? then evnt.numScreenedEvents = defaultEventNr
            if !evnt.isWeekly?
                isWeekly = (evnt.id == "e009") #Jobless Claims is weekly
                evnt.isWeekly = isWeekly

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
    
    return

globalRangeDateChanged = (evnt) ->
    log "globalRangeDateChanged"

    return


############################################################
retrieveAllEventDates = ->
    log "retrieveAllEventDates"
    try
        proms = eventList.map((evnt) -> data.getEventDates(evnt.id))
        datesList = await Promise.all(proms)
        
        for evnt,i in eventList

            dates = datesList[i]
            if !Array.isArray(dates) then throw new Error("Event #{evnt.id} had invalid response!")
            
            evnt.dates = dates.sort()
            isWeekly = evnt.isWeekly
            num = evnt.numScreenedEvents

            { datesToScreen, nextDates } = extractRelevantDates(num, dates, isWeekly)
            
            evnt.datesToScreen = datesToScreen
            evnt.nextDates = nextDates

        onEventChoiceChange(eventList.filter((el) -> el.isChosen))
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
    olog { date, evnt }
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

    # # Add Company Events
    # evnt = {label: "Quartalsbericht", rangeNrText: "X", rangeDateText: "dd.mm.yyyy", id: "xxxx1"}
    # el = createEventChoiceElement(evnt)
    # inputEl = el.querySelector("input")
    # inputEl.checked = false
    # el.classList.add("inactive")
    # eventChoiceContent.appendChild(el)
    
    # evnt = {label: "Dividendenausschüttung", rangeNrText: "X", rangeDateText: "dd.mm.yyyy", id: "xxxx2"}
    # el = createEventChoiceElement(evnt)
    # inputEl = el.querySelector("input")
    # inputEl.checked = false
    # el.classList.add("inactive")
    # eventChoiceContent.appendChild(el)

    # el = document.createElement("tr")
    # el.appendChild(document.createElement("td"))
    # el.appendChild(document.createElement("td"))
    # el.appendChild(document.createElement("td"))
    # el.appendChild(document.createElement("td"))
    # el.classList.add("separator")
    # eventChoiceContent.appendChild(el)

    # Add Global known Events

    for evnt in eventList
        num = evnt.numScreenedEvents || defaultEventNr
        evnt.rangeNrText = "#{num}"
        date = evnt.rangeDate || dateFromNumEvents(num, evnt)
        evnt.rangeDateText = formatDate(date)
        
        el = createEventChoiceElement(evnt)
        eventChoiceContent.appendChild(el)

    return

############################################################
formatDate = (dateYYYYMMDD) ->
    tkns = dateYYYYMMDD.split("-")
    tkns = tkns.reverse()
    return tkns.join(".")

############################################################
createEventChoiceElement = (evnt) ->
    log "createEventChoiceElement"
    el = document.importNode(eventChoiceRowTemplate.content, true)
    chosenInput = el.querySelector("input.choose")
    chosenInput.checked = evnt.isChosen
    el.querySelector('[data-name="c"]').textContent = evnt.label

    rangeNrEl = el.querySelector('[data-range-nr="c"]')
    rangeNrEl.textContent = evnt.rangeNrText
    rangeNrEl.addEventListener("click", eventRangeClicked)

    rangeDateEl = el.querySelector('[data-range-date="c"]')
    rangeDateEl.textContent = evnt.rangeDateText
    rangeDateEl.addEventListener("click", eventRangeClicked)

    el.querySelector('[data-id="i"]').dataset.id = evnt.id

    el.querySelector('.choose').addEventListener("change", eventChoiceChanged)
    return el.firstElementChild

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
eventRangeClicked = (evnt) ->
    log "eventRangeClicked"
    ## TODO implement
    onEventChoiceChange(eventList.filter((el) -> el.isChosen))
    return
