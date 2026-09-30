#!/bin/sh
# Builds dist/tickr-<version>.plasmoid: the file the KDE Store and `kpackagetool6 -i` take.
cd "$(dirname "$0")/.." || exit 1
version=$(sed -n 's/.*"version": "\(.*\)".*/\1/p' package.json | head -1)
packaged=$(sed -n 's/.*"Version": "\(.*\)".*/\1/p' package/metadata.json | head -1)
if [ "$version" != "$packaged" ]; then
    echo "version mismatch: package.json $version, metadata.json $packaged" >&2
    exit 1
fi
bun run build >/dev/null || exit 1
mkdir -p dist && rm -f "dist/tickr-$version.plasmoid"
(cd package && zip -qr "../dist/tickr-$version.plasmoid" . -x '*.bak' '.*') || exit 1
echo "dist/tickr-$version.plasmoid"
