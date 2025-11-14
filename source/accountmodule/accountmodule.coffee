############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("accountmodule")
#endregion

############################################################
import { sha256 } from "secret-manager-crypto-utils"
import {
    createValidator, STRINGHEX64, NUMBER
} from "thingy-schema-validate"

############################################################
import * as triggers from "./navtriggers.js"

############################################################
import { login } from "./scimodule.js"
import * as cfg from "./configmodule.js"
import { setAccountEmail } from "./accountframemodule.js"

############################################################
dataKey = "sentinel-account-data"
accountData = null

############################################################
loginResultSchema= { authCode: STRINGHEX64, validUntil: NUMBER }
validateLoginResult = createValidator(loginResultSchema)

############################################################
export initialize = ->
    log "initialize"
    dataString = localStorage.getItem(dataKey)
    if dataString then accountData = JSON.parse(dataString)
    ## TODO check if still valid and remove if not
    return

############################################################
saveAccountData = ->
    log "saveAccountData"
    if !accountData? then return localStorage.removeItem(dataKey)
    dataString = JSON.stringify(accountData)
    return localStorage.setItem(dataKey, dataString)

############################################################
export accountExists = ->
    log "accountExists"
    return accountData?

export executeLogout = ->
    log "executeLogout"
    ## TODO implement
    return

export executeLogin = ( email, password ) ->
    log "executeLogin"
    # throw new Error("Error on Purpose!")

    passwordSH = await sha256(cfg.pwdSalt+password)
    result = await login(email, passwordSH)
    err = validateLoginResult(result)
    if err then throw new Error("Invalid Result received!")


    accountData = {
        email: email
        passwordSH: passwordSH
        session: result
    }
    saveAccountData()
    setAccountEmail(email)

    triggers.toSummary()
    return