# marketdatamodule

Handles market history data: fetching from datahub, caching, and seasonality calculations.

## Files

| File | Purpose |
|------|---------|
| `marketdatamodule.coffee` | Main entry, exports public API |
| `datacache.coffee` | Datahub communication and in-memory cache |
| `seasonality.coffee` | Seasonality calculations (average dynamics, leap year handling) |
| `sampledata.coffee` | **Mock data source** - random walk generator for development/testing |

## Cache Design

```
keyToHistory = {
    "GOOGL": [year0, year1, year2, ...]
}
```

- **year0** = current calendar year (incomplete)
- **year1** = last year, **year2** = 2 years ago, etc.
- Each year: array of `[high, low, close]` per trading day
- Position in array = trading day of calendar year (index 0 = first trading day of Jan)
- Calendar years, not rolling periods
- Always fetch max history (30 years), slice locally for different analysis ranges
- Notices: Oldest year might be incomplete as well
- Incomplete years have their full length (365 or 366 for a leap year) but `null` instead of [h,l,c] for the unavailable dates

## Data Flow

```
User requests seasonality for "GOOGL" with 10 years
    |
    v
datacache.getMarketHistory("GOOGL", 10)
    |
    +-- Cache hit? Return slice of cached years
    |
    +-- Cache miss?
            |
            v
        scimodule.getEodData("GOOGL", 30)  --> Datahub
            |
            v
        Transform flat response to year-bucketed structure
            |
            v
        Store in keyToHistory, return requested slice
```

## Datahub Response Format

```coffee
{
    meta: {
        startDate: "YYYY-MM-DD"
        endDate: "YYYY-MM-DD"
        interval: "1d"
        historyComplete: boolean
    }
    data: [[h,l,c], [h,l,c], ...]  # chronological, oldest first
}
```

## Close chunks (seasonality input)
`getCloseChunks(symbol, timeframe, years)` → `{ chunks, refDate }`
- `timeframe`: `yearly` | `quarterly` | `monthly` | `weekly`; chunks newest first, chunk 0 = period of `refDate` (newest data date).
- Window back to Jan 1 of (`refDate` year − `years`).
- Slot space: yearly 366 (FEB29 slot `null` in non-leap years, via `normalizeYearData`), quarterly 93 (`monthInQuarter * 31 + day - 1`), monthly 31, weekly 7 (Mon = 0). Non-existent slots `null`, missing days `undefined`.
- The caller computes the composite: `calculateSeasonalityComposite(chunks, 0, isIncluded)` (re-exported here), `isIncluded(k)` per chunk age or `null` = all. Chunk 0 never enters the composite. Returns `null` if no sample remains.
- datacache buckets all four timeframes in one pass (`getHistoricCloseChunks`).

## Seasonality Calculation
