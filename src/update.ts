// Update check against the project's GitHub releases. Installs from the KDE Store are updated by
// Plasma itself (Discover, Get New Widgets); this covers installs from a release file or source.
import { isRecord, toText } from "./json.ts"

export const REPOSITORY = "snurfer0/tickr"
export const RELEASE_URL = `https://api.github.com/repos/${REPOSITORY}/releases/latest`
/** Checked at most this often; GitHub allows 60 unauthenticated API calls an hour per IP. */
export const CHECK_EVERY_MS = 6 * 60 * 60 * 1000

export interface Release {
    version: string
    /** The `.plasmoid` attached to the release. */
    download: string
    /** Lowercase hex SHA-256 of that file, as GitHub records it. */
    sha256: string
    page: string
}

const VERSION = /^\d+\.\d+\.\d+$/

/**
 * Reads GitHub's latest-release answer. Only a release whose file sits where this project's release
 * workflow puts it, with a checksum GitHub computed, is accepted: the download is later handed to a
 * shell, so nothing in it may be free-form.
 */
export function decodeRelease(json: unknown): Release | null {
    if (!isRecord(json) || json.draft === true || json.prerelease === true) return null
    const version = toText(json.tag_name).replace(/^v/, "")
    if (!VERSION.test(version) || !Array.isArray(json.assets)) return null
    const expected = `https://github.com/${REPOSITORY}/releases/download/v${version}/tickr-${version}.plasmoid`
    for (const asset of json.assets as unknown[]) {
        if (!isRecord(asset) || toText(asset.browser_download_url) !== expected) continue
        const digest = /^sha256:([0-9a-f]{64})$/.exec(toText(asset.digest))
        if (digest === null || digest[1] === undefined) return null
        return {
            version,
            download: expected,
            sha256: digest[1],
            page: `https://github.com/${REPOSITORY}/releases/tag/v${version}`,
        }
    }
    return null
}

/** True when `candidate` is a later x.y.z version than `current`. */
export function isNewer(candidate: string, current: string): boolean {
    const a = candidate.split(".").map(Number)
    const b = current.split(".").map(Number)
    for (let i = 0; i < 3; i++) {
        const x = a[i] ?? 0
        const y = b[i] ?? 0
        if (Number.isNaN(x) || Number.isNaN(y)) return false
        if (x !== y) return x > y
    }
    return false
}

/**
 * Shell command that downloads the release, checks its SHA-256 and upgrades the installed widget.
 * Every value in it was validated by `decodeRelease`, so it needs no further quoting. Prints
 * `TICKR_UPDATED` on success; anything else means it failed and nothing was changed.
 */
export function installCommand(release: Release): string {
    const file = `"\${XDG_CACHE_HOME:-$HOME/.cache}/tickr-${release.version}.plasmoid"`
    return [
        `curl -fsSL --max-time 120 -o ${file} '${release.download}'`,
        `echo '${release.sha256}  '${file} | sha256sum -c --status`,
        `kpackagetool6 -t Plasma/Applet -u ${file}`,
        "echo TICKR_UPDATED",
    ].join(" && ")
}
