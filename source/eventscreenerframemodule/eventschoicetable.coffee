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
    globalNumRange: ""
    globalDateRange: null
    globalDateRangeTo: null
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
    testFunctions()

    if firstInitialization
        onEventChoiceChange = onChangeListener
        chooseEventInput.addEventListener("change", globalChoiceChanged)
        rangeNrInput.addEventListener("change", globalRangeNrChanged)
        rangeNrInput.addEventListener("keydown", numRangeKeyDowned)
        rangeDateInput.addEventListener("change", globalRangeDateChanged)
        rangeDateToInput.addEventListener("change", globalRangeDateToChanged)
        rangeNrHead.querySelector(".edit-group").addEventListener("click", editGroupClicked)

        if !localState?
            localState = S.load(STATE_KEY)
            if !localState?
                localState = defaultState
                S.save(STATE_KEY, defaultState)

        S.setChangeDetectionFunction(STATE_KEY, () -> true)
        firstInitialization = false

    if eventList? then return onEventChoiceChange(getChosenEvents())
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
                dateRangeTo = null
                localState[evnt.id] = { isChosen, isWeekly, numRange, dateRange }
                log "created new EventState"
                olog eventState

        await retrieveAllEventDates()
        onUpdate()
    catch err then log err
    return

############################################################
onUpdate = ->
    S.save(STATE_KEY)
    updateEventOptions()
    chosenEvents = getChosenEvents()
    # olog chosenEvents.map((el) -> el.id)
    # olog localState
    onEventChoiceChange(chosenEvents)
    return

############################################################
globalChoiceChanged = ->
    log "globalChoiceChanged"
    isChosen = this.checked
    # olog { isChosen }
    localState[evnt.id].isChosen = isChosen for evnt in eventList
    return onUpdate()

globalRangeNrChanged = (evnt) ->
    log "globalRangeNrChanged"
    num = parseInt(this.value)
    if isNaN(num) then return this.value = localState.globalNumRange

    if num > 99 then num = 99
    if num < 3 then num = 3
    this.value = num
    localState.globalNumRange = num
    localState.globalDateRange = null
    localState.globalDateRangeTo = null
    
    for evnt in eventList
        eventState = localState[evnt.id]
        toDate = eventState.dateRangeTo
        
        fromDate = dateFromNumEvents(num, toDate, evnt)
        eventState.dateRange = fromDate
        
        ## calculate real effective num of events we have ;-)
        eventState.numRange = numEventsForDateRange(fromDate, toDate, evnt)
        
        updateEventDatesToScreen(evnt)

    return onUpdate()

globalRangeDateChanged = (evnt) ->
    log "globalRangeDateChanged"
    date = this.value
    if date == ""
        log "resetted globalDateRange!"
        localState.globalDateRange = null
        onUpdate()
        return

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
    
    ## this is the from-date
    localState.globalDateRange = date
    localState.globalDateRangeTo = null
    localState.globalNumRange = ""

    fromDate = localState.globalDateRange
    
    olog { fromDate, toDate }
    
    for evnt in eventList
        eventState = localState[evnt.id]
        toDate = eventState.dateRangeTo
        fromDate = localState.globalDateRange # reset to what we intend to set
        num = numEventsForDateRange(fromDate, toDate, evnt)

        # deal with impossibilities...
        if num < 3
            num = 3
            fromDate = dateFromNumEvents(num, toDate, evnt)
            num = numEventsForDateRange(fromDate, toDate, evnt)

        if num > 99
            num = 99
            fromDate = dateFromNumEvents(num, toDate, evnt)

        eventState.numRange = num
        eventState.dateRange = fromDate
        eventState.dateRangeTo = toDate
        updateEventDatesToScreen(evnt)

    return onUpdate()

