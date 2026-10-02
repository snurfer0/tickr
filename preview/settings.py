#!/usr/bin/python3
"""Render the settings view off-screen to a PNG, with live network so the search really runs.
Usage: settings.py out.png [section=0|1|2] [search=<text>] [height=<px>] [key=value ...]
  key=value overrides a stored setting (coins=BTC,ETH scheme=ocean)."""
import os
import sys

os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")

from PyQt6.QtCore import QTimer, QUrl  # noqa: E402
from PyQt6.QtQml import QQmlComponent, QQmlPropertyMap  # noqa: E402
from PyQt6.QtQuick import QQuickView  # noqa: E402
from PyQt6.QtWidgets import QApplication  # noqa: E402

out = sys.argv[1]
args = dict(a.split("=", 1) for a in sys.argv[2:])
ui = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "package", "contents", "ui")

app = QApplication(sys.argv[:1])
view = QQuickView()
engine = view.engine()
# Plasma provides i18n() to widgets; outside it, pass the text through and fill in %1.
engine.globalObject().setProperty("i18n", engine.evaluate(
    "(function (text) { for (var i = 1; i < arguments.length; i++) text = text.replace('%' + i, arguments[i]); return text })"))
view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(os.path.join(ui, "..", "..", "..", "preview", "stage.qml")))
view.resize(620, int(args.pop("height", "720")))

values = {"coins": "BTC, ETH, SOL", "scheme": "classic", "upColor": "#4ade80", "downColor": "#f87171",
          "fontFamily": "", "fontSize": 13, "bold": False, "spacing": 16, "showLabel": True,
          "showChange": True, "flash": True, "panelCount": 0, "list": 0, "interval": 10,
          "checkUpdates": True, "autoUpdate": True, "lastUpdateCheck": "0"}
section, search = int(args.pop("section", "0")), args.pop("search", None)
for key, value in args.items():
    kind = type(values[key])
    values[key] = value.lower() == "true" if kind is bool else kind(value)
# Stands in for Plasmoid.configuration: a property map the pages read and write.
config = QQmlPropertyMap()
for key, value in values.items():
    config.insert(key, value)

# Stands in for Updater.qml, which needs Plasma's data engines.
stub = QQmlComponent(engine)
stub.setData(b"""import QtQml
QtObject {
    property string current: "0.1.0"
    property var release: ({ version: "0.2.0", page: "" })
    property string status: "available"
    property bool busy: false
    function check(force) {}
    function install() {}
    function restartPlasma() {}
}""", QUrl())
updater = stub.create()

component = QQmlComponent(engine, QUrl.fromLocalFile(os.path.join(ui, "SettingsView.qml")))
item = component.createWithInitialProperties({"config": config, "updater": updater})
for error in component.errors():
    print(error.toString(), file=sys.stderr)
if item is None:
    sys.exit(1)
item.setParentItem(view.rootObject())
view.rootObject().setProperty("page", item)
item.setProperty("section", section)
view.show()


def find(node, name):
    """Depth-first over the visual tree: items made by Loaders are not QObject children."""
    if node.objectName() == name:
        return node
    for child in node.childItems():
        hit = find(child, name)
        if hit is not None:
            return hit
    return None


def drive():
    if search is not None:
        find(item, "search").setProperty("text", search)


def grab():
    view.grabWindow().save(out)
    print("coins:", repr(config.value("coins")), "scheme:", config.value("scheme"))
    app.quit()


QTimer.singleShot(2500, drive)
QTimer.singleShot(6000, grab)
app.exec()
