############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("sidenavmodule")
#endregion

############################################################
import * as triggers from "./navtriggers.js"

############################################################
folded = true

############################################################
export initialize = ->
    log "initialize"
    sidenavControls.addEventListener("click", controlClicked)
    summaryBtn.addEventListener("click", triggers.toSummary)
    currencytrendBtn.addEventListener("click", triggers.toCurrencytrend)
    seasonalityBtn.addEventListener("click", triggers.toSeasonality)
    eventscreenerBtn.addEventListener("click", triggers.toEventscreener)
    forexscreenerBtn.addEventListener("click", triggers.toForexscreener)
    optionscreenerBtn.addEventListener("click", triggers.toOptionscreener)
    sectorrotationBtn.addEventListener("click", triggers.toSectorrotation)
    trafficlightBtn.addEventListener("click", triggers.toTrafficlight)
    accountBtn.addEventListener("click", triggers.toAccount)
    
    # headerRect = header.getBoundingClientRect()
    # headerHeight = headerRect.top - headerRect.bottom
    # headerHeight = Math.max(headerHeight, header.offsetHeight)

    # sidenav.style.paddingTop = "#{headerHeight + 35}px"
    # sidenavControls.style.top = "#{headerHeight}px"
    return

############################################################
controlClicked = ->
    folded = !folded
    if folded then sidenav.classList.add("folded")
    else sidenav.classList.remove("folded")
    return

############################################################
export setSummaryState = ->
    log "setSummaryState"
    sidenav.className = "summary"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setCurrencytrendState = ->
    log "setCurrencytrendState"
    sidenav.className = "currencytrend"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setSeasonalityState = ->
    log "setSeasonalityState"
    sidenav.className = "seasonality"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setEventscreenerState = ->
    log "setEventscreenerState"
    sidenav.className = "eventscreener"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setForexscreenerState = ->
    log "setForexscreenerState"
    sidenav.className = "forexscreener"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setOptionscreenerState = ->
    log "setOptionscreenerState"
    sidenav.className = "optionscreener"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setSectorrationState = ->
    log "setSectorrationState"
    sidenav.className = "sectorrotation"
    folded = true
    if folded then sidenav.classList.add("folded")
    return
    
export setTrafficlightState = ->
    log "setTrafficlightState"
    sidenav.className = "trafficlight"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export setAccountState = ->
    log "setAccountState"
    sidenav.className = "account"
    folded = true
    if folded then sidenav.classList.add("folded")
    return

export hide = ->
    log "hide"
    sidenav.className = "hidden"
    return
