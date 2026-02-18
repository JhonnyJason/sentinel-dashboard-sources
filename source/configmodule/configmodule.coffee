############################################################
export appVersion = "v0.1.3"
export heartbeatMS = 120_000 # ~2min

############################################################
url = "https://sentinel-access-manager-dev.dotv.ee"
if window.location.origin == "https://sentinel.ewag-handelssysteme.de"
    url = "https://sentinel-access-manager.dotv.ee"
export urlAccessManager = url

export urlWebsocketBackend = "https://sentinel-backend.dotv.ee"
export urlDatahub = "https://sentinel-datahub.dotv.ee"

# export urlWebsocketBackend = "wss://sentinel-backend.dotv.ee/"

# local testing
# export urlAccessManager = "https://localhost:6999"
# export urlWebsocketBackend = "http://localhost:3333"
# export urlWebsocketBackend = "wss://localhost:6999/"
# export urlWebsocketBackend = "https://localhost:6999/"


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
