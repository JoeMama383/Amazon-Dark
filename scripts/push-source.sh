#!/bin/sh
# Run this from the freshly extracted source ZIP on the phone.
set -eu
STAGE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=/var/mobile/Amazon-Dark-phone
grep -qx 'Version: 7.644~static-style-delivery' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.644-static-style-delivery"' "$STAGE/src/Tweak.xm"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null
[ "$STAGE" != "$REPO" ] || { echo 'Run the helper from the extracted ad7644 source folder.' >&2; exit 1; }
rm -f "$REPO/src/ADMenuRepair7620.js" "$REPO/src/ADMenuRepair7620.js.inc"
cp -a "$STAGE/." "$REPO/"
cd "$REPO"
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.644: separate style sources and remove hot-route runtime work'; fi
git push origin main
