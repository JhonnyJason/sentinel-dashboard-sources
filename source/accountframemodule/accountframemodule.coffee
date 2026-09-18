############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("accountframemodule")
#endregion

############################################################
# import M from "mustache"
# currencyPairTemplate = document.getElementById("currency-pair-template").innerHTML
# log currencyPairTemplate

############################################################
import * as accM from "./accountmodule.js"
import * as sci from "./scimodule.js"
import * as cfg from "./configmodule.js"
import * as utl from "./utilsmodule.js"

############################################################
yearlyPrice = 690
monthlyPrice = 69

############################################################
subscriptionState = null

############################################################
deletionLocked = true

############################################################
## DOM-Cache - as domconnect seems to not work :(
couponDisplay = document.getElementById("coupon-display")
originalPriceYearly = document.getElementById("original-price-yearly")
originalPriceMonthly = document.getElementById("original-price-monthly")
promotionBadgeYearly = document.getElementById("promotion-badge-yearly")
promotionBadgeMonthly = document.getElementById("promotion-badge-monthly")
promotionPercentageOffYearly = document.getElementById("promotion-percentage-off-yearly")
promotionPercentageOffMonthly = document.getElementById("promotion-percentage-off-monthly")
discountPriceYearly = document.getElementById("discount-price-yearly")
discountPriceMonthly = document.getElementById("discount-price-monthly")

############################################################
emailChangeFeedback = document.getElementById("email-change-feedback")
passwordChangeFeedback = document.getElementById("password-change-feedback")

############################################################
orderYearlyButton = document.getElementById("order-yearly-button")
orderMonthlyButton = document.getElementById("order-monthly-button")

############################################################
cancelSubscriptionButton = document.getElementById("cancel-subscription-button")
continueSubscriptionButton = document.getElementById("continue-subscription-button")

############################################################
paidAccessEnd = document.getElementById("paid-access-end")
freeAccessEnd = document.getElementById("free-access-end")

############################################################
export initialize = ->
    log "initialize"
    cancelSubscriptionButton.addEventListener("click", cancelSubscriptionClicked)
    continueSubscriptionButton.addEventListener("click", continueSubscriptionClicked)
    
    orderYearlyButton.addEventListener("click", orderYearlyClicked)
    orderMonthlyButton.addEventListener("click", orderMonthlyClicked)

    newEmailInput.addEventListener("focus", activateEmailSection)
    oldPasswordEmailInput.addEventListener("focus", activateEmailSection)

    newPasswordInput.addEventListener("focus", activatePasswordSection)
    repeatedPasswordInput.addEventListener("focus", activatePasswordSection)
    oldPasswordInput.addEventListener("focus", activatePasswordSection)

    deletionButton.addEventListener("click", deletionButtonClicked)
    changePasswordButton.addEventListener("click", changePasswordClicked)
    changeEmailButton.addEventListener("click", changeEmailClicked)
    return


############################################################
cancelSubscriptionClicked = ->
    log "cancelSubscriptionClicked"
    authCode = accM.getAuthCode()
    if !authCode? then return log("No AuthCode available!")

    try
        await sci.cancelSubscription(authCode)
        ## optimistically adjust autoRenew
        subscriptionState.autoRenew = false
        setSubscriptionState(subscriptionState)
    catch err then console.error(err)
    ## TODO: some error feedback to the user
    return

continueSubscriptionClicked = ->
    log "continueSubscriptionClicked"
    authCode = accM.getAuthCode()
    if !authCode? then return log("No AuthCode available!")

    try
        await sci.continueSubscription(authCode)
        ## optimistically adjust autoRenew
        subscriptionState.autoRenew = true
        setSubscriptionState(subscriptionState)
    catch err then console.error(err)
    ## TODO: some error feedback to the user
    return

############################################################
activateEmailSection = ->
    log "activateEmailSection"
    emailSection.classList.remove("virgin")
    passwordSection.classList.add("virgin")
    deletionBlock.classList.add("locked")
    deletionLocked = true

    passwordSection.classList.remove("feedback")
    emailSection.classList.remove("feedback")
    deletionBlock.classList.remove("feedback")
    return

