pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// The popup: every coin with its market, funding (perps), price and 24 h change. Plain QtQuick.
Item {
    id: list

    property var rows: []
    property bool online: true
    property color textColor: "#ffffff"
    property color highlightColor: "#3daee9"
    property string fontFamily: ""
    property string up: "#4ade80"        // empty = no colour, use the text colour
    property string down: "#f87171"
    property string caption: "24 h change"
    property string offlineText: "offline"
    property string configureText: "Edit coins"
    property string notice: ""           // one line above the list, e.g. an available update
    property string noticeAction: ""

    readonly property int rowHeight: 36

    signal opened(string url)
    signal configure()
    signal noticeClicked()

    function tint(change) {
        const colour = change >= 0 ? up : down
        return colour === "" ? textColor : colour
    }

    implicitWidth: 340
    implicitHeight: header.height + banner.height + rows.length * rowHeight + 20

    Item {
        id: header
        width: parent.width
        height: 38

        Text {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: "Tickr"
            color: list.textColor
            font.family: list.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Row {
            anchors { right: edit.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: list.online ? "#4ade80" : "#f87171"
            }
            Text {
                text: list.online ? list.caption : list.offlineText
                color: list.textColor
                opacity: 0.5
                font.family: list.fontFamily
                font.pixelSize: 11
            }
        }
        Link {
            id: edit
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: list.configureText
            onClicked: list.configure()
        }
    }

    Rectangle {
        id: banner
        anchors { top: header.bottom; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
        visible: list.notice !== ""
        height: visible ? 32 : 0
        radius: 6
        color: Qt.alpha(list.highlightColor, 0.15)

        Text {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: list.notice
            color: list.textColor
            font.family: list.fontFamily
            font.pixelSize: 12
        }
        Link {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: list.noticeAction
            onClicked: list.noticeClicked()
        }
    }

    ListView {
        anchors { top: banner.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Keyed by position, so a refresh does not rebuild the rows or lose the hover and scroll.
        model: list.rows.length

        delegate: MouseArea {
            id: line
            required property int index
            readonly property var row: list.rows[index] || {}
            width: ListView.view.width
            height: list.rowHeight
            hoverEnabled: true
            enabled: !!row.url
            cursorShape: Qt.PointingHandCursor
            onClicked: list.opened(row.url)

            Rectangle {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                radius: 6
                color: list.highlightColor
                opacity: line.containsMouse ? 0.18 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                opacity: line.row.stale ? 0.45 : 1

                Text {
                    text: line.row.label || ""
                    color: list.textColor
                    font.family: list.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.maximumWidth: 110
                }
                Text {
                    text: line.row.tag || ""
                    color: list.textColor
                    opacity: 0.4
                    font.family: list.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
                Text {
                    text: line.row.detail || ""
                    color: list.textColor
                    opacity: 0.4
                    font.family: list.fontFamily
                    font.pixelSize: 10
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                }
                Text {
                    text: line.row.price || ""
                    color: list.textColor
                    font.family: list.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: line.row.changeText || ""
                    color: list.tint(line.row.change)
                    font.family: list.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 62
                }
            }
        }
    }

    // Small text button that underlines on hover.
    component Link: MouseArea {
        id: link
        property alias text: label.text
        width: label.implicitWidth
        height: 24
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Text {
            id: label
            anchors.centerIn: parent
            color: link.containsMouse ? list.highlightColor : list.textColor
            opacity: link.containsMouse ? 1 : 0.6
            font.family: list.fontFamily
            font.pixelSize: 11
            font.underline: link.containsMouse
        }
    }
}
