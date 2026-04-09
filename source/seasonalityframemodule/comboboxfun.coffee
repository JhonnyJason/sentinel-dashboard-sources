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
        @blurTimeoutId = null

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
        if @blurTimeoutId
            clearTimeout(@blurTimeoutId)
            @blurTimeoutId = null
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
        @blurTimeoutId = setTimeout((=> @hideDropdown()), 150)
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
        @inputEl.value = "#{opt.symbol} #{opt.name}"
        @hideDropdown()
        @selectionCallback?(opt.symbol)
        return
    #endregion

