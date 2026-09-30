#!/usr/bin/python3
"""Render preview.qml off-screen to a PNG, to judge the design without touching plasmashell.
Usage: preview.py out.png"""
import os
import sys

os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")

from PyQt6.QtCore import QTimer, QUrl  # noqa: E402
from PyQt6.QtWidgets import QApplication  # noqa: E402
from PyQt6.QtQuick import QQuickView  # noqa: E402

here = os.path.dirname(os.path.abspath(__file__))
app = QApplication(sys.argv[:1])
view = QQuickView()
view.setSource(QUrl.fromLocalFile(os.path.join(here, "preview.qml")))
for error in view.errors():
    print(error.toString(), file=sys.stderr)
if view.status() != QQuickView.Status.Ready:
    sys.exit(1)
view.show()


def grab():
    view.grabWindow().save(sys.argv[1])
    app.quit()


QTimer.singleShot(600, grab)
app.exec()
