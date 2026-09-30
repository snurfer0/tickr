import QtQuick
import org.kde.kirigami as Kirigami

// Tickr's own settings window. Changes apply as they are made, so there is nothing to confirm:
// close it when done.
Window {
    id: window

    required property var config
    required property var updater

    signal shortcutRequested()

    function open(section) {
        view.section = section
        show()
        raise()
        requestActivate()
    }

    title: i18n("Tickr Settings")
    width: 620
    height: 720
    minimumWidth: 480
    minimumHeight: 420
    color: Kirigami.Theme.backgroundColor

    SettingsView {
        id: view
        anchors.fill: parent
        config: window.config
        updater: window.updater
        onShortcutRequested: window.shortcutRequested()
    }

    Shortcut { sequences: [StandardKey.Close, "Escape"]; onActivated: window.close() }
}
