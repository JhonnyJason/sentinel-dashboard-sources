############################################################
export class TopRankedList
    constructor: (@sizeLimit) ->
        @bottom = null
        @size = 0

    addElement: (el, rank) =>
        # we are the first element
        if !@bottom? then return @addFirstElement(el, rank)

        # we rank lower than the bottom
        if @bottom.rank > rank then return @appendElement(el, rank)

        ## Okay we have a higher rank than the bottom :-)
        prev = @bottom
        competitor = @bottom.next
        while competitor?
            ## we found our superior
            if competitor.rank > rank then return @insertElement(el, rank, prev, competitor)
            
            ## we ranked higher so checking next iteration
            prev = competitor
            competitor = competitor.next

        ## we run all the way through all the competitors
        ## we arrived at the top and we have higher rank than any
        newEl = { el, rank, next: null }
        prev.next = newEl
 
        if @size == @sizeLimit then @cutOffBottom()
        else @size++       
        return

    cutOffBottom: ->
        oldBottom = @bottom
        @bottom = @bottom.next
        oldBottom.next = null
        oldBottom.el = null
        return

    addFirstElement: (el, rank) =>
        @bottom = { el, rank, next: null }
        @size = 1
        return

    appendElement: (el, rank) =>
        # nothing to append if List is full
        if @size == @sizeLimit then return
        newEl = { el, rank, next: @bottom }
        @bottom = newEl
        @size++
        return

    insertElement: (el, rank, prev, next) =>
        newEl = {el, rank, next}
        prev.next = newEl
        if @size == @sizeLimit then @cutOffBottom()
        else @size++
        return

    compileToArray: =>
        return [] unless @size > 0
        result = new Array(@size)
        tmp = @bottom

        i = @size
        while i--
            result[i] = tmp.el
            tmp = tmp.next

        return result
