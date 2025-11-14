############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("scimodule")
#endregion

############################################################
import {
    createValidator, STRINGHEX64, STRINGEMAIL
} from "thingy-schema-validate"

############################################################
import { urlAccessManager } from "./configmodule.js"

############################################################
urlRegister = urlAccessManager+"/register"
urlLogin = urlAccessManager+"/login"
urlPasswordReset = urlAccessManager+"/requestPasswordReset"

############################################################
validateEmail = createValidator(STRINGEMAIL)

############################################################
loginSchema = {
    email: STRINGEMAIL,
    passwordSH: STRINGHEX64
}
validateLoginArgs = createValidator(loginSchema)


############################################################
export finalizeAction = (args) ->
    log "finalizeAction"
    err = validateFinalizeActionArgs(args)
    if err then throw new Error("Invlid Arguments! (#{err})")
    
    return


############################################################
export initialize = ->
    log "initialize"
    #Implement or Remove :-)
    return

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


export login = (email, passwordSH) ->
    log "login"
    # throw new Error("Error on Purpose!") ## TODO remove
    # return ## TODO remove

    args = { email, passwordSH }
    err = validateLoginArgs(args)
    if err then throw new Error("Invalid Login Arguments!")
    return await request(urlLogin, args)


export requestPasswordReset = (email) ->
    log "requestPasswordReset"
    # throw new Error("Error on Purpose!") ## TODO remove
    # return ## TODO remove
    
    err = validateEmail(email)
    if err then throw new Error("Invalid Email!")
    await request(urlPasswordReset, email)
    return
