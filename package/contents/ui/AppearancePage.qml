pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQC
import "tickr.mjs" as Tickr

// Appearance: a live preview of the panel strip on top, everything that shapes it below.
// Controls read the configuration and write it back the moment they change.
ColumnLayout {
    id: page

    required property var config        // the widget's configuration (Plasmoid.configuration)

    readonly property var colors: Tickr.schemeColors(config.scheme, config.upColor, config.downColor)
    readonly property var families: [i18n("Same as the panel")].concat(Qt.fontFamilies())

    readonly property var sample: [
        { label: "BTC", price: "84,005", change: 0.35, changeText: "+0.35%", known: true, stale: false, tick: 0 },
        { label: "ETH", price: "2,725.41", change: -0.69, changeText: "−0.69%", known: true, stale: false, tick: 0 },
        { label: "SOL", price: "121.25", change: 2.2, changeText: "+2.20%", known: true, stale: false, tick: 0 },
        { label: "WIF", price: "0.2536", change: -5.55, changeText: "−5.55%", known: true, stale: false, tick: 0 }
    ]

    function set(key, value) {
        if (config[key] === value) return
        config[key] = value
        if (config.writeConfig) config.writeConfig()
    }

    spacing: Kirigami.Units.largeSpacing

    // ---- preview ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.alternateBackgroundColor
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        clip: true

        PanelRow {
            anchors.centerIn: parent
            width: implicitWidth
            height: parent.height
            cursorShape: Qt.ArrowCursor
            rows: page.sample
            textColor: Kirigami.Theme.textColor
            up: page.colors.up
            down: page.colors.down
            fontFamily: page.config.fontFamily || Kirigami.Theme.defaultFont.family
            fontSize: page.config.fontSize
            bold: page.config.bold
            gap: page.config.spacing
            showLabel: page.config.showLabel
            showChange: page.config.showChange
            flash: false
        }
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        // ---- colours ----
        Flow {
            Kirigami.FormData.label: i18n("Colors:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: Tickr.SCHEMES

                Rectangle {
                    id: swatch
                    required property var modelData
                    readonly property var paint: Tickr.schemeColors(modelData.id, page.config.upColor, page.config.downColor)
                    readonly property bool selected: page.config.scheme === modelData.id
                    implicitWidth: chip.implicitWidth + Kirigami.Units.largeSpacing * 2
                    implicitHeight: chip.implicitHeight + Kirigami.Units.smallSpacing * 3
                    radius: Kirigami.Units.cornerRadius
                    color: selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                        : hover.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.08) : Qt.alpha(Kirigami.Theme.textColor, 0.04)
                    border.width: selected ? 2 : 1
                    border.color: selected ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)

                    Row {
                        id: chip
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        QQC2.Label { text: "▲"; color: swatch.paint.up || Kirigami.Theme.textColor }
                        QQC2.Label { text: "▼"; color: swatch.paint.down || Kirigami.Theme.textColor }
                        QQC2.Label { text: swatch.modelData.name }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.set("scheme", swatch.modelData.id)
                    }
                }
            }
        }
        RowLayout {
            visible: page.config.scheme === "custom"
            spacing: Kirigami.Units.largeSpacing
            QQC2.Label { text: i18n("Up") }
            KQC.ColorButton {
                color: page.config.upColor
                onAccepted: color => page.set("upColor", color.toString())
            }
            QQC2.Label { text: i18n("Down") }
            KQC.ColorButton {
                color: page.config.downColor
                onAccepted: color => page.set("downColor", color.toString())
            }
        }
        QQC2.CheckBox {
            text: i18n("Flash the price when it moves")
            checked: page.config.flash
            onToggled: page.set("flash", checked)
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- text ----
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Font:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            model: page.families
            currentIndex: Math.max(0, page.families.indexOf(page.config.fontFamily))
            onActivated: index => page.set("fontFamily", index === 0 ? "" : page.families[index])
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Size:")
            QQC2.Label { text: i18n("Small"); opacity: 0.6 }
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 9
                to: 24
                stepSize: 1
                snapMode: QQC2.Slider.SnapAlways
                value: page.config.fontSize
                onMoved: page.set("fontSize", Math.round(value))
            }
            QQC2.Label { text: i18n("Large"); opacity: 0.6 }
            QQC2.Label { text: i18n("%1 px", page.config.fontSize); opacity: 0.6; font.features: { "tnum": 1 } }
        }
        QQC2.CheckBox {
            text: i18n("Bold prices")
            checked: page.config.bold
            onToggled: page.set("bold", checked)
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Spacing:")
            QQC2.Label { text: i18n("Tight"); opacity: 0.6 }
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                from: 6
                to: 40
                stepSize: 2
                value: page.config.spacing
                onMoved: page.set("spacing", Math.round(value))
            }
            QQC2.Label { text: i18n("Wide"); opacity: 0.6 }
        }

        Item { Kirigami.FormData.isSection: true }

        // ---- what to show ----
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("Coin names")
            checked: page.config.showLabel
            onToggled: page.set("showLabel", checked)
        }
        QQC2.CheckBox {
            text: i18n("24 h change")
            checked: page.config.showChange
            onToggled: page.set("showChange", checked)
        }
        QQC2.ComboBox {
            readonly property var counts: [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20]
            Kirigami.FormData.label: i18n("Coins in the panel:")
            model: counts.map(n => n === 0 ? i18n("All of them") : i18n("The first %1", n))
            currentIndex: Math.max(0, counts.indexOf(page.config.panelCount))
            onActivated: index => page.set("panelCount", counts[index])
        }
        QQC2.Label {
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: i18n("The rest stay one click away in the list.")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            readonly property var seconds: [3, 5, 10, 15, 30, 60, 120, 300]
            Kirigami.FormData.label: i18n("Refresh every:")
            model: seconds.map(s => s < 60 ? i18n("%1 seconds", s) : s === 60 ? i18n("1 minute") : i18n("%1 minutes", s / 60))
            // A stored value that is not in the list shows as the nearest slower one.
            currentIndex: Math.max(0, seconds.findIndex(s => s >= page.config.interval))
            onActivated: index => page.set("interval", seconds[index])
        }
        QQC2.Label {
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: i18n("On-chain prices refresh every 30 s at most; DexScreener updates them no faster.")
        }
    }

}
