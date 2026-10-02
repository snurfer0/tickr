#!/usr/bin/python3
"""Loads the built bundle in a real QML engine (the one Plasma uses) and calls it.
Bun does not rewrite newer syntax for older engines, so this proves the bundle actually runs there."""
import os
import sys

os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PyQt6.QtCore import QCoreApplication, QUrl  # noqa: E402
from PyQt6.QtQml import QQmlComponent, QQmlEngine  # noqa: E402

ui = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "package", "contents", "ui")
QML = b"""
import QtQml
import "tickr.mjs" as Tickr

QtObject {
    property var coins: Tickr.parseCoins("BTC, hl:PEPE, dex:solana:abc = X")
    property string keys: coins.map(c => c.key).join(" ")
    property string url: Tickr.binanceUrl(Tickr.bySource(coins, "binance"))
    property string small: Tickr.price(0.000003883)
    property string big: Tickr.price(83758.5)
    property string pct: Tickr.percent(-12.34)
    property real spot: Tickr.decodeBinance({ symbol: "BTCUSDT", lastPrice: "5", priceChangePercent: "1" }, Date.now())["binance:BTCUSDT"].price
    property string perp: Tickr.decodeHyperliquid(
        [{ universe: [{ name: "kPEPE" }] }, [{ midPx: "0.004", prevDayPx: "0.002", funding: "0.00001" }]],
        Tickr.bySource(coins, "hl"))["hl:PEPE"].name
    property string body: Tickr.HYPERLIQUID_BODY
    property string lists: Tickr.parseLists(Tickr.addList("# [A]\\nBTC, !ETH\\n# [B]\\nhl:PEPE", "C"))
        .map(l => l.name + "=" + l.coins.split("\\n").join("+")).join(" ")
}
"""
EXPECT = {
    "keys": "binance:BTCUSDT hl:PEPE dex:solana:abc",
    "url": "https://data-api.binance.vision/api/v3/ticker/24hr?symbol=BTCUSDT",
    "small": "0.0₅3883",
    "big": "83,759",
    "pct": "−12.3%",
    "spot": 5.0,
    "perp": "kPEPE",
    "body": '{"type":"metaAndAssetCtxs"}',
    "lists": "A=BTC+!ETH B=hl:PEPE C=",
}

app = QCoreApplication(sys.argv[:1])
engine = QQmlEngine()
component = QQmlComponent(engine)
component.setData(QML, QUrl.fromLocalFile(os.path.join(ui, "inline.qml")))
obj = component.create()
if obj is None:
    for error in component.errors():
        print(error.toString(), file=sys.stderr)
    sys.exit(1)

failed = 0
for name, want in EXPECT.items():
    got = obj.property(name)
    if got != want:
        failed += 1
        print(f"FAIL {name}: {got!r} != {want!r}", file=sys.stderr)
print("qml engine: bundle loads, %d of %d values correct" % (len(EXPECT) - failed, len(EXPECT)))
sys.exit(1 if failed else 0)
