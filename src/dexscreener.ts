import { isRecord, toNumber, toText } from "./json.ts"
import type { Coin, Quotes } from "./types.ts"

const ENDPOINT = "https://api.dexscreener.com/tokens/v1/"
/** Addresses DexScreener accepts per call. */
const BATCH = 30
/** DexScreener caches responses this long, so asking more often returns the same numbers. */
export const DEX_MIN_INTERVAL_S = 30

/** One URL per chain and per 30 addresses. */
export function dexUrls(coins: Coin[]): string[] {
    const chains = new Map<string, string[]>()
    for (const coin of coins) chains.set(coin.chain, [...(chains.get(coin.chain) ?? []), coin.symbol])
    const urls: string[] = []
    chains.forEach((addresses, chain) => {
        for (let i = 0; i < addresses.length; i += BATCH)
            urls.push(`${ENDPOINT}${chain}/${addresses.slice(i, i + BATCH).join(",")}`)
    })
    return urls
}

interface Pool {
    volume: number
    depth: number
    price: number
    change: number
    name: string
    url: string
}

/**
 * A token trades in many pools; the busiest one (24 h volume, then liquidity) where it is the base
 * token sets the price. Liquidity alone is not enough: abandoned pools can report absurd depth.
 */
export function decodeDex(json: unknown, coins: Coin[]): Quotes {
    const quotes: Quotes = {}
    if (!Array.isArray(json)) return quotes

    const busiest = new Map<string, Pool>()
    for (const pair of json as unknown[]) {
        if (!isRecord(pair) || !isRecord(pair.baseToken)) continue
        const price = toNumber(pair.priceUsd)
        if (!(price > 0)) continue
        const id = `${toText(pair.chainId)}:${toText(pair.baseToken.address).toLowerCase()}`
        const depth = isRecord(pair.liquidity) ? toNumber(pair.liquidity.usd) || 0 : 0
        const volume = isRecord(pair.volume) ? toNumber(pair.volume.h24) || 0 : 0
        const known = busiest.get(id)
        if (known !== undefined && (known.volume > volume || (known.volume === volume && known.depth >= depth)))
            continue
        busiest.set(id, {
            volume,
            depth,
            price,
            change: isRecord(pair.priceChange) ? toNumber(pair.priceChange.h24) || 0 : 0,
            name: toText(pair.baseToken.symbol).replace(/^\$/, ""),
            url: toText(pair.url),
        })
    }

    for (const coin of coins) {
        const pool = busiest.get(`${coin.chain}:${coin.symbol.toLowerCase()}`)
        if (pool === undefined) continue
        quotes[coin.key] = { price: pool.price, change: pool.change, name: pool.name, url: pool.url }
    }
    return quotes
}
