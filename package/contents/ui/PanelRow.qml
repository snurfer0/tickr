pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// The panel strip: LABEL price change, repeated. Plain QtQuick so it can be rendered outside Plasma.
MouseArea {
    id: strip

    property var rows: []
    property bool vertical: false         // in a vertical panel there is no room for text
    property bool showLabel: true
    property bool showChange: true
    property bool flash: true
    property color textColor: "#ffffff"
    property string up: "#4ade80"         // empty = no colour, use the text colour
    property string down: "#f87171"
    property string fontFamily: ""
    property int fontSize: 13
    property bool bold: false
    property int gap: 16

    function tint(change) {
        const colour = change >= 0 ? up : down
        return colour === "" ? textColor : colour
    }

    implicitWidth: line.implicitWidth + 20
    Layout.minimumWidth: vertical ? height : implicitWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    cursorShape: Qt.PointingHandCursor

    Text {
        visible: strip.vertical
        anchors.centerIn: parent
        text: "₿"
        color: strip.textColor
        font.pixelSize: Math.round(strip.width * 0.5)
    }

    Row {
        id: line
        visible: !strip.vertical
        anchors.centerIn: parent
        spacing: strip.gap

        // Keyed by position, not by the rows array: a new array arrives on every refresh, and an
        // array model would rebuild every delegate each time.
        Repeater {
            model: strip.rows.length

            Row {
                id: coin
                required property int index
                readonly property var row: strip.rows[index] || {}
                property real glow: 0             // 1 right after the price moved, fading to 0

                spacing: Math.round(strip.fontSize * 0.4)
                opacity: row.stale ? 0.45 : 1

                readonly property double tickAt: row.tickAt || 0
                onTickAtChanged: if (strip.flash && tickAt > 0 && Date.now() - tickAt < 2000) fade.restart()
                NumberAnimation { id: fade; target: coin; property: "glow"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }

                Text {
                    visible: strip.showLabel
                    anchors.baseline: number.baseline
                    text: coin.row.panelLabel || coin.row.label || ""
                    color: strip.textColor
                    opacity: 0.5
                    font.family: strip.fontFamily
                    font.pixelSize: Math.round(strip.fontSize * 0.77)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                }
                Text {
                    id: number
                    text: coin.row.price || ""
                    // The price lights up in the direction it just moved, then settles back.
                    color: coin.glow > 0 ? Qt.tint(strip.textColor, Qt.alpha(strip.tint(coin.row.tick), coin.glow)) : strip.textColor
                    font.family: strip.fontFamily
                    font.pixelSize: strip.fontSize
                    font.weight: strip.bold ? Font.Bold : Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    visible: strip.showChange && !!coin.row.known
                    anchors.baseline: number.baseline
                    text: coin.row.changeText || ""
                    color: strip.tint(coin.row.change)
                    opacity: (coin.row.change >= 0 ? strip.up : strip.down) === "" ? 0.6 : 1
                    font.family: strip.fontFamily
                    font.pixelSize: Math.round(strip.fontSize * 0.85)
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
