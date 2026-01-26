############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("comboboxfun")
#endregion

############################################################
import * as options from "./symboloptions.js"

############################################################
export class Combobox
    constructor: ({ inputEl, dropdownEl, optionsLimit, minSearchLength }) ->
        log "Combobox constructor"
        @inputEl = inputEl
        @dropdownEl = dropdownEl
        @optionsLimit = optionsLimit ? 30
        @minSearchLength = minSearchLength ? 3

        @fullOptions = []
        @currentOptions = []
        @dropdownVisible = false
        @highlightedIndex = -1
        @selectionCallback = null

        @inputEl.addEventListener("focus", @onFocus)
        @inputEl.addEventListener("input", @onInput)
        @inputEl.addEventListener("keydown", @onKeydown)
        @inputEl.addEventListener("blur", @onBlur)
        @dropdownEl.addEventListener("mousedown", @onDropdownMousedown)
        @setDefaultOptions()
        # query = "asdfggee"
        # text1 = "Joaching Grössl"
        # text2 = "Dascheizzdiewandan!"
        # text3 = "asdfggeeh!"
        # score1 = fuzzyScore3Ways(query, text1)
        # score2 = fuzzyScore3Ways(query, text2)
        # score3 = fuzzyScore3Ways(query, text3)
        # log "#{query} : #{text1} => #{score1}"
        # log "#{query} : #{text2} => #{score2}"
        # log "#{query} : #{text3} => #{score3}"
        
        # if score1 > score2 then log "score1 is bigger than score2"
        # else log "score2 is bigger than score1"

        # throw new Error("Death on Purpose!")

    ############################################################
    #region Public Methods
    onSelect: (callback) ->
        @selectionCallback = callback
        return

    setDefaultOptions: ->
        log "setDefaultOptions"
        @fullOptions = options.defaultTop100
        @updateCurrentOptions()
        return

    provideSearchOptions: (opts) ->
        log "provideSearchOptions"
        log opts.length
        @fullOptions = opts
        @updateCurrentOptions()
        @renderDropdown()
        return
    #endregion

    ############################################################
    #region Event Handlers
    onFocus: =>
        log "onFocus"
        @updateCurrentOptions()
        @showDropdown()
        return

    onInput: =>
        log "onInput"
        query = @inputEl.value.trim()

        ## Reset to defaults if query too short
        if query.length < @minSearchLength
            log "setting default options..."
            @setDefaultOptions()
        else
            log "requesting options from remote!"
            ## Trigger server search (request slightly more than we display)
            options.dynamicSearch(query, @optionsLimit + 20, this)

        @updateCurrentOptions()
        @highlightedIndex = if @currentOptions.length > 0 then 0 else -1
        @renderDropdown()
        return

    onKeydown: (e) =>
        return unless @dropdownVisible

        switch e.key
            when "ArrowDown"
                e.preventDefault()
                if @highlightedIndex < @currentOptions.length - 1
                    @highlightedIndex++
                    @renderDropdown()
                    @scrollToHighlighted()
            when "ArrowUp"
                e.preventDefault()
                if @highlightedIndex > 0
                    @highlightedIndex--
                    @renderDropdown()
                    @scrollToHighlighted()
            when "Enter"
                e.preventDefault()
                if @highlightedIndex >= 0 and @currentOptions[@highlightedIndex]
                    @selectOption(@currentOptions[@highlightedIndex])
            when "Escape"
                e.preventDefault()
                @hideDropdown()
                @inputEl.blur()
        return

    onBlur: =>
        log "onBlur"
        setTimeout((=> @hideDropdown()), 150)
        return

    onDropdownMousedown: (e) =>
        e.preventDefault()
        return
    #endregion

    ############################################################
    #region Internal Methods
    updateCurrentOptions: ->
        query = @inputEl.value.trim()

        if query.length == 0
            @currentOptions = @fullOptions.slice(0, @optionsLimit)
        else
            @currentOptions = @filterAndRank(query)
        return

    filterAndRank: (query) ->
        log "filterAndRank"
        log "fullOptionsLength is: "+@fullOptions.length
        query = query.toLowerCase()
        scored = []
        for opt in @fullOptions
            symbolScore = fuzzyScore(query, opt.symbol.toLowerCase())
            nameScore = fuzzyScore(query, opt.name.toLowerCase())
            if symbolScore > nameScore then score = symbolScore
            else score  = nameScore
            # score = symbolScore + nameScore
            # log "'#{query}' vs. '#{opt.symbol} #{opt.name}' => #{score}"
            scored.push({ opt, score })

        scored.sort((a, b) -> b.score - a.score)
        return scored.slice(0, @optionsLimit).map((s) -> s.opt)

    showDropdown: ->
        return if @dropdownVisible
        @dropdownVisible = true
        @highlightedIndex = if @currentOptions.length > 0 then 0 else -1
        @renderDropdown()
        @dropdownEl.classList.add("visible")
        return

    hideDropdown: ->
        return unless @dropdownVisible
        @dropdownVisible = false
        @highlightedIndex = -1
        @dropdownEl.classList.remove("visible")
        return

    renderDropdown: ->
        html = ""
        for opt, i in @currentOptions
            highlightClass = if i == @highlightedIndex then " highlighted" else ""
            html += """<div class="combobox-option#{highlightClass}" data-index="#{i}" data-symbol="#{opt.symbol}">
                <span class="option-symbol">#{opt.symbol}</span>
                <span class="option-name">#{opt.name}</span>
            </div>"""

        if @currentOptions.length == 0
            html = '<div class="combobox-empty">Keine Ergebnisse</div>'

        @dropdownEl.innerHTML = html

        for optEl in @dropdownEl.querySelectorAll(".combobox-option")
            optEl.addEventListener("click", @onOptionClick)
        return

    scrollToHighlighted: ->
        highlighted = @dropdownEl.querySelector(".highlighted")
        return unless highlighted
        highlighted.scrollIntoView({ block: "nearest" })
        return

    onOptionClick: (e) =>
        index = parseInt(e.currentTarget.dataset.index)
        if @currentOptions[index]
            @selectOption(@currentOptions[index])
        return

    selectOption: (opt) ->
        log "selectOption"
        olog opt
        @inputEl.value = "#{opt.symbol} - #{opt.name}"
        @hideDropdown()
        @selectionCallback?(opt.symbol)
        return
    #endregion