activatePasswordSection = ->
    log "activatePasswordSection"
    emailSection.classList.add("virgin")
    passwordSection.classList.remove("virgin")
    deletionBlock.classList.add("locked")
    deletionLocked = true

    passwordSection.classList.remove("feedback")
    emailSection.classList.remove("feedback")
    deletionBlock.classList.remove("feedback")
    return

unlockDeletion = ->
    log "unlockDeletion"
    deletionLocked = false
    emailSection.classList.add("virgin")
    passwordSection.classList.add("virgin")
    deletionBlock.classList.remove("locked")

    passwordSection.classList.remove("feedback")
    emailSection.classList.remove("feedback")
    deletionBlock.classList.remove("feedback")
    return 


############################################################
deletionButtonClicked = (evnt) ->
    log "deletionButtonClicked"
    if deletionLocked then return unlockDeletion()
    deletionBlock.classList.remove("feedback")
    
    passwd = oldPasswordDeletionInput.value
    if !passwd 
        deletionBlock.classList.add("feedback")
        deletionFeedback.textContent = "Kein Passwort wurde eingegeben!"
        return

    
    deletionBlock.classList.add("pending")
    try await accM.executeAccountDeletion(passwd)
    catch err
        log err
        deletionBlock.classList.add("feedback")
        deletionFeedback.textContent = "Die Löschung konnte nicht durchgeführt werden!"
    finally 
        deletionBlock.classList.remove("pending")    
    return

changePasswordClicked = (evnt) ->
    log "changePasswordClicked"
    passwordSection.classList.remove("feedback")

    newPwd = newPasswordInput.value
    if !newPwd
        passwordSection.classList.add("feedback")
        passwordChangeFeedback.textContent = "Nicht alle Passwörter wurden ausgefüllt!"
        return

    newPwdRep = repeatedPasswordInput.value
    if !newPwdRep
        passwordSection.classList.add("feedback")
        passwordChangeFeedback.textContent = "Nicht alle Passwörter wurden ausgefüllt!"
        return

    oldPwd = oldPasswordInput.value
    if !oldPwd
        passwordSection.classList.add("feedback")
        passwordChangeFeedback.textContent = "Nicht alle Passwörter wurden ausgefüllt!"
        return

    if newPwd != newPwdRep
        passwordSection.classList.add("feedback")
        passwordChangeFeedback.textContent = "Die neuen Passwörter stimmen nicht überein!"
        return


    passwordSection.classList.add("pending")
    try 
        await accM.executePasswordUpdate(newPwd, oldPwd)
        newPasswordInput.value = ""
        repeatedPasswordInput.value = ""
        oldPasswordInput.value = ""
        passwordSection.classList.add("virgin")
    catch err
        log err
        passwordSection.classList.add("feedback")
        passwordChangeFeedback.textContent = "Das neue Passwort konnte nicht gesetzt werden!"
    finally passwordSection.classList.remove("pending")  
    return

changeEmailClicked = (evnt) ->
    log "changeEmailClicked"
    emailSection.classList.remove("feedback")

    email = newEmailInput.value
    if !email
        emailSection.classList.add("feedback")
        emailChangeFeedback.textContent = "Keine Emailadresse eingegeben!"
        return

    password = oldPasswordEmailInput.value
    if !password
        emailSection.classList.add("feedback")
        emailChangeFeedback.textContent = "Kein Passwort eingegeben!"
        return
   
    emailSection.classList.add("pending")
    try 
        await accM.executeEmailUpdate(email, password)
        oldPasswordEmailInput.value = ""
        newEmailInput.value = ""
        emailSection.classList.add("virgin")
    catch err
        log err
        emailSection.classList.add("feedback")
        emailChangeFeedback.textContent = "Die neue Emailadresse konnte nicht gesetzt werden!"
    finally 
        emailSection.classList.remove("pending")    
    return



############################################################
orderYearlyClicked = (evnt) ->
    log "orderYearlyClicked"
    authCode = accM.getAuthCode()
    if !authCode? then return log("No AuthCode available!")

    try { link } = await sci.getCheckoutLink(true, authCode)
    catch err then console.error(err)
    
    # olog { link }
    if link then window.open(link, "_self")
    else console.error("getCheckoutLink() - result did not contain a Link!")
    return

