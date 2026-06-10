 ############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("hlcbacktestingmodule")
#endregion

############################################################
import * as utl from "./utilsmodule.js"

############################################################
export class SymbolBacktester
    constructor: (@symbol, @key) ->
        @runInfoObjects = []
        @evaluationObjects = []
        @summary = null
        @dataPerYear = null
        @tradingDaysPerYear = null
        @splitFactors = null
        @currentYear = null
        ##
        @ready = false
        @evaluated = false

    addBacktestRun: (startYear, startIdx, endIdx) =>
        # startIdx and endIdx need to be real indices - endIdx might be overlown
        
        if !@ready then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun when not being in ready state!")
        if @evaluated then throw new Error("Symbol Backtester #{@symbol}:#{key} cannot addBacktestRun in an evaluated state!")

        infoObj = Object.create(null)

        yearIdx = @getYearIdx(startYear)
        hlcData = @dataPerYear[yearIdx]
        tDaysData = @tradingDaysPerYear[yearIdx]

        ## getting true startIdx 
        while tDaysData[startIdx] == false            
            if startIdx > 0 then startIdx--
            else # we need to overflow one year back
                startYear = startYear - 1
                len = utl.getDaysOfYear(startYear)
                startIdx = len - 1
                endIdx = endIdx + len
                return @addBacktestRun(startYear, startIdx, endIdx)

        startDate = utl.realIdxToYYYYMMDD(startIdx)    

        if tDaysData[startIdx] != true # we were out of known data
            startDate = utl.lastWeekdayBefore(startDate)

        ## getting true endIdx
        ## Here we need to care about overflow from the beginning
        len = utl.getDaysOfYear(startYear)
        if endIdx >= len
            endYear = startYear + 1
            endIdx  -= len
            len = utl.getDaysOfYear(endYear)
            if endIdx >= len
                endYear += 1
                endIdx -= len
                len = utl.getDaysOfYear(endYear)
                if endIdx >= len
                    endYear += 1
                    endIdx -= len
                    len = utl.getDaysOfYear(endYear)
                    if endIdx >= len then throw new Error("Symbol Backtester #{@symbol}:#{key} provided endIdx has too much overflow!")
        
        yearIdx = @getYearIdx(endYear)
        hlcData = @dataPerYear[yearIdx]
        tDaysData = @tradingDaysPerYear[yearIdx]

        while tDaysData[endIdx] == false            
            if startIdx < len then startIdx++
            else # we need to overflow one year forward
                startYear = startYear - 1
                len = utl.getDaysOfYear(startYear)
                startIdx = len - 1
                endIdx = endIdx + len
                return @addBacktestRun(startYear, startIdx, endIdx)

        startDate = utl.realIdxToYYYYMMDD(startIdx)    

        if tDaysData[startIdx] != true # we were out of known data
            startDate = utl.lastWeekdayBefore(startDate)


        @runInfoObjects.push(infoObj)
        return


    ############################################################
    getYearIdx: (year) -> currentYear - year


############################################################
createRunInfoObject = (year, startIdx, endIdx) ->
    log "createRunInfoObject"
    
    return {}