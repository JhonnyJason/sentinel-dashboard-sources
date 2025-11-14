############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("noaccountmodule")
#endregion


############################################################
import { register, requestPasswordReset } from "./scimodule.js"
import { executeLogin } from "./accountmodule.js"

############################################################
mode = "login"
## possible modes:
# register
# register-success
# register-failure
# login-failure
# password-reset-failure
# password-reset-success

############################################################
export initialize = ->
    log "initialize"
    registerButton.addEventListener("click", setRegisterState)
    loginButton.addEventListener("click", setLoginState)
    passwordResetButton.addEventListener("click", passwordResetClicked)

    loginRegisterForm.addEventListener("submit", handleLoginRegisterSubmit)
    loginRegisterSection.className = mode
    #Implement or Remove :-)

    return
    
############################################################
#region UI State Setters
setRegisterState = ->
    mode = "register"
    loginRegisterSection.className = mode
    passwordInput.removeAttribute("required")
    ## Not in an Error/Success state anymore :-)
    emailInput.removeEventListener("keyup", keyupOnErrorSuccess)
    passwordInput.removeEventListener("keyup", keyupOnErrorSuccess)
    return

setLoginState = ->
    mode = "login"
    loginRegisterSection.className = mode
    passwordInput.setAttribute("required", "")
    ## Not in an Error/Success state anymore :-)
    emailInput.removeEventListener("keyup", keyupOnErrorSuccess)
    passwordInput.removeEventListener("keyup", keyupOnErrorSuccess)
    return



############################################################
setRegisterSuccess = ->
    log "setRegisterSuccess"
    mode = "register-success"
    loginRegisterSection.className = mode
    emailInput.addEventListener("keyup", keyupOnErrorSuccess)
    return

indicateRegisterError = (error) ->
    log "indicateRegisterError"
    console.error(error.message)
    mode = "register-failure"
    loginRegisterSection.className = mode
    emailInput.addEventListener("keyup", keyupOnErrorSuccess)
    return


############################################################
indicateLoginError = (error) ->
    log "indicateLoginError"
    console.error(error.message)
    mode = "login-failure"
    loginRegisterSection.className = mode
    emailInput.addEventListener("keyup", keyupOnErrorSuccess)
    passwordInput.addEventListener("keyup", keyupOnErrorSuccess)
    return

############################################################
setPasswordResetRequestSuccess = ->
    log "setPasswordResetRequestSuccess"
    mode = "password-reset-success"
    loginRegisterSection.className = mode
    emailInput.addEventListener("keyup", keyupOnErrorSuccess)
    passwordInput.addEventListener("keyup", keyupOnErrorSuccess)
    return

indicatePasswordResetError = (error) ->
    log "indicatePasswordResetError"
    console.error(error.message)
    mode = "password-reset-failure"
    loginRegisterSection.className = mode
    emailInput.addEventListener("keyup", keyupOnErrorSuccess)
    passwordInput.addEventListener("keyup", keyupOnErrorSuccess)
    return

#endregion

############################################################
#region Handle Form Submit
handleLoginRegisterSubmit = (evnt) ->
    log "handleLoginRegisterSubmit"
    evnt.preventDefault()

    email = emailInput.value
    password = passwordInput.value

    if mode == "login"
        try await handleLoginSubmit(email, password)
        catch err then console.error(err.message)
        return
    
    if mode == "register"
        try await handleRegisterSubmit(email)
        catch err then console.error(err.message)
        return

    return

############################################################
handleRegisterSubmit = (email) ->
    log "handleRegisterSubmit"
    try await register(email)
    catch err then return indicateRegisterError(err)

    setRegisterSuccess()
    return

handleLoginSubmit = (email, password) ->
    log "handleLoginSubmit"
    try await executeLogin(email, password)
    catch err then return indicateLoginError(err)
    return

#endregion


############################################################
keyupOnErrorSuccess = (evnt) ->
    if evnt.key == "Escape" then return
    if evnt.key == "Enter" then return

    if mode == "login-failure" or mode == "password-reset-failure" or 
    mode == "password-reset-success"
        setLoginState()
        return
    
    if mode == "register-failure" or mode == "register-success"
        setRegisterState()
        return

    console.error("leaveErrorSuccessStae -> illegal mode: "+mode)
    return

############################################################
passwordResetClicked = ->
    log "passwordResetClicked"
    passwordInput.value = ""
    email = emailInput.value

    try await requestPasswordReset(email)
    catch err then return indicatePasswordResetError(err)

    setPasswordResetRequestSuccess()
    return

############################################################
## Export UI state modifiers
export hide = ->
    log "hide"
    noaccountframe.className = "hidden"
    return

export show = ->
    log "show"
    noaccountframe.className = ""
    emailInput.focus()
    return
