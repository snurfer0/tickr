import QtQuick
import "tickr.mjs" as Tickr

// One search across Binance, Hyperliquid and DexScreener. The exchanges' market lists are loaded
// the first time something is typed; on-chain results are fetched per query and join when they
// arrive.
Item {
    id: search

    property string query: ""

    property var pairs: []              // Binance spot pairs
    property var perps: []              // Hyperliquid perps
    property var tokens: []             // DexScreener results for the current query
    property int pending: 0             // market lists still loading
    property bool searchingTokens: false
    property string failed: ""          // sources that did not answer, comma separated
    property int serial: 0              // drops DexScreener answers that arrive after a newer query
    property double loadedAt: 0

    readonly property string text: query.trim()
    readonly property bool busy: pending > 0 || searchingTokens
    readonly property var suggestions: text === "" ? []
        : Tickr.searchSpot(pairs, text, 3).concat(Tickr.searchPerps(perps, text, 3)).concat(tokens)

    function note(source, ok) {
        const names = failed === "" ? [] : failed.split(", ")
        const at = names.indexOf(source)
        if (ok && at >= 0) names.splice(at, 1)
        if (!ok && at < 0) names.push(source)
        failed = names.join(", ")
    }

    // The lists change slowly (new listings, halts); an hour-old copy is good enough.
    function load() {
        if (pending > 0 || Date.now() - loadedAt < 60 * 60 * 1000) return
        pending = 2
        loadedAt = Date.now()
        Tickr.request(Tickr.SPOT_LIST_URL, "", (status, json) => {
            if (status === 200) pairs = Tickr.decodeSpotList(json)
            note("Binance", status === 200)
            pending--
        })
        Tickr.request(Tickr.HYPERLIQUID_URL, Tickr.HYPERLIQUID_BODY, (status, json) => {
            if (status === 200) perps = Tickr.decodePerpList(json)
            note("Hyperliquid", status === 200)
            pending--
        })
    }

    function searchTokens() {
        const current = ++serial
        if (text.length < 2) { tokens = []; searchingTokens = false; return }
        const urls = Tickr.dexSearchUrls(text), answers = []
        urls.forEach(url => Tickr.request(url, "", (status, json) => {
            if (current !== serial) return
            answers.push(status === 200 ? json : null)
            if (answers.length < urls.length) return
            tokens = Tickr.decodeDexSearch(answers, 4)
            searchingTokens = false
            note("DexScreener", answers.some(answer => answer !== null))
        }))
    }

    onTextChanged: {
        if (text !== "") load()
        tokens = []
        searchingTokens = text.length >= 2
        debounce.restart()
    }

    Timer { id: debounce; interval: 350; onTriggered: search.searchTokens() }
}
