//##########################################################
const maxTypos = 3
const maxFrontPunishment = 0.3
const maxEndPunishment = 0.9
const maxGapPunishment = 0.5

//##########################################################
export function fuzzyScore(query, text) {
    if(text.length > 32) {text = text.slice(0, 32) }
    if(query.length > 32) { query = query.slice(0, 32) }
    const matchPattern = subsequenceMatchPattern(query, text)
    const result = matchPatternToScore(matchPattern,  query.length)
    // if(result > 95) {console.log(""+query+" on "+text+" = "+result)}
    return result
}

//##########################################################
/*
    Output for the subsequenceMatchPattern would look like this

    [0, 3, 2 ] // when seq = "amd" and text = "amden"
    [0, 3, 1, 1, 0] // seq = "amdn" and text = "amden"
    [5] // seq = "qoqo" and text = "amden"

    Basicallly odd indices like the [1,3,5,7,...] represent the length of a continously matching sequence.
    While the indices [0,2,4,6, ...] represent the gaps in between.

*/
//##########################################################
export function subsequenceMatchPattern(seq, text) {
    const S = seq.length, T = text.length;
    const dp = createMatchingTable(seq, text)

    // --- 2. Traceback to find matched text indices ---
    // Walk back from dp[S][T] to recover which text positions were matched.
    const matchedTextIndices = [];
    let i = S, j = T;

    while (i > 0 && j > 0) {
    if (seq[i - 1] === text[j - 1] && dp[i][j] === dp[i - 1][j - 1] + 1) {
        matchedTextIndices.push(j - 1); // text index (0-based)
        i--; j--;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
    } else {
        j--;
    }
    }

    matchedTextIndices.reverse(); // now in ascending order

    // --- 3. Encode as [gap, run, gap, run, ..., trailing_gap] ---
    // If no match found, return a single gap covering the full text.
    if (matchedTextIndices.length === 0) { return [T] }

    const result = [];
    let textCursor = 0;

    for (let k = 0; k < matchedTextIndices.length; ) {
    // Gap: distance from textCursor to the start of this run
    const runStart = matchedTextIndices[k];
    result.push(runStart - textCursor);
    textCursor = runStart;

    // Run: count how many consecutive text positions are matched
    let runLen = 0;
    while (
        k < matchedTextIndices.length &&
        matchedTextIndices[k] === textCursor
    ) {
        runLen++;
        textCursor++;
        k++;
    }
        result.push(runLen);
    }

    // Trailing gap: remaining text after last matched position
    result.push(T - textCursor);

    return result
}

//##########################################################
function createMatchingTable(query, text) {
    const S = query.length, T = text.length;

    // --- Build DP table ---
    // dp[i][j] = length of longest subsequence of seq[0..i-1] found in text[0..j-1]
    const tbl = Array.from({ length: S + 1 }, () => new Array(T + 1).fill(0));

    for (let i = 1; i <= S; i++) {
        for (let j = 1; j <= T; j++) {
            if (query[i - 1] === text[j - 1]) {
                tbl[i][j] = tbl[i - 1][j - 1] + 1;
            } else {
                tbl[i][j] = Math.max(tbl[i - 1][j], tbl[i][j - 1]);
            }
        }
    }

  return tbl
}

//##########################################################
function matchPatternToScore(pattern, fullLen) {
    if (pattern.length == 1) { return 0 } // nothing matched at all
    if (pattern.length == 2) { 
        console.log("We should take care to fill the last gap even if it is 0!")
        console.log(pattern)
        pattern.push(0) 
    } 

    if((pattern.length % 2) != 1) { throw new Error("MatchPattern must have odd nr of elements!") }

    const maxLength = 3 + (2 * maxTypos)
    if(pattern.length > maxLength){ return  0 } // we have too many gaps

    var matchLength = 0
    for(var i = 1; i < pattern.length; i += 2) { matchLength += pattern[i] }
    if ((matchLength + maxTypos) < fullLen) { return 0 } // we have too many missing characters

    // Base score depending on how much of our query string is a match
    var score = 100.0 * (matchLength / fullLen)

    // Add front Punishment factor
    var pF = Math.max((1.0 / (1.0 + pattern[0])), maxFrontPunishment)
    score *= pF

    // Add end Punishment factor
    pF = Math.max((1.0 / (1.0 + (0.01 * pattern[pattern.length - 1]))), maxEndPunishment)
    score *= pF

    //Add punishment Factors for gaps
    pF = 1.0
    for(var i = 2; i < pattern.length - 1; i += 2) {
        var gap = pattern[i] 
        pF = Math.max((pF / (1.0 + (i * 0.02 * gap))), maxGapPunishment)
    }
    score *= pF

    return score
}