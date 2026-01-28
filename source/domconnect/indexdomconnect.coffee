indexdomconnect = {name: "indexdomconnect"}

############################################################
indexdomconnect.initialize = () ->
    global.content = document.getElementById("content")
    global.accountframe = document.getElementById("accountframe")
    global.newEmailInput = document.getElementById("new-email-input")
    global.symbolCombobox = document.getElementById("symbol-combobox")
    global.symbolInput = document.getElementById("symbol-input")
    global.symbolDropdown = document.getElementById("symbol-dropdown")
    global.timeframeSelect = document.getElementById("timeframe-select")
    global.methodSelect = document.getElementById("method-select")
    global.seasonalityChart = document.getElementById("seasonality-chart")
    global.currencytrendframe = document.getElementById("currencytrendframe")
    global.economicAreas = document.getElementById("economic-areas")
    global.sidenav = document.getElementById("sidenav")
    global.summaryBtn = document.getElementById("summary-btn")
    global.currencytrendBtn = document.getElementById("currencytrend-btn")
    global.seasonalityBtn = document.getElementById("seasonality-btn")
    global.eventscreenerBtn = document.getElementById("eventscreener-btn")
    global.forexscreenerBtn = document.getElementById("forexscreener-btn")
    global.trafficlightBtn = document.getElementById("trafficlight-btn")
    global.accountBtn = document.getElementById("account-btn")
    global.noaccountframe = document.getElementById("noaccountframe")
    global.loginRegisterSection = document.getElementById("login-register-section")
    global.loginButton = document.getElementById("login-button")
    global.registerButton = document.getElementById("register-button")
    global.loginRegisterForm = document.getElementById("login-register-form")
    global.emailInput = document.getElementById("email-input")
    global.passwordInput = document.getElementById("password-input")
    global.passwordResetButton = document.getElementById("password-reset-button")
    global.header = document.getElementById("header")
    global.logoutButton = document.getElementById("logout-button")
    global.s = document.getElementById("s")
    global.l = document.getElementById("l")
    return
    
module.exports = indexdomconnect