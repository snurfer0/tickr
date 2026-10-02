import { describe, expect, test } from "bun:test"
import {
    addCoin,
    binanceUrl,
    bySource,
    decodeBinance,
    decodeDex,
    decodeDexSearch,
    decodeHyperliquid,
    decodePerpList,
    decodeRelease,
    decodeSpotList,
    describe as describeCoin,
    dexSearchUrls,
    dexUrls,
    displayName,
    formatCoins,
    funding,
    hasCoin,
    installCommand,
    isNewer,
    moveCoin,
    parseCoins,
    percent,
    price,
    removeCoin,
    SCHEMES,
    schemeColors,
    searchPerps,
    searchSpot,
    shortAddress,
    toggleCoin,
} from "../src/index.ts"

const WIF = "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm"
const BONK = "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263"
const NOW = 1790774566596

const LIST = `
  BTC, binance:eth
  binance:ETH/BTC
  WBTC            # must not be read as W/BTC
  solusdc = SOL-C
  hl:BTC
  hl:PEPE
  dex:solana:${WIF}
  dex:solana:${BONK} = BONK
  dex:base:0x532f27101965dd16442E59d40670FaF5eBB142E4
  BTC             # duplicate, dropped
  nonsense:thing
`

describe("parseCoins", () => {
    const coins = parseCoins(LIST)

    test("keys, in order, without duplicates or unknown sources", () => {
        expect(coins.map((c) => c.key)).toEqual([
            "binance:BTCUSDT",
            "binance:ETHUSDT",
            "binance:ETHBTC",
            "binance:WBTCUSDT",
            "binance:SOLUSDC",
            "hl:BTC",
            "hl:PEPE",
            `dex:solana:${WIF}`,
            `dex:solana:${BONK}`,
            "dex:base:0x532f27101965dd16442E59d40670FaF5eBB142E4",
        ])
    })

    test("labels", () => {
        expect(coins.map((c) => c.label)).toEqual(["BTC", "ETH", "ETH/BTC", "WBTC", "SOL-C", "", "", "", "BONK", ""])
    })

    test("display names: own label, then the feed's name, then the symbol", () => {
        const [spot, perp, token] = parseCoins(`BTC, hl:pepe, dex:solana:${WIF}`)
        if (spot === undefined || perp === undefined || token === undefined) throw new Error("three coins expected")
        expect(displayName(spot)).toBe("BTC")
        expect(displayName(perp)).toBe("PEPE")
        expect(displayName(perp, { price: 1, change: 0, url: "", name: "kPEPE" })).toBe("kPEPE")
        expect(displayName(token)).toBe("EKpQ…zcjm")
        expect(displayName(token, { price: 1, change: 0, url: "", name: "WIF" })).toBe("WIF")
        const [named] = parseCoins("hl:PEPE = PEPE-PERP")
        expect(named && displayName(named, { price: 1, change: 0, url: "", name: "kPEPE" })).toBe("PEPE-PERP")
    })

    test("tags follow the source", () => {
        expect(coins.map((c) => c.tag)).toEqual([
            ...Array(5).fill("SPOT"),
            ...Array(2).fill("PERP"),
            ...Array(3).fill("DEX"),
        ])
    })

    test("empty and junk input", () => {
        expect(parseCoins("")).toEqual([])
        expect(parseCoins("# only a comment\n , ,\n:::")).toEqual([])
        expect(parseCoins("dex:solana")).toEqual([])
    })
})

describe("formatCoins", () => {
    test("round trip keeps keys, labels and order", () => {
        const coins = parseCoins(LIST)
        const again = parseCoins(formatCoins(coins))
        expect(again).toEqual(coins)
    })

    test("writes the shortest entry that reads back the same", () => {
        const text = formatCoins(parseCoins("BTC, solusdc, binance:ETH/BTC = Ratio, hl:btc = Perp, dex:base:0xabc"))
        expect(text.split("\n")).toEqual([
            "BTC",
            "binance:SOLUSDC",
            "binance:ETH/BTC = Ratio",
            "hl:btc = Perp",
            "dex:base:0xabc",
        ])
    })

    test("describe", () => {
        const [spot, perp, token] = parseCoins(`binance:ETH/BTC, hl:BTC, dex:solana:${WIF}`)
        expect(spot && describeCoin(spot)).toBe("ETH/BTC spot")
        expect(perp && describeCoin(perp)).toBe("BTC-USD perpetual")
        expect(token && describeCoin(token)).toBe("EKpQ…zcjm")
    })
})

