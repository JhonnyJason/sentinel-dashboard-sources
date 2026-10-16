############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("chanceriskprofilemodule")
#endregion

############################################################
import uPlot from "uplot"
import { simulate } from "./tradesimulationmodule.js"
import { binProfile } from "./chanceriskbins.js"

############################################################
summary = null
chart = null
binOffset = 0 # user steps away from the FD bin width, reset by new results (not persisted)
minLabelPx = 45 # x labels closer than this are thinned out
zeroLineTop = 10 # px the 0% line reaches above the plot area
zeroLineBottom = 5 # px it reaches into the x axis

############################################################
export initialize = ->
    log "initialize"
    # the tab may be hidden (display none) when results arrive -> draw once it gets a size
    new ResizeObserver(render).observe(chanceriskprofile)
    chanceriskprofileBinsSelect.addEventListener("change", binsSelected)
    return

binsSelected = ->
    binOffset = parseInt(chanceriskprofileBinsSelect.value)
    render()
    return

############################################################
# results: the SymbolBacktester summary
export setResults = (results) ->
    log "setResults"
    summary = results
    binOffset = 0 # new sample -> the FD rule decides again
    requestAnimationFrame(render) # see equityperformancemodule: hidden + shown within one frame
    return

############################################################
# raw trades (no stop-loss / take-profit / fees): independent of the Performance tab controls
render = ->
    return unless summary? and chanceriskprofile.clientWidth
    chart?.destroy()
    chart = null
    # price change, not profit: a short's profits sit left of 0 (still green)
    dir = if summary.isLong then 1 else -1
    profile = binProfile(simulate(summary).trades, dir, binOffset)
    updateBinsSelect(profile?.choices ? []) # no trades: no stale choices from the previous results
    return unless profile?
    { edges, losses, wins } = profile

    toP = (f) -> 100 * f
    w = toP(edges[1] - edges[0])
    xs = (toP(e) + w / 2 for e in edges[...-1])
    totals = (l + wins[i] for l, i in losses)
    splits = edges.map(toP)
    zeroIdx = Math.round(-edges[0] / (edges[1] - edges[0]))
    # every k-th edge, counted from 0 so the 0% edge always has its label
    k = Math.ceil(minLabelPx / (chanceriskprofile.clientWidth / losses.length))
    label = (v, i) -> if (i - zeroIdx) % k == 0 then +v.toFixed(2) + "%" else ""

    # "overshadowed": the minority colour gets darker where the majority goes against the price side
    # favourable side = right of 0 for longs, left for shorts (0 is always an edge, so no bin straddles it)
    redDark = (not (x * dir > 0) and wins[i] > losses[i] for x, i in xs)
    greenDark = (x * dir > 0 and losses[i] > wins[i] for x, i in xs)

    # stacked by drawing order: the total in green, the losing part in red over its lower end
    barSeries = (color, darkColor, isDark) ->
        colors = { unit: 3, values: -> ((if d then darkColor else color) for d in isDark) }
        bars = uPlot.paths.bars({ size: [0.9, 40], disp: { fill: colors, stroke: colors } })
        return { paths: bars, fill: color, stroke: color, points: { show: false } }

    options = {
        width: chanceriskprofile.clientWidth
        height: chanceriskprofile.clientHeight
        legend: { show: false }
        padding: [zeroLineTop, null, null, null] # room for the 0% line above the tallest bar
        cursor: { show: false }
        scales: {
            x: { time: false, range: -> [splits[0], splits[splits.length - 1]] }
            y: { range: (u, min, max) -> [0, max] }
        }
        axes: [
            { stroke: "#ffffff", grid: { show: false }, splits: (-> splits), values: (u, vals) -> vals.map(label) }
            { stroke: "#ffffff", grid: { stroke: "#ffffff22", width: 1, dash: [5, 10] }, ticks: { show: false }, incrs: [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000] }
        ]
        series: [
            {}
            barSeries("#4caf50", "#357a38", greenDark) # cd-up-green
            barSeries("#ff6464", "#b34646", redDark) # cd-down-red
        ]
    }
    options.hooks = { draw: [drawZeroLine] }
    chart = new uPlot(options, [xs, totals, losses], chanceriskprofile)
    return

# the choices depend on the data -> rebuilt on every render
updateBinsSelect = (choices) ->
    chanceriskprofileBinsSelect.innerHTML = ""
    for { offset, count, width } in choices
        text = "#{count} Balken à #{+(100 * width).toFixed(4)}%"
        text += " (Auto)" if offset == 0 # suffix: the option fronts stay aligned
        chanceriskprofileBinsSelect.add(new Option(text, offset, false, offset == binOffset))
    return

# vertical 0% line over the bars: where the price stood at entry - overshoots the plot area, so it stays visible between dense bars
drawZeroLine = (u) ->
    { ctx, bbox } = u
    x = Math.round(u.valToPos(0, "x", true)) + 0.5
    ctx.save()
    ctx.strokeStyle = "#ffffff"
    ctx.lineWidth = uPlot.pxRatio
    ctx.beginPath()
    ctx.moveTo(x, bbox.top - zeroLineTop * uPlot.pxRatio)
    ctx.lineTo(x, bbox.top + bbox.height + zeroLineBottom * uPlot.pxRatio)
    ctx.stroke()
    ctx.restore()
    return