############################################################
#region Fuzzy Scoring Algorithms
## Switch between implementations for benchmarking
USE_DP_SCORING = true

############################################################
fuzzyScore = (query, text) ->
    return fuzzyScore3Ways(query, text)
    # if USE_DP_SCORING then fuzzyScoreDP(query, text)
    # else fuzzyScoreEfficient(query, text)

############################################################
## Efficient O(n) version - requires first/last char present
fuzzyScoreEfficient = (query, text) ->
    return 0 if query.length == 0

    rF = 2 # reward factor
    bpF = 0.1 # big punishment factor
    spF = 0.95 # slight punishment factor

    # Find first and last query char positions in text
    first = text.indexOf(query[0])
    last = text.lastIndexOf(query[query.length - 1])

    return 0 if first == -1 or last == -1 or last < first

    # Scoring
    score = 1
    score *= Math.pow(bpF, first)                         # chars before first (big punishment)
    score *= Math.pow(spF, (text.length - 1 - last))      # chars after last (slight punishment)

    # Check middle chars fit in order
    qi = 1
    for i in [first + 1...last]
        if qi < query.length - 1 and text[i] == query[qi]
            qi++
            score *= rF                         # reward fit
        else
            score *= bpF                         # punish gap

    return score

############################################################
## DP-style O(n*m) version - more robust, finds any subsequence
fuzzyScoreDP = (query, text) ->
    return 0 if query.length == 0

    ## rewarded on match punished on mismatch DP-Style to find any subsequence
    rF = 2       # reward factor
    pF = 0.72    # punishment factor

    tbl = new Array(query.length + 2)
    for i in [0...tbl.length]
        tbl[i] = Array(text.length + 2).fill(0)

    for i in [0..query.length]
        for j in [0..text.length]
            # log "iteration: (i:#{i},j:#{j})"
            if i == 0 or j == 0 or (i == 1 and j == 1) 
                tbl[i][j] = 1
                continue

            if i <= 1 or j <= 1
                tbl[i][j] = 1
                continue

            if query[i - 1] == text[j - 1]  # Match
                # log "match!"
                tbl[i][j] = tbl[i - 1][j - 1] * rF
                continue

            # Mismatch -> Higher score of the previous matches * punishment Factor
            if tbl[i - 1][j] > tbl[i][j - 1] then tbl[i][j] = tbl[i - 1][j] * pF
            else tbl[i][j] = tbl[i][j - 1] * pF
    olog tbl
    return tbl[query.length][text.length]

