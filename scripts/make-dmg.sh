#!/bin/zsh
# Packages an .app into a compressed drag-to-install DMG plus a SHA-256 file.
# Usage: scripts/make-dmg.sh <path/to/App.app> <path/to/out.dmg> <volume name>
set -euo pipefail

app=$1
dmg=$2
volume=$3

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

mkdir -p "${dmg:h}"
rm -f "$dmg" "$dmg.sha256"
hdiutil create -volname "$volume" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
(cd "${dmg:h}" && shasum -a 256 "${dmg:t}" > "${dmg:t}.sha256")
echo "Created $dmg"
