############################################################
export appVersion = "v0.0.7a"
export heartbeatMS = 120_000 # ~2min

############################################################
export urlAccessManager = "https://sentinel-access-manager-dev.dotv.ee"
export urlWebsocketBackend = "https://sentinel-backend.dotv.ee"
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
