# scoring

Consolidates all scoring pipeline logic: normalization math, area scoring functions, pair-level scoring model, and display helpers.

## Files

| File | Role |
|------|------|
| `normmath.coffee` | Pure math for param conversions (peak/steepness ↔ a,b,c; neutralRate/sensitivity ↔ a,b; amplification ↔ b,d) |
| `areanorm.coffee` | Pure normalization score functions: `inflNorm`, `mrrNorm`, `gdpgNorm`, `cotNorm` — each takes `(data, params)` → score in [0, 2] |
| `ScoreCombinator.coffee` | Pair-level scoring engine: diff curves + final combination weights + calculation |
| `scorehelper.coffee` | Display helpers: diff curve wrappers, color/trend-text mapping, horizon score functions |

## Design

- **Pure functions** — `normmath` and `areanorm` have no state, no DOM, no side effects
- **scorehelper** — bridges ScoreCombinator (live playground) and default params (standalone display)
- **EconomicArea** delegates to `areanorm` via closures in its `normFun` map
