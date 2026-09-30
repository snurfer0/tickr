// Finding coins to add: the settings page shows these as click-to-add suggestions.
import { STABLES } from "./coins.ts"
import { shortAddress } from "./format.ts"
import { isRecord, toNumber, toText } from "./json.ts"
import type { Tag } from "./types.ts"

export interface Suggestion {
    /** Coin-list entry that adds this coin, e.g. `BTC`, `hl:HYPE`, `dex:solana:<address> = WIF`. */
    entry: string
    title: string
    subtitle: string
    tag: Tag
    /** DexScreener chain id; empty for the exchanges. */
    chain: string
    /** In US dollars; 0 when the search does not know it. */
    price: number
}

// ---- Binance spot ------------------------------------------------------------------------------

/**
 * Best bid and ask of every spot pair, about 430 KB, fetched once when the settings open.
 * The plain price list is not usable: Binance keeps delisted and halted pairs in it with their
 * last price frozen (XMR/USDT still reads 118.70 long after trading stopped). A pair nobody can
 * trade has no bid or ask, which is how those are told apart here.
 */
export const SPOT_LIST_URL = "https://data-api.binance.vision/api/v3/ticker/bookTicker"

// Tried in this order, so BTCUSDT is BTC/USDT and ETHBTC is ETH/BTC.
const QUOTES = ["USDT", "USDC", "FDUSD", "BTC", "ETH", "BNB", "EUR", "TRY", "BRL", "JPY"]
const POPULAR_SPOT = ["BTC", "ETH", "SOL", "BNB", "XRP", "DOGE", "PEPE", "SUI"]

export interface SpotPair {
    base: string
    quote: string
    price: number
}

export function decodeSpotList(json: unknown): SpotPair[] {
    if (!Array.isArray(json)) return []
    const pairs: SpotPair[] = []
    for (const row of json as unknown[]) {
        if (!isRecord(row)) continue
        const bid = toNumber(row.bidPrice)
        const ask = toNumber(row.askPrice)
        if (!(bid > 0) || !(ask > 0)) continue
        const price = (bid + ask) / 2
        const symbol = toText(row.symbol)
        const quote = QUOTES.find((q) => symbol.length > q.length && symbol.endsWith(q))
        if (quote !== undefined) pairs.push({ base: symbol.slice(0, -quote.length), quote, price })
    }
    return pairs
}

function spotSuggestion(pair: SpotPair): Suggestion {
    const entry =
        pair.quote === "USDT"
            ? pair.base
            : STABLES.includes(pair.quote)
              ? `binance:${pair.base}${pair.quote}`
              : `binance:${pair.base}/${pair.quote}`
    return {
        entry,
        title: pair.quote === "USDT" ? pair.base : `${pair.base}/${pair.quote}`,
        subtitle: `${pair.base}/${pair.quote} spot`,
        tag: "SPOT",
        chain: "",
        // Only dollar-quoted prices are comparable at a glance.
        price: STABLES.includes(pair.quote) ? pair.price : 0,
    }
}

/**
 * One result per coin: its USDT pair, or the next best quote if it has none. Exact name first, then
 * names starting with the query, then containing it. Typing a whole pair (`ETHBTC`, `eth/btc`,
 * `pepeusdc`) finds that pair.
 */
export function searchSpot(pairs: SpotPair[], query: string, limit: number): Suggestion[] {
    const wanted = query.toUpperCase().replace(/[^A-Z0-9]/g, "")
    if (wanted === "") {
        return POPULAR_SPOT.map((base) => pairs.find((p) => p.base === base && p.quote === "USDT"))
            .filter((pair): pair is SpotPair => pair !== undefined)
            .slice(0, limit)
            .map(spotSuggestion)
    }
    const exactPair = pairs.filter((pair) => pair.base + pair.quote === wanted && pair.base !== wanted)
    const best = new Map<string, { pair: SpotPair; score: number }>()
    for (const pair of pairs) {
        const match = pair.base === wanted ? 0 : pair.base.startsWith(wanted) ? 1 : pair.base.includes(wanted) ? 2 : -1
        if (match < 0) continue
        const score = match * 1000 + QUOTES.indexOf(pair.quote) * 50 + pair.base.length
        const known = best.get(pair.base)
        if (known === undefined || score < known.score) best.set(pair.base, { pair, score })
    }
    const byName = Array.from(best.values())
        .sort((a, b) => a.score - b.score)
        .map((scored) => scored.pair)
    return exactPair.concat(byName).slice(0, limit).map(spotSuggestion)
}

// ---- Hyperliquid perps -------------------------------------------------------------------------

const POPULAR_PERPS = ["BTC", "ETH", "SOL", "HYPE", "XRP", "DOGE", "kPEPE", "FARTCOIN"]

export interface Perp {
    name: string
    price: number
}

/** Reads the same `metaAndAssetCtxs` response the live feed uses; delisted markets are left out. */
export function decodePerpList(json: unknown): Perp[] {
    if (!Array.isArray(json)) return []
    const [meta, contexts] = json as unknown[]
    if (!isRecord(meta) || !Array.isArray(meta.universe) || !Array.isArray(contexts)) return []
    const perps: Perp[] = []
    ;(meta.universe as unknown[]).forEach((entry, i) => {
        if (!isRecord(entry) || entry.isDelisted === true) return
        const name = toText(entry.name)
        const context: unknown = contexts[i]
        const price = isRecord(context) ? toNumber(context.midPx) || toNumber(context.markPx) || 0 : 0
        if (name !== "") perps.push({ name, price })
    })
    return perps
}