orderMonthlyClicked = (evnt) ->
    log "orderMonthlyClicked"
    authCode = accM.getAuthCode()
    if !authCode? then return log("No AuthCode available!")

    try { link } = await sci.getCheckoutLink(false, authCode)
    catch err then console.error(err)
    
    # olog { link }
    if link then window.open(link, "_self")
    else console.error("getCheckoutLink() - result did not contain a Link!")
    return

############################################################
retrieveBenefits = ->
    log "retrieveBenefits"    
    badge = subscriptionState.badge
    
    ## TODO upgrade: getting freeAccess as Badge Benefit
    if subscriptionState.badgeCouponUsed 
        subscriptionState.discount = 0
        return


    try subscriptionState.discount = await sci.discountForBadge(badge)
    catch err then console.error(err)
    ## TODO also retrieve yearly and monthly prices from somewhere (access-manager?)
    # olog subscriptionState
    return

renderPrices = ->
    log "renderPrices"
    badge = subscriptionState.badge
    promotionBadgeYearly.textContent = badge
    promotionBadgeMonthly.textContent = badge

    originalPriceYearly.textContent = utl.minDecimalPrice(yearlyPrice)
    originalPriceMonthly.textContent = utl.minDecimalPrice(monthlyPrice)
    
    discount = parseFloat(subscriptionState.discount)
    # discount = 0 # testing non-discount mode

    if isNaN(discount) then discount = 0
    if discount < 0 then discount = 0
    if discount > 100 then discount  = 100
    promotionPercentageOffYearly.textContent = utl.minDecimalPrice(discount)
    promotionPercentageOffMonthly.textContent = utl.minDecimalPrice(discount)

    realYearlyPrice = utl.minDecimalPrice(yearlyPrice * 0.01 * (100 - discount))
    realMonthlyPrice = utl.minDecimalPrice(monthlyPrice * 0.01 * (100 - discount))
    discountPriceYearly.textContent =  realYearlyPrice
    discountPriceMonthly.textContent = realMonthlyPrice
    

    if discount == 0 then abonnementOrders.classList.add("no-discount")
    else abonnementOrders.classList.remove("no-discount")
    return

############################################################
export setAccountEmail = (email) ->
    log "setAccountEmail"
    newEmailInput.setAttribute("placeholder", email)
    return

############################################################
export setSubscriptionState = (state) ->
    log "setSubscriptionState"
    if !state then state = Object.create(null)
    olog state
    
    subscriptionState = state 
    dateToday = (new Date()).toISOString().slice(0,10)

    # state.isTester = true # test tester-access state

    ## test limited-access state
    # dateToday = "2026-10-02"
    # state.subscribedUntil = "2026-10-01"

    # # test unlimited-access state    
    # dateToday = "2026-10-02"
    # state.subscribedUntil = "2027-10-01"
    
    ## test free-access state
    # state.freeAccessUntil = "2026-10-02"

    if state.badge
        couponDisplay.textContent = state.badge
        accountframe.classList.add("has-coupon")
        await retrieveBenefits()

    if state.isTester
        accountStatus.classList = "tester-access"
        return

    # Only before the System is live and the userData are not repaired
    # if dateToday < "2026-10-01" ## treat it as free access
    #     if !state.freeAccessUntil or state.freeAccessUntil < "2026-10-01"
    #         state.freeAccessUntil = "2026-10-01"
            
    if state.subscribedUntil? and state.subscribedUntil > dateToday
        accountStatus.className = "unlimited-access"
        paidAccessEnd.textContent = formatDate(state.subscribedUntil)
        if state.autoRenew then autorenewManagement.className = "auto-renew" 
        else autorenewManagement.className = "auto-renew-cancelled"

    else if state.freeAccessUntil? and state.freeAccessUntil > dateToday
        accountStatus.className = "free-access"
        freeAccessEnd.textContent = formatDate(state.freeAccessUntil)
        if state.autoRenew 
            autorenewManagement.className = "auto-renew"
            accountStatus.className = "unlimited-access"
            paidAccessEnd.textContent = formatDate(state.freeAccessUntil)

    else accountStatus.className = "limited-access"

    renderPrices()
    return


formatDate = (date) -> 
    [y,m,d] = date.split("-")
    return [d,m,y].join(".")