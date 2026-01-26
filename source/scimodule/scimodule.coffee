############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scimodule")
#endregion

############################################################
import {
    createValidator, getErrorMessage, 
    STRINGHEX64, STRINGHEX32, STRINGEMAIL, NONEMPTYSTRING, 
    NUMBERORNOTHING, NUMBER
} from "thingy-schema-validate"

############################################################
import { urlAccessManager, urlDatahub } from "./configmodule.js"
import { getAuthCode } from "./accountmodule.js"
import { defaultSymbols } from "./defaultsymbols.js"

############################################################
#region Requet URLs
urlRegister = urlAccessManager+"/register"
urlLogin = urlAccessManager+"/login"
urlLoginX = urlAccessManager+"/loginX"
urlLogout = urlAccessManager+"/logout"
urlRefreshSession = urlAccessManager+"/refreshSession"
urlPasswordReset = urlAccessManager+"/requestPasswordReset"
urlUpdateEmail = urlAccessManager+"/updateEmail"
urlUpdatePasword = urlAccessManager+"/updatePassword"
urlDeleteAccount = urlAccessManager+"/deleteAccount"

urlGetData = urlDatahub+"/getEODHLCData"

#endregion

############################################################
#region Schema Validators
validateEmail = createValidator(STRINGEMAIL)
validateAuthCode = createValidator(STRINGHEX32)

############################################################
validateLoginArgs = createValidator({
    email: STRINGEMAIL,
    passwordSH: STRINGHEX64
})

validateLoginXArgs = createValidator({
    email: STRINGEMAIL,
    passwordSHX: STRINGHEX64
})

validateUpdateEmailArgs = createValidator({
    newEmail: STRINGEMAIL
    email: STRINGEMAIL,
    passwordSH: STRINGHEX64
})
validateUpdatePasswordArgs = createValidator({
    newPasswordSH: STRINGHEX64
    email: STRINGEMAIL,
    passwordSH: STRINGHEX64
})


validateGetDataArgs = createValidator({
    authCode: STRINGHEX32,
    dataKey: NONEMPTYSTRING,
    yearsBack: NUMBERORNOTHING
})

validateGetSymbolOptionsArgs = createValidator({
    authCode: STRINGHEX32,
    query: NONEMPTYSTRING,
    limit: NUMBER
})
#endregion

############################################################
request  = (url, args) ->
    log "request"

    options =
        method: 'POST'
        mode: 'cors'
    
        body: JSON.stringify(args)
        headers: {'Content-Type': 'application/json'}

    try response = await fetch(url, options)
    catch err then throw new Error("Network Error: "+err.message)

    ## return void on 204
    if response.status == 204 then return
    ## return response body on 200 - should always be JSON
    if response.status == 200
        try return await response.json()
        catch err then throw new Error("ResultParsing Error: "+err.message)

        ## Any Error will not be "OK" - and might have an error Messge for us...
    try errorMessage = await response.text()
    catch err then throw new Error("ErrorParsing Error: "+err.message)

    throw new Error(errorMessage)
    return

############################################################
export register = (email) ->
    log "register"
    # throw new Error("Error on Purpose!") ## TODO remove
    # return ## TODO remove
    
    err = validateEmail(email)
    if err then throw new Error("Invalid Email!")
    await request(urlRegister, email)
    return


############################################################
export login = (email, passwordSH) ->
    log "login"
    args = { email, passwordSH }
    err = validateLoginArgs(args)
    if err then throw new Error("Invalid Login Arguments!")
    return await request(urlLogin, args)

export loginX = (email, passwordSHX) ->
    args = { email, passwordSHX }
    err = validateLoginXArgs(args)
    if err then throw new Error("Invalid LoginX Arguments!")
    return await request(urlLoginX, args)

export refreshSession = (authCode) ->
    log "refreshSession"
    err = validateAuthCode(authCode)
    if err then throw new Error("Invalid authCode!")
    return await request(urlRefreshSession, authCode)

export logout = (authCode) ->
    log "logout"
    err = validateAuthCode(authCode)
    if err then throw new Error("Invalid authCode!")
    return await request(urlLogout, authCode)

############################################################
export requestPasswordReset = (email) ->
    log "requestPasswordReset"    
    err = validateEmail(email)
    if err then throw new Error("Invalid Email!")
    await request(urlPasswordReset, email)
    return

export updateEmail = (newEmail, email, passwordSH) ->
    log "updateEmail"
    args = { newEmail, email, passwordSH }
    err = validateUpdateEmailArgs(args)
    if err then throw new Error("Invalid updateEmail args!")
    return await request(urlUpdateEmail, args)

export updatePassword = (newPasswordSH, email, passwordSH) ->
    log "updatePassword"
    args = { newPasswordSH, email, passwordSH }
    err = validateUpdatePasswordArgs(args)
    if err then throw new Error("Invalid updatePassword args!")
    return await request(urlUpdatePasword, args)


############################################################
export getEodData = (dataKey, yearsBack) ->
    log "getEodData"    
    authCode = getAuthCode()
    args = { authCode, dataKey, yearsBack }
    err = validateGetDataArgs(args)
    # if err then log getErrorMessage(err)
    if err then throw new Error("Invalid getData args!")
    return await request(urlGetData, args)
    # resultSchema: {
    #     meta: {
    #         startDate: NONEMPTYSTRING,
    #         endDate: NONEMPTYSTRING,
    #         interval: "1d",
    #         historyComplete: BOOLEAN
    #     },
    #     data: ARRAY
    # }

############################################################
export getSymbolOptions = (query, limit) ->
    log "getSymbolOptions"   
    authCode = getAuthCode()
    args = { authCode, query, limit }
    err = validateGetSymbolOptionsArgs(args)
    # if err then log getErrorMessage(err)
    if err then throw new Error("Invalid getData args!")
    # return await request(urlGetSymbolOptions, args)
    
    ## Sample return
    return await new Promise (rslv) ->
        setTimeout((() -> rslv(defaultSymbols)), 500)