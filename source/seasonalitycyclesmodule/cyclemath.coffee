############################################################
# Pure cycle logic (no DOM) - see SPEC.md §2, §4, §5, §6.1
# Dates are "YYYY-MM-DD" strings, all date math in UTC.
# Editor state: { presetName, origin, name, unit, size, k, labels, included, base } - k is the slider value
# (position of today's period), so the anchor is always normalized.
############################################################
DAY = 86400000

export UNITS = ["years", "quarters", "months", "weeks"]
export MAX_SIZE = { years: 20, quarters: 32, months: 32, weeks: 32 }
# size of a fresh Benutzerdefiniert
export DEFAULT_SIZE = { years: 4, quarters: 4, months: 6, weeks: 7 }

############################################################
#region Periods
pad = (n) -> String(n).padStart(2, "0")
utcYmd = (date) -> "#{date.getUTCFullYear()}-#{pad(date.getUTCMonth() + 1)}-#{pad(date.getUTCDate())}"

export mod = (a, n) -> ((a % n) + n) % n

export isValidYmd = (s) ->
    return false unless typeof s == "string" and /^\d{4}-\d{2}-\d{2}$/.test(s)
    [y, m, d] = s.split("-").map(Number)
    return utcYmd(new Date(Date.UTC(y, m - 1, d))) == s

export ymdOf = (d) -> "#{d.getFullYear()}-#{pad(d.getMonth() + 1)}-#{pad(d.getDate())}"
export todayYmd = -> ymdOf(new Date())

export periodIdxOfDate = (unit, ymd) ->
    [y, m, d] = ymd.split("-").map(Number)
    switch unit
        when "years" then y
        when "quarters" then y * 4 + Math.floor((m - 1) / 3)
        when "months" then y * 12 + m - 1
        # weeks since Monday 1970-01-05 (day number 4)
        when "weeks" then Math.floor((Date.UTC(y, m - 1, d) / DAY - 4) / 7)

export keyFromIdx = (unit, idx) ->
    switch unit
        when "years" then "#{idx}"
        when "quarters" then "#{Math.floor(idx / 4)}-Q#{mod(idx, 4) + 1}"
        when "months" then "#{Math.floor(idx / 12)}-#{pad(mod(idx, 12) + 1)}"
        when "weeks" then utcYmd(new Date((idx * 7 + 4) * DAY))

export labelFromIdx = (unit, idx) ->
    key = keyFromIdx(unit, idx)
    switch unit
        when "years" then key
        when "quarters", "months" then "#{key.slice(5)}.#{key.slice(0, 4)}"
        when "weeks" then key.split("-").reverse().join(".")

# returns null for a key not matching the unit (or a weeks key not on a Monday)
export idxFromKey = (unit, key) ->
    return null unless typeof key == "string"
    switch unit
        when "years"
            return if /^\d{4}$/.test(key) then Number(key) else null
        when "quarters"
            m = /^(\d{4})-Q([1-4])$/.exec(key)
            return m and Number(m[1]) * 4 + Number(m[2]) - 1
        when "months"
            m = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(key)
            return m and Number(m[1]) * 12 + Number(m[2]) - 1
        when "weeks"
            return null unless isValidYmd(key)
            idx = periodIdxOfDate("weeks", key)
            return if keyFromIdx("weeks", idx) == key then idx else null
    return null

#endregion

############################################################
#region Cycles + Grid
export positionOf = (idx, anchorIdx, n) -> mod(idx - anchorIdx, n)
export cycleOf = (idx, anchorIdx, n) -> Math.floor((idx - anchorIdx) / n)

# cycle: getCycle() setting; chunk k = k periods before the period of refYmd (newest data date)
export includedChunkFn = (cycle, refYmd) ->
    refIdx = periodIdxOfDate(cycle.unit, refYmd)
    anchorIdx = idxFromKey(cycle.unit, cycle.anchor)
    return (k) -> cycle.included[positionOf(refIdx - k, anchorIdx, cycle.size)] == true

export isFullCycle = (cycle) -> cycle.included.every((b) -> b == true)

# displayed chunk ages, oldest first: continuous (isIncluded null) [1, 0],
# single [d] with d = newest included age - null if no position is included
export displayAges = (cycle, isIncluded) ->
    return [1, 0] unless isIncluded?
    for k in [0...cycle.size] when isIncluded(k) then return [k]
    return null

# latest data only where unambiguous: continuous, or exactly one included position
# lying in the current / previous period - weeks have no fitting cycle, never in single mode
export showsLatest = (cycle, isIncluded, ages) ->
    return true unless isIncluded?
    return cycle.unit != "weeks" and ages[0] <= 1 and cycle.included.filter(Boolean).length == 1

# rows newest first; cells without data have label null
export buildGrid = (unit, n, anchorIdx, rangeFrom, rangeTo) ->
    pFrom = periodIdxOfDate(unit, rangeFrom)
    pTo = periodIdxOfDate(unit, rangeTo)
    rows = []
    for c in [cycleOf(pTo, anchorIdx, n)..cycleOf(pFrom, anchorIdx, n)] by -1
        cells = for pos in [0...n]
            idx = anchorIdx + c * n + pos
            label = if pFrom <= idx <= pTo then labelFromIdx(unit, idx) else null
            { key: keyFromIdx(unit, idx), label }
        rows.push({ cycle: c, cells })
    return rows

#endregion

