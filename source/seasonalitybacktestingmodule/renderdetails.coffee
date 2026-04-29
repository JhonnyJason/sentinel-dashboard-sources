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
        { label: "Startkurs"}
        { label: "Endkurs"}
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
        td = document.createElement("td")
        td.textContent = formatDate(result.entryDate)
        row.appendChild(td)

        # Start price column
        td = document.createElement("td")
        td.innerHTML = formatAbsolutePrice(result.startAba, result.missingF)
        row.appendChild(td)

        # End price column
        td = document.createElement("td")
        endPriceAba = result.startAba * result.changeF
        td.innerHTML = formatAbsolutePrice(endPriceAba, result.missingF)
        row.appendChild(td)

        # End date column
        td = document.createElement("td")
        td.textContent = formatDate(result.exitDate)
        row.appendChild(td)


        # Profit column (flip sign for Short)
        td = document.createElement("td")
        profit = if currentIsShort then -result.changeP else result.changeP
        td.textContent = formatPercent(profit)
        td.classList.add(if profit >= 0 then "positive" else "negative")
        row.appendChild(td)

        # Profit Abs column
        td = document.createElement("td")
        profitAbs = result.startAba * profit / 100
        td.innerHTML = formatAbsoluteDelta(profitAbs, result.missingF)
        td.classList.add(if profitAbs >= 0 then "positive" else "negative")
        row.appendChild(td)

        # Max Rise column
        td = document.createElement("td")
        td.textContent = formatPercent(result.maxRiseP)
        row.appendChild(td)

        # Max Rise Abs column
        td = document.createElement("td")
        maxRiseAbs = result.startAba * result.maxRiseP / 100
        td.innerHTML = formatAbsoluteDelta(maxRiseAbs, result.missingF)
        row.appendChild(td)

        # Max Drop column
        td = document.createElement("td")
        td.textContent = formatPercent(result.maxDropP)
        row.appendChild(td)

        # Max Drop Abs column
        td = document.createElement("td")
        maxDropAbs = result.startAba * result.maxDropP / 100
        td.innerHTML = formatAbsoluteDelta(maxDropAbs, result.missingF)
        row.appendChild(td)

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
                (a, b) -> (-a.changeP) - (-b.changeP)  # Flipped for Short
            else
                (a, b) -> a.changeP - b.changeP
        when "profitA"
            if currentIsShort
                (a, b) -> (-a.startAr * a.changeP) - (-b.startAr * b.changeP)
            else
                (a, b) -> (a.startAr * a.changeP) - (b.startAr * b.changeP)
        when "maxRise"
            (a, b) -> a.maxRiseP - b.maxRiseP
        when "maxRiseA"
            (a, b) -> (a.startAr * a.maxRiseP) - (b.startAr * b.maxRiseP)
        when "maxDrop"
            (a, b) -> (-a.maxDropP) - (-b.maxDropP) # Flipped for max Drops
        when "maxDropA"
            (a, b) -> (-a.startAr * a.maxDropP) - (-b.startAr * b.maxDropP)
        else
            (a, b) -> 0

    sorted.sort(compareFn)
    unless sortAscending then sorted.reverse()
    return sorted

############################################################
formatPercent = (value) ->
    sign = if value >= 0 then "+" else ""
    return "#{sign}#{value.toFixed(1)}%"

formatAbsoluteDelta = (value, missingF) ->
    sign = if value >= 0 then "+" else ""
    html = formatAbsolutePrice(value, missingF)
    return "#{sign}#{html}"

formatAbsolutePrice = (value, missingF) ->
    if missingF > 1 then return "#{value.toFixed(2)}<span class='missing-factor' title='Fehlender Faktor zum exakten historischen Wert.'>#{missingF.toFixed(2)}</span>"
    else return "#{value.toFixed(2)}"

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
