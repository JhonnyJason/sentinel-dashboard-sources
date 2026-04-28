############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("symboloptionsmodule")
#endregion

############################################################
allSymbolsURL = "#{window.location.origin}/all_symbols.json" 
allSymbols = null

############################################################
export initialize = (c) ->
    if c.uriAllSymbolsFile? then allSymbolsURL = "#{window.location.origin}/all_symbols.json"
    retrieveAllSymbols() # Just load in parallel, donot await ;-)
    return

############################################################
retrieveAllSymbols = ->
    log "retrieveAllSymbols"
    try
        response = await fetch(allSymbolsURL)
        if !response.ok then throw new Error("allSymbols retrieval failed! Status: #{response.status}")

        try allSymbols = await response.json()
        catch err then throw new Error("allSymbols retrieval failed! Unparsable JSON!")
        log "retrieval of allSymbols successfull! #{allSymbols.length} symbols loaded!"
    catch err then console.error err
    return

############################################################
symbolsUpdated = (newURL) ->
    log "symbolsUpdated"
    return if newURL == allSymbolsURL
    allSymbolsURL = newURL
    await retrieveAllSymbols()
    return

############################################################
export getAllSymbols = -> allSymbols || defaultTop100

## TODO implement some automtatic update of this list############################################################
export defaultTop100 = [ 
    [ "NVDA", "Nvidia" ],
    [ "AAPL","Apple Inc."],
    [ "MSFT", "Microsoft" ],
    [ "AMZN", "Amazon" ],
    [ "GOOGL", "Alphabet Inc. (Class A)" ],
    [ "GOOG", "Alphabet Inc. (Class C)" ],
    [ "META", "Meta Platforms" ],
    [ "AVGO", "Broadcom" ],
    [ "TSLA", "Tesla, Inc." ],
    [ "BRK.B", "Berkshire Hathaway" ],
    [ "LLY", "Lilly (Eli)" ],
    [ "WMT", "Walmart" ],
    [ "JPM", "JPMorgan Chase" ],
    [ "V", "Visa Inc." ],
    [ "ORCL", "Oracle Corporation" ],
    [ "MA", "Mastercard" ],
    [ "XOM", "ExxonMobil" ],
    [ "JNJ", "Johnson & Johnson" ],
    [ "PLTR", "Palantir Technologies" ],
    [ "ABBV", "AbbVie" ],
    [ "BAC", "Bank of America" ],
    [ "NFLX", "Netflix" ],
    [ "COST", "Costco" ],
    [ "AMD", "Advanced Micro Devices" ],
    [ "HD", "Home Depot (The)" ],
    [ "PG", "Procter & Gamble" ],
    [ "GE", "GE Aerospace" ],
    [ "MU", "Micron Technology" ],
    [ "CVX", "Chevron Corporation" ],
    [ "CSCO", "Cisco" ],
    [ "KO", "Coca-Cola Company (The)" ],
    [ "UNH", "UnitedHealth Group" ],
    [ "WFC", "Wells Fargo" ],
    [ "MS", "Morgan Stanley" ],
    [ "IBM", "IBM" ],
    [ "CAT", "Caterpillar Inc." ],
    [ "GS", "Goldman Sachs" ],
    [ "MRK", "Merck & Co." ],
    [ "AXP", "American Express" ],
    [ "PM", "Philip Morris International" ],
    [ "CRM", "Salesforce" ],
    [ "RTX", "RTX Corporation" ],
    [ "APP", "AppLovin Corporation" ],
    [ "TMUS", "T-Mobile US" ],
    [ "ABT", "Abbott Laboratories" ],
    [ "TMO", "Thermo Fisher Scientific" ],
    [ "MCD", "McDonald's" ],
    [ "LRCX", "Lam Research" ],
    [ "C", "Citigroup" ],
    [ "AMAT", "Applied Materials" ],
    [ "DIS", "Walt Disney Company (The)" ],
    [ "ISRG", "Intuitive Surgical" ],
    [ "LIN", "Linde plc" ],
    [ "PEP", "PepsiCo" ],
    [ "INTU", "Intuit" ],
    [ "QCOM", "Qualcomm" ],
    [ "SCHW", "Charles Schwab Corporation" ],
    [ "GEV", "GE Vernova" ],
    [ "AMGN", "Amgen" ],
    [ "T", "AT&T" ],
    [ "INTC", "Intel" ],
    [ "BKNG", "Booking Holdings" ],
    [ "VZ", "Verizon" ],
    [ "TJX", "TJX Companies" ],
    [ "BA", "Boeing" ],
    [ "UBER", "Uber" ],
    [ "NEE", "NextEra Energy" ],
    [ "BLK", "BlackRock" ],
    [ "APH", "Amphenol" ],
    [ "ACN", "Accenture" ],
    [ "ANET", "Arista Networks" ],
    [ "DHR", "Danaher Corporation" ],
    [ "KLAC", "KLA Corporation" ],
    [ "NOW", "ServiceNow" ],
    [ "SPGI", "S&P Global" ],
    [ "TXN", "Texas Instruments" ],
    [ "COF", "Capital One" ],
    [ "GILD", "Gilead Sciences" ],
    [ "ADBE", "Adobe Inc." ],
    [ "PFE", "Pfizer" ],
    [ "BSX", "Boston Scientific" ],
    [ "UNP", "Union Pacific Corporation" ],
    [ "LOW", "Lowe's" ],
    [ "SYK", "Stryker Corporation" ],
    [ "PGR", "Progressive Corporation" ],
    [ "ADI", "Analog Devices" ],
    [ "PANW", "Palo Alto Networks" ],
    [ "WELL", "Welltower" ],
    [ "DE", "Deere & Company" ],
    [ "HON", "Honeywell" ],
    [ "ETN", "Eaton Corporation" ],
    [ "MDT", "Medtronic" ],
    [ "CB", "Chubb Limited" ],
    [ "BX", "Blackstone Inc." ],
    [ "PLD", "Prologis" ],
    [ "CRWD", "CrowdStrike" ],
    [ "COP", "ConocoPhillips" ],
    [ "VRTX", "Vertex Pharmaceuticals" ],
    [ "KKR", "KKR" ],
    [ "LMT", "Lockheed Martin" ]
]
