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
        catch err 
            console.error(err)
            ## seems all is invalid we may just delete it
            deleteAccountData()

    ## our sesssion is close to expiry
    else if remainingValidMS < refreshMarginMS
        try await refreshSession()
        catch err
            console.error(err)
            ## maybe authCode is invalid so reLogin could help
            try await reLogin()
            catch err 
                console.error(err)
                ## seems all is invalid we may just delete it
                deleteAccountData()

    else ## it seems we have valid access then:)
        onAquiredAccess(true) 

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
refreshSession = ->
    log "refreshSession"
    authCode = accountData.session.authCode
    if !authCode? then throw new Error("No autCode in session!")

    result = await sci.refreshSession(authCode)

    err = validateRefreshSessionResult(result)
    if err then throw new Error("Invalid Result received!")

    accountData.session.authCode =  result.authCode
    accountData.session.validUntil =  result.validUntil
    saveAccountData()
    onAquiredAccess()
    return

reLogin = ->
    log "reLogin"
    email = accountData.email
    passwordSHX = accountData.passwordSHX
    result = await sci.loginX(email, passwordSHX)

    err = validateLoginResult(result)
    if err then throw new Error("Invalid Result received!")

    accountData.passwordSHX = result.passwordSHX
    accountData.session.authCode = result.authCode
    accountData.session.validUntil = result.validUntil
    saveAccountData()
    onAquiredAccess()
    return

############################################################
onAquiredAccess = (refreshIfFail) ->
    log "onAquiredAccess"
    authCode = getAuthCode()
    try
        subscriptionData = await sci.getSubscriptionData(authCode)
        setSubscriptionState(subscriptionData)
    catch err then console.error(err)

    if refreshIfFail and !subscriptionData? then assertAuthorization()
    else heartbeat()
    return

############################################################
logoutClicked = ->
    log "logoutClicked"
    executeLogout()
    return

############################################################
export accountExists = ->
    log "accountExists"
    return accountData?

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
    return

export executeEmailUpdate = (newEmail, password) ->
    log "executeEmailUpdate"
    passwordSH = await sha256(cfg.pwdSalt+password)
    result = await sci.updateEmail(newEmail, accountData.email, passwordSH)
    return

export executePasswordUpdate = (newPassword, password) ->
    log "executePasswordUpdate"
    passwordSH = await sha256(cfg.pwdSalt+password)
    newPasswordSH = await sha256(cfg.pwdSalt+newPassword)
    result = await sci.updatePassword(newPasswordSH, accountData.email, passwordSH)
    return

export assertAuthorization = ->
    log "assertAuthorization"
    try await refreshSession()
    catch err
        console.error(err)
        ## maybe authCode is invalid so reLogin could help
        try await reLogin()
        catch err
            console.error(err)
            ## seems all is invalid we may just delete it
            deleteAccountData()
    return

export getAuthCode = ->
    log "getAuthCode"
    if accountData? and accountData.session?
        return accountData.session.authCode
    return
