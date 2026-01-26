############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("symboloptions")
#endregion


############################################################
import { getSymbolOptions } from "./scimodule.js"

############################################################
nextSearch = null

############################################################
blocked = false

############################################################
cooldownMS = 200

############################################################
export initialize = (c) ->
    if c.cooldownMS? then cooldownMS = c.cooldownMS
    return


############################################################
export dynamicSearch = (searchString, limit, requester) ->
    log "dynamicSearch"
    if blocked
        nextSearch = { searchString, limit, requester }
        return

    blocked = true
    await retrieveOptions(searchString, limit, requester)
    setTimeout(unblock, cooldownMS)
    return

############################################################
retrieveOptions = (searchString, limit, requester) ->
    log "retrieveOptions"
    results = []
    try results = await getSymbolOptions(searchString, limit)
    catch err then log err
    
    requester?.provideSearchOptions(results)
    return

############################################################
unblock = ->
    unless nextSearch?
        blocked = false
        return

    { searchString, limit, requester } = nextSearch
    nextSearch = null
    await retrieveOptions(searchString, limit, requester)
    setTimeout(unblock, cooldownMS)
    return

############################################################
export defaultTop30 = [
    {symbol:"NVDA",name:"Nvidia"},
    {symbol:"AAPL",name:"Apple Inc."},
    {symbol:"MSFT",name:"Microsoft"},
    {symbol:"AMZN",name:"Amazon"},
    {symbol:"GOOGL",name:"Alphabet Inc. (Class A)"},
    {symbol:"GOOG",name:"Alphabet Inc. (Class C)"},
    {symbol:"META",name:"Meta Platforms"},
    {symbol:"AVGO",name:"Broadcom"},
    {symbol:"TSLA",name:"Tesla, Inc."},
    {symbol:"BRK.B",name:"Berkshire Hathaway"},
    {symbol:"LLY",name:"Lilly (Eli)"},
    {symbol:"WMT",name:"Walmart"},
    {symbol:"JPM",name:"JPMorgan Chase"},
    {symbol:"V",name:"Visa Inc."},
    {symbol:"ORCL",name:"Oracle Corporation"},
    {symbol:"MA",name:"Mastercard"},
    {symbol:"XOM",name:"ExxonMobil"},
    {symbol:"JNJ",name:"Johnson & Johnson"},
    {symbol:"PLTR",name:"Palantir Technologies"},
    {symbol:"ABBV",name:"AbbVie"},
    {symbol:"BAC",name:"Bank of America"},
    {symbol:"NFLX",name:"Netflix"},
    {symbol:"COST",name:"Costco"},
    {symbol:"AMD",name:"Advanced Micro Devices"},
    {symbol:"HD",name:"Home Depot (The)"},
    {symbol:"PG",name:"Procter & Gamble"},
    {symbol:"GE",name:"GE Aerospace"},
    {symbol:"MU",name:"Micron Technology"},
    {symbol:"CVX",name:"Chevron Corporation"},
]

