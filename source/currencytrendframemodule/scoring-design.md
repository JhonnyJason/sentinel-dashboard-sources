# Forex Scoring Design

## Overview

Calculate a score for currency pairs (BASE/QUOTE) where:
- **Positive score** → Bullish on BASE currency (expect BASE to strengthen vs QUOTE)
- **Negative score** → Bearish on BASE currency (expect BASE to weaken vs QUOTE)

## Fundamental Assumption

**Time horizon**: This scoring model targets **medium to long-term** currency trends, not short-term reactions.

This matters because some indicators have opposite short-term vs long-term effects. Example:
- **Short-term**: High inflation → currency weakness (purchasing power erosion)
- **Long-term**: High inflation → central bank tightens policy → higher rates → capital inflows → currency strength

We model the **policy response chain**, not the immediate market reaction.

## Top-Level Formula

```
score = wI * inflationScore + wL * interestScore + wG * gdpScore + wC * cotScore
```

Where `wI`, `wL`, `wG`, `wC` are optimizable weights.

---

## Component Scores

### 1. Inflation Score

**Concept**: Inflation in a "sweet spot" signals likely monetary tightening → bullish.
- Too low: deflation risk, policy may ease → bearish
- Sweet spot: healthy pressure, tightening expected → bullish
- Too high: runaway inflation risk outweighs tightening → bearish

#### Step 1: Normalization (per area)

Each economic area has its own normalization function that maps raw inflation to a **normalized score in [0, 3]**.

**Three characteristic points** define the curve shape:
```
zeroLow → peak → zeroHigh
    0       3        0
```

**Parameters**:
- **2 free parameters**: `zeroLow`, `zeroHigh` (boundaries where score = 0)
- **1 derived value**: `peak = (zeroLow + zeroHigh) / 2` (symmetric midpoint)

**Function**:
```
quadratic(x) = a + bx + cx²

normalizeInflation(inflation) =
    normalized = quadratic(inflation)
    return clamp(normalized, 0, 3)                # enforce output bounds
```

The quadratic is a downward parabola with roots at `zeroLow` and `zeroHigh`, peaking at 3.
Outside `[zeroLow, zeroHigh]`, the parabola goes negative → clamped to 0.

**Output range**: Always **[0, 3]**. This ensures:
- No negative intermediate values
- Comparable across all economic areas
- Unified range for all normalization functions

**Visualization**:
```
Normalized
   3 |           ****
   2 |         **    **
   1 |       **        **
   0 +-----**------------**-----------→ Inflation %
          ↑       ↑        ↑
       zeroLow   peak   zeroHigh
```

#### Quadratic Coefficient Derivation

The quadratic passes through `(zeroLow, 0)` and `(zeroHigh, 0)` with peak at the midpoint.

**Factor form**:
```
f(x) = k × (x - zeroLow)(x - zeroHigh)

where k = -12 / (zeroHigh - zeroLow)²
```

The negative k creates a downward parabola. The factor 12 ensures `f(peak) = 3`.

**Expanded coefficients** `f(x) = a + bx + cx²`:
```
c = k
b = -k × (zeroLow + zeroHigh)
a = k × zeroLow × zeroHigh
```

**Properties**:
- Symmetric around `peak = (zeroLow + zeroHigh) / 2`
- Always goes to -∞ at extremes → clamped to 0
- No boundary condition constraints needed (parabola always well-behaved)

#### Per-Area Parameters (Free)

| Area | zeroLow | zeroHigh | peak (derived) | Rationale |
|------|---------|----------|----------------|-----------|
| EUR  | -2%     | 10%      | 4.0%           | Reference baseline |
| USD  | -2%     | 10%      | 4.0%           | Similar to EUR |
| JPY  | -3%     | 8%       | 2.5%           | Low inflation norm, more deflation tolerance |
| GBP  | -2%     | 10%      | 4.0%           | Similar to EUR |
| CAD  | -2%     | 10%      | 4.0%           | Developed economy |
| AUD  | -1%     | 11%      | 5.0%           | Commodity, tolerates higher |
| CHF  | -3%     | 8%       | 2.5%           | Low inflation norm, like JPY |
| NZD  | -1%     | 11%      | 5.0%           | Commodity, like AUD |

- `zeroLow`: Lower inflation where score = 0 (below → clamped to 0)
- `zeroHigh`: Upper inflation where score = 0 (above → clamped to 0)
- `peak`: Midpoint where score = 3 (derived, not free)

