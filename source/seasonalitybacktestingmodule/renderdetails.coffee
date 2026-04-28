############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("saisonalityframe:renderdetails")
#endregion

############################################################
#region DOM cache for the cases where the implicit-dom-connect fails
backtestingDetailsTable = document.getElementById("backtesting-details-table")
backtestingWarning = document.querySelector('#backtesting-details-container .warning')
#endregion

############################################################
# Table sorting state
currentYearlyResults = null
currentIsShort = false
sortColumn = "startDate"  # "startDate", "profit", "maxRise", "maxDrop"
sortAscending = false  # default: newest year first


############################################################
renderBacktestingTable = ->
    log "renderBacktestingTable"
    return unless currentYearlyResults?

    backtestingDetailsTable.innerHTML = ""

    # Sort data
    sortedResults = sortYearlyResults(currentYearlyResults)

    # Create header row with sort indicators
    thead = document.createElement("thead")
    headerRow = document.createElement("tr")
    headers = [
        { label: "Start", key: "startDate" }
        { label: "Ende" }
        { label: "Profit", key: "profit" }
        { label: "Profit Abs", key: "profitA" }
        { label: "Max Anstieg", key: "maxRise" }
        { label: "Max Anstieg Abs", key: "maxRiseA" }
        { label: "Max Rückgang", key: "maxDrop" }
        { label: "Max Rückgang Abs", key: "maxDropA" }
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
    backtestingDetailsTable.appendChild(thead)

    # Create body with sorted results
    tbody = document.createElement("tbody")
    for result in sortedResults
        row = document.createElement("tr")
        if result.warn then row.classList.add("warn")

        # Start date column
        startDateCell = document.createElement("td")
        startDateCell.textContent = formatDate(result.startDate)
        row.appendChild(startDateCell)

        # End date column
        endDateCell = document.createElement("td")
        endDateCell.textContent = formatDate(result.endDate)
        row.appendChild(endDateCell)

        # Profit column (flip sign for Short)
        profitCell = document.createElement("td")
        profit = if currentIsShort then -result.profitP else result.profitP
        profitCell.textContent = formatPercent(profit)
        profitCell.classList.add(if profit >= 0 then "positive" else "negative")
        row.appendChild(profitCell)

        # Profit Abs column
        profitAbsCell = document.createElement("td")
        profitAbs = result.startA * profit / 100
        profitAbsCell.textContent = formatAbsolute(profitAbs)
        profitAbsCell.classList.add(if profitAbs >= 0 then "positive" else "negative")
        row.appendChild(profitAbsCell)

        # Max Rise column
        maxRiseCell = document.createElement("td")
        maxRiseCell.textContent = formatPercent(result.maxRiseP)
        row.appendChild(maxRiseCell)

        # Max Rise Abs column
        maxRiseAbsCell = document.createElement("td")
        maxRiseAbs = result.startA * result.maxRiseP / 100
        maxRiseAbsCell.textContent = formatAbsolute(maxRiseAbs)
        row.appendChild(maxRiseAbsCell)

        # Max Drop column
        maxDropCell = document.createElement("td")
        maxDropCell.textContent = formatPercent(result.maxDropP)
        row.appendChild(maxDropCell)

        # Max Drop Abs column
        maxDropAbsCell = document.createElement("td")
        maxDropAbs = result.startA * result.maxDropP / 100
        maxDropAbsCell.textContent = formatAbsolute(maxDropAbs)
        row.appendChild(maxDropAbsCell)

        tbody.appendChild(row)

    backtestingDetailsTable.appendChild(tbody)
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
    renderBacktestingTable()
    return

sortYearlyResults = (results) ->
    sorted = [...results]  # Copy to avoid mutating original

    compareFn = switch sortColumn
        when "startDate"
            (a, b) -> a.year - b.year
        when "profit"
            if currentIsShort
                (a, b) -> (-a.profitP) - (-b.profitP)  # Flipped for Short
            else
                (a, b) -> a.profitP - b.profitP
        when "profitA"
            if currentIsShort
                (a, b) -> (-a.startA * a.profitP) - (-b.startA * b.profitP)
            else
                (a, b) -> (a.startA * a.profitP) - (b.startA * b.profitP)
        when "maxRise"
            (a, b) -> a.maxRiseP - b.maxRiseP
        when "maxRiseA"
            (a, b) -> (a.startA * a.maxRiseP) - (b.startA * b.maxRiseP)
        when "maxDrop"
            (a, b) -> (-a.maxDropP) - (-b.maxDropP) # Flipped for max Drops
        when "maxDropA"
            (a, b) -> (-a.startA * a.maxDropP) - (-b.startA * b.maxDropP)
        else
            (a, b) -> 0

    sorted.sort(compareFn)
    unless sortAscending then sorted.reverse()
    return sorted

############################################################
formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatAbsolute = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(2)}"

formatDate = (value) ->
    date = new Date(value)
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()

    dayStr = if day < 10 then "0#{day}" else "#{day}"
    monthStr = if month < 10 then "0#{month}" else "#{month}"
    return "#{dayStr}.#{monthStr}.#{year}"


############################################################
export render = (results) ->
    log "render"
    # Populate details table (reset sort state for new data)
    currentYearlyResults = results.yearlyResults
    currentIsShort = !results.isLong
    sortColumn = "startDate"
    sortAscending = false
    renderBacktestingTable()

    # Show warning if any year had anomalies
    if results.warn
        backtestingWarning.style.display = "block"
    else
        backtestingWarning.style.display = "none"

    return
