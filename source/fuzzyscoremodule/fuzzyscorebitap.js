//###########################################################
//region Extracted Bitap Algorithm from Fuse.js
// Simplified for single-query, single-text scoring
//###########################################################

const MAX_BITS = 32;

/**
 * Creates a pattern alphabet mask for bitwise operations.
 * Each character in the pattern gets a bitmask where bits are set
 * at positions where the character appears in the pattern.
 */
function createPatternAlphabet(pattern) {
  const mask = {};
  for (let i = 0, len = pattern.length; i < len; i++) {
    const char = pattern.charAt(i);
    mask[char] = (mask[char] || 0) | (1 << (len - i - 1));
  }
  return mask;
}

/**
 * Bitap (Shift-Or/Shift-And) search algorithm with Levenshtein distance.
 * Returns a score between 0 and 1, where 0 is perfect match, 1 is no match.
 *
 * Based on Fuse.js implementation, simplified for single text pattern matching.
 *
 * @param {string} text - The text to search in
 * @param {string} pattern - The query pattern
 * @param {Object} options - Search options
 * @param {number} options.threshold - Max threshold (0-1), higher = more permissive
 * @param {number} options.distance - How far from expected location to search
 * @param {number} options.location - Expected location of match (default: 0)
 * @returns {number} Score from 0 (perfect) to 1 (no match)
 */
function bitapScore(text, pattern, {
  threshold = 0.6,
  distance = 100,
  location = 0
} = {}) {
  if (pattern.length > MAX_BITS) {
    // we only deal with smaller patterns and cut off larger ones...
    pattern = pattern.slice(0, MAX_BITS)
  }

  if (pattern.length === 0) {
    return 1; // No match for empty pattern
  }

  const patternLen = pattern.length;
  const textLen = text.length;
  const expectedLocation = Math.max(0, Math.min(location, textLen));
  let currentThreshold = threshold;
  let bestLocation = expectedLocation;

  // Score calculation: combines accuracy (errors/length) and proximity (distance from expected)
  const calcScore = (errors, currentLoc) => {
    const accuracy = errors / patternLen;
    const proximity = Math.abs(expectedLocation - currentLoc);
    if (!distance) return proximity ? 1.0 : accuracy;
    return accuracy + proximity / distance;
  };

  // Quick exact match check
  let index = text.indexOf(pattern, bestLocation);
  while (index > -1) {
    const score = calcScore(0, index);
    currentThreshold = Math.min(score, currentThreshold);
    bestLocation = index + patternLen;
    index = text.indexOf(pattern, bestLocation);
  }

  // Reset for fuzzy search
  bestLocation = -1;
  let finalScore = 1;
  let binMax = patternLen + textLen;
  const mask = 1 << (patternLen - 1);
  const patternAlphabet = createPatternAlphabet(pattern);

  let lastBitArr = [];

  // Iterate through allowed errors (0 to patternLen-1)
  for (let i = 0; i < patternLen; i++) {
    let binMin = 0;
    let binMid = binMax;

    // Binary search for the maximum distance at this error level
    while (binMin < binMid) {
      const score = calcScore(i, expectedLocation + binMid);
      if (score <= currentThreshold) {
        binMin = binMid;
      } else {
        binMax = binMid;
      }
      binMid = Math.floor((binMax - binMin) / 2 + binMin);
    }

    binMax = binMid;
    let start = Math.max(1, expectedLocation - binMid + 1);
    let finish = Math.min(expectedLocation + binMid, textLen) + patternLen;

    const bitArr = new Array(finish + 2);
    bitArr[finish + 1] = (1 << i) - 1;

    // Scan backwards through text
    for (let j = finish; j >= start; j--) {
      const currentLocation = j - 1;
      const charMatch = patternAlphabet[text[currentLocation]] || 0;

      // First pass: exact match using shift-and
      bitArr[j] = ((bitArr[j + 1] << 1) | 1) & charMatch;

      // Subsequent passes: allow errors (insertion, deletion, substitution)
      if (i) {
        bitArr[j] |=
          ((lastBitArr[j + 1] | lastBitArr[j]) << 1) | 1 | lastBitArr[j + 1];
      }

      // Check if we have a complete match
      if (bitArr[j] & mask) {
        finalScore = calcScore(i, currentLocation);

        if (finalScore <= currentThreshold) {
          currentThreshold = finalScore;
          bestLocation = currentLocation;

          // Early exit if we've passed the expected location
          if (bestLocation <= expectedLocation) {
            break;
          }
          start = Math.max(1, 2 * expectedLocation - bestLocation);
        }
      }
    }

    // No hope for better match at higher error levels
    if (calcScore(i + 1, expectedLocation) > currentThreshold) {
      break;
    }

    lastBitArr = bitArr;
  }

  return bestLocation >= 0 ? Math.max(0.001, finalScore) : 1;
}

//###########################################################
//region Fuzzy Scoring Algorithms
//###########################################################

/**
 * Main fuzzy scoring function - extracted from Fuse.js Bitap algorithm
 *
 * Returns a score where:
 * - 0 = no match
 * - Higher values = better match (inverted from Fuse's internal scoring)
 *
 * @param {string} query - The search query
 * @param {string} text - The text to search in
 * @returns {number} Score from 0 (no match) to ~1 (perfect match)
 */
export function fuzzyScore(query, text) {
  if (!query || !text) return 0;
  if (query.length === 0) return 0;
  if (text.length === 0) return 0;

  // Case insensitive by default
  const pattern = query.toLowerCase();
  const target = text.toLowerCase();

  // Exact match = perfect score (with length check for overrun penalty)
  if (pattern === target) {
    return applyOverrunPenalty(1, query.length, text.length);
  }

  // Use Bitap algorithm
  const score = bitapScore(target, pattern, {
    threshold: 1.0,  // Allow all matches, we'll filter ourselves
    distance: 100,   // Search within 100 chars of expected location
    location: 0      // Prefer matches at the start
  });

  // Convert Fuse score (0=perfect, 1=no match) to our scoring (0=no match, 1=perfect)
  // Score is already clamped between 0.001 and 1 in bitapScore
  if (score >= 1) return 0;

  const baseScore = 1 - score;
  return applyOverrunPenalty(baseScore, query.length, text.length);
}

/**
 * Apply penalty when query is longer than text.
 * penaltyFactor = 1 / (1 + overrun / pattern_length)
 * final_score = original_score * penaltyFactor
 *
 * @param {number} score - Base score
 * @param {number} queryLen - Query length
 * @param {number} textLen - Text length
 * @returns {number} Adjusted score
 */
function applyOverrunPenalty(score, queryLen, textLen) {
  if (queryLen <= textLen) return score;

  // overrun = how many extra chars in query vs text
  const overrun = queryLen - textLen;

  // penaltyFactor = 1 / (1 + overrun / pattern_length)
  const penaltyFactor = 1 / (1 + overrun / textLen);

  return score * penaltyFactor;
}

//endregion