export function searchPerps(perps: Perp[], query: string, limit: number): Suggestion[] {
    const wanted = query.toUpperCase().replace(/[^A-Z0-9]/g, "")
    const suggestion = (perp: Perp): Suggestion => ({
        entry: `hl:${perp.name}`,
        title: perp.name,
        subtitle: `${perp.name}-USD perpetual`,
        tag: "PERP",
        chain: "",
        price: perp.price,
    })
    if (wanted === "") {
        return POPULAR_PERPS.map((name) => perps.find((p) => p.name === name))
            .filter((perp): perp is Perp => perp !== undefined)
            .slice(0, limit)
            .map(suggestion)
    }
    const rank = (name: string): number => {
        const upper = name.toUpperCase()
        // kPEPE should be found by typing PEPE.
        const bare = name.startsWith("k") ? upper.slice(1) : upper
        if (upper === wanted || bare === wanted) return 0
        if (upper.startsWith(wanted) || bare.startsWith(wanted)) return 1
        return upper.includes(wanted) ? 2 : -1
    }
    return perps
        .map((perp) => ({ perp, score: rank(perp.name) }))
        .filter((scored) => scored.score >= 0)
        .sort((a, b) => a.score - b.score || a.perp.name.length - b.perp.name.length)
        .slice(0, limit)
        .map((scored) => suggestion(scored.perp))
}

// ---- DexScreener -------------------------------------------------------------------------------

const SEARCH = "https://api.dexscreener.com/latest/dex/search?q="

/**
 * DexScreener matches symbols literally, and many memecoins carry a dollar sign (dogwifhat is
 * `$WIF`): a single word is therefore searched both as typed and with `$` in front.
 * Names with spaces and contract addresses are searched as they are.
 */
export function dexSearchUrls(query: string): string[] {
    const text = query.trim()
    const urls = [SEARCH + encodeURIComponent(text)]
    if (/^[A-Za-z0-9]{2,12}$/.test(text)) urls.push(SEARCH + encodeURIComponent(`$${text}`))
    return urls
}

function compact(usd: number): string {
    if (usd >= 1e9) return `$${(usd / 1e9).toFixed(1)}B`
    if (usd >= 1e6) return `$${(usd / 1e6).toFixed(1)}M`
    if (usd >= 1e3) return `$${(usd / 1e3).toFixed(0)}K`
    return `$${usd.toFixed(0)}`
}

/**
 * One suggestion per token, busiest first, from one or more search responses (the same pool in
 * two responses is counted once). Ranking is by 24 h volume, not liquidity: copycat tokens
 * show up with huge fake liquidity but nobody trades them, so volume keeps the real one on top.
 */
export function decodeDexSearch(responses: unknown[], limit: number): Suggestion[] {
    const pairs: unknown[] = []
    for (const json of responses)
        if (isRecord(json) && Array.isArray(json.pairs)) pairs.push(...(json.pairs as unknown[]))
    interface Token {
        chain: string
        address: string
        symbol: string
        name: string
        volume: number
        busiest: number
        price: number
    }
    const tokens = new Map<string, Token>()
    const seenPools = new Set<string>()
    for (const pair of pairs) {
        if (!isRecord(pair) || !isRecord(pair.baseToken)) continue
        const chain = toText(pair.chainId)
        const address = toText(pair.baseToken.address)
        const price = toNumber(pair.priceUsd)
        if (chain === "" || address === "" || !(price > 0)) continue
        const pool = `${chain}:${toText(pair.pairAddress)}`
        if (toText(pair.pairAddress) !== "" && seenPools.has(pool)) continue
        seenPools.add(pool)
        const volume = isRecord(pair.volume) ? toNumber(pair.volume.h24) || 0 : 0
        const id = `${chain}:${address.toLowerCase()}`
        const token = tokens.get(id)
        if (token === undefined) {
            tokens.set(id, {
                chain,
                address,
                symbol: toText(pair.baseToken.symbol).replace(/^\$/, ""),
                name: toText(pair.baseToken.name),
                volume,
                busiest: volume,
                price,
            })
            continue
        }
        token.volume += volume
        // The price comes from the pool people actually trade in.
        if (volume > token.busiest) {
            token.busiest = volume
            token.price = price
        }
    }
    return Array.from(tokens.values())
        .sort((a, b) => b.volume - a.volume)
        .slice(0, limit)
        .map((token) => {
            const named = token.name === "" || token.name === token.symbol ? "" : `${token.name} · `
            const traded = token.volume >= 1000 ? `${compact(token.volume)} traded in 24 h` : "almost no trading"
            const short = shortAddress(token.address)
            return {
                entry:
                    token.symbol === ""
                        ? `dex:${token.chain}:${token.address}`
                        : `dex:${token.chain}:${token.address} = ${token.symbol}`,
                title: token.symbol || short,
                subtitle: `${named}${short} · ${traded}`,
                tag: "DEX",
                chain: token.chain,
                price: token.price,
            }
        })
}
