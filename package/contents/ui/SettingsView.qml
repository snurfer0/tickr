pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Everything inside the settings window: a section switcher and three scrollable pages.
Rectangle {
    id: view

    required property var config
    required property var updater
    property int section: 0

    signal shortcutRequested()

    function focusSearch() { if (section === 0) coins.focusSearch() }

    readonly property var sections: [
        { name: i18n("Coins"), icon: Qt.resolvedUrl("../icons/coins.svg") },
        { name: i18n("Appearance"), icon: Qt.resolvedUrl("../icons/appearance.svg") },
        { name: i18n("About"), icon: Qt.resolvedUrl("../icons/tickr.svg") }
    ]

    color: Kirigami.Theme.backgroundColor
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Section switcher: a rounded track with a pill that slides under the chosen section.
        Item {
            Layout.fillWidth: true
            implicitHeight: track.height + Kirigami.Units.largeSpacing * 2

            Rectangle {
                id: track
                anchors.centerIn: parent
                width: segments.width + 8
                height: segments.height + 8
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

                Rectangle {
                    readonly property Item target: segments.children[view.section] || null
                    x: segments.x + (target ? target.x : 0)
                    y: segments.y
                    width: target ? target.width : 0
                    height: segments.height
                    radius: height / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.13)
                    border.width: 1
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: segments
                    anchors.centerIn: parent

                    Repeater {
                        model: view.sections

                        MouseArea {
                            id: segment
                            required property var modelData
                            required property int index
                            readonly property bool current: view.section === index
                            width: label.implicitWidth + Kirigami.Units.largeSpacing * 3
                            height: label.implicitHeight + Kirigami.Units.smallSpacing * 3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.section = index

                            Row {
                                id: label
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing * 2
                                opacity: segment.current ? 1 : segment.containsMouse ? 0.85 : 0.6
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Kirigami.Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: segment.modelData.icon
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                }
                                QQC2.Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.modelData.name
                                    font.weight: segment.current ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: view.section

            Page { CoinsPage { id: coins; config: view.config; Layout.fillWidth: true } }
            Page { AppearancePage { config: view.config; Layout.fillWidth: true } }
            Page {
                AboutPage {
                    config: view.config
                    updater: view.updater
                    Layout.fillWidth: true
                    onShortcutRequested: view.shortcutRequested()
                }
            }
        }
    }

    // A scrollable page with even margins; its content is laid out top to bottom.
    component Page: QQC2.ScrollView {
        id: page
        default property alias content: column.data
        contentWidth: availableWidth
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        Item {
            width: page.availableWidth
            implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 4
            ColumnLayout {
                id: column
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.largeSpacing * 2 }
            }
        }
    }
}
