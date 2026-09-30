import QtQuick

// Where a price comes from: a small coloured pill per source, plus the chain for on-chain tokens.
Row {
    id: badge

    property string tag: "SPOT"          // SPOT | PERP | DEX
    property string chain: ""
    property color textColor: "#ffffff"
    property string fontFamily: ""

    readonly property var sources: ({
        SPOT: { name: "Binance", color: "#f0b90b" },
        PERP: { name: "Hyperliquid", color: "#3ddbc1" },
        DEX: { name: "DexScreener", color: "#8ea2c6" }
    })
    readonly property var source: sources[tag] || sources.SPOT

    spacing: 4

    Rectangle {
        width: name.implicitWidth + 10
        height: name.implicitHeight + 4
        radius: height / 2
        color: Qt.alpha(badge.source.color, 0.16)
        border.width: 1
        border.color: Qt.alpha(badge.source.color, 0.55)

        Text {
            id: name
            anchors.centerIn: parent
            text: badge.source.name
            color: badge.source.color
            font.family: badge.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
    Rectangle {
        visible: badge.chain !== ""
        width: chainName.implicitWidth + 10
        height: chainName.implicitHeight + 4
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(badge.textColor, 0.25)

        Text {
            id: chainName
            anchors.centerIn: parent
            text: badge.chain
            color: badge.textColor
            opacity: 0.7
            font.family: badge.fontFamily
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }
}
