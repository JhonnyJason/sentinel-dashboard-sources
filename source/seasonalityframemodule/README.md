# Seasonality Frame Module

UI module for seasonality chart display and symbol selection.

## Files

| File | Purpose |
|------|---------|
| `seasonalityframemodule.coffee` | Main coordinator - state management, data retrieval, wiring |
| `comboboxfun.coffee` | `Combobox` class - fuzzy-ranked filtering, keyboard navigation, dropdown |
| `chartfun.coffee` | uPlot chart rendering and axis interactions |
| `symboloptions.coffee` | Symbol search - rate-limited server search with requester callback, default S&P 500 list |
| `seasonalityframe.pug` | HTML template |
| `styles.styl` | Styling |

## Module Interfaces

### seasonalityframemodule
```coffee
initialize(config)           # Called at app startup
```

### comboboxfun
```coffee
# Combobox class
box = new Combobox({ inputEl, dropdownEl, optionsLimit, minSearchLength })
box.onSelect(callback)           # Attach selection handler (callback receives symbol)
box.setDefaultOptions()          # Sets fullOptions from symboloptions.defaultTop100
box.provideSearchOptions(opts)   # Sets fullOptions to server results, refilters
```

**Internal state**:
- `fullOptions` - Complete option pool (from defaults or server)
- `currentOptions` - Displayed options (filtered/sliced from fullOptions)
- `optionsLimit` - Max options to display (default 30)

**Fuzzy scoring**: Counts matched characters in order, takes best of symbol vs name score.

### chartfun
```coffee
drawChart(container, xAxisData, seasonalityData, latestData)
resetChart(container)
```

### symboloptions
```coffee
dynamicSearch(searchString, limit, requester)  # Rate-limited, calls requester.provideSearchOptions(results)
defaultTop100                                   # Array of {symbol, name} (~100 S&P 500 stocks)
```

## Data Flow

```
Initialization:
    new Combobox({ inputEl, dropdownEl, optionsLimit: 30 })
        → constructor calls setDefaultOptions()
        → fullOptions = defaultTop100

User types in combobox:
    → Combobox.onInput → updateCurrentOptions (fuzzy rank fullOptions)
    → if query < 3 chars: setDefaultOptions() (reset to defaults)
    → if query >= 3 chars: dynamicSearch(query, limit+20, this)
        → scimodule.getSymbolOptions(searchString, limit)
        → Combobox.provideSearchOptions(results)
        → fullOptions = results → updateCurrentOptions → render

User selects symbol:
    → Combobox calls selectionCallback(symbol)
    → seasonalityframemodule.onStockSelected
    → retrieveRelevantData (TODO: wire to marketdatamodule)
    → chartfun.drawChart
```
