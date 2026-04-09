import fs from "node:fs"
import path from "node:path"

const commoditiesPath = path.resolve("./", "commodities.json")
const currenciesPath = path.resolve("./", "currencies.json")
const stocksPath = path.resolve("./", "stocks.json")

const outputFilePath = path.resolve("..", "all_symbols.json")

// Read stocks.json and compile into [["<symbol>","<name>"], ...] format
var stocksData = JSON.parse(fs.readFileSync(stocksPath, "utf-8"))
// TODO Read currencies and compile them 
// TODO Read commodities and compile them into

stocksData = stocksData.filter(el => typeof el.symbol == "string" && typeof el.name == "string")
const result = stocksData.map(stock => [stock.symbol, stock.name])

fs.writeFileSync(outputFilePath, JSON.stringify(result))
