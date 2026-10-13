############################################################
# Pure chart layout (no DOM) - axis + series for the seasonality chart
# ages: displayed chunk ages, oldest first - continuous [1, 0], single [d]
# chunks and composites are in slot space (see marketdatamodule getCloseChunks),
# each part only keeps the slots existing in its period, so FEB29 / day 29-31
# appear exactly where the calendar has them
############################################################
import * as utl from "./utilsmodule.js"

############################################################
# the period `age` periods before the period of refDate
# returns { slots, start } - start at noon of the first day
export periodPart = (timeframe, refDate, age) ->
    y = refDate.getFullYear()
    m = refDate.getMonth()
    switch timeframe
        when "yearly"
            year = y - age
            slots = [0...366]
            if !utl.isLeapYear(year) then slots.splice(utl.FEB29, 1)
            return { slots, start: new Date(year, 0, 1, 12) }
        when "quarterly"
            start = new Date(y, m - m % 3 - 3 * age, 1, 12)
            slots = []
            for i in [0...3]
                days = daysInMonth(start.getFullYear(), start.getMonth() + i)
                slots.push(i * 31 + d) for d in [0...days]
            return { slots, start }
        when "monthly"
            start = new Date(y, m - age, 1, 12)
            return { slots: [0...daysInMonth(start.getFullYear(), start.getMonth())], start }
        when "weekly"
            # slot 0 = Monday, getDay() has Sunday = 0
            start = new Date(y, m, refDate.getDate() - (refDate.getDay() + 6) % 7 - 7 * age, 12)
            return { slots: [0...7], start }
    throw new Error("periodPart: unknown timeframe #{timeframe}")

daysInMonth = (year, month) -> new Date(year, month + 1, 0).getDate()

############################################################
# returns { ages, parts, xAxisData, backStartIdx } - backStartIdx = start of the last part
export buildAxis = (timeframe, refDate, ages) ->
    parts = (periodPart(timeframe, refDate, age) for age in ages)
    xAxisData = parts.flatMap((p) -> dayAxis(p.start, p.slots.length))
    backStartIdx = xAxisData.length - parts[parts.length - 1].slots.length
    return { ages, parts, xAxisData, backStartIdx }

dayAxis = (startDate, days) ->
    startTS = startDate.getTime() / 1000
    return (startTS + i * 86_400 for i in [0...days])

############################################################
# composite: N + 1 points, point i + 1 = end of slot i
# the 100 point is the start of the last part: earlier parts are built backward
# ending at 100, the last part forward from 100 - the turn of period is a real factor
export placeComposite = (axis, composite) ->
    factors = utl.toFactorsArray(composite)
    partFactors = ((factors[s] for s in p.slots) for p in axis.parts)
    lastFactors = partFactors.pop()
    frontFactors = partFactors.flat()
    front = if frontFactors.length then utl.fromFactorsBackward(frontFactors).slice(1) else []
    return [...front, ...utl.fromFactorsForward(lastFactors).slice(1)]

############################################################
# chunks: close chunks, newest first - chunk ages[j] is shown on part j, in percent of
# the last close before the last part (fallback: the first close of the last part)
export placeLatest = (axis, chunks) ->
    lastAge = axis.ages[axis.ages.length - 1]
    ref = numbers(chunks[lastAge + 1]).pop() ? numbers(chunks[lastAge])[0]
    toPercent = (v) -> if Number.isFinite(v) and ref? then 100 * v / ref else null
    return axis.parts.flatMap((p, j) -> (toPercent(chunks[axis.ages[j]]?[s]) for s in p.slots))

numbers = (chunk) -> (chunk ? []).filter(Number.isFinite)