globalRangeDateToChanged = (evnt) ->
    log "globalRangeDateToChanged"
    date = this.value
    if date == ""
        log "resetted globalDateRangeTo!"
        localState.globalDateRangeTo = null
        onUpdate()
        return

    try dateObj = new Date(date)
    catch err
        log err
        this.value = localState.globalDateRangeTo
        return
    
    # log "date preadjusted " + date

    today = new Date()
    minDate = new Date()
    minDate.setFullYear(minDate.getFullYear() - 31)
    
    todayYYYYMMDD = today.toISOString().slice(0, 10)
    
    if dateObj.getTime() > today.getTime() then date = todayYYYYMMDD
    if dateObj.getTime() < minDate.getTime() then date = minDate.toISOString().slice(0, 10)

    log "date postadjusted " + date

    ## this is the to-date
    localState.globalDateRangeTo = date
    localState.globalDateRange = null
    localState.globalNumRange = ""
    
    if localState.globalDateRangeTo == todayYYYYMMDD
        localState.globalDateRangeTo = null

    toDate = localState.globalDateRangeTo
    for evnt in eventList
        eventState = localState[evnt.id]
        fromDate = eventState.dateRange
        num = numEventsForDateRange(fromDate, toDate, evnt)

        # deal with impossibilities...
        if num < 3 # try to repair once
            num = 3
            fromDate = dateFromNumEvents(num, toDate, evnt)
            num = numEventsForDateRange(fromDate, toDate, evnt)
            ## simply apply the "post-repair-state" - or skip?
            # if num < 3 # we just donot have enough events... skip application
            #     log "Too few Events to screen even after fromDate adjustment! continue..."
            #     continue

        if num > 99 # we should always be able to recude size
            num = 99
            thisDate = dateFromNumEvents(num, toDate, evnt)

        eventState.numRange = num
        eventState.dateRange = fromDate
        eventState.dateRangeTo = toDate
        updateEventDatesToScreen(evnt)

    return onUpdate()


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
    return

############################################################
updateEventDatesToScreen = (evnt) ->
    # log "updateEventDatesToScreen"
    eventState = localState[evnt.id]
    if !eventState? then throw new Error("Event with id: #{evnt.id} did not have a localState!")

    isWeekly = eventState.isWeekly
    if eventState.dateRange?
        fromDate = eventState.dateRange
        toDate = eventState.dateRangeTo
        num = numEventsForDateRange(fromDate, toDate, evnt)
    else if eventState.numRange? then num = eventState.numRange
    else throw new Error("Event with id: #{evnt.id} did neither have a dateRange nor a numRange!")

    ## TODO do this somewhere else - it makes a difference to power users (tab open for days)
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
dateFromNumEvents = (num, toDate, evnt) ->
    # log "dateFromNumEvents"
    if !toDate? then toDate = (new Date()).toISOString().slice(0, 10)

    if !num? or num <= 0 then return toDate
    if !evnt.dates? or evnt.dates.length == 0 then return toDate

    i = 0
    while i < evnt.dates.length and evnt.dates[i] < toDate
        i++

    if i == 0 then return toDate # all events are in the future

    targetIdx = i - num
    if targetIdx < 0 then targetIdx = 0
    return evnt.dates[targetIdx]

numEventsForDateRange = (fromDate, toDate, evnt) ->
    # range Dates are provided as "YYYY-MM-DD" or null if they are not specified
    # log "numEventsForDateRange"
    # olog { fromDate, toDate, evnt }
    if !fromDate? then return 0 # no default fromDate
    if !toDate? then toDate = (new Date()).toISOString().slice(0, 10) # default toDate is today
    if fromDate >= toDate then return 0
    if !evnt.dates? or evnt.dates.length == 0 then return 0

    # Find start index - also counts date == fromDate!
    startIdx = 0
    while startIdx < evnt.dates.length and evnt.dates[startIdx] < fromDate
        startIdx++

    # Find end index - doesn't use date == toDate
    endIdx = 0
    while endIdx < evnt.dates.length and evnt.dates[endIdx] < toDate
        endIdx++

    num = endIdx - startIdx
    if num < 0 then return 0
    return num

############################################################
getChosenEvents = -> return eventList.filter(
    (evnt) -> 
        eventState = localState[evnt.id]
        if eventState? and eventState.isChosen == true then return true
        return false
)

############################################################
updateEventOptions = ->
    log "updateEventOptions"
    eventChoiceContent.innerHTML = ""

    if localState.globalNumRange? then rangeNrInput.value = localState.globalNumRange
    else rangeNrInput.value = ""

    if localState.globalDateRange? then rangeDateInput.value = localState.globalDateRange
    else rangeDateInput.value = ""
    
    if localState.globalDateRangeTo? then rangeDateToInput.value = localState.globalDateRangeTo
    else rangeDateToInput.value = ""

    for evnt in eventList
        el = createEventChoiceElement(evnt)
        eventChoiceContent.appendChild(el)

    return