describe("adding from search", () => {
    test("adds once, keeps order, ignores junk", () => {
        const list = addCoin("BTC, ETH", "hl:HYPE")
        expect(list.split("\n")).toEqual(["BTC", "ETH", "hl:HYPE"])
        expect(addCoin(list, "BTC")).toBe(list)
        expect(addCoin(list, "nonsense:thing")).toBe(list)
        expect(hasCoin(list, "binance:BTCUSDT")).toBe(true)
        expect(hasCoin(list, "hl:BTC")).toBe(false)
        expect(addCoin("", `dex:solana:${WIF} = WIF`)).toBe(`dex:solana:${WIF} = WIF`)
    })

    test("remove and move", () => {
        const list = "BTC\nETH\nhl:HYPE = Hype"
        expect(removeCoin(list, "binance:ETHUSDT")).toBe("BTC\nhl:HYPE = Hype")
        expect(removeCoin(list, "nope")).toBe(list)
        expect(moveCoin(list, 2, 0)).toBe("hl:HYPE = Hype\nBTC\nETH")
        expect(moveCoin(list, 0, 2)).toBe("ETH\nhl:HYPE = Hype\nBTC")
        expect(moveCoin(list, 1, 1)).toBe(list)
        expect(moveCoin(list, 5, 0)).toBe(list)
        expect(moveCoin(list, 0, 9)).toBe(list)
    })

    test("hide and show", () => {
        const list = "BTC\nbinance:ETH/BTC = Ratio\nhl:HYPE"
        const hidden = toggleCoin(toggleCoin(list, "binance:ETHBTC"), "hl:HYPE")
        expect(hidden).toBe("BTC\n!binance:ETH/BTC = Ratio\n!hl:HYPE")
        expect(parseCoins(hidden).map((c) => c.hidden)).toEqual([false, true, true])
        expect(parseCoins(hidden).map((c) => c.key)).toEqual(parseCoins(list).map((c) => c.key))
        expect(parseCoins("! hl:HYPE")[0]?.hidden).toBe(true)
        expect(hasCoin(hidden, "hl:HYPE")).toBe(true)
        expect(addCoin(hidden, "hl:HYPE")).toBe(hidden)
        expect(moveCoin(hidden, 2, 0)).toBe("!hl:HYPE\nBTC\n!binance:ETH/BTC = Ratio")
        expect(removeCoin(hidden, "binance:ETHBTC")).toBe("BTC\n!hl:HYPE")
        expect(toggleCoin(hidden, "nope")).toBe(hidden)
        expect(toggleCoin(toggleCoin(hidden, "hl:HYPE"), "binance:ETHBTC")).toBe(list)
    })
})

