export snapshot = {
  areaParams: {
    eurozone: { 
        infl: { a: 1.111, b: 0.444, c: -0.056 }
        mrr: { f: -2.2, n: 2.0, c: 5.5, s: 1.2 }
        gdpg: { a: 1.5, b: 0.5, c: -0.125 }
        cot: { n: 50, e: 1.6 } 
    },
    usa: {
        infl: { a: 1.111, b: 0.444, c: -0.056 }
        mrr: { f: -1.7, n: 2.7, c: 6.0, s: 1.2 }
        gdpg: { a: 1.383, b: 0.494, c: -0.099 }
        cot: { n: 50, e: 1.6 }

    }, 
    japan: { 
        infl: { a: 1.587, b: 0.331, c: -0.066 }
        mrr: { f: -1, n: 0.5, c: 3.5, s: 1.2 }
        gdpg: { a: 1.875, b: 0.25, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    },
    uk: {
        infl: { a: 1.111, b: 0.444, c: -0.056 }
        mrr: { f: -2, n: 2.5, c: 6.0, s: 1.2 }
        gdpg: { a: 1.5, b: 0.5, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    },
    canada: {
        infl: { a: 1.111, b: 0.444, c: -0.056 }
        mrr: { f: -2, n: 2.5, c: 6.0, s: 1.2 }
        gdpg: { a: 1.5, b: 0.5, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    },
    australia: {
        infl: { a: 0.611, b: 0.556, c: -0.056 }
        mrr: { f: -2, n: 2.9, c: 7.0, s: 1.2 }
        gdpg: { a: 0.875, b: 0.75, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    },
    switzerland: {
        infl: { a: 1.587, b: 0.331, c: -0.066 }
        mrr: { f: -1, n: 0.8, c: 4.0, s: 1.2 }
        gdpg: { a: 1.875, b: 0.25, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    },
    newzealand: {
        infl: { a: 0.611, b: 0.556, c: -0.056 }
        mrr: { f: -2, n: 2.9, c: 7.0, s: 1.2 }
        gdpg: { a: 0.875, b: 0.75, c: -0.125 }
        cot: { n: 50, e: 1.6 }
    }
  },

  globalParams: {
    diffCurves: { 
        infl: { b: 1.25, d: 0.313 }
        mrr:  { b: 1.25, d: 0.313 }
        gdpg: { b: 1.25, d: 0.313 }
        cot:  { b: 1.25, d: 0.313 }
    },
    finalWeights: { 
        st: { i: 14, l: 28, g: 8, c: 51, f: 13  }   # short term
        ml: { i: 8, l: 8, g: 4, c: 5, f:13 }   # medium-long term
        lt: { i: 8, l: 5, g: 7, c: 1, f: 13 }   # long term
    }
  }
}

############################################################
# convenience exports
export finalWeights = snapshot.globalParams.finalWeights
export diffParams = snapshot.globalParams.diffCurves
export areaParams = snapshot.areaParams