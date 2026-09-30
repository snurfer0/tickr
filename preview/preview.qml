import QtQuick
import QtQuick.Layouts
import "../package/contents/ui"

// Both views with fixed sample rows on a dark backdrop, rendered off-screen by preview.py.
Rectangle {
    id: stage
    width: 900; height: 420
    color: "#15171c"

    readonly property var rows: [
        { label: "BTC", tag: "SPOT", price: "84,005", change: -0.27, changeText: "−0.27%", detail: "", url: "x", known: true, stale: false },
        { label: "ETH", tag: "SPOT", price: "2,706.99", change: -1.17, changeText: "−1.17%", detail: "", url: "x", known: true, stale: false },
        { label: "SOL", tag: "SPOT", price: "120.00", change: 2.2, changeText: "+2.20%", detail: "", url: "x", known: true, stale: false },
        { label: "HYPE", tag: "PERP", price: "86.58", change: -2.09, changeText: "−2.09%", detail: "+0.0013%/h", url: "x", known: true, stale: false },
        { label: "kPEPE", tag: "PERP", price: "0.004356", change: 0.97, changeText: "+0.97%", detail: "−0.0020%/h", url: "x", known: true, stale: false },
        { label: "WIF", tag: "DEX", price: "0.2536", change: 5.55, changeText: "+5.55%", detail: "", url: "x", known: true, stale: false },
        { label: "BONK", tag: "DEX", price: "0.0₅3867", change: 5.89, changeText: "+5.89%", detail: "", url: "x", known: true, stale: true },
        { label: "NOPE", tag: "SPOT", price: "—", change: 0, changeText: "", detail: "not trading", url: "", known: false, stale: true }
    ]

    Rectangle {                       // stand-in for the panel
        x: 20; y: 20; width: 860; height: 36; radius: 8; color: "#22252c"
        PanelRow {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Layout.minimumWidth; height: parent.height
            rows: stage.rows.slice(0, 6)
        }
    }
    Rectangle {                       // stand-in for the popup
        x: 20; y: 76; width: 340; height: list.implicitHeight; radius: 10; color: "#22252c"
        CoinList { id: list; anchors.fill: parent; rows: stage.rows }
    }
}
