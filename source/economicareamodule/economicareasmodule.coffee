############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("economicareasmodule")
#endregion

############################################################
import { areaParams as dAP } from "./defaultsnapshot.js"
import { EconomicArea } from "./EconomicArea.js"


############################################################
eurozone = new EconomicArea({ #  351.4 mio Citizens
    "icon-href": "#svg-europe-icon"
    
    title: "Eurozone"
    key: "eurozone"
    currencyName: "Euro"
    currencyShort:"EUR"
    populationM: 351.4,

    inflParams: dAP.eurozone.infl
    mrrParams: dAP.eurozone.mrr
    gdpgParams: dAP.eurozone.gdpg
    cotParams: dAP.eurozone.cot
})

usa = new EconomicArea({ # 340.1mio Citizens
    "icon-href": "#svg-usa-icon"
    
    title: "USA"
    key: "usa"
    currencyName: "US-Dollar"
    currencyShort: "USD"
    populationM: 340.1,

    inflParams: dAP.usa.infl
    mrrParams: dAP.usa.mrr
    gdpgParams: dAP.usa.gdpg
    cotParams: dAP.usa.cot
})

japan =  new EconomicArea({ # 124mio Citizens
    "icon-href": "#svg-japan-icon"

    title: "Japan"
    key: "japan"
    currencyName: "Yen"
    currencyShort: "JPY"
    populationM: 124,
    
    infParams: dAP.japan.infl 
    mrrParams: dAP.japan.mrr
    gdpgParams: dAP.japan.gdpg
    cotParams: dAP.japan.cot
})

uk = new EconomicArea({ # 69.2mio Citizens
    "icon-href": "#svg-uk-icon"

    title: "Großbritannien"
    key: "uk"
    currencyName: "Pfund"
    currencyShort: "GBP"
    populationM: 69.2,

    inflParams: dAP.uk.infl 
    mrrParams: dAP.uk.mrr
    gdpgParams: dAP.uk.gdpg
    cotParams: dAP.uk.cot
})

canada = new EconomicArea({ # 41.3mio Citizens
    "icon-href": "#svg-canada-icon"
    
    title: "Kanada"
    key: "canada"
    currencyName: "Canada Dollar"
    currencyShort: "CAD"
    populationM: 41.3,
    
    inflParams: dAP.canada.infl
    mrrParams: dAP.canada.mrr
    gdpgParams: dAP.canada.gdpg
    cotParams: dAP.canada.cot
})

australia = new EconomicArea({ # 27.4mio Citizens
    "icon-href": "#svg-australia-icon"

    title: "Australien"
    key: "australia"
    currencyName: "Australia Dollar"
    currencyShort: "AUD"
    populationM: 27.4,

    inflParams: dAP.australia.infl
    mrrParams: dAP.australia.mrr
    gdpgParams: dAP.australia.gdpg
    cotParams: dAP.australia.cot
})

switzerland = new EconomicArea({ # 9mio Citizens
    "icon-href": "#svg-switzerland-icon"

    title: "Schweiz"
    key: "switzerland"
    currencyName: "Franken"
    currencyShort: "CHF"
    populationM: 9,

    inflParams: dAP.switzerland.infl
    mrrParams: dAP.switzerland.mrr
    gdpgParams: dAP.switzerland.gdpg
    cotParams: dAP.switzerland.cot
})

newzealand = new EconomicArea({ # 5.4mio Citizens
    "icon-href": "#svg-newzealand-icon"
    
    title: "Neuseeland"
    key: "newzealand"
    currencyName: "New Zealand Dollar"
    currencyShort: "NZD"
    populationM: 5.4,

    inflParams: dAP.newzealand.infl
    mrrParams: dAP.newzealand.mrr
    gdpgParams: dAP.newzealand.gdpg
    cotParams: dAP.newzealand.cot
})


export allAreas = {
    eurozone, usa, japan, uk, canada, australia, switzerland, newzealand
}