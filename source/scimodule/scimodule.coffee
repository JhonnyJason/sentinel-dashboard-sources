############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scimodule")
#endregion

############################################################
import {
    createValidator, getErrorMessage, 
    STRINGHEX64, STRINGHEX32, STRINGEMAIL, NONEMPTYSTRING, 
    NUMBERORNOTHING
} from "thingy-schema-validate"

############################################################
import { urlAccessManager, urlDatahub } from "./configmodule.js"
import { getAuthCode } from "./accountmodule.js"

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
export getSymbolOptions = (search) ->
    log "getSymbolOptions"   
    authCode = getAuthCode()
    args = { authCode, search }
    err = validateGetSymbolOptionsArgs(args)
    # if err then log getErrorMessage(err)
    if err then throw new Error("Invalid getData args!")
    # return await request(urlGetSymbolOptions, args)
    
    ## Sample return
    sample = [
        {symbol:"AKAM",name:"Akamai Technologies"},
        {symbol:"WYNN",name:"Wynn Resorts"},
        {symbol:"BEN",name:"Franklin Resources"},
        {symbol:"ZBRA",name:"Zebra Technologies"},
        {symbol:"CLX",name:"Clorox"},
        {symbol:"HST",name:"Host Hotels & Resorts"},
        {symbol:"UDR",name:"UDR, Inc."},
        {symbol:"BF.B",name:"Brown\u2013Forman"},
        {symbol:"CF",name:"CF Industries"},
        {symbol:"AIZ",name:"Assurant"},
        {symbol:"CPT",name:"Camden Property Trust"},
        {symbol:"IVZ",name:"Invesco"},
        {symbol:"MRNA",name:"Moderna"},
        {symbol:"HAS",name:"Hasbro"},
        {symbol:"SWK",name:"Stanley Black & Decker"},
        {symbol:"BLDR",name:"Builders FirstSource"},
        {symbol:"EPAM",name:"EPAM Systems"},
        {symbol:"ALGN",name:"Align Technology"},
        {symbol:"DOC",name:"Healthpeak Properties"},
        {symbol:"GL",name:"Globe Life"},
        {symbol:"DAY",name:"Dayforce"},
        {symbol:"RVTY",name:"Revvity"},
        {symbol:"FDS",name:"FactSet"},
        {symbol:"BXP",name:"BXP, Inc."},
        {symbol:"PNW",name:"Pinnacle West"},
        {symbol:"SJM",name:"J.M. Smucker Company (The)"},
        {symbol:"AES",name:"AES Corporation"},
        {symbol:"NCLH",name:"Norwegian Cruise Line Holdings"},
        {symbol:"MGM",name:"MGM Resorts"},
        {symbol:"BAX",name:"Baxter International"},
        {symbol:"CRL",name:"Charles River Laboratories"},
        {symbol:"NWSA",name:"News Corp (Class A)"},
        {symbol:"SWKS",name:"Skyworks Solutions"},
        {symbol:"AOS",name:"A. O. Smith"},
        {symbol:"TAP",name:"Molson Coors Beverage Company"},
        {symbol:"TECH",name:"Bio-Techne"},
        {symbol:"MOH",name:"Molina Healthcare"},
        {symbol:"HSIC",name:"Henry Schein"},
        {symbol:"PAYC",name:"Paycom"},
        {symbol:"FRT",name:"Federal Realty Investment Trust"},
        {symbol:"APA",name:"APA Corporation"},
        {symbol:"POOL",name:"Pool Corporation"},
        {symbol:"ARE",name:"Alexandria Real Estate Equities"},
        {symbol:"CPB",name:"Campbell Soup Company"},
        {symbol:"CAG",name:"Conagra Brands"},
        {symbol:"DVA",name:"DaVita"},
        {symbol:"GNRC",name:"Generac"},
        {symbol:"MOS",name:"Mosaic Company (The)"},
        {symbol:"MTCH",name:"Match Group"},
        {symbol:"LW",name:"Lamb Weston"},
        {symbol:"NWS",name:"News Corp (Class B)"}
    ]
    return await new Promise (rslv) ->
        setTimeout(rslv, 500, sample)