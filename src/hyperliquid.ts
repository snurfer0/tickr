import { isRecord, toNumber, toText } from "./json.ts"
import type { Coin, Quotes } from "./types.ts"

export const HYPERLIQUID_URL = "https://api.hyperliquid.xyz/info"
/** One POST returns every perp with mark, mid, previous-day price and funding. */
export const HYPERLIQUID_BODY = JSON.stringify({ type: "metaAndAssetCtxs" })

/**
 * The response is `[meta, contexts]`, where `contexts[i]` belongs to `meta.universe[i]`.
 * Hyperliquid lists some small-priced coins per thousand (kPEPE, kBONK); `hl:PEPE` finds those too.
 */
export function decodeHyperliquid(json: unknown, coins: Coin[]): Quotes {
    const quotes: Quotes = {}
    if (!Array.isArray(json)) return quotes
    const [meta, contexts] = json as unknown[]
    if (!isRecord(meta) || !Array.isArray(meta.universe) || !Array.isArray(contexts)) return quotes

    const names: string[] = meta.universe.map((entry: unknown) => (isRecord(entry) ? toText(entry.name) : ""))
    const index = new Map<string, number>()
    names.forEach((name, i) => {
        if (!index.has(name.toUpperCase())) index.set(name.toUpperCase(), i)
    })

    for (const coin of coins) {
        const wanted = coin.symbol.toUpperCase()
        const i = index.get(wanted) ?? index.get(`K${wanted}`)
        if (i === undefined) continue
        const context: unknown = contexts[i]
        const name = names[i]
        if (!isRecord(context) || name === undefined) continue
        const price = toNumber(context.midPx) || toNumber(context.markPx)
        if (!(price > 0)) continue
        const previous = toNumber(context.prevDayPx)
        quotes[coin.key] = {
            price,
            change: previous > 0 ? (price / previous - 1) * 100 : 0,
            funding: (toNumber(context.funding) || 0) * 100,
            name,
            url: `https://app.hyperliquid.xyz/trade/${name}`,
        }
    }
    return quotes
}
