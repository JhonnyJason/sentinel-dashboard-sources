############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("chanceriskprofilemodule")
#endregion

############################################################
import uPlot from "uplot"
import { simulate } from "./tradesimulationmodule.js"
import { binProfile } from "./chanceriskbins.js"
import { bellFit, bellCount } from "./chanceriskbell.js"

############################################################
summary = null
chart = null
binOffset = 0 # user steps away from the FD bin width, reset by new results (not persisted)
minLabelPx = 45 # x labels closer than this are thinned out
zeroLineTop = 10 # px the 0% line reaches above the plot area
zeroLineBottom = 5 # px it reaches into the x axis
bellColor = "#bbbbbb"
centerColor = "#e0e0e0"
lossColors = ["#b89090", "#d87a7a", "#ff6464"] # 1σ, 2σ, 3σ - out to the bars' red
profitColors = ["#90b892", "#6eb371", "#4caf50"] # out to the bars' green
labelFontPx = 11
labelRowPx = 14 # the σ labels above the plot area: name over the % position, 2 lines
labelGap = 18 # px between the labels and the plot area
labelsTop = labelGap + 2 * labelRowPx + 10 # + room between the labels and the box edge

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
    fit = if profile? then bellFit(profile.values, dir) else null
    marks = if fit? then sigmaMarks(fit, dir) else []
    updateLegend(fit, marks, dir)
    return unless profile?
    { edges, losses, wins, values } = profile

    toP = (f) -> 100 * f
    w = toP(edges[1] - edges[0])
    xs = (toP(e) + w / 2 for e in edges[...-1])
    totals = (l + wins[i] for l, i in losses)
    splits = edges.map(toP)
    # the fitted curve in counts at an x in % - same scale as the bars
    bellAt = (x) -> bellCount(fit, values.length, edges[1] - edges[0], x / 100)
    bellPeak = if fit? then bellAt(toP(fit.center)) else 0
    zeroIdx = Math.round(-edges[0] / (edges[1] - edges[0]))
    # every k-th edge, counted from 0 so the 0% edge always has its label
    k = Math.ceil(minLabelPx / (chanceriskprofile.clientWidth / losses.length))
    label = (v, i) -> if (i - zeroIdx) % k == 0 then pct(v) else ""

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
        padding: [(if fit? then labelsTop else zeroLineTop), null, null, null] # room for the σ labels / the 0% line above the tallest bar
        cursor: { show: false }
        scales: {
            x: { time: false, range: -> [splits[0], splits[splits.length - 1]] }
            y: { range: (u, min, max) -> [0, Math.max(max, bellPeak)] }
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
    options.hooks.draw.push(((u) -> drawSigmaLines(u, marks)), ((u) -> drawBell(u, bellAt))) if fit?
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

pct = (x) -> +x.toFixed(2) + "%"
signedPct = (x) -> (if x > 0 then "+" else "") + pct(x) # σ positions always carry a sign
# shortcut: values in [99.95%, 100%) still show 100%, as asked
share = (s) -> if s < 0.9995 then Math.min(Math.round(100 * s), 99) else Math.round(100 * s) # no 100% with values beyond the line

# the separation lines: center and ±1/2/3σ, red towards the loss (left for longs, right for shorts), "−" always left as in the bell curve
# -> [{ x (in %), color, name, side (-1 loss, 1 profit, 0 center), k }]
sigmaMarks = (fit, dir) ->
    marks = [{ x: 100 * fit.center, color: centerColor, name: "Mittelwert", side: 0, k: 0 }]
    for k in [1..3]
        sigma = (if k > 1 then k else "") + "σ"
        for [side, colors] in [[-1, lossColors], [1, profitColors]]
            x = 100 * (fit.center + side * dir * k * fit.sigma)
            sign = if side * dir < 0 then "−" else "+"
            marks.push({ x, color: colors[k - 1], name: sign + sigma, side, k })
    return marks

# dashed verticals from below their label down to the x axis; lines outside the x range are skipped
drawSigmaLines = (u, marks) ->
    { ctx, bbox } = u
    r = uPlot.pxRatio
    ctx.save()
    ctx.font = "#{labelFontPx * r}px Arial, Helvetica, sans-serif"
    ctx.textAlign = "center"
    ctx.textBaseline = "bottom"
    ctx.lineWidth = r
    ctx.setLineDash([6 * r, 4 * r])
    textBottom = bbox.top - labelGap * r
    # narrow charts: < 500px no %, < 450px "M", < 250px the name rows alternate (center, ±2σ on top; ±σ, ±3σ below)
    w = u.width
    for { x, color, name, k } in marks when u.scales.x.min <= x <= u.scales.x.max
        px = Math.round(u.valToPos(x, "x", true)) + 0.5
        ctx.fillStyle = color
        name = "M" if k == 0 and w < 450
        texts = if w < 500 then [name] else [(if k then signedPct(x) else pct(x)), name]
        row = if w < 250 then (k + 1) % 2 else 0
        for text, i in texts # bottom up
            half = ctx.measureText(text).width / 2
            ctx.fillText(text, Math.min(Math.max(px, half), ctx.canvas.width - half), textBottom - (row + i) * labelRowPx * r) # kept inside the canvas
        ctx.strokeStyle = color
        ctx.beginPath()
        ctx.moveTo(px, bbox.top)
        ctx.lineTo(px, bbox.top + bbox.height)
        ctx.stroke()
    ctx.restore()
    return

# the actual shares per side: "−σ: Zwischen −1.05% und 0.12% liegen 61%", the loss box on the loss side
# implicit-dom-connect: the ids below are only used in a list
# chanceriskprofileLossLegend.
# chanceriskprofileProfitLegend.
updateLegend = (fit, marks, dir) ->
    chanceriskprofileLegend.hidden = not fit?
    chanceriskprofileLegend.classList.toggle("short", dir < 0)
    return unless fit?
    center = pct(marks[0].x)
    for [side, el, shares] in [[-1, chanceriskprofileLossLegend, fit.loss], [1, chanceriskprofileProfitLegend, fit.profit]]
        lines = ("<p><b style=\"color: #{m.color}\">#{m.name}:</b> Zwischen <b style=\"color: #{m.color}\">#{signedPct(m.x)}</b> und <b>#{center}</b> liegen <b>#{share(shares[m.k - 1])}%</b></p>" for m in marks when m.side == side)
        el.innerHTML = lines.join("")
    return

# the fitted bell curve over the bars, one point per device pixel
drawBell = (u, bellAt) ->
    { ctx, bbox } = u
    ctx.save()
    ctx.beginPath()
    ctx.rect(bbox.left, bbox.top, bbox.width, bbox.height)
    ctx.clip()
    ctx.strokeStyle = bellColor
    ctx.lineWidth = 1.5 * uPlot.pxRatio
    ctx.lineJoin = "round"
    ctx.beginPath()
    for px in [0..bbox.width]
        x = u.posToVal(px / uPlot.pxRatio, "x")
        ctx.lineTo(bbox.left + px, u.valToPos(bellAt(x), "y", true))
    ctx.stroke()
    ctx.restore()
    return
