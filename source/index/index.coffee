import Modules from "./allmodules"
import domconnect from "./indexdomconnect"
domconnect.initialize()

############################################################
import { appLoaded } from "navhandler"
global.allModules = Modules
############################################################
cfg = Modules.configmodule

############################################################
appStartup = ->
    appLoaded()
    Modules.datamodule.startHeartbeat()
    return

############################################################
run = ->
    try
        promises = (m.initialize(cfg) for n,m of Modules when m.initialize?) 
        await Promise.all(promises)
        await appStartup()
    catch err then console.error(err)
############################################################
run()