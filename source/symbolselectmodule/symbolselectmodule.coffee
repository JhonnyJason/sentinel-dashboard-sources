############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("symbolselectmodule")
#endregion

############################################################
import * as options from "./symboloptionsmodule.js"
import { fuzzyScore } from "./fuzzyscoremodule.js"
import { TopRankedList } from "./toprankedlist.js"

############################################################
maxBusyTimeMS = 5

############################################################
letMainThreadRun = ->
    if window.scheduler? and window.scheduler.yield? then return scheduler.yield()
    return new Promise((reslv) -> setTimeout(reslv, 0));

############################################################
## opts = { container, optionsLimit = 30, minSearchLength = 3 }
export class SymbolSelect
    constructor:(opts) ->
        @parentEl = opts.container
        throw new Error("No container defined!") unless @parentEl?
        @parentEl.classList.add("symbol-select-container")
        
        @inputEl = document.createElement("INPUT")
        @inputEl.setAttribute("type", "text")
        @inputEl.setAttribute("placeholder", "Symbol suchen...")
        @inputEl.setAttribute("autocomplete", "off")
        @parentEl.appendChild(@inputEl)
        
        @dropdownEl = document.createElement("DIV")
        @dropdownEl.classList.add("dropdown")
        @parentEl.appendChild(@dropdownEl)

        # @inputEl = opts.container.getElementsByClassName("")[0]
        # @dropdownEl = opts.container.getElementsByClassName("")[0]
        @minSearchLength = opts.minSearchLength ? 3        
        @optionsLimit = opts.optionsLimit ? 30
        
        # @defaultOptions = opts.defaultOptions ? []
        # @allOptions = opts.defaultOptions ? []
        # @shownOptions = @defaultOptions ? @allOptions.slice(0, @optionsLimit)

        # @fullOptions = [] ## full Options?
        @shownOptions = null # == currently shown Options?
        @latestSuccessfulQuery = null

        @query = ""
        @inQuery = false
        @restartQuery = false
        
        @dropdownVisible = false
        @highlightedIndex = -1
        @selectionCallback = null
        @blurTimeoutId = null

        @inputEl.addEventListener("focus", @onFocus)
        @inputEl.addEventListener("input", @onInput)
        @inputEl.addEventListener("keydown", @onKeydown)
        @inputEl.addEventListener("blur", @onBlur)
        @dropdownEl.addEventListener("mousedown", @onDropdownMousedown)
        @updateShownOptions()

    ########################################################
    #region Methods
    setOnSelectListener: (cb) => @selectionCallback = cb
    
    resetSearch: =>
        log "resetSearch"
        @inputEl.value = ""
        @hideDropdown()
        @updateShownOptions()
        @inputEl.blur()
        return

    freeze: =>
        log "freeze" 
        @parentEl.classList.add("frozen")
        return
    
    unfreeze: =>
        log "unfreeze"
        @parentEl.classList.remove("frozen")
        return

    destroy: =>
        @parentEl.innerHTML = ""
        @parentEl = null
        @inputEl = null        
        @dropdownEl = null
        
        # @fullOptions = null
        @shownOptions = null
        @latestSuccessfulQuery = null

        @query = ""
        @inQuery = false
        @restartQuery = false

        @dropdownVisible = false
        @highlightedIndex = -1
        @selectionCallback = null

        if @blurTimeoutId then clearTimeout(@blurTimeoutId)
        @blurTimeoutId = null

    ############################################################
    #region Event Handlers
    onFocus: =>
        log "onFocus"
        # if @blurTimeoutId
        #     clearTimeout(@blurTimeoutId)
        #     @blurTimeoutId = null
        @updateShownOptions()
        @showDropdown()
        return

    onInput: =>
        log "onInput"
        @updateShownOptions()
        @showDropdown()
        return

    onKeydown: (e) =>
        return unless @dropdownVisible

        switch e.key
            when "ArrowDown"
                e.preventDefault()
                if @highlightedIndex < @shownOptions.length - 1
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
                if @highlightedIndex >= 0 and @shownOptions[@highlightedIndex]
                    @selectOption(@shownOptions[@highlightedIndex])
            when "Escape"
                e.preventDefault()
                @hideDropdown()
                @inputEl.blur()
        return

    onBlur: =>
        log "onBlur"
        @blurTimeoutId = setTimeout((=> @hideDropdown()), 150)
        return

    onDropdownMousedown: (e) =>
        e.preventDefault()
        return
    #endregion

    ############################################################
    #region Internal Methods
    updateShownOptions: ->
        log "updateShownOptions"
        query = @inputEl.value.trim().toLowerCase()
        
        # if @latestSuccessfulQuery is our query as we know it
        #    this means the shownOptions are the result for this query
        #    then there is no need for any action
        if query == @query and query == @latestSuccessfulQuery then return
        
        #region update current search query
        # here is the only place where we would change the @query 
        if @isQuerying and query != @query
            @query = query
            @restartQuery = true
            return

        @query = query
        #endregion

        ## Reset to defaults if query too short
        if query.length == 0
            log "setting default options..."
            @isQuerying = false
            @restartQuery = false
            @shownOptions = options.defaultTop100.slice(0, @optionsLimit)
            @latestSuccessfulQuery = query        
        else
            log "searching through all symbols!"
            @executeAllSymbolsQuery()
        return

    executeAllSymbolsQuery: =>
        log "executeAllSymbolsQuery"
        # this function shall only ever run once per instance
        if @isQuerying then throw new Error("executeAllSymbolsQuery called multiple times!")
        
        @isQuerying = true
        allOptions = options.getAllSymbols()
        log "start checking through all #{allOptions.length} symbols.."
        loop
            start = performance.now()
            log "start outer Loop"
            @restartQuery = false
            rankedList = new TopRankedList(@optionsLimit)
            scored = []
            for opt,i in allOptions
                if typeof opt[0] != "string" or typeof opt[1] != "string"
                    log "@#{i} we reached #{opt} and die!"

                symbolScore = fuzzyScore(@query, opt[0].toLowerCase())
                nameScore = fuzzyScore(@query, opt[1].toLowerCase())
                if symbolScore > nameScore then score = symbolScore
                else score  = nameScore

                rankedList.addElement(opt, score)
                
                if (performance.now() - start) > maxBusyTimeMS
                    log "hit maxBusyTimeMS @#{i}"
                    await letMainThreadRun()
                    if @restartQuery 
                        log "We restart the loop"
                        break # restart the inner loop
                    start = performance.now()

            if i == allOptions.length # we reached the end!
                log "we reached the end of the outer loop @#{i}"
                @shownOptions = rankedList.compileToArray()
                @latestSuccessfulQuery = @query
                break # the outer loop

        @isQuerying = false
        log "We finished Querying!"
        if @dropdownVisible then @renderDropdown()
        return

    showDropdown: ->
        log "showDropdown"
        @renderDropdown()
        @dropdownVisible = true
        @highlightedIndex = if @shownOptions.length > 0 then 0 else -1
        @dropdownEl.classList.add("visible")
        return

    hideDropdown: ->
        @dropdownVisible = false
        @highlightedIndex = -1
        @dropdownEl.classList.remove("visible")
        return

    renderDropdown: ->
        log "renderDropdown"
        html = ""
        for opt, i in @shownOptions
            highlightClass = if i == @highlightedIndex then " highlighted" else ""
            html += """<div class="option#{highlightClass}" data-index="#{i}" data-symbol="#{opt[0]}">
                <span class="symbol">#{opt[0]}</span>
                <span class="name">#{opt[1]}</span>
            </div>"""

        if @shownOptions.length == 0
            html = '<div class="empty">Keine Ergebnisse</div>'

        @dropdownEl.innerHTML = html

        for optEl in @dropdownEl.querySelectorAll(".option")
            optEl.addEventListener("click", @onOptionClick)
        return

    scrollToHighlighted: ->
        highlighted = @dropdownEl.querySelector(".highlighted")
        return unless highlighted
        highlighted.scrollIntoView({ block: "nearest" })
        return

    onOptionClick: (e) =>
        index = parseInt(e.currentTarget.dataset.index)
        if @shownOptions[index]
            @selectOption(@shownOptions[index])
        return

    selectOption: (opt) ->
        log "selectOption"
        olog opt
        @inputEl.value = "#{opt[0]} #{opt[1]}"
        @hideDropdown()
        @selectionCallback(opt[0]) unless typeof @selectionCallback != "function"
        return
    #endregion


#endregion