############################################################
#region Editor State
# presetName: selected preset ("" = Benutzerdefiniert), origin: the saved custom preset
# the state came from (may be overwritten), name: content of the name input,
# base: { presetName, key } of the selected preset, so reverting all edits selects it again
export emptyState = -> { presetName: "", origin: "", name: "", unit: null, size: null, k: 0, labels: [], included: [], base: null }

fitLabels = (labels, size) -> (labels[i] ? "" for i in [0...(size ? 0)])
# included: positions taken into the analysis, new positions start included
fitIncluded = (included, size) -> (included[i] ? true for i in [0...(size ? 0)])

editKey = (s) -> JSON.stringify([s.name.trim(), s.unit, s.size, s.k, s.labels, s.included])
withBase = (state) -> { state..., base: { presetName: state.presetName, key: editKey(state) } }

# every edit turns the state into an unsaved Benutzerdefiniert - unless it is back at the base
edit = (state, changes) ->
    next = { state..., changes... }
    reverted = state.base? and editKey(next) == state.base.key
    return { next..., presetName: if reverted then state.base.presetName else "" }

export applySetting = (setting, today) ->
    { name, unit, size, anchor } = setting
    k = 0
    if anchor? then k = positionOf(periodIdxOfDate(unit, today), idxFromKey(unit, anchor), size)
    origin = if setting.official then "" else name
    labels = fitLabels(setting.labels ? [], size)
    included = fitIncluded(setting.included ? [], size)
    return withBase({ presetName: name, origin, name, unit, size, k, labels, included })

# "Benutzerdefiniert" picked in the select: default size of the unit, all positions included,
# starting with the current period
export customDefault = (unit) ->
    size = DEFAULT_SIZE[unit]
    return { emptyState()..., unit, size, labels: fitLabels([], size), included: fitIncluded([], size) }

export setUnit = (state, unit) ->
    size = state.size and Math.min(state.size, MAX_SIZE[unit])
    return edit(state, { unit, size, k: 0, labels: fitLabels([], size), included: fitIncluded([], size) })

# non-numeric or empty input keeps the last valid size
export commitSize = (state, raw) ->
    raw = String(raw).trim()
    v = Number(raw)
    return state unless state.unit and raw and !isNaN(v)
    size = Math.min(Math.max(Math.round(v), 1), MAX_SIZE[state.unit])
    labels = fitLabels(state.labels, size)
    included = fitIncluded(state.included, size)
    return edit(state, { size, k: Math.min(state.k, size - 1), labels, included })

export setSlider = (state, k) -> edit(state, { k })

export setLabel = (state, pos, text) ->
    labels = [state.labels...]
    labels[pos] = text
    return edit(state, { labels })

export setIncluded = (state, pos, isIncluded) ->
    included = [state.included...]
    included[pos] = isIncluded
    return edit(state, { included })

export setName = (state, name) -> edit(state, { name })

export anchorIdxOf = (state, today) -> periodIdxOfDate(state.unit, today) - state.k

export toSetting = (state, today) ->
    return null unless state.unit and state.size
    { unit, size, labels, included } = state
    anchor = keyFromIdx(unit, anchorIdxOf(state, today))
    return { name: state.name.trim(), unit, size, anchor, labels: [labels...], included: [included...] }

#endregion

############################################################
#region Presets
# presets: [{ name, unit, size, anchor, labels, included?, official? }] - official ones are never deletable
selectedPreset = (state, presets) -> presets.find((p) -> p.name == state.presetName)

# taken = used by an official or a different custom preset (own origin may be overwritten)
isTaken = (name, state, presets) -> presets.some((p) -> p.name == name and (p.official or p.name != state.origin))

export nameStatus = (state, presets) ->
    name = state.name.trim()
    selected = selectedPreset(state, presets)
    # only a name that blocks an otherwise possible save counts as taken
    savable = Boolean(state.unit and state.size and name) and !selected
    taken = savable and isTaken(name, state, presets)
    canSave = savable and !taken
    # the origin stays deletable while edited
    canDelete = presets.some((p) -> p.name == state.origin and !p.official)
    return { taken, canSave, canDelete }

# returns { reason: "incomplete" | "empty" | "duplicate" } or { presets, state }
export savePreset = (state, presets, today) ->
    setting = toSetting(state, today)
    return { reason: "incomplete" } unless setting
    { name } = setting
    return { reason: "empty" } unless name
    return { reason: "duplicate" } if isTaken(name, state, presets)
    i = presets.findIndex((p) -> p.name == name)
    presets = [presets...]
    if i < 0 then presets.push(setting) else presets[i] = setting
    return { presets, state: withBase({ state..., presetName: name, origin: name, name }) }

# deletes the origin (a custom preset, also while edited); the returned state keeps the values,
# the module then switches to the first preset of the timeframe
export deletePreset = (state, presets) ->
    return null unless nameStatus(state, presets).canDelete
    presets = presets.filter((p) -> p.name != state.origin)
    return { presets, state: { state..., presetName: "", origin: "", base: null } }

# validates presets coming back from storage
export isValidPreset = (p) ->
    return false unless p? and typeof p.name == "string" and p.name.trim()
    return false unless p.unit in UNITS and Number.isInteger(p.size)
    return false unless 1 <= p.size <= MAX_SIZE[p.unit]
    return false if p.labels? and !(Array.isArray(p.labels) and p.labels.length == p.size and p.labels.every((l) -> typeof l == "string"))
    return false if p.included? and !(Array.isArray(p.included) and p.included.length == p.size and p.included.every((b) -> typeof b == "boolean"))
    return !p.anchor? or idxFromKey(p.unit, p.anchor)?

#endregion
