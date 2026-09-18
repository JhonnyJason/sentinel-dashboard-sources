############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("accountmodule")
#endregion

############################################################
#region Modules from the Environment
import { sha256 } from "secret-manager-crypto-utils"
import {
    createValidator, STRINGHEX64, STRINGHEX32, NUMBER, STRINGEMAIL
} from "thingy-schema-validate"

############################################################
import * as triggers from "./navtriggers.js"

############################################################
import * as sci from "./scimodule.js"
import * as cfg from "./configmodule.js"
import { setAccountEmail, setSubscriptionState } from "./accountframemodule.js"
import { heartbeat } from "./datamodule.js"

#endregion

############################################################
#region Local Variables
dataKey = "sentinel-account-data"
accountData = null
refreshMarginMS = 300_000 # ~5min

############################################################
setValidAuthCode = null
validAuthCode = new Promise((rslv) -> setValidAuthCode = rslv)
authCodeResolved = false

# ############################################################
# subscriptionData = null

############################################################
## validators
validateLoginResult = createValidator({ 
    authCode: STRINGHEX32, 
    validUntil: NUMBER,
    passwordSHX: STRINGHEX64  
})
validateRefreshSessionResult = createValidator({
    authCode: STRINGHEX32,
    validUntil: NUMBER
})
validateAccountData = createValidator({
    email: STRINGEMAIL
    passwordSHX: STRINGHEX64
    session: {
        authCode: STRINGHEX32
        validUntil: NUMBER
    }
})

#endregion

############################################################
export initialize = ->
    log "initialize"

    ## Digest stored AccountData
    if logoutButton? then logoutButton.addEventListener("click", logoutClicked)
    
    ## Digest stored AccountData
    accountDataString = localStorage.getItem(dataKey) 
    accountData = JSON.parse(accountDataString) if accountDataString?

    if accountData? then err = validateAccountData(accountData)
    if err then deleteAccountData()

    if accountData? then setAccountEmail(accountData.email)
    checkSession()
    return

############################################################
deleteAccountData = ->
    log "deleteAccountData"
    accountData = null
    setAccountEmail("")
    localStorage.removeItem(dataKey)
    triggers.toNoAccount()
    return

saveAccountData = ->
    log "saveAccountData"
    if !accountData? then return localStorage.removeItem(dataKey)
    
    setAccountEmail(accountData.email)
    dataString = JSON.stringify(accountData)
    return localStorage.setItem(dataKey, dataString)

############################################################
checkSession = ->
    log "checkSession"
    return unless accountData?
    log "we have accountData available - thus should refresh session or reLogin..."
    now = Date.now()
    remainingValidMS = accountData.session.validUntil - now

    ## our session has expired
    if remainingValidMS < 0
        try await reLogin()
        catch err then console.error("checkSession->reLogin error: "+err.message)
    
    ## our sesssion is close to expiry
    else if remainingValidMS < refreshMarginMS or !authCodeResolved
        try await refreshSession()
        catch err then console.error("checkSession->refreshSession error: "+err.message)

    ## This would only be relevant on first load
    ## for now we start with authCodeResolved = false -> as such we need to refreshSession anyways
    # ## we assume we have a valid authCode
    # # - optimistically execute onAquiredAccess
    # # - but set refreshIfFail to correct invalid authCode
    # else 
    #     try await onAquiredAccess(true)
    #     catch err then console.log("checkSession->onAquiredAccess error:"+err.message)

    resetSessionCheckTimeout()
    return

resetSessionCheckTimeout = ->
    return unless accountData?
    
    now = Date.now()
    remainingValidMS = accountData.session.validUntil - now 
    if remainingValidMS < 0 then return

    ## checking again in half-time thus we may ignore inaccuracies 
    nextCheckMS = remainingValidMS / 2
    setTimeout(checkSession, nextCheckMS)
    return

############################################################
resetValidAuthCodePromise = ->
    log "resetValidAuthCodePromise"
    authCodeResolved = false
    validAuthCode = new Promise((rslv) -> setValidAuthCode = rslv)
    return

resolveValidAuthCodePromise = (authCode) ->
    log "resolveValidAuthCodePromise"
    authCodeResolved = true
    setValidAuthCode(authCode)
    return

