export appVersion = "v0.0.4"
export heartbeatMS = 120000

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


export backendWSURL = "https://sentinel-backend.dotv.ee/"
# export backendWSURL = "wss://sentinel-backend.dotv.ee/"

# local testing
# export backendWSURL = "wss://localhost:6999/"
# export backendWSURL = "https://localhost:6999/"