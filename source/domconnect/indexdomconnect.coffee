indexdomconnect = {name: "indexdomconnect"}

############################################################
indexdomconnect.initialize = () ->
    global.content = document.getElementById("content")
    global.currencytrendframe = document.getElementById("currencytrendframe")
    global.economicAreas = document.getElementById("economic-areas")
    global.sidenav = document.getElementById("sidenav")
    global.summaryBtn = document.getElementById("summary-btn")
    global.currencytrendBtn = document.getElementById("currencytrend-btn")
    return
    
module.exports = indexdomconnect