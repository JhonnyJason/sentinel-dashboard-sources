# scoring

Consolidates all scoring pipeline logic: normalization math, area scoring functions, pair-level scoring model, and display helpers.

## Files

| File | Role |
|------|------|
| `normmath.coffee` | Pure math for param conversions (peak/steepness ↔ a,b,c; neutralRate/sensitivity ↔ a,b; amplification ↔ b,d) |
| `areanorm.coffee` | Pure normalization score functions: `inflNorm`, `mrrNorm`, `gdpgNorm`, `cotNorm` — each takes `(data, params)` → score in [0, 2] |
| `defaultsnapshot.coffee` | Default parameters: per-area norm params, diff params, final weights |
| `scorehelper.coffee` | Display helpers: diff curve wrappers, color/trend-text mapping, horizon score functions |

## Design

- **Pure functions** — `normmath` and `areanorm` have no state, no DOM, no side effects
- **scorehelper** — applies the default params from `defaultsnapshot` (overridable via `setGlobalParams`)
- **EconomicArea** delegates to `areanorm` via closures in its `normFun` map
