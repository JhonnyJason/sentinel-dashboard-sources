############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scimodule")
#endregion

############################################################
import {
    createValidator, getErrorMessage, STRINGORNOTHING,
    STRINGHEX64, STRINGHEX32, STRINGEMAIL, NONEMPTYSTRING, 
    NUMBERORNOTHING, NUMBER
} from "thingy-schema-validate"

############################################################
import { urlAccessManager, urlDatahub, urlLinkGuardian } from "./configmodule.js"
import { getAuthCode, assertAuthorization } from "./accountmodule.js"

############################################################
#region Requet URLs
urlRegister = urlAccessManager+"/register"
urlLogin = urlAccessManager+"/login"
urlLoginX = urlAccessManager+"/loginX"
urlLogout = urlAccessManager+"/logout"
urlRefreshSession = urlAccessManager+"/refreshSession"
urlGetSubscriptionData = urlAccessManager+"/getSubscriptionData"
urlPasswordReset = urlAccessManager+"/requestPasswordReset"
urlUpdateEmail = urlAccessManager+"/updateEmail"
urlUpdatePasword = urlAccessManager+"/updatePassword"
urlDeleteAccount = urlAccessManager+"/deleteAccount"
urlGetCheckoutLink = urlAccessManager+"/getCheckoutLink"

urlGetData = urlDatahub+"/getEODHLCData"

urlDiscountForBadge = urlLinkGuardian+"/getDiscount"
#endregion

############################################################
#region Schema Validators
validateEmail = createValidator(STRINGEMAIL)
validateAuthCode = createValidator(STRINGHEX32)

############################################################
validateRegisterArgs = createValidator({
    email: STRINGEMAIL,
    linkName: STRINGORNOTHING
})

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
requestToPromise = new Map()

############################################################
deleteAfterAwait = (key, prom) ->
    try
        result = await prom
        # log "deleteAfterAwait - resolved to result!"
        # olog {result}
    catch err
        log "deleteAfterAwait - exception thrown!"
        # olog {err}

    requestToPromise.delete(key)
    return


############################################################
requestExecute = (url, options, isRetry) ->
    try response = await fetch(url, options)
    catch err then throw new Error("Network Error: "+err.message)

    ## return void on 204
    if response.status == 204 then return
    ## return response body on 200 - should always be JSON
    if response.status == 200
        try return await response.json()
        catch err then throw new Error("ResultParsing Error: "+err.message)
    
    ## Any other Error will not be "OK" - and might have an error Messge for us...
    if response.status == 401
        try await assertAuthorization()
        catch err then throw new Error("Authorization could not be established! #{err.message}")
        return await requestExecute(url, options, true) unless isRetry
        throw new Error("Authorization issue, but refresshed session, and retried :-(!")

    try errorMessage = await response.text()
    catch err then throw new Error("ErrorParsing Error: "+err.message)

    throw new Error(errorMessage)
    return

############################################################
request  = (url, args) ->
    log "request "+url
    bodyStr = JSON.stringify(args)
    key = url+bodyStr

    if requestToPromise.has(key) then return await requestToPromise.get(key)
    
    options =
        method: 'POST'
        mode: 'cors'    
        body: bodyStr
        headers: {'Content-Type': 'application/json'}
    
    prom = requestExecute(url, options)
    requestToPromise.set(key, prom)
    deleteAfterAwait(key, prom)
    return await prom


############################################################
export register = (email, linkName) ->
    log "register"
    # throw new Error("Error on Purpose!") ## TODO remove
    # return ## TODO remove
    args = {email, linkName}
    # err = validateEmail(args)
    err = validateRegisterArgs(args)
    if err then throw new Error("Invalid Email!")
    await request(urlRegister, args)
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

export getSubscriptionData = (authCode) ->
    log "getSubscriptionData"
    err = validateAuthCode(authCode)
    if err then throw new Error("Invalid authCode!")
    return await request(urlGetSubscriptionData, authCode)

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

export deleteAccount = (email, passwordSH) ->
    args = { email, passwordSH }
    err = validateLoginArgs(args)
    if err then throw new Error("Invalid Deletion Arguments!")
    return await request(urlDeleteAccount, args)

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
export discountForBadge = (badge) ->
    log "discountForBadge"
    return await request(urlDiscountForBadge, badge)

############################################################
export getCheckoutLink = (isYearly, authCode) ->
    log "getCheckoutLink"
    return await request(urlGetCheckoutLink, {isYearly, authCode})