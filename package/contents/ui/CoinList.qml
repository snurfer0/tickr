pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// The popup: a search box, then either the lists and the coins of the one on show or, while typing,
// matches from Binance, Hyperliquid and DexScreener to add with a click. Styled by hand, so it
// looks the same inside Plasma and in the off-screen preview.
Item {
    id: list

    property var rows: []                // the coins of the list on show, formatted by main.qml
    property var lists: [""]             // list names, "" for one nobody has named
    property int active: 0               // position of the list on show
    property var results: []             // search matches, each with `added`
    property bool searching: false       // a search is still running
    property string failed: ""           // sources that did not answer
    property bool online: true
    property color textColor: "#ffffff"
    property color highlightColor: "#3daee9"
    property color backgroundColor: "#22252c"
    property string fontFamily: ""
    property string up: "#4ade80"        // empty = no colour, use the text colour
    property string down: "#f87171"
    property string notice: ""           // one line above the list, e.g. an available update
    property string noticeAction: ""
    property var tr: text => text        // translator; main.qml passes Plasma's i18n

    readonly property alias query: input.text
    readonly property bool typing: input.text.trim() !== ""
    readonly property int rowHeight: 36
    readonly property int resultHeight: 46
    property int current: 0              // highlighted result, for the keyboard

    signal opened(string url)
    signal added(string entry)
    signal removed(string key)
    signal toggled(string key)           // shown in the panel ↔ hidden from it
    signal switched(int index)
    signal listAdded(string name)
    signal listRenamed(int index, string name)
    signal listRemoved(int index)
    signal moved(int from, int to)
    signal configure()
    signal noticeClicked()

    readonly property string statusText: searching ? tr("Searching…")
        : failed !== "" ? tr("No answer from %1; results from there are missing.").replace("%1", failed)
        : results.length === 0 ? tr("Nothing matches “%1”.").replace("%1", query.trim())
        : ""

    function focusSearch() { input.forceActiveFocus() }
    function clearSearch() { input.text = ""; editing = -1; doomed = -1 }

    function tint(change) {
        const colour = change >= 0 ? up : down
        return colour === "" ? textColor : colour
    }

    onResultsChanged: if (current >= results.length) current = 0

    // Height the content would need; main.qml caps the popup, and the lists scroll beyond that.
    readonly property int bodyHeight: typing
        ? results.length * resultHeight + (statusText !== "" ? 34 : 0)
        : 6 + tabs.height + (rows.length ? rows.length * rowHeight + 26 : hint.height)
    implicitWidth: 380
    implicitHeight: 10 + field.height + 8 + banner.height + bodyHeight + 12 + footer.height

    // ---- footer: name, connection state and settings, kept quiet ----
    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 30

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
            height: 1
            color: list.textColor
            opacity: 0.08
        }
        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text: "Tickr"
                color: list.textColor
                opacity: 0.4
                font.family: list.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: !list.online
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: "#f87171"
            }
            Text {
                visible: !list.online
                text: list.tr("offline")
                color: list.textColor
                opacity: 0.4
                font.family: list.fontFamily
                font.pixelSize: 11
            }
        }
        Link {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: list.tr("Settings")
            onClicked: list.configure()
        }
    }

    // ---- search box ----
    Rectangle {
        id: field
        anchors { top: parent.top; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        height: 34
        radius: 8
        color: Qt.alpha(list.textColor, 0.06)
        border.width: 1
        border.color: input.activeFocus ? Qt.alpha(list.highlightColor, 0.8) : Qt.alpha(list.textColor, 0.1)

        Kirigami.Icon {
            id: glass
            anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
            width: 16; height: 16
            source: "search"
            color: list.textColor
            opacity: 0.5
        }
        TextInput {
            id: input
            anchors { left: glass.right; right: clear.left; leftMargin: 8; rightMargin: 6; verticalCenter: parent.verticalCenter }
            color: list.textColor
            selectionColor: list.highlightColor
            font.family: list.fontFamily
            font.pixelSize: 13
            clip: true
            onTextChanged: list.current = 0

            Keys.onDownPressed: if (list.typing) list.current = Math.min(list.current + 1, list.results.length - 1)
            Keys.onUpPressed: if (list.typing) list.current = Math.max(list.current - 1, 0)
            Keys.onReturnPressed: list.addCurrent()
            Keys.onEnterPressed: list.addCurrent()
            Keys.onEscapePressed: event => {
                if (text === "") { event.accepted = false; return }      // let Plasma close the popup
                text = ""
            }

            Text {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: list.tr("Add a coin, perp or token…")
                color: list.textColor
                opacity: 0.4
                font: input.font
            }
        }
        MouseArea {
            id: clear
            visible: input.text !== ""
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            width: visible ? 22 : 0; height: 22
            cursorShape: Qt.PointingHandCursor
            onClicked: { input.text = ""; input.forceActiveFocus() }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 14; height: 14
                source: "window-close-symbolic"
                color: list.textColor
                opacity: clear.containsMouse ? 0.9 : 0.5
            }
        }
    }

    function addCurrent() {
        const pick = results[current]
        if (typing && pick && !pick.added) added(pick.entry)
    }

    // ---- update notice ----
    Rectangle {
        id: banner
        anchors { top: field.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        visible: list.notice !== "" && !list.typing
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

    // ---- the lists: click to switch, double-click to rename, + for a new one; × on the list on
    // show removes it, after asking when it holds coins ----
    property int editing: -1                      // list being named; lists.length for a new one
    property int doomed: -1                       // list the dialog asks about, -1 if none

    // × is only on the list on show, so `rows` are the coins that would go with it.
    function askRemove(index) {
        if (rows.length === 0) { listRemoved(index); return }
        doomed = index
        confirm.forceActiveFocus()
    }
    function answerRemove(yes) {
        const index = doomed
        doomed = -1
        input.forceActiveFocus()
        if (yes && index >= 0) listRemoved(index)
    }

    function edit(index) {
        editing = index
        nameInput.text = lists[index] || ""
        nameInput.selectAll()
        nameInput.forceActiveFocus()
    }
    function commitName() {
        const name = nameInput.text.trim()
        const index = editing
        editing = -1
        input.forceActiveFocus()
        if (name === "") return
        if (index < lists.length) listRenamed(index, name)
        else listAdded(name)
    }

    Item {
        id: tabs
        visible: !list.typing
        anchors { top: banner.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
        height: visible ? 24 : 0

        ListView {
            id: tabView
            visible: list.editing < 0
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: list.lists.length + 1          // one tab per list, then +
            currentIndex: list.active
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: MouseArea {
                id: tab
                required property int index
                readonly property bool adder: index === list.lists.length
                readonly property bool current: index === list.active
                readonly property bool closable: current && list.lists.length > 1
                readonly property bool hovered: containsMouse || drop.containsMouse
                width: title.implicitWidth + 16 + (closable ? 14 : 0)
                height: ListView.view.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: adder ? list.edit(index) : list.switched(index)
                onDoubleClicked: if (!adder) list.edit(index)

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: tab.current ? Qt.alpha(list.highlightColor, 0.25) : Qt.alpha(list.textColor, tab.hovered ? 0.1 : 0)
                }
                Text {
                    id: title
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.adder ? "+" : list.lists[tab.index] || list.tr("Main")
                    color: list.textColor
                    opacity: tab.current || tab.hovered ? 1 : 0.6
                    font.family: list.fontFamily
                    font.pixelSize: 12
                    font.weight: tab.current ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: drop
                    visible: tab.closable
                    anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                    width: 16; height: 16
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.askRemove(tab.index)
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: "window-close-symbolic"
                        color: drop.containsMouse ? "#f87171" : list.textColor
                        opacity: drop.containsMouse ? 1 : 0.5
                    }
                }
            }
        }

        // Naming a list takes the place of the tabs: Enter keeps the name, Escape drops it.
        Rectangle {
            visible: list.editing >= 0
            anchors.fill: parent
            radius: 6
            color: Qt.alpha(list.textColor, 0.06)
            border.width: 1
            border.color: Qt.alpha(list.highlightColor, 0.8)

            TextInput {
                id: nameInput
                anchors { left: parent.left; right: cancel.left; leftMargin: 8; rightMargin: 6; verticalCenter: parent.verticalCenter }
                color: list.textColor
                selectionColor: list.highlightColor
                font.family: list.fontFamily
                font.pixelSize: 12
                maximumLength: 24
                clip: true
                Keys.onReturnPressed: list.commitName()
                Keys.onEnterPressed: list.commitName()
                Keys.onEscapePressed: { list.editing = -1; input.forceActiveFocus() }
                // Clicking or typing elsewhere drops the name, so the field never lingers unfocused.
                onActiveFocusChanged: if (!activeFocus) list.editing = -1

                Text {
                    visible: nameInput.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: list.tr("List name, then Enter")
                    color: list.textColor
                    opacity: 0.4
                    font: nameInput.font
                }
            }
            MouseArea {
                id: cancel
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 18; height: 18
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { list.editing = -1; input.forceActiveFocus() }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    source: "window-close-symbolic"
                    color: list.textColor
                    opacity: cancel.containsMouse ? 0.9 : 0.5
                }
            }
        }
    }

    Text {
        id: hint
        visible: !list.typing && list.rows.length === 0
        anchors { top: tabs.bottom; left: parent.left; right: parent.right }
        height: visible ? 56 : 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: list.tr("No coins in this list yet. Search above to add one.")
        color: list.textColor
        opacity: 0.5
        font.family: list.fontFamily
        font.pixelSize: 11
    }

    // ---- the ticker's coins: click for the chart, drag a row to reorder, the eye to keep a coin
    // out of the panel, × to remove ----
    // While a row is dragged, `order` holds the positions as they will be after the drop, so the
    // list rearranges live; the change is committed once, on release.
    property var order: null
    property int dragging: -1                     // original index of the dragged row, -1 if none
    readonly property var shown: order ? order.map(i => rows[i]) : rows

    function startDrag(index) {
        const positions = []
        for (let i = 0; i < rows.length; i++) positions.push(i)
        order = positions
        dragging = index
    }
    function dragTo(slot) {
        if (dragging < 0) return
        const next = order.filter(i => i !== dragging)
        next.splice(Math.max(0, Math.min(slot, rows.length - 1)), 0, dragging)
        order = next
    }
    function endDrag() {
        const to = order ? order.indexOf(dragging) : -1
        const from = dragging
        order = null
        dragging = -1
        if (from >= 0 && to >= 0 && to !== from) moved(from, to)
    }

    // Column widths shared by the headers and the rows, so they line up.
    readonly property int priceWidth: 92
    readonly property int changeWidth: 58
    readonly property int buttonWidth: 20

    RowLayout {
        id: columns
        visible: !list.typing && list.rows.length > 0
        anchors { top: tabs.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 8 }
        height: visible ? 18 : 0
        spacing: 8
        ColumnTitle { text: list.tr("Ticker"); Layout.fillWidth: true }
        ColumnTitle { text: list.tr("Price"); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: list.priceWidth }
        ColumnTitle { text: list.tr("24h"); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: list.changeWidth }
        Item { Layout.preferredWidth: 2 * list.buttonWidth }
    }

    ListView {
        id: coinView
        visible: !list.typing
        anchors { top: columns.bottom; topMargin: 2; left: parent.left; right: parent.right; bottom: footer.top; bottomMargin: 4 }
        clip: true
        interactive: list.dragging < 0
        boundsBehavior: Flickable.StopAtBounds
        // Keyed by position, so a refresh does not rebuild the rows or lose the hover and scroll.
        model: list.shown.length

        delegate: MouseArea {
            id: line
            required property int index
            readonly property var row: list.shown[index] || {}
            readonly property bool lifted: list.order !== null && list.order[index] === list.dragging
            readonly property bool hovered: containsMouse || toggle.containsMouse || remove.containsMouse
            property real pressY: 0
            property bool dragged: false
            width: ListView.view.width
            height: list.rowHeight
            hoverEnabled: true
            // The whole row drags: a press that moves more than a few pixels picks the row up,
            // one that does not is a click and opens the chart. Stays enabled without a chart
            // link, so a coin that is not trading can still be moved or removed.
            preventStealing: true
            cursorShape: list.dragging >= 0 ? Qt.ClosedHandCursor : row.url ? Qt.PointingHandCursor : Qt.OpenHandCursor
            onPressed: mouse => { pressY = mouse.y; dragged = false }
            onPositionChanged: mouse => {
                if (!pressed) return
                if (!dragged && Math.abs(mouse.y - pressY) > 6) { dragged = true; list.startDrag(index) }
                if (dragged) list.dragTo(Math.floor(mapToItem(coinView.contentItem, mouse.x, mouse.y).y / list.rowHeight))
            }
            onReleased: if (dragged) list.endDrag()
            onCanceled: if (dragged) list.endDrag()
            onClicked: if (!dragged && row.url) list.opened(row.url)

            Hover { shown: (line.hovered && list.dragging < 0) || line.lifted }

            // Grip: only a hint that the row can be dragged.
            Text {
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                text: "⠿"
                color: list.textColor
                opacity: line.hovered || line.lifted ? 0.45 : 0
                font.pixelSize: 13
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 8 }
                spacing: 8
                opacity: line.row.stale || line.row.hidden ? 0.45 : 1

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
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: list.priceWidth
                }
                Text {
                    text: line.row.changeText || ""
                    color: list.tint(line.row.change)
                    font.family: list.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: list.changeWidth
                }
                // Hide and remove: always shown, faint until the pointer is on them.
                Row {
                    Layout.preferredWidth: 2 * list.buttonWidth
                    Layout.preferredHeight: 20

                    MouseArea {
                        id: toggle
                        width: list.buttonWidth; height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: list.dragging < 0
                        onClicked: list.toggled(line.row.key)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            source: line.row.hidden ? "view-hidden-symbolic" : "view-visible-symbolic"
                            color: toggle.containsMouse ? list.highlightColor : list.textColor
                            opacity: list.dragging >= 0 ? 0 : toggle.containsMouse ? 1 : 0.5
                        }
                    }
                    MouseArea {
                        id: remove
                        width: list.buttonWidth; height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: list.dragging < 0
                        onClicked: list.removed(line.row.key)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            source: "window-close-symbolic"
                            color: remove.containsMouse ? "#f87171" : list.textColor
                            opacity: list.dragging >= 0 ? 0 : remove.containsMouse ? 1 : 0.5
                        }
                    }
                }
            }
        }

        Scrollbar { view: coinView }
    }

    // ---- search results ----
    ListView {
        id: resultView
        visible: list.typing
        anchors { top: banner.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: footer.top; bottomMargin: 4 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: list.results
        currentIndex: list.current
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: MouseArea {
            id: hit
            required property var modelData
            required property int index
            width: ListView.view.width
            height: list.resultHeight
            hoverEnabled: true
            enabled: !modelData.added
            cursorShape: Qt.PointingHandCursor
            onClicked: list.added(modelData.entry)
            onContainsMouseChanged: if (containsMouse) list.current = index

            Hover { shown: list.current === hit.index && !hit.modelData.added }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10
                opacity: hit.modelData.added ? 0.5 : 1

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Row {
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hit.modelData.title
                            color: list.textColor
                            font.family: list.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        SourceBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            tag: hit.modelData.tag
                            chain: hit.modelData.chain
                            textColor: list.textColor
                            fontFamily: list.fontFamily
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: hit.modelData.subtitle
                        color: list.textColor
                        opacity: 0.5
                        elide: Text.ElideRight
                        font.family: list.fontFamily
                        font.pixelSize: 11
                    }
                }
                Text {
                    visible: hit.modelData.price > 0
                    text: "$" + hit.modelData.priceText
                    color: list.textColor
                    opacity: 0.85
                    font.family: list.fontFamily
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }
                Kirigami.Icon {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    source: hit.modelData.added ? "checkmark" : "list-add"
                    color: list.textColor
                }
            }
        }

        footer: Text {
            id: status
            visible: text !== ""
            width: ListView.view ? ListView.view.width : 0
            height: visible ? implicitHeight : 0
            topPadding: 8
            bottomPadding: 8
            leftPadding: 14
            rightPadding: 14
            wrapMode: Text.Wrap
            horizontalAlignment: list.results.length ? Text.AlignLeft : Text.AlignHCenter
            color: list.textColor
            opacity: 0.5
            font.family: list.fontFamily
            font.pixelSize: 11
            text: list.statusText
        }

        Scrollbar { view: resultView }
    }

    // ---- asks before a list and its coins go: covers the popup, so nothing under it reacts ----
    MouseArea {
        id: confirm
        visible: list.doomed >= 0
        anchors.fill: parent
        z: 10
        hoverEnabled: true
        preventStealing: true
        onClicked: list.answerRemove(false)
        onWheel: wheel => wheel.accepted = true
        Keys.onEscapePressed: list.answerRemove(false)
        Keys.onReturnPressed: list.answerRemove(true)
        Keys.onEnterPressed: list.answerRemove(true)

        Rectangle { anchors.fill: parent; color: Qt.alpha(list.backgroundColor, 0.8) }

        MouseArea {                               // a click on the card does not dismiss it
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 300)
            height: card.implicitHeight + 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.tint(list.backgroundColor, Qt.alpha(list.textColor, 0.06))
                border.width: 1
                border.color: Qt.alpha(list.textColor, 0.15)
            }
            ColumnLayout {
                id: card
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: list.tr("Delete “%1”?").replace("%1", list.lists[list.doomed] || list.tr("Main"))
                    color: list.textColor
                    elide: Text.ElideRight
                    font.family: list.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: list.rows.length === 1 ? list.tr("Its coin goes with it. This cannot be undone.")
                        : list.tr("Its %1 coins go with it. This cannot be undone.").replace("%1", list.rows.length)
                    color: list.textColor
                    opacity: 0.6
                    wrapMode: Text.Wrap
                    font.family: list.fontFamily
                    font.pixelSize: 12
                }
                RowLayout {
                    Layout.topMargin: 10
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    Button { text: list.tr("Cancel"); onClicked: list.answerRemove(false) }
                    Button { text: list.tr("Delete"); danger: true; onClicked: list.answerRemove(true) }
                }
            }
        }
    }

    // Button of the dialog: quiet by default, red for the one that deletes.
    component Button: MouseArea {
        id: button
        property alias text: caption.text
        property bool danger: false
        implicitWidth: caption.implicitWidth + 24
        implicitHeight: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: button.danger ? Qt.alpha("#f87171", button.containsMouse ? 1 : 0.85)
                : Qt.alpha(list.textColor, button.containsMouse ? 0.16 : 0.08)
        }
        Text {
            id: caption
            anchors.centerIn: parent
            color: button.danger ? "#1b1d22" : list.textColor
            font.family: list.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    // Thin scrollbar that shows only when the list is longer than the popup.
    component Scrollbar: Rectangle {
        required property Flickable view
        visible: view.contentHeight > view.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 4
        radius: 2
        y: view.visibleArea.yPosition * view.height
        height: Math.max(24, view.visibleArea.heightRatio * view.height)
        color: list.textColor
        opacity: 0.25
    }

    // Small caps label above a column.
    component ColumnTitle: Text {
        color: list.textColor
        opacity: 0.4
        font.family: list.fontFamily
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    // Rounded hover background for a row.
    component Hover: Rectangle {
        property bool shown: false
        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
        radius: 6
        color: list.highlightColor
        opacity: shown ? 0.18 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
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
