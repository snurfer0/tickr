export type Source = "binance" | "hl" | "dex"
export type Tag = "SPOT" | "PERP" | "DEX"

/** One line of the user's coin list. */
export interface Coin {
    /** Unique id, also the key quotes are stored under: `binance:BTCUSDT`, `hl:BTC`, `dex:solana:<address>`. */
    key: string
    source: Source
    tag: Tag
    /** Trading pair (Binance), coin name (Hyperliquid) or token address (DexScreener). */
    symbol: string
    /** DexScreener chain id; empty for the exchanges. */
    chain: string
    /** Binance quote asset (`USDT`, `BTC`); empty for the other sources. `symbol` is base + quote. */
    quote: string
    /** Text shown in the panel. Empty means "use the name the feed reports". */
    label: string
}

export interface Quote {
    price: number
    /** 24 h change in percent. */
    change: number
    /** Page to open when the coin is clicked. */
    url: string
    /** Name as the feed knows it (token symbol, or Hyperliquid's `kPEPE`). */
    name?: string
    /** Perps only: funding in percent per hour. */
    funding?: number
}

export type Quotes = Record<string, Quote>
