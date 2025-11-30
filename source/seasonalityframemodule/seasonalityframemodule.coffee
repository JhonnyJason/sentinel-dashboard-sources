############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("seasonalityframemodule")
#endregion

############################################################
import uPlot from "uplot"

############################################################
import * as mData from "./marketdatamodule.js"
import * as seasnlty from "./seasonality.js"
import * as utl from "./utilsmodule.js"


############################################################
currentSelectedStock = null
currentSelectedTimeframe = null
currentSelectedMethod = null

############################################################
seasonalityChart = document.getElementById("seasonality-chart")
chartHandle = null

############################################################
xAxisData = null
seasonalityData = null
latestData = null

############################################################
pickedStartIdx = null
pickedEndIdx = null


############################################################
## Maybe not used...
monthNames = {
    MMMM:["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    MMM:["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    MM: ["Ja", "Fe", "Mä", "Ap", "Ma", "Ju", "Ju", "Au", "Se", "Ok", "No", "De"]
    M: ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
}

############################################################
export initialize = (c) ->
    log "initialize"
    renderMS = c.uiRerenderMS || 5000
    # setInterval(drawChart, renderMS)
    stockSelect.addEventListener("change", stockSelected)
    timeframeSelect.addEventListener("change", timeframeSelected)
    methodSelect.addEventListener("change", methodSelected)
    
    currentSelectedStock = stockSelect.value
    currentSelectedTimeframe = timeframeSelect.value
    currentSelectedMethod = methodSelect.value
    return


############################################################
stockSelected = ->
    log "stockSelected"
    currentSelectedStock = stockSelect.value
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return

timeframeSelected = ->
    log "timeframeSelected"
    currentSelectedTimeframe = timeframeSelect.value
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return

methodSelected = ->
    log "methodSelected"
    currentSelectedMethod = methodSelect.value
    olog {
        currentSelectedStock,
        currentSelectedTimeframe,
        currentSelectedMethod
    }
    resetAndRender()
    return


############################################################
resetAndRender = ->
    log "resetAndRender"
    resetSeasonalityState()
    if currentSelectedStock then retrieveRelevantData() 
    drawChart()
    return

############################################################
retrieveRelevantData = ->
    log "retrieveRelevantData"
    symbol = currentSelectedStock
    years = parseInt(currentSelectedTimeframe)
    method = parseInt(currentSelectedMethod)
    
    seasonalityData = mData.getSeasonalityComposite(symbol, years, method)
    latestData = mData.getThisAndLastYearData(symbol)
    
    today = new Date()
    currentYear = today.getFullYear()
    lastYear = currentYear - 1
    currentYearIsLeap = seasnlty.isLeapYear(currentYear)
    lastYearIsLeap = seasnlty.isLeapYear(lastYear)

    if currentYearIsLeap then return orderDataAsCurrentYearIsLeap()
    if lastYearIsLeap then return orderDataAsLastYearIsLeap()
    orderDataWithoutFeb29()
    return

############################################################
orderDataWithoutFeb29 = ->
    log "orderDataWithoutFeb29"
    ## reorder seasonality composite
    compositeWithoutFeb29 = []
    for dp,i in seasonalityData when i != seasnlty.FEB29
        compositeWithoutFeb29.push(dp)

    ## We don't have a factor from the last Element to the first of next year
    ##   So we take it as 1:1
    factors = seasnlty.toFactorsArray(compositeWithoutFeb29)
    frontData = seasnlty.dataArrayFromFactors(factors, compositeWithoutFeb29[0], false)
    log "Array Lengths:"
    log frontData.length
    log compositeWithoutFeb29.length
    
    seasonalityData = [...frontData, ...compositeWithoutFeb29]
    log seasonalityData.length

    ##Time Axis... TODO

    return

orderDataAsLastYearIsLeap = ->
    log "orderDataAsLastYearIsLeap"
    ## reorder seasonality composite
    olog seasonalityData
    compositeWithoutFeb29 = []
    for dp,i in seasonalityData when (i != seasnlty.FEB29)
        compositeWithoutFeb29.push(dp)
    # olog compositeWithoutFeb29
    
    ## We don't have a factor from the last Element to the first of next year
    ##   So we take it as 1:1
    factors = seasnlty.toFactorsArray(seasonalityData)
    # olog factors
    frontData = seasnlty.dataArrayFromFactors(factors, seasonalityData[0], false)
    # olog frontData
    # log "Array Lengths:"
    # log seasonalityData.length
    # log frontData.length
    # log compositeWithoutFeb29.length
    
    seasonalityData = [...frontData, ...compositeWithoutFeb29]
    # log seasonalityData.length

    ## reorder latestData
    thisYearsData = latestData[0]
    lastYearsData = latestData[1]
    factors = seasnlty.toFactorsArray(lastYearsData)
    lastYearsData = seasnlty.dataArrayFromFactors(factors, thisYearsData[0], false)

    missingData = new Array(365 - thisYearsData.length)
    missingData.fill(null)

    latestData = [...lastYearsData, ...thisYearsData, ...missingData]
    # log latestData.length
    ## Create Time Axis
    jan1Latest = utl.getJan1Date()
    axisTime = jan1Latest.getTime() / 1000
    currentYearTimeAxis = []
    for i in [0...365]
        currentYearTimeAxis[i] = axisTime
        axisTime += 86_400 # = 60 * 60 * 24

    axisTime = jan1Latest.getTime() / 1000 - 86_400
    lastYearTimeAxis = new Array(366) ## is leap year
    i = 366
    while i--
        lastYearTimeAxis[i] = axisTime
        axisTime -= 86_400
    
    xAxisData = [...lastYearTimeAxis, ...currentYearTimeAxis]
    # log xAxisData.length
    return


############################################################
resetSeasonalityState = ->
    log "resetSeasonalityState"
    if chartHandle? then chartHandle.destroy()
    seasonalityChart.innerHTML = ""

    chartHandle = null

    xAxisData = null
    seasonalityData = null
    latestData = null

    pickedStartIdx = null
    pickedEndIdx = null

    return

############################################################
timestampToAxisName = (val) ->
    dateObj = new Date(val)
    date = date.getDate()
    month = monthNames.MMM[date.getMonth()]
    return month+" "+date


############################################################
onSetSelect = (u) ->
    log "onSetSelect"
    if u.select.width > 0
        log "Use Selection now!"
        startIndex = u.posToIdx(u.select.left);
        endIndex = u.posToIdx(u.select.left + u.select.width);

        log startIndex
        log endIndex
        ## TODO implement

    return false

############################################################
# xScaleKey = "x"
xAxisMouseDown = (evnt, u) ->
    y0 = evnt.clientY;
    x0 = evnt.clientX;
    
    # scaleKey = u.axes[i].scale
    scale = u.scales["x"]
    currentMin = scale.min
    currentMax = scale.max
    dim = u.bbox.width
    
    range = currentMax - currentMin
    unitsPerPx = range / (dim / uPlot.pxRatio)

    mousemove = (e) ->
        d = x0 - e.clientX
        shiftyBy = d * unitsPerPx;
        
        # if e.shiftKey then min = currentMin - shiftyBy 
        # else min =  currentMin + shiftyBy
        min = currentMin + shiftyBy
        max = currentMax + shiftyBy
        
        cancelSelect(u)
        u.setScale("x", { min, max })
        return

    mouseup = (e) ->
        document.removeEventListener('mousemove', mousemove)
        document.removeEventListener('mousemove', mouseup)

    document.addEventListener('mousemove', mousemove)
    document.addEventListener('mouseup', mouseup)

############################################################
oldMinScale = null
oldMaxScale = null

############################################################
cancelSelect = (u) ->
    log "cancelSelect"
    u.setSelect({width: 0, height: 0}, false)
    ## TODO clear other select
    return


############################################################
plotMouseDown = (evnt, u) ->
    log "plotMouseDown"
    evnt.stopPropagation()
    scaleOnMouseDown = u.scales["x"]
    oldMinScale = scaleOnMouseDown.min
    oldMaxScale = scaleOnMouseDown.max
    return false

plotClick = (evnt, u) ->
    log "plotClick"
    evnt.stopPropagation()
    return false


plotMouseUp = (evnt, u) ->
    log "plotMouseUp"
    evnt.stopPropagation()
    selectObj = u.select
    olog selectObj
    # u.select.show = false
    u.setSelect({width: u.select.width, height: u.select.height}, false)
    ## TODO remove selection
    return false

onInit = (u) -> 
    xAxisEl = u.root.getElementsByClassName('u-axis')[0]
    # xAxisEl = u.root.querySelectorAll('.u-axis')[0]
    xAxisEl.classList.add("movable")
    wrappedMouseDownListener = (evnt) -> xAxisMouseDown(evnt, u)
    xAxisEl.addEventListener("mousedown", wrappedMouseDownListener)
    
    # plotEl = u.root.getElementsByClassName('u-over')[0]
    # wrappedMouseDownListener = (evnt) -> plotMouseDown(evnt, u)
    # plotEl.addEventListener("mousedown", wrappedMouseDownListener)
    # wrappedMouseUpListener = (evnt) -> plotMouseUp(evnt, u)
    # plotEl.addEventListener("mouseup", wrappedMouseUpListener)
    # wrappedClickListener = (evnt) -> plotClick(evnt, u)
    # plotEl.addEventListener("click", wrappedClickListener)

    # axisEls = u.root.querySelectorAll('.u-axis');
    return
    
############################################################
drawChart = ->
    log "drawChart"
    rect = seasonalityChart.getBoundingClientRect();
    width = Math.floor(rect.width)
    height = Math.floor(rect.height)
    
    jan1Latest = utl.getJan1Date()
    jan1Before = new Date(jan1Latest)
    jan1Before.setYear(jan1Latest.getFullYear() - 1)
    dec31Next = utl.getDec31Date()
    
    min = jan1Latest.getTime() / 1000
    max = dec31Next.getTime() / 1000
    rangeDif = max - min 

    absoluteMax = max
    absoluteMin = jan1Before.getTime() / 1000

    setXRange = (u, min, max) ->
        min = max - rangeDif
        dif = min - absoluteMin
        
        if dif < 0 # we are below absoluteMin
            min -= dif
            max -= dif

        dif = absoluteMax - max
        if dif < 0 # we are above absoluteMax
            min += dif
            max += dif

        return [min, max]


    options = {
        width: width - 15,
        # height: 500,
        height: height,
        padding: [30,15,15,15]
        scales: {
            x: { 
                time: true,
                # range: [min, max ]
                range: setXRange
            }
        },
        series: [
            {},
            {
                # show: true,
                label: "Seasonality Composite 10J",
                stroke: "#ffffff",
            },
            {
                # show: true,
                label: "Neuester Verlauf",
                stroke: "#faba01",
            },
        ],
        axes: [
            { 
                space: 50
                scale: "x"
                # space: 30
                stroke: "#ffffff"
                values: [ 
                    [3600 * 24 * 365, "{MMM}", null, null, null, null, null, null, 0 ],
                ]
                #v[0]:   minimum num secs in found axis split (tick incr)
                #v[1]:   default tick format
                #v[2-7]: rollover tick formats
                #v[8]:   mode: 0: replace [1] -> [2-7], 1: concat [1] + [2-7]

            },
            {
                show: true
                values: (u, vals, space) -> vals.map((v)-> v.toFixed(0) + '%'),
                # side: 0,
                space: 50
                gap: 10
                size: 65
                stroke: "#ffffff"
                grid: { 
                    show: true,
                    stroke: "#ffffff22"
                    width: 1,
                    dash: [5,10]
                },
                ticks: { show: false}
                # ticks:{
                #     # show: true,
                #     # stroke: "#fee",
                #     # width: 20,
                #     # dash: [],
                #     # size: 100,
                # }
            },
        ],
        hooks: { ## does not work as expected
            init: [onInit]
            setSelect: [onSetSelect]
        },
        cursor: {
            drag: {
                setScale: false,
                x: true,
                y: false,
            }
        }
    }

    # time = []
    # date0 = new Date("January 1, 2024 20:00:00")
    # # unix timestamps -> we need s instead of ms
    # date0TimeS = date0.getTime() / 1000
    # dayFactor = 85_400 # = 60 * 60 * 24
    # for day in [0...366]
    #     xDayTimeS = date0TimeS + day * dayFactor 
    #     time.push(xDayTimeS) 
    
    # cleanAvg = mData.getCleanAverage()
    # currentData = mData.getThisYearData()
    # for i in [currentData.length...366]
    #     currentData[i] = null

    # log "time.length: "+time.length
    # log "cleanAvg.length: "+cleanAvg.length
    # log "currentData.length: "+currentData.length

    data = []
    # olog xAxisData
    # olog seasonalityData
    # olog latestData

    data.push(xAxisData)
    data.push(seasonalityData)
    data.push(latestData)
    
    # data = [
    #     [ 1, 2, 3, 4, 5, 6, 7],
    #     [40,43,60,65,71,73,80]
    # ]

    chartHandle = new uPlot(options, data, seasonalityChart);

    return