############################################################
createEventChoiceElement = (evnt) ->
    log "createEventChoiceElement"
    # olog evnt
    eventState = localState[evnt.id]
    fromDate = eventState.dateRange
    toDate = eventState.dateRangeTo
    num = eventState.numRange || numEventsForDateRange(fromDate, toDate, evnt)
    date = eventState.dateRange || dateFromNumEvents(eventState.numRange, toDate, evnt)


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

    rangeDateToEl = el.querySelector('[data-range-to-date="c"]')
    if toDate? then rangeDateToEl.value = toDate 
    else rangeDateToEl.value = (new Date()).toISOString().slice(0, 10)
    rangeDateToEl.addEventListener("change", eventDateToRangeChanged)

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
    isChecked = this.checked
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
    if !localState[evntId]? then console.error("Event with id: #{evntId} did not have a localState!")
    
    localState[evntId].isChosen = isChecked
    onUpdate()
    return

############################################################
eventDateRangeChanged = (evnt) ->
    log "eventDateRangeChanged"
    rowEl = this.parentNode.parentNode
    evntId = rowEl.dataset.id
    log evntId
    eventState = localState[evntId]
    
    newFromDate = this.value
    try dateObj = new Date(newFromDate)
    catch err
        log err
        this.value = eventState.dateRange
        return

    evnt = idToEvent[evntId]
    toDate = eventState.dateRangeTo
    num = numEventsForDateRange(newFromDate, toDate, evnt)
    olog { num, newFromDate, toDate }

    # deal with impossibilities...
    if num < 3
        num = 3
        newFromDate = dateFromNumEvents(num, toDate, evnt)
        num = numEventsForDateRange(newFromDate, toDate, evnt)

    if num > 99
        num = 99
        newFromDate = dateFromNumEvents(num, toDate, evnt)

    eventState.dateRange = newFromDate
    eventState.numRange = num
    updateEventDatesToScreen(evnt)

    onUpdate()
    return

############################################################
eventDateToRangeChanged = (evnt) ->
    log "eventDateToRangeChanged"
    rowEl = this.parentNode.parentNode
    evntId = rowEl.dataset.id
    log evntId
    eventState = localState[evntId]
    
    newToDate = this.value
    try dateObj = new Date(newToDate)
    catch err
        log err
        this.value = eventState.dateRangeTo
        return

    todayYYYYMMDD = (new Date()).toISOString().slice(0, 10)
    if newToDate == "" then newToDate = todayYYYYMMDD
    if newToDate > todayYYYYMMDD then newToDate = todayYYYYMMDD

    evnt = idToEvent[evntId]
    fromDate = eventState.dateRange
    num = numEventsForDateRange(fromDate, newToDate, evnt)
    olog { num, fromDate, newToDate }

    # deal with impossibilities...
    if num < 3 # Try to repair once
        num = 3
        fromDate = dateFromNumEvents(num, newToDate, evnt)
        num = numEventsForDateRange(fromDate, newToDate, evnt)
        ## simply apply the "post-repair-state" - or skip?
        # if num < 3 # we just donot have enough events...
        #     log "Too few Events to screen even after fromDate adjustment! Resetting change..."
        #     this.value = eventState.dateRangeTo
        #     return

    if num > 99 # we should always be able to reduce size
        num = 99
        fromDate = dateFromNumEvents(num, newToDate, evnt)

    if newToDate == todayYYYYMMDD then eventState.dateRangeTo = null
    else eventState.dateRangeTo = newToDate
    
    eventState.dateRange = fromDate
    eventState.numRange = num

    updateEventDatesToScreen(evnt)

    onUpdate()
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

    # input > 99 or < 3 is not allowed
    if num > 99 then num = 99
    if num < 3 then num = 3
    
    evnt = idToEvent[evntId]
    toDate = eventState.dateRangeTo
    fromDate = dateFromNumEvents(num, toDate, evnt)
    num = numEventsForDateRange(fromDate, toDate, evnt)

    eventState.dateRange = fromDate
    eventState.numRange = num
    updateEventDatesToScreen(evnt)

    onUpdate()
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
        input.value = "" # this will take latest known value
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


