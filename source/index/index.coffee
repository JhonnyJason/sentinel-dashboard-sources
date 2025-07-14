import Modules from "./allmodules"
import domconnect from "./indexdomconnect"
domconnect.initialize()

############################################################
import { appLoaded } from "navhandler"
global.allModules = Modules

############################################################
appStartup = ->
    appLoaded()
    Modules.datamodule.startHeartbeat()
    return

############################################################
run = ->
    promises = (m.initialize() for n,m of Modules when m.initialize?) 
    await Promise.all(promises)
    appStartup()

############################################################
run()