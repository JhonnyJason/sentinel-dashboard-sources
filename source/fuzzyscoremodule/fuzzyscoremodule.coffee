############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("fuzzyscoremodule")
#endregion

import { fuzzyScore as fuzzyScoreDP } from "./fuzzyscoredp.js"
import { fuzzyScore as fuzzyScoreBitap } from "./fuzzyscorebitap.js"


############################################################
export fuzzyScore = fuzzyScoreDP