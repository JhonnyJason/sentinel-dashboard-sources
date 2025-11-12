############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("accountframemodule")
#endregion

############################################################
import M from "mustache"

# currencyPairTemplate = document.getElementById("currency-pair-template").innerHTML
# log currencyPairTemplate

############################################################
import * as cfg from "./configmodule.js"

############################################################
export initialize = ->
    log "initialize"
    #Implement or Remove :-)
    return