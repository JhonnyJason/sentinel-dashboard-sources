############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("equityperformancemodule")
#endregion

############################################################
import uPlot from "uplot"
import { simulate } from "./tradesimulationmodule.js"

############################################################
summary = null
controls = {}
equityChart = null
tradesChart = null

############################################################
export initialize = ->
    log "initialize"
    equityControls.addEventListener("input", onControlsChanged)
    equityControls.addEventListener("change", onControlCommitted)
    # equityStopLossLine. equityTakeProfitLine. # this line is needed to workaround a DOM-connect bug...
    for line in [equityStopLossLine, equityTakeProfitLine]
        line.addEventListener("pointerdown", onLevelDragStart)
        line.addEventListener("pointermove", onLevelDrag)
    # the tab may be hidden (display none) when results arrive -> draw once it gets a size
    observer = new ResizeObserver(render)
    observer.observe(equityCurveChart)
    observer.observe(equityTradesChart) # rows differ in height
    return

############################################################
# inputs in %, empty = off; the stop-loss is entered negative (same sign as simulate expects)
onControlsChanged = ->
    log "onControlsChanged"
    sl = parseFloat(equityStopLossInput.value)
    tp = parseFloat(equityTakeProfitInput.value)
    fee = parseFloat(equityFeeInput.value)
    controls = {
        stopLossF: if sl < 0 then sl / 100 else null
        takeProfitF: if tp > 0 then tp / 100 else null
        feeF: if fee > 0 then fee / 100 else 0
        reinvest: equityReinvestRadio.checked
    }
    render()
    return

# a level of 0 means off - show it as the empty field; on change, not input: typing "0.5" passes through "0"
onControlCommitted = (evt) ->
    el = evt.target
    return unless el == equityStopLossInput or el == equityTakeProfitInput
    if parseFloat(el.value) == 0 then el.value = ""
    return

# the line keeps the pointer capture while the chart below it is rebuilt
onLevelDragStart = (evt) ->
    evt.currentTarget.setPointerCapture(evt.pointerId)
    return

# the inputs stay the single source of truth; kept 0.1% off zero so a line never hides mid-drag
onLevelDrag = (evt) ->
    line = evt.currentTarget
    return unless line.hasPointerCapture(evt.pointerId)
    rect = tradesChart.over.getBoundingClientRect()
    y = Math.min(Math.max(evt.clientY - rect.top, 0), rect.height)
    v = tradesChart.posToVal(y, "y")
    if line == equityStopLossLine then equityStopLossInput.value = Math.min(-0.1, v).toFixed(1)
    else equityTakeProfitInput.value = Math.max(0.1, v).toFixed(1)
    onControlsChanged()
    return

############################################################
# results: the SymbolBacktester summary
export setResults = (results) ->
    log "setResults"
    summary = results
    # next frame: on a reload the region is hidden and shown again within the same frame,
    # so the ResizeObserver sees no change and would never redraw
    requestAnimationFrame(render)
    return

############################################################
render = ->
    return unless summary? and equityCurveChart.clientWidth
    { trades, equity, stats } = simulate(summary, controls)
    # same runs in the same order without stop-loss and take-profit: theoretical bars, dots and a fixed y range
    theoTrades = simulate(summary, Object.assign({}, controls, { stopLossF: null, takeProfitF: null })).trades
    dates = [trades[0]?.entryDate].concat(t.exitDate for t in trades)
    renderEquityCurve(dates, equity)
    renderTradesChart(dates, trades, theoTrades)
    renderSummary(stats)
    return

# Both charts share the x axis: x = point index (0 = start, i = after trade i),
# labelled with the year of dates[i] (the exit date of trade i)
baseOptions = (chartEl, dates) -> {
    width: chartEl.clientWidth
    height: chartEl.clientHeight
    legend: { show: false }
    cursor: { y: false, drag: { x: false, y: false, setScale: false } }
    scales: { x: { time: false } }
    axes: [
        { stroke: "#ffffff", grid: { show: false }, values: (u, splits) -> splits.map((i) -> dates[i]?.slice(0, 4) ? "") }
        { stroke: "#ffffff", grid: { stroke: "#ffffff22", width: 1, dash: [5, 10] }, ticks: { show: false } }
    ]
}

renderEquityCurve = (dates, equity) ->
    equityChart?.destroy()
    # equityCurveChart. # this line is needed to workaround a DOM-connect bug...
    options = baseOptions(equityCurveChart, dates)
    options.series = [
            {}
        { stroke: "#ffffff", width: 2, fill: "rgba(255, 255, 255, 0.5)" }
    ]
    equityChart = new uPlot(options, [equity.map((e, i) -> i), equity], equityCurveChart)
    return

