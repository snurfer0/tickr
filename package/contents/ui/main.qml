import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "tickr.mjs" as Tickr

PlasmoidItem {
    id: root

    readonly property var config: Plasmoid.configuration
    readonly property var coins: Tickr.parseCoins(config.coins)
    readonly property int interval: Math.max(3, config.interval)             // seconds
    readonly property int dexInterval: Math.max(interval, Tickr.DEX_MIN_INTERVAL_S)

    property var quotes: ({})          // coin key → quote
    property var seen: ({})            // coin key → time of its last good quote, ms
    property var rejected: ({})        // Binance pairs that do not exist or are halted
    property var ticks: ({})           // coin key → { dir: ±1, at: ms } for the last price move
    property double now: Date.now()

    readonly property var colors: Tickr.schemeColors(config.scheme, config.upColor, config.downColor)
    readonly property string fontFamily: config.fontFamily || Kirigami.Theme.defaultFont.family

    // What both views draw: one entry per coin, already formatted. A quote counts as stale after
    // three refreshes without an answer.
    readonly property var rows: coins.map(coin => {
        const quote = quotes[coin.key]
        const name = Tickr.displayName(coin, quote)
        const tick = ticks[coin.key]
        return {
            label: name,
            // In the panel a perp must not look like the spot price next to it.
            panelLabel: coin.tag === "PERP" && !coin.label ? name + " " + i18n("perp") : name,
            tag: coin.tag,
            price: quote ? Tickr.price(quote.price) : "—",
            change: quote ? quote.change : 0,
            changeText: quote ? Tickr.percent(quote.change) : "",
            detail: rejected[coin.key] ? i18n("not trading")
                : quote && quote.funding !== undefined ? Tickr.funding(quote.funding) : "",
            url: quote ? quote.url : "",
            known: !!quote,
            tick: tick ? tick.dir : 0,
            tickAt: tick ? tick.at : 0,
            stale: !quote || now - (seen[coin.key] || 0) > 3000 * (coin.source === "dex" ? dexInterval : interval)
        }
    })
    readonly property bool online: rows.some(row => !row.stale)

    function accept(fresh) {
        now = Date.now()
        const keys = Object.keys(fresh)
        if (!keys.length) return
        const stamps = {}, moved = {}
        keys.forEach(key => {
            stamps[key] = now
            const before = quotes[key]
            if (before && before.price !== fresh[key].price)
                moved[key] = { dir: fresh[key].price > before.price ? 1 : -1, at: now }
        })
        ticks = Object.assign({}, ticks, moved)
        quotes = Object.assign({}, quotes, fresh)
        seen = Object.assign({}, seen, stamps)
    }

    function reject(coin) {
        const next = Object.assign({}, rejected)
        next[coin.key] = true
        rejected = next
        if (!quotes[coin.key]) return
        const kept = Object.assign({}, quotes)
        delete kept[coin.key]
        quotes = kept
    }

    function pollBinance() {
        const wanted = Tickr.bySource(coins, "binance").filter(coin => !rejected[coin.key])
        if (!wanted.length) return
        Tickr.request(Tickr.binanceUrl(wanted), "", (status, json) => {
            if (status === 200) {
                const fresh = Tickr.decodeBinance(json, Date.now())
                accept(fresh)
                // Binance answers for halted pairs too; those come back without a quote.
                wanted.filter(coin => !fresh[coin.key]).forEach(reject)
            } else if (status === 400) {
                // One unknown symbol fails the whole batch: ask one by one to find it.
                wanted.forEach(coin => Tickr.request(Tickr.binanceUrl([coin]), "", (s, j) => {
                    if (s === 200) accept(Tickr.decodeBinance(j, Date.now()))
                    else if (s === 400) reject(coin)
                }))
            }
        })
    }

    function pollHyperliquid() {
        const wanted = Tickr.bySource(coins, "hl")
        if (!wanted.length) return
        Tickr.request(Tickr.HYPERLIQUID_URL, Tickr.HYPERLIQUID_BODY, (status, json) => {
            if (status === 200) accept(Tickr.decodeHyperliquid(json, wanted))
        })
    }

    function pollDex() {
        const wanted = Tickr.bySource(coins, "dex")
        Tickr.dexUrls(wanted).forEach(url => Tickr.request(url, "", (status, json) => {
            if (status === 200) accept(Tickr.decodeDex(json, wanted))
        }))
    }

    function refresh() {
        now = Date.now()
        pollBinance()
        pollHyperliquid()
    }

    onCoinsChanged: { rejected = ({}); refresh(); pollDex() }

    Timer { interval: root.interval * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { interval: root.dexInterval * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.pollDex() }

    Updater {
        id: updater
        config: root.config
        current: Plasmoid.metaData.version
    }

    // Settings live in Tickr's own window: changes take effect as they are made, so it has no
    // OK / Apply / Cancel. Plasma's dialog is kept only for the keyboard shortcut.
    property var settingsWindow: null
    function openSettings(section) {
        if (!settingsWindow) settingsWindow = settingsComponent.createObject(root)
        settingsWindow.open(section)
    }
    Component {
        id: settingsComponent
        SettingsWindow {
            config: root.config
            updater: updater
            onShortcutRequested: Plasmoid.internalAction("configure").trigger()
        }
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Tickr Settings…")
            icon.name: "configure"
            onTriggered: root.openSettings(0)
        }
    ]
    Component.onCompleted: {
        const standard = Plasmoid.internalAction("configure")
        if (standard) standard.visible = false
    }

    Plasmoid.icon: Qt.resolvedUrl("../icons/tickr.svg")
    toolTipMainText: "Tickr"
    toolTipSubText: rows.filter(row => row.known).map(row => row.label + "  " + row.price + "  " + row.changeText).join("\n")
        || i18n("Waiting for prices")

    compactRepresentation: PanelRow {
        rows: root.config.panelCount > 0 ? root.rows.slice(0, root.config.panelCount) : root.rows
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        showLabel: root.config.showLabel
        showChange: root.config.showChange
        flash: root.config.flash
        textColor: Kirigami.Theme.textColor
        up: root.colors.up
        down: root.colors.down
        fontFamily: root.fontFamily
        fontSize: root.config.fontSize
        bold: root.config.bold
        gap: root.config.spacing
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: CoinList {
        rows: root.rows
        online: root.online
        textColor: Kirigami.Theme.textColor
        highlightColor: Kirigami.Theme.highlightColor
        up: root.colors.up
        down: root.colors.down
        fontFamily: root.fontFamily
        caption: i18n("24 h change")
        offlineText: i18n("offline")
        configureText: i18n("Edit coins")
        notice: updater.status === "available" ? i18n("Tickr %1 is available", updater.release.version)
            : updater.status === "installed" ? i18n("Tickr %1 is installed", updater.release.version) : ""
        noticeAction: updater.status === "available" ? i18n("Update") : updater.status === "installed" ? i18n("Restart Plasma") : ""
        Layout.minimumWidth: 300
        Layout.preferredWidth: 340
        Layout.minimumHeight: Math.min(implicitHeight, 160)
        Layout.preferredHeight: Math.min(implicitHeight, 520)
        onOpened: url => Qt.openUrlExternally(url)
        onConfigure: root.openSettings(0)
        onNoticeClicked: updater.status === "available" ? updater.install() : updater.restartPlasma()
    }
}
