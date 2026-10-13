############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalitycyclesmodule")
#endregion

############################################################
import * as C from "./cyclemath.js"
import * as S from "./statemodule.js"

############################################################
NO_DATA = "Keine Daten im gewählten Zeitraum"
TAKEN = "Name existiert bereits"
PRESETS_KEY = "seasonalitycycles-user-presets"
MAX_ROWS = 2 # current + previous cycle cover every position
DELETE_UNLOCK_MS = 10000

MONTHS = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

# one official preset per position of a cycle, only that position included
cyclePresets = (cycle, names) ->
    for name, pos in names
        { cycle..., name, included: (i == pos for i in [0...cycle.size]), official: true }

fixedPresets = [
    cyclePresets({ unit: "years", size: 4, anchor: "2024", labels: ["Wahljahr", "Nachwahljahr", "Midterm-Jahr", "Vorwahljahr"] }, ["US Wahljahr", "US Nachwahljahr", "US Midterm-Jahr", "US Vorwahljahr"])...
    cyclePresets({ unit: "quarters", size: 4, anchor: "2026-Q1", labels: ["Q1", "Q2", "Q3", "Q4"] }, ["1. Quartal", "2. Quartal", "3. Quartal", "4. Quartal"])...
    cyclePresets({ unit: "months", size: 12, anchor: "2026-01", labels: MONTHS }, MONTHS)...
    cyclePresets({ unit: "months", size: 3, anchor: "2026-01", labels: ["1. Monat", "2. Monat", "3. Monat"] }, ["1. Monat im Quartal", "2. Monat im Quartal", "3. Monat im Quartal"])...
]

# units with a chart timeframe
USABLE_UNITS = ["years", "quarters", "months", "weeks"]

############################################################
#region State
presets = [] # official presets first, then the user presets
state = C.emptyState()
active = false # false = "Kein Zyklus"
unit = "years" # follows the chart timeframe (setUnit), filters the presets
rangeFrom = null
rangeTo = null
onChange = null
deleteUnlockedFor = "" # preset name armed by the first delete click
deleteLockTimer = null

#endregion

############################################################
export initialize = ->
    log "initialize"
    cyclesSelect.addEventListener("change", presetSelected)
    cyclesNameInput.addEventListener("input", nameChanged)
    cyclesSaveButton.addEventListener("click", saveClicked)
    cyclesDeleteButton.addEventListener("click", deleteClicked)
    cyclesSizeInput.addEventListener("change", sizeCommitted)
    cyclesAnchorSlider.addEventListener("input", sliderMoved)
    cyclesAnchorSlider.addEventListener("change", emitChange)
    cyclesTableArea.addEventListener("input", labelChanged)
    cyclesTableArea.addEventListener("change", tableChanged)
    loadPresets()
    renderPresetOptions()
    render()
    return

############################################################
#region Event Listeners
presetSelected = ->
    value = cyclesSelect.value
    active = value != "none"
    if value.startsWith("p:")
        preset = presets.find((p) -> p.name == value.slice(2))
        state = C.applySetting(preset, C.todayYmd())
    else if value == "custom" then state = C.customDefault(unit)
    render()
    emitChange()
    return

sizeCommitted = ->
    state = C.commitSize(state, cyclesSizeInput.value)
    render()
    emitChange()
    return

# live render while dragging, emit only on commit ("change")
sliderMoved = ->
    # mirrored: right = later anchor (k = 0)
    state = C.setSlider(state, Number(cyclesAnchorSlider.max) - Number(cyclesAnchorSlider.value))
    render()
    return

# label inputs live in the table header: don't rebuild the table while typing
labelChanged = (evt) ->
    pos = evt.target.dataset.pos
    return unless pos?
    state = C.setLabel(state, Number(pos), evt.target.value)
    renderControls()
    return

# label commit or position checkbox toggled
tableChanged = (evt) ->
    pos = evt.target.dataset.include
    if pos?
        state = C.setIncluded(state, Number(pos), evt.target.checked)
        # toggle in place instead of rebuilding the table, so the checkbox keeps focus
        for td in cyclesTableArea.querySelectorAll("tbody tr:not(.more) td:nth-child(#{Number(pos) + 1})")
            td.classList.toggle("included", evt.target.checked)
        renderControls()
    emitChange()
    return

nameChanged = ->
    state = C.setName(state, cyclesNameInput.value)
    renderControls()
    return

saveClicked = ->
    result = C.savePreset(state, presets, C.todayYmd())
    return unless result.presets
    applyPresetChange(result)
    return

# first click unlocks (and discards edits, so it shows what gets deleted), second click deletes
deleteClicked = ->
    if deleteUnlockedFor
        result = C.deletePreset(state, presets)
        lockDelete()
        return unless result
        # continue with the first preset of this timeframe, "Kein Zyklus" if there is none
        first = result.presets.find((p) -> p.unit == unit)
        if first then result.state = C.applySetting(first, C.todayYmd())
        else
            result.state = C.emptyState()
            active = false
        applyPresetChange(result)
        return
    origin = presets.find((p) -> p.name == state.origin)
    return unless origin
    deleteUnlockedFor = origin.name
    deleteLockTimer = setTimeout(lockDelete, DELETE_UNLOCK_MS)
    if state.presetName != origin.name
        state = C.applySetting(origin, C.todayYmd())
        render()
        emitChange()
    else renderControls()
    return

lockDelete = ->
    deleteUnlockedFor = ""
    renderControls()
    return

applyPresetChange = (result) ->
    { presets, state } = result
    S.save(PRESETS_KEY, presets.filter((p) -> !p.official))
    renderPresetOptions()
    render()
    emitChange()
    return

