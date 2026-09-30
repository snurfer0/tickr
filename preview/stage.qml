import QtQuick
import org.kde.kirigami as Kirigami

// Backdrop for settings.py: a settings page is parented in here and stretched to fit.
Rectangle {
    property Item page
    color: Kirigami.Theme.backgroundColor
    onPageChanged: if (page) { page.anchors.fill = this }
}