describe("search", () => {
    const pairs = decodeSpotList([
        { symbol: "BTCUSDT", bidPrice: "83999", askPrice: "84001" },
        { symbol: "BTCUSDC", bidPrice: "84000", askPrice: "84000" },
        { symbol: "WBTCUSDT", bidPrice: "84000", askPrice: "84000" },
        { symbol: "ETHBTC", bidPrice: "0.03", askPrice: "0.03" },
        { symbol: "ETHUSDT", bidPrice: "2700", askPrice: "2700" },
        // Halted on Binance: still listed, but with an empty order book.
        { symbol: "XMRUSDT", bidPrice: "0.00000000", askPrice: "0.00000000" },
        { symbol: "WEIRD", bidPrice: "1", askPrice: "1" },
    ])

    test("spot list splits base and quote, drops halted and unknown pairs", () => {
        expect(pairs).toHaveLength(5)
        expect(pairs[3]).toEqual({ base: "ETH", quote: "BTC", price: 0.03 })
        expect(searchSpot(pairs, "btc", 1)[0]?.price).toBe(84000)
        expect(searchSpot(pairs, "xmr", 5)).toEqual([])
        expect(searchSpot(pairs, "ethbtc", 2)[0]?.price).toBe(0)
    })

    test("spot: one result per coin, exact name first; a whole pair finds that pair", () => {
        const found = searchSpot(pairs, "btc", 10)
        expect(found.map((s) => s.entry)).toEqual(["BTC", "WBTC"])
        expect(found.map((s) => s.subtitle)).toEqual(["BTC/USDT spot", "WBTC/USDT spot"])
        expect(searchSpot(pairs, "eth", 10).map((s) => s.entry)).toEqual(["ETH"])
        expect(searchSpot(pairs, "eth/btc", 10).map((s) => s.entry)).toEqual(["binance:ETH/BTC"])
        expect(searchSpot(pairs, "btcusdc", 10).map((s) => s.title)).toEqual(["BTC/USDC"])
        for (const s of [...found, ...searchSpot(pairs, "ethbtc", 10)]) expect(parseCoins(s.entry)).toHaveLength(1)
        expect(parseCoins("binance:ETH/BTC")[0]?.key).toBe("binance:ETHBTC")
    })

    test("spot: empty query lists popular coins that exist", () => {
        expect(searchSpot(pairs, "", 10).map((s) => s.entry)).toEqual(["BTC", "ETH"])
    })

    test("perps: PEPE finds kPEPE, delisted markets are hidden, prices come along", () => {
        const perps = decodePerpList([
            { universe: [{ name: "BTC" }, { name: "kPEPE" }, { name: "OLD", isDelisted: true }, { name: "PEOPLE" }] },
            [{ midPx: "84000" }, { midPx: null, markPx: "0.0043" }, { midPx: "1" }, {}],
        ])
        expect(perps).toEqual([
            { name: "BTC", price: 84000 },
            { name: "kPEPE", price: 0.0043 },
            { name: "PEOPLE", price: 0 },
        ])
        expect(searchPerps(perps, "pepe", 5).map((s) => s.entry)).toEqual(["hl:kPEPE"])
        expect(searchPerps(perps, "pe", 5).map((s) => s.entry)).toEqual(["hl:kPEPE", "hl:PEOPLE"])
        expect(searchPerps(perps, "", 5).map((s) => s.entry)).toEqual(["hl:BTC", "hl:kPEPE"])
        expect(searchPerps(perps, "btc", 1)[0]).toMatchObject({
            price: 84000,
            subtitle: "BTC-USD perpetual",
            chain: "",
        })
        expect(decodePerpList(null)).toEqual([])
    })

    test("dex: one suggestion per token, ranked by volume so untraded copycats sink", () => {
        const pair = (
            chainId: string,
            address: string,
            symbol: string,
            priceUsd: string,
            usd: number,
            h24: number,
        ) => ({
            chainId,
            baseToken: { address, symbol, name: `${symbol} coin` },
            priceUsd,
            liquidity: { usd },
            volume: { h24 },
        })
        const busy = { ...pair("solana", "A", "$WIF", "0.25", 7300000, 1300000), pairAddress: "pool1" }
        const found = decodeDexSearch(
            [
                {
                    pairs: [
                        pair("ethereum", "0xFAKE", "WIF", "1.35", 675000000, 0),
                        pair("solana", "A", "$WIF", "0.24", 900, 5000),
                    ],
                },
                // The second response repeats a pool: it must not be counted twice.
                { pairs: [busy, busy, pair("base", "0xB", "WIF", "0.26", 4000, 2500)] },
                null,
            ],
            5,
        )
        expect(found.map((s) => s.entry)).toEqual([
            "dex:solana:A = WIF",
            "dex:base:0xB = WIF",
            "dex:ethereum:0xFAKE = WIF",
        ])
        expect(found[0]).toEqual({
            entry: "dex:solana:A = WIF",
            title: "WIF",
            subtitle: "$WIF coin · A · $1.3M traded in 24 h",
            tag: "DEX",
            chain: "solana",
            price: 0.25,
        })
        expect(found[2]).toMatchObject({ subtitle: "WIF coin · 0xFAKE · almost no trading", chain: "ethereum" })
        expect(parseCoins(found[0]?.entry ?? "")[0]).toMatchObject({ key: "dex:solana:A", label: "WIF" })
        expect(decodeDexSearch([{ pairs: null }, 7], 5)).toEqual([])
        expect(dexSearchUrls(" dog wif ")).toEqual(["https://api.dexscreener.com/latest/dex/search?q=dog%20wif"])
        expect(dexSearchUrls("wif").map((u) => u.split("q=")[1])).toEqual(["wif", "%24wif"])
        expect(dexSearchUrls("EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm")).toHaveLength(1)
    })
})

describe("schemes", () => {
    test("preset, mono, custom and unknown ids", () => {
        expect(schemeColors("classic", "", "")).toEqual({ up: "#4ade80", down: "#f87171" })
        expect(schemeColors("mono", "#111", "#222")).toEqual({ up: "", down: "" })
        expect(schemeColors("custom", "#111", "#222")).toEqual({ up: "#111", down: "#222" })
        expect(schemeColors("nope", "", "")).toEqual({ up: "#4ade80", down: "#f87171" })
        expect(new Set(SCHEMES.map((s) => s.id)).size).toBe(SCHEMES.length)
    })
})

