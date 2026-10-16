############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityblocksmodule")
#endregion

############################################################
import uPlot from "uplot"
import { blockRanges, calculateBlockReturns } from "./marketdatamodule.js"
import { barSeries, dotSeries, drawZeroLine } from "./equityperformancemodule.js"
import { leapNormToYYYYMMDD } from "./utilsmodule.js"

############################################################
# weeks are deferred (plan/deferred.md)
timeframeToBlocks = { yearly: ["months", "days"], quarterly: ["months", "days"], monthly: ["days"], weekly: ["days"] }

monthNames = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
weekdayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
pad = (n) -> String(n).padStart(2, "0")

# x axis label per block index (= slot index for days)
labelFns = {
    yearly: {
        months: (i) -> monthNames[i]
        days: (i) -> leapNormToYYYYMMDD(i, 2000).slice(5).split("-").reverse().join(".") # 366 slot space
    }
    quarterly: {
        months: (i) -> "Monat #{i + 1}"
        days: (i) -> "#{pad(i % 31 + 1)}/M#{Math.floor(i / 31) + 1}" # slot = monthInQuarter * 31 + day - 1
    }
    monthly: { days: (i) -> pad(i + 1) }
    weekly: { days: (i) -> weekdayNames[i] }
}

############################################################
data = null
block = "months"
blocksChart = null

############################################################
export initialize = ->
    log "initialize"
    seasonalityBlocksTabs.addEventListener("click", onTabClicked)
    return

onTabClicked = (evt) ->
    clicked = evt.target.dataset.block
    return unless data? and clicked? and clicked != block
    block = clicked
    updateTabs()
    render()
    return

# unavailable blocks hidden - a single tab just shows which block is on
updateTabs = ->
    blocks = timeframeToBlocks[data.timeframe]
    for button in seasonalityBlocksTabs.querySelectorAll("button")
        button.hidden = button.dataset.block not in blocks
        button.classList.toggle("active", button.dataset.block == block)
    return

############################################################
# data: the frame's chartData - same chunks and cycle filter as the composite
export setData = (chartData) ->
    log "setData"
    data = chartData
    blocks = timeframeToBlocks[data.timeframe]
    # keep the chosen block if the timeframe offers it, else the first one
    if block not in blocks then block = blocks[0]
    updateTabs()
    render()
    return

############################################################
# avg as bars (losses light red tinted), min red / max green dots
render = ->
    log "render"
    blocksChart?.destroy()
    { timeframe, chunks, isIncluded } = data
    { avg, min, max } = calculateBlockReturns(chunks, blockRanges(timeframe, block), isIncluded)
    label = labelFns[timeframe][block]

    xs = (i + 1 for a, i in avg)
    profits = avg.map((a) -> if a? and a >= 0 then a else null)
    losses = avg.map((a) -> if a? and a < 0 then a else null)
    values = [0].concat(min.filter((v) -> v?), max.filter((v) -> v?))
    yRange = uPlot.rangeNum(Math.min(values...), Math.max(values...), 0.1, true)
    bars = uPlot.paths.bars({ size: [0.6, 40] }) # same as the trades chart
    width = seasonalityBlocksChart.clientWidth
    # dots narrower than the bars (366 days): bar px = 0.6 * plot width / n, plot width < width (y axis)
    # uPlot's size is the full diameter incl. the 1px stroke (radius = (size - 1) / 2) -> below 2 it vanishes
    dotSize = Math.max(2, Math.min(6, 0.6 * width / xs.length - 1))

    options = {
        width: width
        height: seasonalityBlocksChart.clientHeight
        legend: { show: false }
        cursor: { drag: { x: false, y: false, setScale: false } }
        scales: { x: { time: false, range: -> [0.5, xs.length + 0.5] }, y: { range: -> yRange } }
        axes: [
            # integer steps only: a split between two bars has no label
            { stroke: "#ffffff", grid: { show: false }, incrs: [1, 2, 3, 5, 7, 10, 14, 31, 61], values: (u, splits) -> splits.map((x) -> if Number.isInteger(x) and x >= 1 and x <= xs.length then label(x - 1) else "") }
            { stroke: "#ffffff", grid: { show: false }, ticks: { show: false }, values: (u, vals) -> vals.map((v) -> v + "%") }
        ]
        series: [
            {}
            barSeries(bars, "#dddddd")
            barSeries(bars, "#e8c8c8") # loss: grey with a light red tint
            dotSeries("#b03030", dotSize) # min
            dotSeries("#4caf50", dotSize) # max, cd-up-green
        ]
        hooks: { drawAxes: [drawZeroLine] }
    }
    blocksChart = new uPlot(options, [xs, profits, losses, min, max], seasonalityBlocksChart)
    return
