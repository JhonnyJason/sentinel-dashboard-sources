############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("fouriermodule")
#endregion

############################################################
import *  as fft from "fft.js"

############################################################
sampleZero = new Array(356*30)
sampleZero.fill(0)

sampleOne = new Array(356*30)
sampleOne.fill(0)
sampleOne[i] = 1 for el,i in sampleOne by 2 

audioCtx = null

############################################################
# fftSize = 256
fftSize = 512
fftK = null
fftOutput = null


############################################################
export initialize = (c) ->
    log "initialize"
    # sampleRate = 192000 # 384_000 
    # audioCtx = new AudioContext({sampleRate})
    
    # fftK = new fft(fftSize)
    # fftOutput = fftK.createComplexArray()

    # log "sampleRate: "+audioCtx.sampleRate
    # log "fftSize: "+fftSize

    # setTimeout(runComparision, 2000)
    return


############################################################
runComparision = ->
    log "runComparision"
    result = await fftJSRun(sampleZero)
    console.log(result)
    result = await fftJSRun(sampleOne)
    console.log(result)
    # await fftAudio()
    return

fftAudioRun = (sample) ->
    log "fftAudioRun"
    log "sampleRate: "+audioCtx.sampleRate
    log "fftSize: "+fftSize

    start = performance.now()
    sourceBuf = audioCtx.createBufferSource()
    audioBuf = audioCtx.createBuffer(1, sample.length, audioCtx.sampleRate)

    timeMS = performance.now() - start
    log "fftAudio took #{timeMS}ms"
    return

fftJSRun = (sample) ->
    log "fftJSRun"
    log "fftSize: "+fftSize

    fourierExtract = new Array(fftSize * 2)
    start = performance.now()

    fftK.realTransform(fftOutput, sample)
    for i in [183...fftSize] # cut off the higher frequencies
        fftOutput[i] = 0
        fftOutput[fftSize + i] = 0
    fftK.inverseTransform(fourierExtract, fftOutput)

    timeMS = performance.now() - start
    log "fftJS took #{timeMS}ms"
    return fourierExtract