# fires only with a complete cycle, or null when switched to "Kein Zyklus"
emitChange = ->
    cycle = getCycle()
    if cycle? or !active then onChange?(cycle)
    return

#endregion

############################################################
#region Presets
# stored presets come from localStorage: keep only valid, uniquely named ones
loadPresets = ->
    S.setChangeDetectionFunction(PRESETS_KEY, -> true)
    stored = S.get(PRESETS_KEY)
    stored = [] unless Array.isArray(stored)
    presets = [fixedPresets...]
    for p in stored when C.isValidPreset(p) and p.unit in USABLE_UNITS and !presets.some((q) -> q.name == p.name)
        presets.push({ name: p.name, unit: p.unit, size: p.size, anchor: p.anchor, labels: p.labels, included: p.included })
    return

#endregion

############################################################
#region Rendering
renderPresetOptions = ->
    options = (new Option(p.name, "p:" + p.name) for p in presets when p.unit == unit)
    cyclesSelect.replaceChildren(new Option("Kein Zyklus", "none"), options..., new Option("Benutzerdefiniert", "custom"))
    return

render = ->
    today = C.todayYmd()
    complete = Boolean(state.unit and state.size)
    seasonalitycycles.hidden = !active

    cyclesSizeInput.disabled = !state.unit
    if state.unit then cyclesSizeInput.max = C.MAX_SIZE[state.unit]
    cyclesSizeInput.value = state.size ? ""

    cyclesAnchorSlider.disabled = !complete
    cyclesAnchorSlider.max = if complete then state.size - 1 else 0
    cyclesAnchorSlider.value = Number(cyclesAnchorSlider.max) - state.k

    start = if complete then " " + C.labelFromIdx(state.unit, C.anchorIdxOf(state, today)) else ""
    cyclesAnchorReadout.textContent = "Zyklus beginnt#{start}"

    renderControls()
    renderTable(complete, today)
    return

# select, name line and buttons - everything that changes while typing
renderControls = ->
    if !active then cyclesSelect.value = "none"
    else if state.presetName then cyclesSelect.value = "p:" + state.presetName
    else cyclesSelect.value = "custom"

    # only write on change, so the caret doesn't jump while typing
    if cyclesNameInput.value != state.name then cyclesNameInput.value = state.name
    { taken, canSave, canDelete } = C.nameStatus(state, presets)
    cyclesNameInput.classList.toggle("taken", taken)
    cyclesNameHint.textContent = if taken then TAKEN else ""
    cyclesSaveButton.disabled = !canSave
    cyclesDeleteButton.disabled = !canDelete
    # any change away from the armed preset locks again
    if state.presetName != deleteUnlockedFor then deleteUnlockedFor = ""
    if !deleteUnlockedFor then clearTimeout(deleteLockTimer)
    cyclesDeleteButton.classList.toggle("unlocked", Boolean(deleteUnlockedFor))
    cyclesDeleteButton.title = if deleteUnlockedFor then "Erneut klicken zum Löschen" else ""
    return

renderTable = (complete, today) ->
    cyclesTableArea.replaceChildren()
    return unless complete
    unless rangeFrom and rangeTo and rangeFrom <= rangeTo
        cyclesTableArea.textContent = NO_DATA
        return

    n = state.size
    rows = C.buildGrid(state.unit, n, C.anchorIdxOf(state, today), rangeFrom, rangeTo)
    head = for pos in [0...n]
        "<th><label class=\"edit-group\"><input type=\"text\" data-pos=\"#{pos}\" placeholder=\"#{pos}\" aria-label=\"Bezeichnung Position #{pos}\"><svg><use href=\"#svg-edit-icon\"></use></svg></label></th>"
    checks = for pos in [0...n]
        checked = if state.included[pos] then " checked" else ""
        "<th><input type=\"checkbox\" data-include=\"#{pos}\"#{checked} aria-label=\"Position #{pos} einbeziehen\"></th>"
    body = for row in rows.slice(0, MAX_ROWS)
        cells = for c, pos in row.cells
            classes = []
            if !c.label? then classes.push("empty")
            if state.included[pos] then classes.push("included")
            "<td class=\"#{classes.join(" ")}\" data-period=\"#{c.key}\">#{c.label ? ""}</td>"
        "<tr>#{cells.join("")}</tr>"
    if rows.length > MAX_ROWS then body.push("<tr class=\"more\"><td colspan=\"#{n}\">⋮</td></tr>")
    # only generated keys and labels here - the user's position labels go in as values below
    cyclesTableArea.innerHTML = "<table><thead><tr>#{head.join("")}</tr><tr>#{checks.join("")}</tr></thead><tbody>#{body.join("")}</tbody></table>"
    input.value = state.labels[i] for input, i in cyclesTableArea.querySelectorAll("th input")
    return

#endregion

############################################################
#region Exports
# back to "Kein Zyklus" without emitting - the caller reloads
export deactivate = ->
    active = false
    render()
    return

# from / to: "YYYY-MM-DD", inclusive; invalid dates show the no-data message
export setRange = (from, to) ->
    rangeFrom = if C.isValidYmd(from) then from else null
    rangeTo = if C.isValidYmd(to) then to else null
    render()
    return

# the active cycle { name, unit, size, anchor, labels, included } or null
export getCycle = -> if active then C.toSetting(state, C.todayYmd()) else null

export setOnChangeListener = (fn) -> onChange = fn

# the chart timeframe changed: back to "Kein Zyklus", only presets of the new unit are offered
export setUnit = (newUnit) ->
    return if newUnit == unit
    unit = newUnit
    wasActive = active
    active = false
    # Benutzerdefiniert continues from the values, converted to the new unit
    if state.unit then state = C.setUnit(state, unit)
    renderPresetOptions()
    render()
    if wasActive then emitChange()
    return

#endregion
