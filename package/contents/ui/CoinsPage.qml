pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "tickr.mjs" as Tickr

// Coins: one search across Binance, Hyperliquid and DexScreener, click to add, drag to reorder.
// The list is stored as text in config.coins, but nobody has to type it. Every change is saved
// at once.
ColumnLayout {
    id: page

    required property var config        // the widget's configuration (Plasmoid.configuration)

    property var pairs: []              // Binance spot pairs, loaded once
    property var perps: []              // Hyperliquid perps, loaded once
    property var tokens: []             // DexScreener results for the current query
    property bool searchingTokens: false
    property string failed: ""          // sources that did not answer, for one quiet note
    property string written: ""         // the last text this page stored, to tell our edits from outside ones
    property int searchSerial: 0        // drops DexScreener answers that arrive after a newer query

    readonly property string stored: config.coins
    readonly property string query: search.text.trim()
    // Exchanges answer from the lists already loaded; on-chain results join when they arrive.
    readonly property var suggestions: query === ""
        ? Tickr.searchSpot(pairs, "", 4).concat(Tickr.searchPerps(perps, "", 2))
        : Tickr.searchSpot(pairs, query, 3).concat(Tickr.searchPerps(perps, query, 3)).concat(tokens)

    spacing: Kirigami.Units.largeSpacing

    ListModel { id: chosen }

    // ---- the chosen list ----

    function load() {
        chosen.clear()
        Tickr.parseCoins(stored).forEach(coin => chosen.append(entryFor(coin)))
    }

    function entryFor(coin) {
        return { key: coin.key, source: coin.source, tag: coin.tag, symbol: coin.symbol, chain: coin.chain,
                 quote: coin.quote, label: coin.label, what: Tickr.describe(coin) }
    }

    function save() {
        const coins = []
        for (let i = 0; i < chosen.count; i++) coins.push(chosen.get(i))
        written = Tickr.formatCoins(coins)
        config.coins = written
        if (config.writeConfig) config.writeConfig()
    }

    function has(entry) {
        const coin = Tickr.parseCoins(entry)[0]
        if (!coin) return true
        for (let i = 0; i < chosen.count; i++) if (chosen.get(i).key === coin.key) return true
        return false
    }

    function add(entry) {
        const coin = Tickr.parseCoins(entry)[0]
        if (!coin || has(entry)) return
        chosen.append(entryFor(coin))
        save()
    }

    // ---- search ----

    function note(source, ok) {
        const names = failed === "" ? [] : failed.split(", ")
        const at = names.indexOf(source)
        if (ok && at >= 0) names.splice(at, 1)
        if (!ok && at < 0) names.push(source)
        failed = names.join(", ")
    }

    function searchTokens() {
        const serial = ++searchSerial
        if (query.length < 2) { tokens = []; searchingTokens = false; return }
        const urls = Tickr.dexSearchUrls(query), answers = []
        urls.forEach(url => Tickr.request(url, "", (status, json) => {
            if (serial !== searchSerial) return
            answers.push(status === 200 ? json : null)
            if (answers.length < urls.length) return
            tokens = Tickr.decodeDexSearch(answers, 4)
            searchingTokens = false
            note("DexScreener", answers.some(answer => !!answer))
        }))
    }

    function focusSearch() { search.forceActiveFocus() }

    Timer { id: debounce; interval: 350; onTriggered: page.searchTokens() }

    onQueryChanged: {
        tokens = []
        searchingTokens = query.length >= 2
        debounce.restart()
    }
    onStoredChanged: if (stored !== written) load()
    Component.onCompleted: {
        load()
        Tickr.request(Tickr.SPOT_LIST_URL, "", (status, json) => {
            pairs = Tickr.decodeSpotList(json)
            note("Binance", status === 200)
        })
        Tickr.request(Tickr.HYPERLIQUID_URL, Tickr.HYPERLIQUID_BODY, (status, json) => {
            perps = Tickr.decodePerpList(json)
            note("Hyperliquid", status === 200)
        })
    }

    // ---- search ----
    // Built on ActionTextField rather than SearchField: SearchField brings its own clear button,
    // with a backspace-shaped icon, that also fires `accepted` (which here adds the top result).
    Kirigami.ActionTextField {
        id: search
        objectName: "search"
        Layout.fillWidth: true
        placeholderText: i18n("Search a coin, perp or token, or paste a contract address")
        leftPadding: glass.width + Kirigami.Units.smallSpacing * 3
        inputMethodHints: Qt.ImhNoPredictiveText
        focusSequences: [StandardKey.Find]
        onAccepted: if (page.suggestions.length) page.add(page.suggestions[0].entry)      // Enter adds the top result

        Kirigami.Icon {
            id: glass
            anchors { left: parent.left; leftMargin: Kirigami.Units.smallSpacing * 2; verticalCenter: parent.verticalCenter }
            implicitWidth: Kirigami.Units.iconSizes.sizeForLabels
            implicitHeight: Kirigami.Units.iconSizes.sizeForLabels
            color: search.placeholderTextColor
            source: "search"
        }
        rightActions: [
            Kirigami.Action {
                icon.name: "window-close-symbolic"
                text: i18n("Clear")
                visible: search.text.length > 0
                onTriggered: { search.clear(); search.forceActiveFocus() }
            }
        ]
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        QQC2.Label {
            visible: page.query === "" && page.suggestions.length > 0
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: i18n("Popular")
        }

        Repeater {
            model: page.suggestions

            QQC2.ItemDelegate {
                id: hit
                required property var modelData
                // Re-evaluated whenever the chosen list changes.
                readonly property bool added: chosen.count >= 0 && page.has(modelData.entry)
                Layout.fillWidth: true
                enabled: !added
                onClicked: page.add(modelData.entry)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing * 2
                            QQC2.Label { text: hit.modelData.title; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            SourceBadge {
                                tag: hit.modelData.tag
                                chain: hit.modelData.chain
                                textColor: Kirigami.Theme.textColor
                            }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: hit.modelData.subtitle
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                        }
                    }
                    QQC2.Label {
                        visible: hit.modelData.price > 0
                        text: "$" + Tickr.price(hit.modelData.price)
                        opacity: 0.8
                        font.features: { "tnum": 1 }
                    }
                    Kirigami.Icon {
                        source: hit.added ? "checkmark" : "list-add"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        opacity: hit.added ? 0.5 : 1
                    }
                }
            }
        }

        RowLayout {
            visible: page.searchingTokens
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing * 2
            QQC2.BusyIndicator { implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: Kirigami.Units.iconSizes.small }
            QQC2.Label { opacity: 0.6; text: i18n("Searching on-chain tokens…") }
        }

        QQC2.Label {
            visible: !page.searchingTokens && page.suggestions.length === 0 && (page.query !== "" || page.failed !== "")
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
            text: page.query === "" ? i18n("Could not load the markets.") : i18n("Nothing matches “%1”.", page.query)
        }

        QQC2.Label {
            visible: page.failed !== ""
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            wrapMode: Text.Wrap
            color: Kirigami.Theme.neutralTextColor
            font: Kirigami.Theme.smallFont
            text: i18n("No answer from %1. Results from there are missing; check the connection or the firewall.", page.failed)
        }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    // ---- chosen ----
    RowLayout {
        Layout.fillWidth: true
        Kirigami.Heading { level: 4; text: i18n("In your ticker") }
        QQC2.Label { text: chosen.count; opacity: 0.5 }
        Item { Layout.fillWidth: true }
        QQC2.Label {
            visible: chosen.count > 1
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: i18n("Drag to reorder")
        }
    }

    QQC2.Label {
        visible: chosen.count === 0
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.6
        text: i18n("Nothing here yet. Search above and click a result to add it.")
    }

    ListView {
        id: view
        Layout.fillWidth: true
        implicitHeight: contentHeight
        interactive: false
        model: chosen
        moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: Kirigami.Units.shortDuration } }

        delegate: Item {
            id: slot
            required property int index
            required property string label
            required property string tag
            required property string what
            required property string source
            required property string symbol
            required property string chain
            required property string quote
            required property string key
            property bool renaming: false
            width: view.width
            height: card.implicitHeight

            function rename(text) {
                renaming = false
                if (text.trim() === label) return
                chosen.setProperty(index, "label", text.trim())
                page.save()
            }

            QQC2.ItemDelegate {
                id: card
                width: slot.width
                hoverEnabled: true
                down: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.ListItemDragHandle {
                        listItem: card
                        listView: view
                        onMoveRequested: (from, to) => chosen.move(from, to, 1)
                        onDropped: page.save()
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing * 2
                            QQC2.Label {
                                visible: !slot.renaming
                                text: Tickr.displayName(slot)
                                font.weight: Font.DemiBold
                            }
                            QQC2.TextField {
                                visible: slot.renaming
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                                placeholderText: i18n("Name shown in the panel")
                                text: slot.label
                                onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                                onAccepted: slot.rename(text)
                                onActiveFocusChanged: if (!activeFocus && slot.renaming) slot.rename(text)
                                Keys.onEscapePressed: { text = slot.label; slot.renaming = false }
                            }
                            SourceBadge {
                                tag: slot.tag
                                chain: slot.chain
                                textColor: Kirigami.Theme.textColor
                            }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: slot.what
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideMiddle
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        display: QQC2.AbstractButton.IconOnly
                        text: i18n("Rename")
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: slot.renaming = !slot.renaming
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"
                        display: QQC2.AbstractButton.IconOnly
                        text: i18n("Remove")
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: { chosen.remove(slot.index); page.save() }
                    }
                }
            }
        }
    }

}