#### Derived Values (Coefficients)

| Area | a     | b     | c      |
|------|-------|-------|--------|
| EUR  | 1.667 | 0.667 | -0.083 |
| USD  | 1.667 | 0.667 | -0.083 |
| JPY  | 2.380 | 0.496 | -0.099 |
| GBP  | 1.667 | 0.667 | -0.083 |
| CAD  | 1.667 | 0.667 | -0.083 |
| AUD  | 0.917 | 0.833 | -0.083 |
| CHF  | 2.380 | 0.496 | -0.099 |
| NZD  | 0.917 | 0.833 | -0.083 |

**Fixed values** (same for all areas):
- `peakScore` = 3
- `floorScore` = 0

#### Step 2: Difference Curve

After normalization, we have two comparable values:
```
baseNorm ∈ [0, 3]
quoteNorm ∈ [0, 3]
diff = baseNorm - quoteNorm ∈ [-3, +3]
```

The difference curve combines these into the final inflation score:
```
inflationScore = inflationDiffCurve(diff)
```

**Curve shape**: Symmetric cubic that amplifies large differences.

```
inflationDiffCurve(diff) = b × diff + d × diff³
```

**Rationale**: Small inflation differences between economies are noise; large divergences
represent clear policy/economic gaps that warrant stronger signals. The cubic term
provides non-linear amplification while preserving symmetry.

**Parameters** (scaled for [-3, +3] input range):

| Param | Value | Description |
|-------|-------|-------------|
| b | 2.78 | Linear coefficient (baseline sensitivity) |
| d | 0.248 | Cubic coefficient (large-diff amplification) |

**Derivation**: Scaled from legacy formula to preserve output magnitudes with the
new [-3, +3] diff range (was [-6, +6]).

**Output at key points**:
```
f(±3)   = ±15.0   (max divergence)
f(±1.5) = ±5.0    (moderate divergence)
f(±0.5) = ±1.4    (small divergence, nearly linear)
f(0)    = 0       (identical normalized scores)
```

**Properties**:
- Symmetric: `f(-diff) = -f(diff)` ✓
- Through origin: `f(0) = 0` ✓
- Preserves sign of difference ✓
- Amplification ratio at extremes: ~1.8× vs linear

**Sign logic**:
- Base in sweet spot (3), quote at floor (0) → diff=+3 → +15 (bullish base) ✓
- Base at floor (0), quote in sweet spot (3) → diff=-3 → -15 (bearish base) ✓

---

### 2. Interest Rate Score

**Concept**: Higher interest rates attract capital → strengthens currency.

#### Step 1: Normalization (per area)

Each economic area has a linear normalization function on its instance:

```
normalizedMRR = a + b × mrr
```

**Parameters per area:**

| Area | a | b | (equiv. neutralRate) | Rationale |
|------|-----|-----|----------------------|-----------|
| EUR | -2.5 | 1.0 | 2.5% | Reference baseline |
| USD | -2.5 | 1.0 | 2.5% | Similar to EUR |
| JPY | -0.75 | 1.5 | 0.5% | Low rate norm; small changes matter more |
| GBP | -2.5 | 1.0 | 2.5% | Standard |
| CAD | -2.5 | 1.0 | 2.5% | Standard |
| AUD | -3.0 | 0.9 | 3.3% | Higher rate norm |
| CHF | -0.7 | 1.4 | 0.5% | Low rate norm |
| NZD | -3.0 | 0.9 | 3.3% | Higher rate norm |

- `a`: Offset (conceptually: `a = -b × neutralRate`)
- `b`: Sensitivity factor (how much a 1% deviation matters)
- `neutralRate`: Reference column only; actual params are `a` and `b`

**Output examples** (JPY with a=-0.75, b=1.5):
```
mrr=0.5% → -0.75 + 1.5×0.5 = 0    (neutral)
mrr=1.5% → -0.75 + 1.5×1.5 = 1.5  (above normal)
mrr=0.0% → -0.75 + 1.5×0.0 = -0.75 (below normal)
```

#### Step 2: Difference Curve

```
diff = baseNorm - quoteNorm
interestScore = interestDiffCurve(diff)
```

Uses the same symmetric cubic shape as inflation, but with different parameters:

```
interestDiffCurve(diff) = b_L × diff + d_L × diff³
```

