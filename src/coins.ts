import { shortAddress } from "./format.ts"
import type { Coin, Quote, Source } from "./types.ts"

/** Dollar stablecoins: pairs against these are written without a slash (BTCUSDC). */
export const STABLES = ["USDT", "USDC", "FDUSD"]

/** In front of an entry: the coin stays in the list but is left out of the panel. */
const HIDDEN = "!"

/**
 * Reads the coin list. One coin per line or comma separated, `#` starts a comment:
 *
 *     BTC  |  binance:BTC  |  binance:ETH/BTC    spot on Binance, against USDT unless a quote is given
 *     hl:BTC                                     perpetual on Hyperliquid
 *     dex:solana:<token address>                 any token DexScreener tracks, by chain and address
 *
 * `= NAME` at the end overrides the label shown, `!` in front hides the coin from the panel.
 * Unknown sources and duplicates are dropped.
 */
export function parseCoins(text: string): Coin[] {
    const coins: Coin[] = []
    const seen = new Set<string>()
    for (const row of text.split("\n")) {
        for (const entry of row.replace(/#.*/, "").split(",")) {
            const coin = parseEntry(entry.trim())
            if (coin === null || seen.has(coin.key)) continue
            seen.add(coin.key)
            coins.push(coin)
        }
    }
    return coins
}

function parseEntry(entry: string): Coin | null {
    const hidden = entry.startsWith(HIDDEN)
    const coin = parseSource(hidden ? entry.slice(HIDDEN.length).trim() : entry)
    if (coin !== null) coin.hidden = hidden
    return coin
}

function parseSource(entry: string): Coin | null {
    if (entry === "") return null
    const eq = entry.lastIndexOf("=")
    const label = eq > 0 ? entry.slice(eq + 1).trim() : ""
    const parts = (eq > 0 ? entry.slice(0, eq) : entry).split(":").map((part) => part.trim())
    const last = parts[parts.length - 1] ?? ""
    const source = parts.length > 1 ? (parts[0] ?? "").toLowerCase() : "binance"

    if (source === "binance" || source === "spot") return spot(last, label)
    if (source === "hl" || source === "hyperliquid" || source === "perp") return perp(last, label)
    if (source === "dex" && parts.length >= 3) return token(parts[1] ?? "", parts[2] ?? "", label)
    return null
}

/** BTC → BTCUSDT; BTCUSDC stays; any other quote needs a slash: ETH/BTC. */
function spot(text: string, label: string): Coin | null {
    const symbol = text.toUpperCase().replace(/[^A-Z0-9/]/g, "")
    let base = symbol
    let quote = "USDT"
    if (symbol.includes("/")) {
        const [left, right] = symbol.split("/")
        base = left ?? ""
        quote = right ?? ""
    } else {
        for (const stable of STABLES) {
            if (symbol.length > stable.length && symbol.endsWith(stable)) {
                base = symbol.slice(0, -stable.length)
                quote = stable
            }
        }
    }
    if (base === "" || quote === "") return null
    const shown = STABLES.includes(quote) ? base : `${base}/${quote}`
    return coin("binance", base + quote, "", label || shown, quote)
}

function perp(text: string, label: string): Coin | null {
    const name = text.replace(/[^A-Za-z0-9]/g, "")
    if (name === "") return null
    return coin("hl", name, "", label)
}

function token(chain: string, address: string, label: string): Coin | null {
    if (chain === "" || address === "") return null
    return coin("dex", address, chain.toLowerCase(), label)
}

const TAGS = { binance: "SPOT", hl: "PERP", dex: "DEX" } as const

function coin(source: Source, symbol: string, chain: string, label: string, quote = ""): Coin {
    const key = chain === "" ? `${source}:${symbol}` : `${source}:${chain}:${symbol}`
    return { key, source, tag: TAGS[source], symbol, chain, quote, label, hidden: false }
}

export function bySource(coins: Coin[], source: Source): Coin[] {
    return coins.filter((c) => c.source === source)
}

/**
 * Text shown for a coin: the user's label, else the feed's own name (so `hl:PEPE` reads kPEPE, the
 * contract it is actually priced as), else the symbol, with long token addresses shortened.
 */
export function displayName(coin: Coin, quote?: Quote): string {
    if (coin.label !== "") return coin.label
    if (quote?.name !== undefined && quote.name !== "") return quote.name
    if (coin.source === "dex") return shortAddress(coin.symbol)
    return coin.source === "hl" ? coin.symbol.toUpperCase() : coin.symbol
}

/** The coin list as text, one entry per line: what `parseCoins` reads back to the same list. */
export function formatCoins(coins: Coin[]): string {
    return coins.map((c) => (c.hidden ? HIDDEN : "") + entryOf(c)).join("\n")
}

function entryOf(coin: Coin): string {
    if (coin.source === "dex") return `dex:${coin.chain}:${coin.symbol}${coin.label === "" ? "" : ` = ${coin.label}`}`
    if (coin.source === "hl") return `hl:${coin.symbol}${coin.label === "" ? "" : ` = ${coin.label}`}`
    const base = coin.symbol.slice(0, coin.symbol.length - coin.quote.length)
    const stable = STABLES.includes(coin.quote)
    const text =
        coin.quote === "USDT" ? base : stable ? `binance:${base}${coin.quote}` : `binance:${base}/${coin.quote}`
    const natural = stable ? base : `${base}/${coin.quote}`
    return coin.label === natural ? text : `${text} = ${coin.label}`
}

/** What a coin is, next to its source badge in the settings list: `BTC/USDT spot`, `HYPE-USD perpetual`, `EKpQ…zcjm`. */
export function describe(coin: Coin): string {
    if (coin.source === "hl") return `${coin.symbol}-USD perpetual`
    if (coin.source === "dex") return shortAddress(coin.symbol)
    return `${coin.symbol.slice(0, coin.symbol.length - coin.quote.length)}/${coin.quote} spot`
}

/** True when the list already holds the coin this entry describes. */
export function hasCoin(list: string, entry: string): boolean {
    const [coin] = parseCoins(entry)
    return coin !== undefined && parseCoins(list).some((c) => c.key === coin.key)
}

/** The list with the entry's coin appended; unchanged when the entry is invalid or already there. */
export function addCoin(list: string, entry: string): string {
    const [coin] = parseCoins(entry)
    if (coin === undefined || hasCoin(list, entry)) return list
    return formatCoins([...parseCoins(list), coin])
}

/** The list without the coin under this key. */
export function removeCoin(list: string, key: string): string {
    return formatCoins(parseCoins(list).filter((c) => c.key !== key))
}

/** The list with the coin under this key switched between shown in the panel and hidden from it. */
export function toggleCoin(list: string, key: string): string {
    const coins = parseCoins(list)
    for (const coin of coins) if (coin.key === key) coin.hidden = !coin.hidden
    return formatCoins(coins)
}

/** The list with the coin at `from` moved to position `to`; unchanged for positions out of range. */
export function moveCoin(list: string, from: number, to: number): string {
    const coins = parseCoins(list)
    const [coin] = coins.splice(from, 1)
    if (coin === undefined || to < 0 || to > coins.length) return list
    coins.splice(to, 0, coin)
    return formatCoins(coins)
}
