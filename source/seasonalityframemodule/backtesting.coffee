############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("backtesting")
#endregion

############################################################
# Backtesting Module - Shell
#
# Purpose: Calculate backtesting statistics for a selected date range
# across all available historic years.
#
# Data Requirements:
# - Historic HLC (High, Low, Close) data from datacache
# - HLC needed because: max rise/drop requires highs and lows within the range
#
# Direction Detection:
# - Automatically determined from results
# - Positive average profit → "Long"
# - Negative average profit → "Short"
#
# Profit Calculation:
# - For each historic year: (closeAtEnd - closeAtStart) / closeAtStart * 100
#
# Required Output:
# - tradeDescription: "[DD.MM. - DD.MM.] Long/Short"
# - winRate: percentage of years with positive result (for Long) or negative (for Short)
# - maxRise: maximum peak during trade period across all years
# - maxDrop: maximum drop during trade period across all years
# - averageProfit: mean of all yearly profits
# - medianProfit: median of all yearly profits
# - daysInTrade: number of trading days in the range
# - yearlyResults: array of per-year results for details table
#
############################################################

############################################################
# TODO: Implement actual calculation
# Parameters:
#   - hlcData: historic HLC data from datacache (per year)
#   - startDayOfYear: 0-365 index for trade start
#   - endDayOfYear: 0-365 index for trade end
#   
# Returns: BacktestingResult object
############################################################
export runBacktesting = (startIdx, endIdx) ->
    log "runBacktesting (stub)"
    olog { startIdx, endIdx }

    # Return mock data for UI development
    return {
        directionString: "Long" 
        timeframeString: "[12.01. - 24.01.]"
        winRate: 75
        maxRise: 8.5
        maxDrop: -3.2
        averageProfit: 4.2
        medianProfit: 3.8
        daysInTrade: 12
        yearlyResults: [
            { year: 2024, profit: 5.2, maxHigh: 7.1, maxLow: -1.2 }
            { year: 2023, profit: 3.8, maxHigh: 4.5, maxLow: -2.1 }
            { year: 2022, profit: -2.1, maxHigh: 1.2, maxLow: -4.5 }
            { year: 2021, profit: 6.1, maxHigh: 8.5, maxLow: -0.8 }
        ]
    }

############################################################
# Helper to format day-of-year index to "DD.MM." string
# TODO: Implement properly using utilsmodule date helpers
formatDayOfYear = (dayIdx) ->
    # Stub - will need proper date calculation
    "01.01."