| Param | Value | Description |
|-------|-------|-------------|
| b_L | 0 | Linear coefficient (disabled) |
| d_L | 0.05 | Cubic coefficient |

**Rationale**: With `b_L = 0`, small interest rate differences produce near-zero signal.
Only significant divergences matter. The pure cubic `0.05 × diff³` provides aggressive
amplification at extremes while staying quiet for noise.

**Output at key points**:
```
f(±6) = ±10.8   (max divergence)
f(±3) = ±1.35   (moderate divergence)
f(±1) = ±0.05   (small divergence, nearly zero)
f(0)  = 0
```

**Sign logic**: `baseNorm > quoteNorm` → base has better rates → positive score ✓

---

### 3. GDP Growth Score

**Concept**: GDP in a "sweet spot" signals healthy economy → bullish.
- Too low/negative: recession risk → bearish
- Sweet spot: healthy growth → bullish
- Too high: overheating risk, policy tightening → bearish

#### Step 1: Normalization (per area)

Each economic area has its own normalization function that maps raw GDP growth
to a **normalized score in [0, 3]**.

**Three characteristic points** define the curve shape:
```
zeroLow → peak → zeroHigh
    0       3        0
```

**Parameters**:
- **2 free parameters**: `zeroLow`, `zeroHigh` (boundaries where score = 0)
- **1 derived value**: `peak = (zeroLow + zeroHigh) / 2` (symmetric midpoint)

**Function**:
```
quadratic(x) = a + bx + cx²

normalizeGDP(gdpg) =
    normalized = quadratic(gdpg)
    return clamp(normalized, 0, 3)            # enforce output bounds
```

The quadratic is a downward parabola with roots at `zeroLow` and `zeroHigh`, peaking at 3.
Outside `[zeroLow, zeroHigh]`, the parabola goes negative → clamped to 0.

**Visualization**:
```
Normalized
   3 |           ****
   2 |         **    **
   1 |       **        **
   0 +-----**------------**-----------→ GDP %
          ↑       ↑        ↑
       zeroLow   peak   zeroHigh
```

#### Quadratic Coefficient Derivation

Same approach as inflation:

```
f(x) = k × (x - zeroLow)(x - zeroHigh)

where k = -12 / (zeroHigh - zeroLow)²
```

Expanded coefficients `f(x) = a + bx + cx²`:
```
c = k
b = -k × (zeroLow + zeroHigh)
a = k × zeroLow × zeroHigh
```

#### Per-Area Parameters (Free)

| Area | zeroLow | zeroHigh | peak (derived) | Rationale |
|------|---------|----------|----------------|-----------|
| EUR  | -2%    | 6%     | 2%         | Mature, 2% target |
| USD  | -2%    | 7%     | 2.5%       | Higher growth norm |
| JPY  | -3%    | 5%     | 1%         | Stagnation-tolerant |
| GBP  | -2%    | 6%     | 2%         | Similar to EUR |
| CAD  | -2%    | 6%     | 2%         | Resource economy |
| AUD  | -1%    | 7%     | 3%         | Higher growth norm |
| CHF  | -3%    | 5%     | 1%         | Low growth norm |
| NZD  | -1%    | 7%     | 3%         | Similar to AUD |

- `zeroLow`: GDP where score = 0 (below → clamped to 0)
- `zeroHigh`: GDP where score = 0 (above → clamped to 0)
- `peak`: Midpoint where score = 3 (derived, not free)

#### Derived Values (Coefficients)

| Area | a       | b       | c       |
|------|---------|---------|---------|
| EUR  | 2.25   | 0.75    | -0.188  |
| USD  | 2.074  | 0.741   | -0.148  |
| JPY  | 2.813  | 0.375   | -0.188  |
| GBP  | 2.25   | 0.75    | -0.188  |
| CAD  | 2.25   | 0.75    | -0.188  |
| AUD  | 1.313  | 1.125   | -0.188  |
| CHF  | 2.813  | 0.375   | -0.188  |
| NZD  | 1.313  | 1.125   | -0.188  |

**Fixed values** (same for all areas):
- `peakScore` = 3
- `floorScore` = 0

#### Step 2: Difference Curve

After normalization:
```
baseNorm ∈ [0, 3]
quoteNorm ∈ [0, 3]
diff = baseNorm - quoteNorm ∈ [-3, +3]
```

The difference curve combines these into the final GDP score:
```
gdpScore = gdpDiffCurve(diff)
```

