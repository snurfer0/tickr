import QtQuick
import QtQuick.Layouts
import "../package/contents/ui"

// The panel strip and both states of the popup (coins, and a search) with sample data, rendered
// off-screen by preview.py.
Rectangle {
    id: stage
    width: 830; height: 560
    color: "#15171c"

    readonly property var rows: [
        { label: "BTC", panelLabel: "BTC", tag: "SPOT", price: "84,005", change: -0.27, changeText: "−0.27%", detail: "", url: "x", known: true, stale: false },
        { label: "ETH", panelLabel: "ETH", tag: "SPOT", price: "2,706.99", change: -1.17, changeText: "−1.17%", detail: "", url: "x", known: true, stale: false },
        { label: "SOL", panelLabel: "SOL", tag: "SPOT", price: "120.00", change: 2.2, changeText: "+2.20%", detail: "", url: "x", known: true, stale: false },
        { label: "XMR", panelLabel: "XMR perp", tag: "PERP", price: "545.15", change: 0.66, changeText: "+0.66%", detail: "+0.0013%/h", url: "x", known: true, stale: false },
        { label: "WIF", panelLabel: "WIF", tag: "DEX", price: "0.2536", change: 5.55, changeText: "+5.55%", detail: "", url: "x", known: true, stale: false },
        { label: "BONK", panelLabel: "BONK", tag: "DEX", price: "0.0₅3867", change: 5.89, changeText: "+5.89%", detail: "", url: "x", known: true, stale: false, hidden: true }
    ]
    readonly property var results: [
        { entry: "PEPE", title: "PEPE", subtitle: "PEPE/USDT spot", tag: "SPOT", chain: "", price: 0.00000443, priceText: "0.0₅443", added: false },
        { entry: "hl:kPEPE", title: "kPEPE", subtitle: "kPEPE-USD perpetual", tag: "PERP", chain: "", price: 0.004427, priceText: "0.004427", added: true },
        { entry: "dex:ethereum:0x6982 = PEPE", title: "PEPE", subtitle: "Pepe · 0x69…1933 · $1.5M traded in 24 h", tag: "DEX", chain: "ethereum", price: 0.0000044, priceText: "0.0₅4423", added: false },
        { entry: "dex:solana:7nfd = PEPE", title: "PEPE", subtitle: "Pepe · 7nfd…iFF3 · $300K traded in 24 h", tag: "DEX", chain: "solana", price: 0.000004, priceText: "0.0₅4", added: false }
    ]

    Rectangle {                       // stand-in for the panel
        x: 20; y: 16; width: 790; height: 36; radius: 8; color: "#22252c"
        PanelRow {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: implicitWidth; height: parent.height
            rows: stage.rows.slice(0, 5)
        }
    }
    Rectangle {
        objectName: "popup"
        x: 20; y: 68; width: 380; height: Math.min(coins.implicitHeight, 480); radius: 10; color: "#22252c"
        CoinList { id: coins; anchors.fill: parent; rows: stage.rows; lists: ["Majors", "Memes", "Perps"] }
    }
    Rectangle {
        x: 430; y: 68; width: 380; height: Math.min(found.implicitHeight, 480); radius: 10; color: "#22252c"
        CoinList { id: found; anchors.fill: parent; rows: stage.rows; results: stage.results; searching: true }
        Component.onCompleted: found.focusSearch()
    }
    Timer { interval: 50; running: true; onTriggered: found.children[1].children[1].text = "pepe" }
}