# Bars at x = 1..n in percent: regular exits grey (losses light red tinted); a trade cut by the stop-loss (orange) or the
# take-profit (green) is a narrower bar in front of its faded theoretical bar (no stop-loss/take-profit).
# Max drops as red, max rises as green dots; a theoretical extreme the cut trade never reached is faded.
# A dot at the cutting level would only repeat the bar end -> left out.
# The y range comes from the theoretical values, so it does not change with the levels.
renderTradesChart = (dates, trades, theoTrades) ->
    tradesChart?.destroy()
    xs = (i + 1 for t, i in trades)
    toP = (f) -> 100 * f
    cutBy = (exit) -> (t) -> if t.exit == exit then toP(t.profitF) else null
    endProfits = trades.map(cutBy("end"))
    profits = endProfits.map((p) -> if p? and p >= 0 then p else null)
    losses = endProfits.map((p) -> if p? and p < 0 then p else null)
    theoProfits = trades.map((t, i) -> if t.exit != "end" then toP(theoTrades[i].profitF) else null)
    slProfits = trades.map(cutBy("sl"))
    tpProfits = trades.map(cutBy("tp"))
    maxDrops = trades.map((t) -> if t.exit != "sl" and t.maxDropF < 0 then toP(t.maxDropF) else null)
    maxRises = trades.map((t) -> if t.exit != "tp" and t.maxRiseF > 0 then toP(t.maxRiseF) else null)
    theoDrops = trades.map((t, i) -> if theoTrades[i].maxDropF < t.maxDropF then toP(theoTrades[i].maxDropF) else null)
    theoRises = trades.map((t, i) -> if theoTrades[i].maxRiseF > t.maxRiseF then toP(theoTrades[i].maxRiseF) else null)

    rangeVals = [0].concat((toP(t.profitF) for t in theoTrades), (toP(t.maxDropF) for t in theoTrades), (toP(t.maxRiseF) for t in theoTrades), (toP(t.profitF) for t in trades))
    yRange = uPlot.rangeNum(Math.min(rangeVals...), Math.max(rangeVals...), 0.1, true)

    bars = uPlot.paths.bars({ size: [0.6, 40] }) # max px width: few trades would give fat bars
    narrowBars = uPlot.paths.bars({ size: [0.35, 24] })
    noLine = -> null
    barSeries = (paths, color) -> { paths, fill: color, stroke: color, points: { show: false } }
    dotSeries = (color) -> { paths: noLine, points: { show: true, size: 6, fill: color, stroke: color } }

    # equityTradesChart. # this line is needed to workaround a DOM-connect bug...
    options = baseOptions(equityTradesChart, dates)
    options.scales.x.range = -> [0.5, trades.length + 0.5]
    options.scales.y = { range: -> yRange }
    options.axes[1].grid = { show: false }
    options.axes[1].values = (u, vals) -> vals.map((v) -> v + "%")
    options.series = [
        {}
        barSeries(bars, "#dddddd")
        barSeries(bars, "#e8c8c8") # loss: grey with a light red tint
        barSeries(bars, "rgba(221, 221, 221, 0.3)")
        barSeries(narrowBars, "#ff8c00")
        barSeries(narrowBars, "#4caf50") # cd-up-green
        dotSeries("#b03030")
        dotSeries("rgba(176, 48, 48, 0.35)")
        dotSeries("#4caf50")
        dotSeries("rgba(76, 175, 80, 0.35)")
    ]
    # scales and plot area exist only after uPlot's first (async) layout
    options.hooks = { drawAxes: [drawZeroLine], draw: [positionLevelLines] }
    data = [xs, profits, losses, theoProfits, slProfits, tpProfits, maxDrops, theoDrops, maxRises, theoRises]
    tradesChart = new uPlot(options, data, equityTradesChart)
    return

# drawn with the axes, so the bars cover it
drawZeroLine = (u) ->
    { ctx, bbox } = u
    y = Math.round(u.valToPos(0, "y", true)) + 0.5
    ctx.save()
    ctx.strokeStyle = "rgba(255, 255, 255, 0.5)"
    ctx.lineWidth = uPlot.pxRatio
    ctx.beginPath()
    ctx.moveTo(bbox.left, y)
    ctx.lineTo(bbox.left + bbox.width, y)
    ctx.stroke()
    ctx.restore()
    return

positionLevelLines = (u) ->
    positionLevelLine(u, equityStopLossLine, controls.stopLossF)
    positionLevelLine(u, equityTakeProfitLine, controls.takeProfitF)
    return

# spans the full plot area; hidden when the level is off
positionLevelLine = (u, line, levelF) ->
    line.classList.toggle("active", levelF?)
    return unless levelF?
    over = u.over.getBoundingClientRect()
    box = equityTradesChart.getBoundingClientRect()
    line.style.left = "#{over.left - box.left}px"
    line.style.width = "#{over.width}px"
    line.style.top = "#{over.top - box.top + u.valToPos(100 * levelF, "y")}px"
    return

renderSummary = (stats) ->
    # equitySumProfit. # this line is needed to workaround a DOM-connect bug...
    setSignedPercent(equitySumProfit, stats.sumProfitF)
    equityMaxDrawdown.textContent = toPercent(stats.maxDrawdownF)
    equityMaxDrawdownRealized.textContent = toPercent(stats.maxDrawdownRealizedF)
    equityMaxDrawdownAbs.textContent = toUnits(stats.maxDrawdownAbs)
    equityMaxDrawdownRealizedAbs.textContent = toUnits(stats.maxDrawdownRealizedAbs)
    equityTotalTrades.textContent = stats.total
    equitySlHits.textContent = stats.slHits
    equityTpHits.textContent = stats.tpHits
    return

# green for a gain, red for a loss, standard colour for exactly 0
setSignedPercent = (el, f) ->
    el.textContent = toPercent(f)
    el.classList.toggle("positive", f > 0)
    el.classList.toggle("negative", f < 0)
    return

############################################################
toPercent = (f) -> "#{(100 * f).toFixed(1)}%"
toUnits = (v) -> "#{v.toFixed(2)} €" # exemplary 100 € base stake