############################################################
refreshSession = ->
    log "refreshSession"
    if authCodeResolved then resetValidAuthCodePromise()
    
    try
        authCode = accountData?.session?.authCode
        if !authCode? then throw new Error("No autCode in session!")

        result = await sci.refreshSession(authCode)
        err = validateRefreshSessionResult(result)
        if err then throw new Error("Invalid Result received!")
    catch err ## Session seems broken
            console.error("refreshSession failed!"+err.message)
            ## maybe authCode is invalid so reLogin could help
            try return await reLogin()
            catch err then console.error("refreshSession->reLogin error:"+err.message)
            return ## here validAuthCode is the pending promise - nothing we can do

    accountData.session.authCode =  result.authCode
    accountData.session.validUntil =  result.validUntil
    saveAccountData()
    onAquiredAccess()
    return

reLogin = ->
    log "reLogin"
    if authCodeResolved then resetValidAuthCodePromise()

    email = accountData.email
    passwordSHX = accountData.passwordSHX

    try
        result = await sci.loginX(email, passwordSHX)
        err = validateLoginResult(result)
        if err then throw new Error("Invalid Result received!")
    catch err
        console.error("loginX failed! "+err.message)
        deleteAccountData() # seems our account data are invalid -> delete
        return

    accountData.passwordSHX = result.passwordSHX
    accountData.session.authCode = result.authCode
    accountData.session.validUntil = result.validUntil
    saveAccountData()
    onAquiredAccess()
    return

############################################################
onAquiredAccess = ->
    log "onAquiredAccess"
    authCode = getAuthCode()
    if !authCode then throw new Error("We donot have an authCode in onAquiredAccess...")

    try subscriptionData = await sci.getSubscriptionData(authCode)
    catch err then console.error(err) ## TODO check if this causes issues
    ## Maybe there is a case where we just aquired a access, but then donot have a valid authCode?
    ## Maybe if the authCode was not propagated serverside? 
    ## -> then a small delay and retry would help...

    resolveValidAuthCodePromise(authCode)
    setSubscriptionState(subscriptionData)
    heartbeat()
    return

############################################################
logoutClicked = ->
    log "logoutClicked"
    executeLogout()
    return

############################################################
export accountExists = -> accountData?

export executeLogout = ->
    log "executeLogout"
    if accountData? and accountData.session?
        authCode = accountData.session.authCode
    
    try await sci.logout(authCode)
    catch err then log err

    deleteAccountData()
    return

export executeLogin = ( email, password ) ->
    log "executeLogin"
    passwordSH = await sha256(cfg.pwdSalt+password)
    result = await sci.login(email, passwordSH)

    err = validateLoginResult(result)
    if err then throw new Error("Invalid Result received!")

    accountData = {
        email: email
        passwordSHX: result.passwordSHX
        session: {
            authCode: result.authCode
            validUntil: result.validUntil
        }
    }

    saveAccountData()
    onAquiredAccess()
    triggers.toSummary()
    return

export executeAccountDeletion = (password) ->
    log "executeAccountDeletion"
    passwordSH = await sha256(cfg.pwdSalt+password)
    result = await sci.deleteAccount(accountData.email, passwordSH)
    deleteAccountData()
    location.reload()
    return

export executeEmailUpdate = (newEmail, password) ->
    log "executeEmailUpdate"
    passwordSH = await sha256(cfg.pwdSalt+password)
    result = await sci.updateEmail(newEmail, accountData.email, passwordSH)
    log "emailUpdate successful!"
    accountData.email = newEmail
    saveAccountData()
    return

export executePasswordUpdate = (newPassword, password) ->
    log "executePasswordUpdate"
    passwordSH = await sha256(cfg.pwdSalt+password)
    newPasswordSH = await sha256(cfg.pwdSalt+newPassword)
    result = await sci.updatePassword(newPasswordSH, accountData.email, passwordSH)
    return

export assertAuthorization = ->
    log "assertAuthorization"
    try await refreshSession() ## will trigger reLogin 
    catch err then console.error("assertAuthorization->refreshSession error:"+err.message)
    return

export getAuthCode = ->

    log "getAuthCode" # we can use this when triggered by user
    if accountData? and accountData.session?
        return accountData.session.authCode
    return

## Use this function for all automatic calls, that might happen in case we are not logged in...
export getValidAuthCode = -> validAuthCode
