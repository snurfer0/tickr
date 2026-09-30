// Calls the three real APIs once. Run with `bun run test:live`; not part of `check`, so CI stays offline.
import { expect, test } from "bun:test"
import {
    binanceUrl,
    bySource,
    decodeBinance,
    decodeDex,
    decodeHyperliquid,
    dexUrls,
    displayName,
    HYPERLIQUID_BODY,
    HYPERLIQUID_URL,
    parseCoins,
    percent,
    price,
    type Quotes,
} from "../src/index.ts"

const coins = parseCoins(`
  BTC, ETH, SOL, binance:ETH/BTC, PEPE
  hl:BTC, hl:HYPE, hl:PEPE
  dex:solana:EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm
  dex:solana:DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263
  dex:base:0x532f27101965dd16442E59d40670FaF5eBB142E4
`)

test("every coin gets a live quote", async () => {
    const quotes: Quotes = {}
    const get = async (url: string, init?: RequestInit): Promise<unknown> => (await fetch(url, init)).json()

    Object.assign(quotes, decodeBinance(await get(binanceUrl(bySource(coins, "binance"))), Date.now()))
    const hl = await get(HYPERLIQUID_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: HYPERLIQUID_BODY,
    })
    Object.assign(quotes, decodeHyperliquid(hl, bySource(coins, "hl")))
    const dex = bySource(coins, "dex")
    for (const url of dexUrls(dex)) Object.assign(quotes, decodeDex(await get(url), dex))

    for (const coin of coins) {
        const quote = quotes[coin.key]
        expect(quote, `no quote for ${coin.key}`).toBeDefined()
        expect(quote?.price).toBeGreaterThan(0)
        console.log(
            coin.tag.padEnd(5),
            displayName(coin, quote).padEnd(8),
            price(quote?.price ?? 0).padStart(12),
            percent(quote?.change ?? 0).padStart(8),
        )
    }
}, 30000)
