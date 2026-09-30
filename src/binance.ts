import { isRecord, toNumber, toText } from "./json.ts"
import type { Coin, Quotes } from "./types.ts"

// Binance's keyless host for public market data. One call covers every symbol.
const ENDPOINT = "https://data-api.binance.vision/api/v3/ticker/24hr"

/** Empty when there is nothing to ask for. A single unknown symbol makes Binance reject the whole batch. */
export function binanceUrl(coins: Coin[]): string {
    const symbols = coins.map((c) => c.symbol)
    const [only] = symbols
    if (only === undefined) return ""
    if (symbols.length === 1) return `${ENDPOINT}?symbol=${only}`
    return `${ENDPOINT}?symbols=${encodeURIComponent(JSON.stringify(symbols))}`
}

/** A pair whose 24 h window closed longer ago than this is not trading. Live pairs close "now". */
const HALTED_AFTER_MS = 15 * 60 * 1000

/**
 * Accepts the array a batch returns and the single object a one-symbol call returns.
 * Halted and delisted pairs are left out: Binance still answers for them, with the last price
 * frozen at the moment trading stopped, and showing that as a live price would be a lie.
 */
export function decodeBinance(json: unknown, now: number): Quotes {
    const quotes: Quotes = {}
    const rows = Array.isArray(json) ? json : [json]
    for (const row of rows) {
        if (!isRecord(row)) continue
        const symbol = toText(row.symbol)
        const price = toNumber(row.lastPrice)
        if (symbol === "" || !(price > 0)) continue
        const closed = toNumber(row.closeTime)
        if (closed > 0 && now - closed > HALTED_AFTER_MS) continue
        quotes[`binance:${symbol}`] = {
            price,
            change: toNumber(row.priceChangePercent) || 0,
            url: `https://www.tradingview.com/chart/?symbol=BINANCE:${symbol}`,
        }
    }
    return quotes
}
