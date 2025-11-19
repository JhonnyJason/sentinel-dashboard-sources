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
import { setAccountEmail } from "./accountframemodule.js"
import { heartbeat } from "./datamodule.js"

#endregion

############################################################
#region Local Variables
dataKey = "sentinel-account-data"
accountData = null
refreshMarginMS = 300_000 # ~5min

############################################################
validateLoginResult = null
validateRefreshSessionResult = null

validateAccountData = null

#endregion

############################################################
export initialize = ->
    log "initialize"
    ## create validators
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

    ## Digest stored AccountData
    if logoutButton? then logoutButton.addEventListener("click", logoutClicked)
    
    ## Digest stored AccountData
    accountDataString = localStorage.getItem(dataKey) 
    accountData = JSON.parse(accountDataString) if accountDataString?

    if accountData? then err = validateAccountData(accountData)
    if err then deleteAccountData()

    if acountData? then setAccountEmail(accountData.email)
    checkSession()
    return

############################################################
deleteAccountData = ->
    accountData = null
    localStorage.removeItem(dataKey)
    triggers.toNoAccount()
    return

saveAccountData = ->
    log "saveAccountData"
    if !accountData? then return localStorage.removeItem(dataKey)
    dataString = JSON.stringify(accountData)
    return localStorage.setItem(dataKey, dataString)

############################################################
checkSession = ->
    return unless accountData?
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
    result = await sci.refreshSession(authCode)

    err = validateRefreshSessionResult(result)
    if err then throw new Error("Invalid Result received!")

    accountData.session.authCode =  result.authCode
    accountData.session.validUntil =  result.validUntil
    saveAccountData()
    heartbeat()
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
    heartbeat()
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

    setAccountEmail("")
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
    setAccountEmail(email)

    triggers.toSummary()
    return

export getAuthCode = ->
    log "getAuthCode"
    if accountData? and accountData.session?
        return accountData.session.authCode
    return
