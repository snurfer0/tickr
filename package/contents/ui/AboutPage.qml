import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// About: version and updates, where prices come from, links, and the way into Plasma's own dialog
// for the keyboard shortcut.
ColumnLayout {
    id: page

    required property var config
    required property var updater
    readonly property string website: "https://github.com/snurfer0/tickr"

    signal shortcutRequested()

    function set(key, value) {
        config[key] = value
        if (config.writeConfig) config.writeConfig()
    }

    spacing: Kirigami.Units.largeSpacing

    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Image {
            source: Qt.resolvedUrl("../icons/tickr.svg")
            sourceSize: Qt.size(64, 64)
        }
        ColumnLayout {
            spacing: 0
            Kirigami.Heading { level: 2; text: "Tickr" }
            QQC2.Label { opacity: 0.6; text: i18n("Version %1", page.updater.current) }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: i18n("Crypto prices in the panel: majors, perpetuals and on-chain tokens. No account and no API keys.")
    }

    // ---- updates ----
    Kirigami.Heading { level: 4; text: i18n("Updates") }
    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        QQC2.BusyIndicator {
            visible: page.updater.busy
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                const release = page.updater.release
                switch (page.updater.status) {
                case "checking": return i18n("Checking for updates…")
                case "latest": return i18n("You have the latest version.")
                case "available": return i18n("Version %1 is available.", release.version)
                case "installing": return i18n("Installing version %1…", release.version)
                case "installed": return i18n("Version %1 is installed. It loads the next time Plasma starts.", release.version)
                case "failed": return i18n("The update did not work. Check the connection, or install it from the release page.")
                default: return i18n("Not checked yet.")
                }
            }
        }
    }
    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        QQC2.Button {
            visible: page.updater.status === "available" || page.updater.status === "failed" && page.updater.release !== null
            icon.name: "update-none"
            text: i18n("Install update")
            onClicked: page.updater.install()
        }
        QQC2.Button {
            visible: page.updater.status === "installed"
            icon.name: "view-refresh"
            text: i18n("Restart Plasma now")
            onClicked: page.updater.restartPlasma()
        }
        QQC2.Button {
            visible: page.updater.status !== "installed"
            enabled: !page.updater.busy
            icon.name: "view-refresh"
            text: i18n("Check now")
            onClicked: page.updater.check(true)
        }
        QQC2.Button {
            visible: page.updater.release !== null
            icon.name: "documentinfo"
            text: i18n("What's new")
            onClicked: Qt.openUrlExternally(page.updater.release.page)
        }
    }
    QQC2.CheckBox {
        text: i18n("Check for updates every few hours")
        checked: page.config.checkUpdates
        onToggled: page.set("checkUpdates", checked)
    }
    QQC2.CheckBox {
        enabled: page.config.checkUpdates
        text: i18n("Install updates automatically")
        checked: page.config.autoUpdate
        onToggled: page.set("autoUpdate", checked)
    }
    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        opacity: 0.6
        font: Kirigami.Theme.smallFont
        text: i18n("Updates come from the project's GitHub releases and are checked against their SHA-256 before installing. If you installed Tickr from the KDE Store, Discover updates it as well.")
    }

    // ---- sources ----
    Kirigami.Heading { level: 4; text: i18n("Where prices come from") }
    Repeater {
        model: [
            { tag: "SPOT", what: i18n("Spot pairs, every refresh") },
            { tag: "PERP", what: i18n("Perpetuals with funding, every refresh") },
            { tag: "DEX", what: i18n("Any on-chain token, every 30 seconds at most") }
        ]
        RowLayout {
            id: line
            required property var modelData
            spacing: Kirigami.Units.largeSpacing
            SourceBadge { tag: line.modelData.tag; textColor: Kirigami.Theme.textColor; Layout.preferredWidth: 96 }
            QQC2.Label { text: line.modelData.what; opacity: 0.8 }
        }
    }
    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        opacity: 0.6
        font: Kirigami.Theme.smallFont
        text: i18n("Tickr contacts only these three services for prices, only for the coins you picked and for what you type in the search, plus GitHub when it checks for updates. It sends no identifiers and has no analytics.")
    }

    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        QQC2.Button {
            icon.name: "internet-services"
            text: i18n("Website")
            onClicked: Qt.openUrlExternally(page.website)
        }
        QQC2.Button {
            icon.name: "tools-report-bug"
            text: i18n("Report a problem")
            onClicked: Qt.openUrlExternally(page.website + "/issues")
        }
        QQC2.Button {
            icon.name: "preferences-desktop-keyboard"
            text: i18n("Keyboard shortcut…")
            onClicked: page.shortcutRequested()
        }
    }
}
