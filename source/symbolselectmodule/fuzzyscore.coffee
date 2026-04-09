############################################################
#region Fuzzy Scoring Algorithms
## Switch between implementations for benchmarking
# USE_DP_SCORING = true

############################################################
export fuzzyScore = (query, text) ->
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