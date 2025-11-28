############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("utilsmodule")
#endregion

############################################################
export getJan1Date = (date) ->
    date = new Date() unless date?
    date.setMilliseconds(0)
    date.setSeconds(0)
    date.setMinutes(0)
    date.setHours(20)
    date.setDate(1)
    date.setMonth(0)
    return date

export getDec31Date = (date) ->
    date = new Date() unless date?
    date.setMilliseconds(0)
    date.setSeconds(0)
    date.setMinutes(0)
    date.setHours(20)
    date.setMonth(11)
    date.setDate(31)
    return date
    
export dateDifDays = (date1, date2) ->
    msDif = (date2.getTime() - date1.getTime())
    daysDif = msDif / 86_400_000 # = 1000 * 60 * 60 * 24
    return Math.floor(daysDif)
