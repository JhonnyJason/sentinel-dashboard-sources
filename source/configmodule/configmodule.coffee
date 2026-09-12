############################################################
export appVersion = "v0.1.43"
export heartbeatMS = 120_000 # ~2min

############################################################
#region service URLs
############################################################
# Access Manager URL
# url = "https://sentinel-access-manager-dev.dotv.ee"
url = "https://localhost:6111"
if window.location.origin == "https://sentinel.ewag-handelssysteme.de"
    url = "https://sentinel-access-manager.dotv.ee"
export urlAccessManager = url

############################################################
# Backend URL
# url = "https://sentinel-backend.dotv.ee"
url = "https://localhost:6112"
if window.location.origin == "https://sentinel.ewag-handelssysteme.de"
    url = "https://sentinel-backend.dotv.ee"
export urlWebsocketBackend = url

############################################################
# Datahub URL
# url = "https://sentinel-datahub.dotv.ee"
url = "https://localhost:6113"
if window.location.origin == "https://sentinel.ewag-handelssysteme.de"
    url = "https://sentinel-datahub.dotv.ee"
export urlDatahub = url

############################################################
# Link Guardian URL
# url = "https://link-guardian.dotv.ee"
url = "https://localhost:6337"
if window.location.origin == "https://sentinel.ewag-handelssysteme.de"
    url = "https://link-guardian.dotv.ee"
export urlLinkGuardian = url

#endregion

############################################################
export uriAllSymbolsFile = "all_symbols.json"

############################################################
export pwdSalt = "holderradio!...<3)()0981salty"

############################################################
export uiRerenderMS = 3000

############################################################
export shownCurrencyPairLabels = [
    "USDJPY",
    "USDCAD",
    "USDCHF",

    "EURUSD",
    "NZDUSD",
    "AUDUSD",
    "GBPUSD",

    ## additional crosspairs
    "EURGBP",
    "EURCHF",
    "EURJPY",
    "EURCAD",
    "EURAUD",
    "EURNZD",

    "GBPCHF",
    "GBPJPY",
    "GBPCAD",
    "GBPAUD",
    "GBPNZD",
    
    "CHFJPY",
    "CADJPY",
    "AUDJPY",
    "NZDJPY",

    "CADCHF",
    "AUDCHF",
    "NZDCHF",

    "AUDCAD",
    "NZDCAD",

    "AUDNZD"
]