############################################################
testFunctions = ->
    # log "testFunctions"
    # testNumEventsForDateRange()
    # testDateFromNumEvents()

    # log "all tests ended successfully :-)"
    return 

testDateFromNumEvents = ->
    log "testDateFromNumEvents"
    sampleEvnt = {
        id: "e010",
        label: "US Quarterly Financial Report",
        type: "USMakro",
        dates: [ 
            "2017-09-06", "2017-12-05", "2018-03-19", "2018-06-05", "2018-09-05",  
            "2018-12-04", "2019-03-18", "2019-06-05", "2019-09-04", "2019-12-03",
            "2020-03-23", "2020-06-08", "2020-09-08", "2020-12-08", "2021-03-22",
            "2021-06-08", "2021-09-07", "2021-12-07", "2022-03-21", "2022-06-07",
            "2022-09-07", "2022-12-07", "2023-03-20", "2023-06-06", "2023-09-06", 
            "2023-12-06", "2024-03-18", "2024-06-10", "2024-09-10", "2024-12-10",
            "2025-03-24", "2025-06-10", "2025-09-09", "2025-12-15", "2026-03-23",
            "2026-06-08", "2026-09-08", "2026-12-07"
        ]
        # ,
        # datesToScreen: [ 
        #     "2023-03-20", "2023-06-06", "2023-09-06", "2023-12-06", "2024-03-18",
        #     "2024-06-10", "2024-09-10", "2024-12-10", "2025-03-24", "2025-06-10", "2025-09-09",
        #     "2025-12-15", "2026-03-23", "2026-06-08" 
        # ],
        # nextDates: [ "2026-09-08", "2026-12-07" ]
    }
    sampleEvnt2 = {
        dates: ["2026-09-08", "2026-12-07" ] ## only future events
    }

    sampleEvnt3 = {
        dates: ["2026-06-08", "2026-09-08", "2026-12-07"] ## only future events
    }


    ## case 0 - no toDate available range
    toDate = null
    num = 3 # "2026-06-08", "2026-03-23" and "2025-12-15" -> "2025-12-15"
    desiredDate = "2025-12-15"
    date = dateFromNumEvents(num, toDate, sampleEvnt)
    
    if desiredDate != date then throw new Error("Case 0: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 1 - no toDate num larger than available range
    toDate = null
    num = 99 #  has only 38 dates -> "2017-09-06" = first available date
    desiredDate = "2017-09-06"
    date = dateFromNumEvents(num, toDate, sampleEvnt)
    
    if desiredDate != date then throw new Error("Case 1: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 2 - no toDate only future samples
    toDate = null
    num = 1
    # sampleEvnt2 only has ["2026-09-08", "2026-12-07"]
    # no date before today found -> return today
    desiredDate = (new Date()).toISOString().slice(0, 10) # today
    date = dateFromNumEvents(num, toDate, sampleEvnt2)
    
    if desiredDate != date then throw new Error("Case 2: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 3 - with toDate available range and toDate hits an event date
    toDate = "2026-06-08" # should be excluded
    num = 2 # "2026-03-23" and "2025-12-15" -> "2025-12-15"
    desiredDate = "2025-12-15"
    date = dateFromNumEvents(num, toDate, sampleEvnt)

    if desiredDate != date then throw new Error("Case 3: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 4 - with toDate available range 
    toDate = "2026-06-06" # should be excluded
    num = 3 # "2026-03-23", "2025-12-15" and "2025-09-09" -> "2025-09-09"
    desiredDate = "2025-09-09"
    date = dateFromNumEvents(num, toDate, sampleEvnt)

    if desiredDate != date then throw new Error("Case 4: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 5 - with toDate num larger than available range
    toDate = "2026-06-06" # should be excluded
    num = 99 #  has only 38 dates -> "2017-09-06" = first available date
    desiredDate = "2017-09-06"
    date = dateFromNumEvents(num, toDate, sampleEvnt)

    if desiredDate != date then throw new Error("Case 5: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    ## case 6 - with toDate only dates after toDate
    toDate = "2026-06-06" # should be excluded
    num = 1 
    # sampleEvnt3 only has ["2026-06-08", "2026-09-08", "2026-12-07"]
    # no date before toDate found -> return toDate
    desiredDate = "2026-06-06"
    date = dateFromNumEvents(num, toDate, sampleEvnt3)

    if desiredDate != date then throw new Error("Case 5: Error!\n desiredDate: #{desiredDate} vs date: #{date}")

    return

testNumEventsForDateRange = ->
    log "testNumEventsForDateRange"
    sampleEvnt = {
        id: "e010",
        label: "US Quarterly Financial Report",
        type: "USMakro",
        dates: [ 
            "2017-09-06", "2017-12-05", "2018-03-19", "2018-06-05", "2018-09-05",  
            "2018-12-04", "2019-03-18", "2019-06-05", "2019-09-04", "2019-12-03",
            "2020-03-23", "2020-06-08", "2020-09-08", "2020-12-08", "2021-03-22",
            "2021-06-08", "2021-09-07", "2021-12-07", "2022-03-21", "2022-06-07",
            "2022-09-07", "2022-12-07", "2023-03-20", "2023-06-06", "2023-09-06", 
            "2023-12-06", "2024-03-18", "2024-06-10", "2024-09-10", "2024-12-10",
            "2025-03-24", "2025-06-10", "2025-09-09", "2025-12-15", "2026-03-23",
            "2026-06-08", "2026-09-08", "2026-12-07"
        ]
        # ,
        # datesToScreen: [ 
        #     "2023-03-20", "2023-06-06", "2023-09-06", "2023-12-06", "2024-03-18",
        #     "2024-06-10", "2024-09-10", "2024-12-10", "2025-03-24", "2025-06-10", "2025-09-09",
        #     "2025-12-15", "2026-03-23", "2026-06-08" 
        # ],
        # nextDates: [ "2026-09-08", "2026-12-07" ]
    }


    # "2025-03-24", "2025-06-10", "2025-09-09", "2025-12-15", "2026-03-23",
    # "2026-06-08", "2026-09-08"


    ## case 0 - valid range without toDate and fromDate right before an event date
    fromDate = "2026-06-07"
    # should find "2026-06-08" -> 1
    toDate = null

    desiredNum = 1
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case: 0 Error!\n desiredNum: #{desiredNum} vs num: #{num}")


    ## case 1 - valid range without toDate and fromDate right on an event date
    fromDate = "2026-03-23"
    # should find: "2026-03-23" and "2026-06-08" -> 2
    toDate = null

    desiredNum = 2
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 1: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case 2 - valid range with toDate and fromDate right before an event date
    fromDate = "2025-09-08"
    # should find: "2025-09-09", "2025-12-15" and "2026-03-23" -> 3
    toDate = "2026-06-07"

    desiredNum = 3
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 2: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case 3 - valid range with fromDate and toDate right on an event date
    fromDate = "2025-06-10"
    # should find: "2025-06-10", "2025-09-09", "2025-12-15" and "2026-03-23" -> 4
    # should not find "2026-06-08"
    toDate = "2026-06-08"

    desiredNum = 4
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 3: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case 4 - valid range with fromDate and toDate just right after an event date
    fromDate = "2025-03-25"
    # should find: "2025-06-10", "2025-09-09", "2025-12-15", "2026-03-23" and "2026-06-08" -> 5
    toDate = "2026-06-09"

    desiredNum = 5
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 4: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case 5 - invalid range fromDate cannot be null -> 0
    fromDate = null
    toDate = "2026-06-09"

    desiredNum = 0
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 5: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case: 6 - invalid range toDate < fromDate -> 0
    fromDate = "2025-06-11"
    toDate = "2025-06-09"

    desiredNum = 0
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case: 6 Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    ## case 7 - valid range but no event -> 0
    fromDate = "2025-06-11"
    toDate = "2025-06-18"

    desiredNum = 0
    num = numEventsForDateRange(fromDate, toDate, sampleEvnt)

    if desiredNum != num then throw new Error("Case 7: Error!\n desiredNum: #{desiredNum} vs num: #{num}")

    return
