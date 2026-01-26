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

## Seasonality Calculation

For any calcuations we need to first Normalize the years to the same length.
Here we might cut off the February 29 or add a February 29 on every year.
Currently we Normalize all years to 366 days (duplicate Feb 28 for non-leap years)

### Average Daily Return method
Uses log-returns for averaging across years (see `seasonality.coffee`):

1. Calculate log-factors: `log(day[i] / day[i+1])`
2. Average factors across years
3. Reconstruct normalized price curve from averaged factors

This approach handles the compounding nature of returns correctly.

Here we also want to calculate the standard deviation for a better picture - still missing.

### Fourier Transform method

1. Concatenate all relevant years into one "signal"
2. 
3. Normalize to values be between -1 and +1
4. Frequency Transform the "signal" 
5. Cut off frequencies from 183
6. Inverse Transform to time-space
7. Extract and skew the yearly dynamics by adding the yearly return gradient

Here we have experiments of pure FFT and frequency cut off available in the fouriermodule.
The full chain needs to be sophisticatedly implemented here.

### Fourier Average method

MAYBE: Is this cool to have?

Here we calculate the fourier transform of each year and then average them.
Also here we want a standard deviation with the averaged line.

## TODO

- [x] Transform datahub response to cache structure (datacache.coffee)
- [ ] Define interface for seasonalityframemodule
- [ ] Wire datacache to marketdatamodule interface
- [ ] Convenience extractors: `getCloses()`, `getHighs()`, `getLows()`
- [ ] Wire up seasonality calculations to interface
- [ ] Implement Standard Deviation in Average Return method
- [ ] Implement Fourier Transform method