describe("requests", () => {
    const coins = parseCoins(LIST)

    test("binance: one symbol, many symbols, none", () => {
        expect(binanceUrl([])).toBe("")
        expect(binanceUrl(parseCoins("BTC"))).toEndWith("?symbol=BTCUSDT")
        expect(decodeURIComponent(binanceUrl(parseCoins("BTC,ETH")))).toEndWith('?symbols=["BTCUSDT","ETHUSDT"]')
    })

    test("dexscreener: one call per chain, 30 addresses per call", () => {
        expect(dexUrls(bySource(coins, "dex"))).toEqual([
            `https://api.dexscreener.com/tokens/v1/solana/${WIF},${BONK}`,
            "https://api.dexscreener.com/tokens/v1/base/0x532f27101965dd16442E59d40670FaF5eBB142E4",
        ])
        const many = parseCoins(Array.from({ length: 31 }, (_, i) => `dex:solana:addr${i}`).join("\n"))
        expect(dexUrls(many)).toHaveLength(2)
    })
})

describe("decoding", () => {
    test("binance batch and single", () => {
        const row = { symbol: "BTCUSDT", lastPrice: "83758.50", priceChangePercent: "-0.749" }
        expect(decodeBinance([row], NOW)["binance:BTCUSDT"]).toMatchObject({ price: 83758.5, change: -0.749 })
        expect(decodeBinance(row, NOW)["binance:BTCUSDT"]?.price).toBe(83758.5)
        expect(decodeBinance({ ...row, closeTime: NOW - 2000 }, NOW)["binance:BTCUSDT"]?.price).toBe(83758.5)
    })

    test("binance: a halted pair gives no quote instead of its frozen last price", () => {
        const xmr = {
            symbol: "XMRUSDT",
            lastPrice: "118.70",
            priceChangePercent: "4.766",
            closeTime: NOW - 21 * 86400000,
        }
        expect(decodeBinance([xmr], NOW)).toEqual({})
    })

    test("binance error body and garbage give nothing", () => {
        expect(decodeBinance({ code: -1121, msg: "Invalid symbol." }, NOW)).toEqual({})
        expect(decodeBinance(null, NOW)).toEqual({})
        expect(decodeBinance([{ symbol: "X", lastPrice: "0" }, 7, "text"], NOW)).toEqual({})
    })

    test("hyperliquid: exact name, case-insensitive, per-thousand fallback", () => {
        const json = [
            { universe: [{ name: "BTC" }, { name: "kPEPE" }] },
            [
                { midPx: "84000", markPx: "83990", prevDayPx: "80000", funding: "0.0000125" },
                { midPx: null, markPx: "0.0043", prevDayPx: "0.0040", funding: "-0.00002" },
            ],
        ]
        const quotes = decodeHyperliquid(json, parseCoins("hl:btc, hl:PEPE, hl:NOPE"))
        expect(quotes["hl:btc"]).toMatchObject({ price: 84000, name: "BTC" })
        expect(quotes["hl:btc"]?.change).toBeCloseTo(5)
        expect(quotes["hl:btc"]?.funding).toBeCloseTo(0.00125)
        expect(quotes["hl:PEPE"]).toMatchObject({ price: 0.0043, name: "kPEPE" })
        expect(quotes["hl:NOPE"]).toBeUndefined()
        expect(decodeHyperliquid({ nope: 1 }, parseCoins("hl:BTC"))).toEqual({})
    })

    test("dexscreener: busiest pool where the token is the base, liquidity breaks ties", () => {
        const pair = (address: string, priceUsd: string, usd: number, h24: number, vol: number) => ({
            chainId: "solana",
            url: `https://dexscreener.com/solana/${usd}`,
            baseToken: { address, symbol: "$WIF" },
            priceUsd,
            liquidity: { usd },
            volume: { h24: vol },
            priceChange: { h24 },
        })
        const json = [
            pair(WIF, "9.99", 500000000, 0, 0),
            pair(WIF, "0.25", 1000, 1, 800),
            pair(WIF, "0.26", 9000, 5.9, 120000),
            pair("other", "9", 99999, 0, 999999),
        ]
        const quotes = decodeDex(json, parseCoins(`dex:solana:${WIF}`))
        expect(quotes[`dex:solana:${WIF}`]).toEqual({
            price: 0.26,
            change: 5.9,
            name: "WIF",
            url: "https://dexscreener.com/solana/9000",
        })
        const quiet = [pair(WIF, "0.30", 10, 0, 0), pair(WIF, "0.31", 20, 0, 0)]
        expect(decodeDex(quiet, parseCoins(`dex:solana:${WIF}`))[`dex:solana:${WIF}`]?.price).toBe(0.31)
        expect(decodeDex(null, [])).toEqual({})
    })

    test("dexscreener: EVM addresses match whatever their case", () => {
        const json = [{ chainId: "base", baseToken: { address: "0xABCDEF", symbol: "X" }, priceUsd: "2" }]
        expect(decodeDex(json, parseCoins("dex:base:0xabcdef"))["dex:base:0xabcdef"]?.price).toBe(2)
    })
})

