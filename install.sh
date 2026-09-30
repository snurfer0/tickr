#!/bin/sh
# Builds the bundle and installs or upgrades the widget for this user.
# A running plasmashell keeps the old version of an already-loaded widget until it restarts.
cd "$(dirname "$0")" || exit 1
bun install --frozen-lockfile >/dev/null && bun run build >/dev/null || exit 1
kpackagetool6 -t Plasma/Applet -u package >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i package >/dev/null || exit 1
echo "Tickr installed. Add it with: right-click the panel → Add Widgets → Tickr"
