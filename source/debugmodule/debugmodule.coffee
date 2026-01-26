import { addModulesToDebug } from "thingy-debug"

############################################################
export modulesToDebug = {

    # accountmodule: true
    # appcoremodule: true
    # datamodule: true
    datacache: true
    # economicareasmodule: true
    fouriermodule: true
    # summaryframemodule: true
    # currencytrendframemodule: true
    # marketdatamodule: true
    # sampledata: true
    scimodule: true
    # navtriggers: true
    # scorehelper: true
    seasonalityframemodule: true
    # uistatemodule: true
}

addModulesToDebug(modulesToDebug)