############################################################
export defaultTop100 = [
    {symbol:"NVDA",name:"Nvidia"},
    {symbol:"AAPL",name:"Apple Inc."},
    {symbol:"MSFT",name:"Microsoft"},
    {symbol:"AMZN",name:"Amazon"},
    {symbol:"GOOGL",name:"Alphabet Inc. (Class A)"},
    {symbol:"GOOG",name:"Alphabet Inc. (Class C)"},
    {symbol:"META",name:"Meta Platforms"},
    {symbol:"AVGO",name:"Broadcom"},
    {symbol:"TSLA",name:"Tesla, Inc."},
    {symbol:"BRK.B",name:"Berkshire Hathaway"},
    {symbol:"LLY",name:"Lilly (Eli)"},
    {symbol:"WMT",name:"Walmart"},
    {symbol:"JPM",name:"JPMorgan Chase"},
    {symbol:"V",name:"Visa Inc."},
    {symbol:"ORCL",name:"Oracle Corporation"},
    {symbol:"MA",name:"Mastercard"},
    {symbol:"XOM",name:"ExxonMobil"},
    {symbol:"JNJ",name:"Johnson & Johnson"},
    {symbol:"PLTR",name:"Palantir Technologies"},
    {symbol:"ABBV",name:"AbbVie"},
    {symbol:"BAC",name:"Bank of America"},
    {symbol:"NFLX",name:"Netflix"},
    {symbol:"COST",name:"Costco"},
    {symbol:"AMD",name:"Advanced Micro Devices"},
    {symbol:"HD",name:"Home Depot (The)"},
    {symbol:"PG",name:"Procter & Gamble"},
    {symbol:"GE",name:"GE Aerospace"},
    {symbol:"MU",name:"Micron Technology"},
    {symbol:"CVX",name:"Chevron Corporation"},
    {symbol:"CSCO",name:"Cisco"},
    {symbol:"KO",name:"Coca-Cola Company (The)"},
    {symbol:"UNH",name:"UnitedHealth Group"},
    {symbol:"WFC",name:"Wells Fargo"},
    {symbol:"MS",name:"Morgan Stanley"},
    {symbol:"IBM",name:"IBM"},
    {symbol:"CAT",name:"Caterpillar Inc."},
    {symbol:"GS",name:"Goldman Sachs"},
    {symbol:"MRK",name:"Merck & Co."},
    {symbol:"AXP",name:"American Express"},
    {symbol:"PM",name:"Philip Morris International"},
    {symbol:"CRM",name:"Salesforce"},
    {symbol:"RTX",name:"RTX Corporation"},
    {symbol:"APP",name:"AppLovin Corporation"},
    {symbol:"TMUS",name:"T-Mobile US"},
    {symbol:"ABT",name:"Abbott Laboratories"},
    {symbol:"TMO",name:"Thermo Fisher Scientific"},
    {symbol:"MCD",name:"McDonald's"},
    {symbol:"LRCX",name:"Lam Research"},
    {symbol:"C",name:"Citigroup"},
    {symbol:"AMAT",name:"Applied Materials"},
    {symbol:"DIS",name:"Walt Disney Company (The)"},
    {symbol:"ISRG",name:"Intuitive Surgical"},
    {symbol:"LIN",name:"Linde plc"},
    {symbol:"PEP",name:"PepsiCo"},
    {symbol:"INTU",name:"Intuit"},
    {symbol:"QCOM",name:"Qualcomm"},
    {symbol:"SCHW",name:"Charles Schwab Corporation"},
    {symbol:"GEV",name:"GE Vernova"},
    {symbol:"AMGN",name:"Amgen"},
    {symbol:"T",name:"AT&T"},
    {symbol:"INTC",name:"Intel"},
    {symbol:"BKNG",name:"Booking Holdings"},
    {symbol:"VZ",name:"Verizon"},
    {symbol:"TJX",name:"TJX Companies"},
    {symbol:"BA",name:"Boeing"},
    {symbol:"UBER",name:"Uber"},
    {symbol:"NEE",name:"NextEra Energy"},
    {symbol:"BLK",name:"BlackRock"},
    {symbol:"APH",name:"Amphenol"},
    {symbol:"ACN",name:"Accenture"},
    {symbol:"ANET",name:"Arista Networks"},
    {symbol:"DHR",name:"Danaher Corporation"},
    {symbol:"KLAC",name:"KLA Corporation"},
    {symbol:"NOW",name:"ServiceNow"},
    {symbol:"SPGI",name:"S&P Global"},
    {symbol:"TXN",name:"Texas Instruments"},
    {symbol:"COF",name:"Capital One"},
    {symbol:"GILD",name:"Gilead Sciences"},
    {symbol:"ADBE",name:"Adobe Inc."},
    {symbol:"PFE",name:"Pfizer"},
    {symbol:"BSX",name:"Boston Scientific"},
    {symbol:"UNP",name:"Union Pacific Corporation"},
    {symbol:"LOW",name:"Lowe's"},
    {symbol:"SYK",name:"Stryker Corporation"},
    {symbol:"PGR",name:"Progressive Corporation"},
    {symbol:"ADI",name:"Analog Devices"},
    {symbol:"PANW",name:"Palo Alto Networks"},
    {symbol:"WELL",name:"Welltower"},
    {symbol:"DE",name:"Deere & Company"},
    {symbol:"HON",name:"Honeywell"},
    {symbol:"ETN",name:"Eaton Corporation"},
    {symbol:"MDT",name:"Medtronic"},
    {symbol:"CB",name:"Chubb Limited"},
    {symbol:"BX",name:"Blackstone Inc."},
    {symbol:"PLD",name:"Prologis"},
    {symbol:"CRWD",name:"CrowdStrike"},
    {symbol:"COP",name:"ConocoPhillips"},
    {symbol:"VRTX",name:"Vertex Pharmaceuticals"},
    {symbol:"KKR",name:"KKR"},
    {symbol:"LMT",name:"Lockheed Martin"}
]