#endregion


fuzzyScore3Ways = (query, text) ->
    return 0 if query.length == 0
    bbpF = 0.1
    bpF = 0.2
    rF = 2
    scr = 1

    chunks = []
    n = 0
    while n < query.length
        chunks.push(query.slice(n, n+3))
        n += 3

    start = 0
    score = 1
    for chunk in chunks when chunk.length == 3
        var0 = chunk
        s0 = scoreForChunk(var0, text, start)
        # if the full chunk has a higher score than the incmpletes may get we take the full one
        if s0[0] >= Math.pow(2,var0.length - 1) * 0.2
            start = s0[1]
            score *= s0[0]
            # log "full chunk right in place!"
            continue

        var1 = chunk[0]+chunk[1]
        s1 = scoreForChunk(var1, text, start)
        # if chunk has its maximum score we immediately take it
        if s1[0] == Math.pow(2, var1.length)
            start = s1[1]
            score *= s1[0] * 0.2
            # log "variant 1 right in place!"
            # log s1
            # log ""
            continue
        s1[0] *= 0.2 # penalty for not being the full chunk

        var2 = chunk[0]+chunk[2]
        s2 = scoreForChunk(var2, text, start)
        # if chunk has its maximum score we immediately take it
        if s2[0] == Math.pow(2, var2.length)
            start = s2[1]
            score *= s2[0] * 0.2
            # log "variant 2 right in place!"
            # log s2
            # log ""
            continue
        s2[0] *= 0.2 # penalty for not being the full chunk

        var3 = chunk[1]+chunk[2]
        s3 = scoreForChunk(var3, text, start)
        # if chunk has its maximum score we immediately take it
        if s3[0] == Math.pow(2, var3.length)
            start = s3[1]
            score *= s3[0] * 0.2
            # log "variant 3 right in place!"
            # log s3
            # log ""
            continue
        s3[0] *= 0.2 # penalty for not being the full chunk

        ## We need to figure out who is max
        if s0[0] > s1[0] then r0 = s0
        else r0 = s1

        if s2[0] > s3[0] then r1 = s2
        else r1 = s3

        if r0[0] > r1[0] then w = r0
        else w = r1
        start = w[1]
        score *= w[0]

        # log "selection winner taken!"
        # log w
        # log ""
        
    if chunks[chunks.length - 1].length == 1
        s0 = scoreForChunk(chunks[chunks.length - 1], text, start)
        score *= s0[0]

    if chunks[chunks.length - 1].length == 2
        # var0 = chunks[chunks.length - 1]
        s0 = scoreForChunk(chunks[chunks.length - 1], text, start)
        score *= s0[0]

    return score

scoreForChunk = (c, text, start) ->
    i = start # start for this search = end of last search
    a = 0 # distance from last end
    ci = 0 # index within chunk
    mt = new Array(c.length) 
    loop
        if c[ci] == text[i] # we have a matching character
            if ci == 0 then mt[0] = a # track distance from last end
            else mt[ci] = i # otherwise track the end of our found sequence
            ci++
            if ci == c.length
                return [Math.pow(0.1, mt[0])*Math.pow(2, ci), mt[ci - 1]]
        else ci = 0

        i++
        a++ 
        if i == text.length # we found nothing
            return [Math.pow(0.1, c.length), start] # full penalty over whole chunk last search end stays