describe("formatting", () => {
    test.each([
        [83758.5, "83,759"],
        [1234567.2, "1,234,567"],
        [2694.75, "2,694.75"],
        [119.515, "119.52"],
        [1, "1.00"],
        [0.255665, "0.2557"],
        [0.5, "0.5"],
        [0.004343, "0.004343"],
        [0.0001, "0.0001"],
        [0.0000999999, "0.0001"],
        [0.00001, "0.0₄1"],
        [0.000003883, "0.0₅3883"],
        [0.0000000000012345, "0.0₁₁1235"],
        [0, "—"],
        [-5, "—"],
        [Number.NaN, "—"],
    ])("price(%p) = %p", (value, text) => {
        expect(price(value)).toBe(text)
    })

    test.each([
        [0.749, "+0.75%"],
        [-12.34, "−12.3%"],
        [250.4, "+250%"],
        [0, "0.00%"],
        [Number.NaN, "—"],
    ])("percent(%p) = %p", (value, text) => {
        expect(percent(value)).toBe(text)
    })

    test("funding", () => {
        expect(funding(0.00125)).toBe("+0.0013%/h")
        expect(funding(-0.002)).toBe("−0.0020%/h")
        expect(funding(0)).toBe("0.0000%/h")
    })
})

describe("updates", () => {
    const sha = "a".repeat(64)
    const asset = (version: string, digest = `sha256:${sha}`) => ({
        browser_download_url: `https://github.com/snurfer0/tickr/releases/download/v${version}/tickr-${version}.plasmoid`,
        digest,
    })

    test("reads a release built by the release workflow", () => {
        expect(decodeRelease({ tag_name: "v1.2.3", assets: [{ name: "notes.txt" }, asset("1.2.3")] })).toEqual({
            version: "1.2.3",
            download: "https://github.com/snurfer0/tickr/releases/download/v1.2.3/tickr-1.2.3.plasmoid",
            sha256: sha,
            page: "https://github.com/snurfer0/tickr/releases/tag/v1.2.3",
        })
    })

    test("refuses anything it could not safely hand to a shell", () => {
        expect(decodeRelease({ tag_name: "v1.2.3", assets: [asset("1.2.3", "")] })).toBeNull()
        expect(decodeRelease({ tag_name: "v1.2.3", assets: [asset("1.2.3", "sha256:'; rm -rf ~")] })).toBeNull()
        expect(decodeRelease({ tag_name: "v1.2.3'; x", assets: [asset("1.2.3")] })).toBeNull()
        expect(decodeRelease({ tag_name: "v1.2.4", assets: [asset("1.2.3")] })).toBeNull()
        expect(decodeRelease({ tag_name: "v1.2.3", prerelease: true, assets: [asset("1.2.3")] })).toBeNull()
        expect(decodeRelease({ message: "API rate limit exceeded" })).toBeNull()
        expect(decodeRelease(null)).toBeNull()
    })

    test("version order", () => {
        expect(isNewer("0.2.0", "0.1.9")).toBe(true)
        expect(isNewer("0.10.0", "0.9.0")).toBe(true)
        expect(isNewer("1.0.0", "1.0.0")).toBe(false)
        expect(isNewer("0.9.9", "1.0.0")).toBe(false)
        expect(isNewer("x", "1.0.0")).toBe(false)
    })

    test("install command checks the file before installing it", () => {
        const release = decodeRelease({ tag_name: "v1.2.3", assets: [asset("1.2.3")] })
        if (release === null) throw new Error("release expected")
        const command = installCommand(release)
        expect(command.indexOf("sha256sum -c")).toBeLessThan(command.indexOf("kpackagetool6"))
        expect(command).toEndWith("&& echo TICKR_UPDATED")
    })

    test("short addresses", () => {
        expect(shortAddress("EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm")).toBe("EKpQ…zcjm")
        expect(shortAddress("0xabc")).toBe("0xabc")
    })
})