**Curve shape**: Symmetric cubic (same structure as inflation/interest):
```
gdpDiffCurve(diff) = b_G × diff + d_G × diff³
```

| Param | Value | Description |
|-------|-------|-------------|
| b_G   | 2.78  | Linear coefficient |
| d_G   | 0.248 | Cubic coefficient |

**Note**: Same parameters as inflation diff curve since both now have [-3, +3] input range.

**Sign logic**: `baseNorm > quoteNorm` → base has healthier growth → positive score ✓

---

### 4. COT (Commitment of Traders) Score

**Concept**: Institutional positioning indicates sentiment. Combines short-term (6-week) and long-term (36-week) indices.

```
cotScore = sC * (baseNormCOT - quoteNormCOT)³

areaNormCOT = area.cotF * (cot6 / 33) * (cot36 / 33)²
```

- COT indices range 0-100 (percentile of historical positioning)
- Division by 33 normalizes to ~0-3 range
- cot36 squared: long-term trend weighted more heavily

| Area | cotF | Rationale |
|------|------|-----------|
| EUR  | 1.0  | Reference |
| USD  | 1.0  | Reference |
| JPY  | 0.9  | Carry trade dynamics |
| GBP  | 1.0  | Standard |
| CAD  | 1.0  | Standard |
| AUD  | 1.0  | Standard |
| CHF  | 0.9  | Safe haven flows |
| NZD  | 1.0  | Standard |

- `sC` = scale factor = 0.05

**Output at key points**:
```
f(±6) = ±10.8   (max divergence)
f(±3) = ±1.35   (moderate divergence)
f(±1) = ±0.05   (small divergence, nearly zero)
f(0)  = 0
```


**Sign logic**: `baseNormCOT > quoteNormCOT` → institutions favor base → positive score ✓

---

## Parameter Summary

### Global Weights
| Param | Description | Initial |
|-------|-------------|---------|
| wI    | Inflation weight | 6 |
| wL    | Interest rate weight | 9 |
| wG    | GDP weight | 4 |
| wC    | COT weight | 11 |

### Difference Curve Parameters
| Param | Description | Initial |
|-------|-------------|---------|
| b_I   | Inflation diff linear coefficient | 2.78 |
| d_I   | Inflation diff cubic coefficient | 0.248 |
| b_L   | Interest diff linear coefficient | 0 |
| d_L   | Interest diff cubic coefficient | 0.05 |
| b_G   | GDP diff linear coefficient | 2.78 |
| d_G   | GDP diff cubic coefficient | 0.248 |
| sC    | COT scale | 0.3 |

### Per-Area Inflation Parameters
- **Free (2)**: `zeroLow`, `zeroHigh`
- **Derived**: `peak` (midpoint), `a`, `b`, `c` (quadratic coefficients)
- **Fixed**: `peakScore` = 3, `floorScore` = 0

### Per-Area Interest Rate Parameters
Each area has: `mrrA`, `mrrB` (linear normalization: `a + b × mrr`)

### Per-Area GDP Parameters
- **Free (2)**: `zeroLow`, `zeroHigh`
- **Derived**: `peak` (midpoint), `a`, `b`, `c` (quadratic coefficients)
- **Fixed**: `peakScore` = 3, `floorScore` = 0

### Per-Area COT Parameters
Each area has: `cotF`

---

## Output Range

Final score clamped to `[-30, +30]` for UI display.

| Score Range | Trend Text |
|-------------|------------|
| > 20        | Super Bullish |
| 10 to 20    | Stark Bullish |
| 3 to 10     | Bullish |
| -3 to 3     | Neutral |
| -10 to -3   | Bearish |
| -20 to -10  | Stark Bearish |
| < -20       | Super Bearish |

---

## Implementation Notes

1. All parameters should be collected in a single config object for easy tuning
2. Quadratic normalization functions are continuous and differentiable → suitable for optimization
3. Per-area parameters allow economic baseline adjustments without changing core formulas
4. All normalization functions output **[0, 3]** → unified range, simpler reasoning
5. All difference curves receive **[-3, +3]** input → consistent across indicators
6. Downward parabolas always go to -∞ at extremes → no boundary condition issues
7. Output clamping to `[0, 3]` handles all edge cases
8. Each EconomicArea instance holds its own normalization parameters (`zeroLow`, `zeroHigh`)
