############################################################
# The bell curve behind the histogram, robust against the outlier trades:
# center = median, sigma = 1.4826 · MAD (the MAD of a normal distribution is 0.6745 σ).
# Computed on the raw trade-day values, so it doesn't depend on the bin width.
import { quantile } from "./chanceriskbins.js"

madToSigma = 1.4826

############################################################
# sorted: binProfile(...).values, dir: 1 for longs, -1 for shorts (the loss side is left of the center for longs)
# -> { center, sigma, loss, profit } or null for sigma 0 (more than half the values identical)
#   loss / profit: the actual share of the values on that side of the center lying within 1σ / 2σ / 3σ of it
export bellFit = (sorted, dir = 1) ->
    return null unless sorted.length
    center = quantile(sorted, 0.5)
    deviations = sorted.map((v) -> Math.abs(v - center)).sort((a, b) -> a - b)
    sigma = madToSigma * quantile(deviations, 0.5)
    return null unless sigma > 0

    # sigma > 0 leaves values on both sides of the median -> no empty side
    shares = (side) ->
        offsets = (o for v in sorted when (o = side * dir * (v - center)) > 0)
        return (offsets.filter((o) -> o <= k * sigma).length / offsets.length for k in [1..3])
    return { center, sigma, loss: shares(-1), profit: shares(1) }

# height of the fitted curve at x in histogram counts: area = n values in bins of width w
export bellCount = (fit, n, w, x) ->
    z = (x - fit.center) / fit.sigma
    return n * w * Math.exp(-z * z / 2) / (fit.sigma * Math.sqrt(2 * Math.PI))
