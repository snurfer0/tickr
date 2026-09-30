import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "tickr.mjs" as Tickr

// Looks for a newer release on GitHub every few hours and, when allowed, installs it. The new
// version is loaded the next time Plasma starts; restartPlasma() does that at once.
Item {
    id: updater

    required property var config
    property string current: "0.0.0"

    property var release: null          // a newer release, once found
    property string status: "idle"      // idle | checking | latest | available | installing | installed | failed
    readonly property bool busy: status === "checking" || status === "installing"

    function check(force) {
        if (busy || status === "installed") return
        const last = Number(config.lastUpdateCheck) || 0
        if (!force && Date.now() - last < Tickr.CHECK_EVERY_MS) return
        status = "checking"
        Tickr.request(Tickr.RELEASE_URL, "", (code, json) => {
            config.lastUpdateCheck = String(Date.now())
            const found = code === 200 ? Tickr.decodeRelease(json) : null
            if (code !== 200 && code !== 404) { status = "failed"; return }
            if (!found || !Tickr.isNewer(found.version, current)) { release = null; status = "latest"; return }
            release = found
            status = "available"
            if (config.autoUpdate) install()
        })
    }

    function install() {
        if (!release || busy) return
        status = "installing"
        // A unique comment keeps the data engine from answering with a cached earlier run.
        shell.connectSource(Tickr.installCommand(release) + " #" + Date.now())
    }

    function restartPlasma() {
        shell.connectSource("systemctl --user restart plasma-plasmashell.service #" + Date.now())
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (updater.status !== "installing") return
            updater.status = String(data.stdout).indexOf("TICKR_UPDATED") >= 0 ? "installed" : "failed"
        }
    }

    // First look a minute after login, when the network is up; then hourly, which check() limits
    // to one request every few hours.
    Timer {
        interval: 60 * 1000
        running: updater.config.checkUpdates
        onTriggered: { updater.check(false); interval = 60 * 60 * 1000; restart() }
    }
}
